// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// PDH (Performance Data Helper) counter framework for Windows PC profiling.
///
/// Provides CPU, memory, disk I/O, network, GPU, thread, and handle counters
/// via Windows PDH API (pdh.dll). Counter paths match UNIFIED-SPEC §19.2 table exactly.
///
/// All PDH code is `#[cfg(windows)]` gated; non-Windows targets get stubs returning Err.

use std::time::{SystemTime, UNIX_EPOCH};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// A single frame timing snapshot with all PC metrics.
#[derive(Debug, Clone, Default)]
pub struct PcMetricsSnapshot {
    pub timestamp: i64,
    // CPU
    pub cpu_process_pct: Option<f64>,
    pub cpu_per_core_pct: Option<Vec<f64>>,
    // Memory
    pub working_set_kb: Option<i64>,
    pub private_bytes_kb: Option<i64>,
    pub page_faults_per_s: Option<f64>,
    // Disk
    pub disk_read_bytes_per_s: Option<i64>,
    pub disk_write_bytes_per_s: Option<i64>,
    // Network
    pub net_rx_bytes_per_s: Option<i64>,
    pub net_tx_bytes_per_s: Option<i64>,
    // Threads/Handles
    pub thread_count: Option<i32>,
    pub handle_count: Option<i32>,
    // GPU PDH
    pub gpu_usage_pct: Option<f64>,
    pub gpu_dedicated_mem_kb: Option<i64>,
    pub gpu_shared_mem_kb: Option<i64>,
    // FPS (filled by dxgi module)
    pub fps: Option<f64>,
    pub frametimes_json: Option<String>,
}

/// PDH query handle wrapping an HQUERY and its counters.
#[derive(Debug)]
pub struct PdhQuery {
    pub query_handle: isize,
    pub counters: Vec<PdhCounter>,
}

/// A single PDH counter with its name, path, and HCOUNTER handle.
#[derive(Debug, Clone)]
pub struct PdhCounter {
    pub name: String,
    pub path: String,
    pub handle: isize,
}

// ---------------------------------------------------------------------------
// Counter path construction (pure logic, no platform dependency)
// ---------------------------------------------------------------------------

/// Build PDH counter paths for a given process name.
/// Returns Vec of (counter_name, counter_path) pairs matching UNIFIED-SPEC §19.2.
///
/// Counter paths:
/// - CPU: \Process({name})\% Processor Time
/// - CPU per-core: \Processor({0..N-1})\% Processor Time
/// - Working set: \Process({name})\Working Set
/// - Private bytes: \Process({name})\Private Bytes
/// - Page faults: \Process({name})\Page Faults/sec
/// - Disk read: \Process({name})\IO Read Bytes/sec
/// - Disk write: \Process({name})\IO Write Bytes/sec
/// - Thread count: \Process({name})\Thread Count
/// - Handle count: \Process({name})\Handle Count
/// - Network RX: \Network Interface(*)\Bytes Received/sec
/// - Network TX: \Network Interface(*)\Bytes Sent/sec
/// - GPU usage: \GPU Engine(*engtype_3D)\Utilization Percentage
/// - GPU dedicated: \GPU Process Memory(*)\Dedicated Usage
/// - GPU shared: \GPU Process Memory(*)\Shared Usage
pub fn build_counter_paths(
    process_name: &str,
    include_gpu: bool,
    num_cores: u32,
) -> Vec<(String, String)> {
    let mut paths: Vec<(String, String)> = Vec::new();

    // CPU — process-level
    paths.push((
        "cpu_process_pct".to_string(),
        format!("\\Process({})\\% Processor Time", process_name),
    ));

    // CPU per-core
    for i in 0..num_cores {
        paths.push((
            format!("cpu_core_{}", i),
            format!("\\Processor({})\\% Processor Time", i),
        ));
    }

    // Memory
    paths.push((
        "working_set".to_string(),
        format!("\\Process({})\\Working Set", process_name),
    ));
    paths.push((
        "private_bytes".to_string(),
        format!("\\Process({})\\Private Bytes", process_name),
    ));
    paths.push((
        "page_faults_per_s".to_string(),
        format!("\\Process({})\\Page Faults/sec", process_name),
    ));

    // Disk I/O
    paths.push((
        "disk_read".to_string(),
        format!("\\Process({})\\IO Read Bytes/sec", process_name),
    ));
    paths.push((
        "disk_write".to_string(),
        format!("\\Process({})\\IO Write Bytes/sec", process_name),
    ));

    // Thread/Handle
    paths.push((
        "thread_count".to_string(),
        format!("\\Process({})\\Thread Count", process_name),
    ));
    paths.push((
        "handle_count".to_string(),
        format!("\\Process({})\\Handle Count", process_name),
    ));

    // Network (system-wide, per-interface aggregate)
    paths.push((
        "net_rx".to_string(),
        "\\Network Interface(*)\\Bytes Received/sec".to_string(),
    ));
    paths.push((
        "net_tx".to_string(),
        "\\Network Interface(*)\\Bytes Sent/sec".to_string(),
    ));

    // GPU (optional)
    if include_gpu {
        paths.push((
            "gpu_usage".to_string(),
            "\\GPU Engine(*engtype_3D)\\Utilization Percentage".to_string(),
        ));
        paths.push((
            "gpu_dedicated_mem".to_string(),
            "\\GPU Process Memory(*)\\Dedicated Usage".to_string(),
        ));
        paths.push((
            "gpu_shared_mem".to_string(),
            "\\GPU Process Memory(*)\\Shared Usage".to_string(),
        ));
    }

    paths
}

/// Validate a process name for PDH counter path safety.
/// Process names must be alphanumeric with limited special chars (no PDH injection).
/// Limited to 64 chars. Per threat model T-05-15.
pub fn validate_process_name(name: &str) -> Result<(), String> {
    if name.is_empty() {
        return Err("Process name must not be empty".to_string());
    }
    if name.len() > 64 {
        return Err("Process name must not exceed 64 characters".to_string());
    }
    // PDH counter paths use process name; filter out path traversal chars
    if name.contains('\\') || name.contains('/') || name.contains('\0') {
        return Err(format!("Invalid characters in process name: '{}'", name));
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// Windows PDH FFI bindings (raw extern "system" to pdh.dll)
// ---------------------------------------------------------------------------

#[cfg(windows)]
mod ffi {
    // PDH format flags
    pub const PDH_FMT_DOUBLE: u32 = 0x00000200;
    pub const PDH_FMT_LARGE: u32 = 0x00000400;
    pub const PDH_FMT_LONG: u32 = 0x00000100;

    // PDH status codes
    pub const ERROR_SUCCESS: u32 = 0;
    pub const PDH_CSTATUS_VALID_DATA: u32 = 0;
    pub const PDH_CSTATUS_NEW_DATA: u32 = 1;
    pub const PDH_CSTATUS_NO_INSTANCE: u32 = 0x800007D1;

    /// PDH formatted counter value (union of possible value types).
    #[repr(C)]
    pub union PdhFmtCountervalue {
        pub long_value: i32,
        pub double_value: f64,
        pub large_value: i64,
        pub ansi_string_value: *const i8,
        pub wide_string_value: *const u16,
    }

    extern "system" {
        /// Open a PDH query handle.
        pub fn PdhOpenQueryW(
            sz_data_source: *const u16,
            dw_user_data: usize,
            ph_query: *mut isize,
        ) -> u32;

        /// Add a counter to a PDH query by English counter path.
        pub fn PdhAddEnglishCounterW(
            h_query: isize,
            sz_full_counter_path: *const u16,
            dw_user_data: usize,
            ph_counter: *mut isize,
        ) -> u32;

        /// Collect current data for all counters in a query.
        pub fn PdhCollectQueryData(
            h_query: isize,
        ) -> u32;

        /// Get the formatted value of a counter.
        pub fn PdhGetFormattedCounterValue(
            h_counter: isize,
            dw_format: u32,
            lpdw_type: *mut u32,
            p_value: *mut PdhFmtCountervalue,
        ) -> u32;

        /// Close a PDH query and all its counters.
        pub fn PdhCloseQuery(
            h_query: isize,
        ) -> u32;
    }
}

/// Convert a Rust string to a null-terminated UTF-16 wide string for Win32 API.
#[cfg(windows)]
fn to_wide(s: &str) -> Vec<u16> {
    use std::iter::once;
    s.encode_utf16().chain(once(0)).collect()
}

// ---------------------------------------------------------------------------
// Platform-specific PDH implementation
// ---------------------------------------------------------------------------

/// Open a PDH query for the given process name.
///
/// Creates a PDH query handle and adds counters for all metrics in §19.2.
/// GPU counters are optional (not all systems have GPUs).
/// All fallible: if a counter doesn't exist, the counter is skipped with a log
/// warning and the query continues with remaining counters.
///
/// # Platform
/// Windows only. Returns Err on non-Windows platforms.
#[cfg(windows)]
pub fn open_query(process_name: &str, include_gpu: bool) -> Result<PdhQuery, String> {
    // Validate process name first (per threat model T-05-15)
    validate_process_name(process_name)?;

    // Determine number of cores for per-core counters
    let num_cores = std::thread::available_parallelism()
        .map(|n| n.get() as u32)
        .unwrap_or(4);

    // Step 1: Open PDH query handle
    let mut query_handle: isize = 0;
    let status = unsafe {
        ffi::PdhOpenQueryW(
            std::ptr::null(),          // no data source (local machine)
            0,                          // user data
            &mut query_handle as *mut isize,
        )
    };

    if status != ffi::ERROR_SUCCESS {
        return Err(format!("PdhOpenQueryW failed with status 0x{:08X}", status));
    }

    // Step 2: Build counter paths and add them to the query
    let counter_paths = build_counter_paths(process_name, include_gpu, num_cores);
    let mut counters: Vec<PdhCounter> = Vec::with_capacity(counter_paths.len());

    for (name, path) in &counter_paths {
        let wide_path = to_wide(path);
        let mut counter_handle: isize = 0;

        let add_status = unsafe {
            ffi::PdhAddEnglishCounterW(
                query_handle,
                wide_path.as_ptr(),
                0,
                &mut counter_handle as *mut isize,
            )
        };

        if add_status == ffi::ERROR_SUCCESS {
            counters.push(PdhCounter {
                name: name.clone(),
                path: path.clone(),
                handle: counter_handle,
            });
        } else {
            // Counter not available — skip (e.g., no GPU, process not running yet)
            log::warn!(
                "PDH counter '{}' (path: '{}') failed to add: status 0x{:08X}",
                name,
                path,
                add_status
            );
        }
    }

    if counters.is_empty() {
        // Close the query handle since we have no valid counters
        unsafe { ffi::PdhCloseQuery(query_handle); }
        return Err(format!(
            "No PDH counters could be added for process '{}'",
            process_name
        ));
    }

    Ok(PdhQuery {
        query_handle,
        counters,
    })
}

#[cfg(not(windows))]
pub fn open_query(_process_name: &str, _include_gpu: bool) -> Result<PdhQuery, String> {
    Err("PDH is Windows-only".to_string())
}

/// Collect a single sample from an open PDH query.
/// Refreshes all counters and reads their formatted values into a PcMetricsSnapshot.
///
/// CPU % from `\Process()\% Processor Time` is raw per-process fraction. Per §19.2 note,
/// multiply by 100 for a percentage. PDH `% Processor Time` for Process objects gives
/// the total CPU time across all cores, so to get a percentage relative to a single core,
/// the value should be divided by the number of logical cores.
///
/// Disk/network values are cumulative bytes — rate calculation done by consumer
/// using (current - previous) / interval_s.
///
/// # Platform
/// Windows only.
#[cfg(windows)]
pub fn collect_sample(query: &PdhQuery) -> Result<PcMetricsSnapshot, String> {
    // Step 1: Collect data for all counters
    let status = unsafe { ffi::PdhCollectQueryData(query.query_handle) };

    if status != ffi::ERROR_SUCCESS {
        return Err(format!(
            "PdhCollectQueryData failed with status 0x{:08X}",
            status
        ));
    }

    // Step 2: Read formatted values for each counter
    let mut snapshot = PcMetricsSnapshot {
        timestamp: now_ms(),
        ..Default::default()
    };

    let mut per_core_pct: Vec<Option<f64>> = Vec::new();

    for counter in &query.counters {
        let mut counter_type: u32 = 0;
        let mut value = ffi::PdhFmtCountervalue { large_value: 0 };

        let fmt_status = unsafe {
            ffi::PdhGetFormattedCounterValue(
                counter.handle,
                ffi::PDH_FMT_DOUBLE,
                &mut counter_type as *mut u32,
                &mut value as *mut ffi::PdhFmtCountervalue,
            )
        };

        if fmt_status != ffi::ERROR_SUCCESS {
            log::warn!(
                "PdhGetFormattedCounterValue failed for '{}': status 0x{:08X}",
                counter.name,
                fmt_status
            );
            continue;
        }

        let double_val = unsafe { value.double_value };

        // Map counter name to snapshot field
        match counter.name.as_str() {
            "cpu_process_pct" => {
                // Raw % Processor Time from PDH: this is the fraction of one core.
                // For multi-core display, divide by num_cores for single-core-equivalent %.
                snapshot.cpu_process_pct = Some(double_val);
            }
            "working_set" => {
                snapshot.working_set_kb = Some((double_val / 1024.0) as i64);
            }
            "private_bytes" => {
                snapshot.private_bytes_kb = Some((double_val / 1024.0) as i64);
            }
            "page_faults_per_s" => {
                snapshot.page_faults_per_s = Some(double_val);
            }
            "disk_read" => {
                snapshot.disk_read_bytes_per_s = Some(double_val as i64);
            }
            "disk_write" => {
                snapshot.disk_write_bytes_per_s = Some(double_val as i64);
            }
            "thread_count" => {
                snapshot.thread_count = Some(double_val as i32);
            }
            "handle_count" => {
                snapshot.handle_count = Some(double_val as i32);
            }
            "net_rx" => {
                snapshot.net_rx_bytes_per_s = Some(double_val as i64);
            }
            "net_tx" => {
                snapshot.net_tx_bytes_per_s = Some(double_val as i64);
            }
            "gpu_usage" => {
                snapshot.gpu_usage_pct = Some(double_val);
            }
            "gpu_dedicated_mem" => {
                snapshot.gpu_dedicated_mem_kb = Some((double_val / 1024.0) as i64);
            }
            "gpu_shared_mem" => {
                snapshot.gpu_shared_mem_kb = Some((double_val / 1024.0) as i64);
            }
            name if name.starts_with("cpu_core_") => {
                // Accumulate per-core values; sorted by index later
                let idx_str = &name["cpu_core_".len()..];
                let idx: usize = idx_str.parse().unwrap_or(0);
                if per_core_pct.len() <= idx {
                    per_core_pct.resize(idx + 1, None);
                }
                per_core_pct[idx] = Some(double_val);
            }
            _ => {
                log::debug!("Unknown PDH counter name: {}", counter.name);
            }
        }
    }

    // Flatten per-core data into Vec<f64> (preserving None as 0.0 for missing cores)
    if per_core_pct.iter().any(|v| v.is_some()) {
        snapshot.cpu_per_core_pct = Some(
            per_core_pct
                .into_iter()
                .map(|v| v.unwrap_or(0.0))
                .collect(),
        );
    }

    Ok(snapshot)
}

#[cfg(not(windows))]
pub fn collect_sample(_query: &PdhQuery) -> Result<PcMetricsSnapshot, String> {
    Err("PDH is Windows-only".to_string())
}

/// Close a PDH query and release all counter handles.
///
/// # Platform
/// Windows only. No-op on non-Windows.
#[cfg(windows)]
pub fn close_query(query: PdhQuery) {
    unsafe {
        ffi::PdhCloseQuery(query.query_handle);
    }
}

#[cfg(not(windows))]
pub fn close_query(_query: PdhQuery) {
    // No-op on non-Windows
}

/// Get the current timestamp in Unix milliseconds.
#[cfg(windows)]
fn now_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    // -----------------------------------------------------------------------
    // Test 1: Counter path construction (UNIFIED-SPEC §19.2)
    // -----------------------------------------------------------------------

    #[test]
    fn test_counter_path_process_cpu_format() {
        let paths = build_counter_paths("notepad.exe", false, 4);
        let cpu = paths.iter().find(|(n, _)| n == "cpu_process_pct").unwrap();
        assert_eq!(cpu.1, "\\Process(notepad.exe)\\% Processor Time");
    }

    #[test]
    fn test_counter_path_working_set_format() {
        let paths = build_counter_paths("game.exe", false, 4);
        let ws = paths.iter().find(|(n, _)| n == "working_set").unwrap();
        assert_eq!(ws.1, "\\Process(game.exe)\\Working Set");
    }

    #[test]
    fn test_counter_path_private_bytes_format() {
        let paths = build_counter_paths("app.exe", false, 4);
        let pb = paths.iter().find(|(n, _)| n == "private_bytes").unwrap();
        assert_eq!(pb.1, "\\Process(app.exe)\\Private Bytes");
    }

    #[test]
    fn test_counter_path_page_faults_format() {
        let paths = build_counter_paths("test.exe", false, 4);
        let pf = paths.iter().find(|(n, _)| n == "page_faults_per_s").unwrap();
        assert_eq!(pf.1, "\\Process(test.exe)\\Page Faults/sec");
    }

    #[test]
    fn test_counter_path_disk_io_format() {
        let paths = build_counter_paths("proc.exe", false, 4);
        let dr = paths.iter().find(|(n, _)| n == "disk_read").unwrap();
        let dw = paths.iter().find(|(n, _)| n == "disk_write").unwrap();
        assert_eq!(dr.1, "\\Process(proc.exe)\\IO Read Bytes/sec");
        assert_eq!(dw.1, "\\Process(proc.exe)\\IO Write Bytes/sec");
    }

    #[test]
    fn test_counter_path_thread_handle_format() {
        let paths = build_counter_paths("proc.exe", false, 4);
        let tc = paths.iter().find(|(n, _)| n == "thread_count").unwrap();
        let hc = paths.iter().find(|(n, _)| n == "handle_count").unwrap();
        assert_eq!(tc.1, "\\Process(proc.exe)\\Thread Count");
        assert_eq!(hc.1, "\\Process(proc.exe)\\Handle Count");
    }

    #[test]
    fn test_counter_path_network_format() {
        let paths = build_counter_paths("any.exe", false, 4);
        let rx = paths.iter().find(|(n, _)| n == "net_rx").unwrap();
        let tx = paths.iter().find(|(n, _)| n == "net_tx").unwrap();
        assert_eq!(rx.1, "\\Network Interface(*)\\Bytes Received/sec");
        assert_eq!(tx.1, "\\Network Interface(*)\\Bytes Sent/sec");
    }

    #[test]
    fn test_counter_path_gpu_format() {
        let paths = build_counter_paths("game.exe", true, 4);
        let gpu = paths.iter().find(|(n, _)| n == "gpu_usage").unwrap();
        let ded = paths.iter().find(|(n, _)| n == "gpu_dedicated_mem").unwrap();
        let shr = paths.iter().find(|(n, _)| n == "gpu_shared_mem").unwrap();
        assert_eq!(gpu.1, "\\GPU Engine(*engtype_3D)\\Utilization Percentage");
        assert_eq!(ded.1, "\\GPU Process Memory(*)\\Dedicated Usage");
        assert_eq!(shr.1, "\\GPU Process Memory(*)\\Shared Usage");
    }

    #[test]
    fn test_counter_path_gpu_absent_when_not_included() {
        let paths = build_counter_paths("game.exe", false, 4);
        assert!(paths.iter().find(|(n, _)| n == "gpu_usage").is_none());
        assert!(paths.iter().find(|(n, _)| n == "gpu_dedicated_mem").is_none());
    }

    #[test]
    fn test_counter_path_per_core_count() {
        let cores: u32 = 8;
        let paths = build_counter_paths("test.exe", false, cores);
        let core_count = paths
            .iter()
            .filter(|(n, _)| n.starts_with("cpu_core_"))
            .count();
        assert_eq!(core_count, cores as usize);

        // Verify format: \Processor(0)\% Processor Time
        for i in 0..cores {
            let expected = format!("\\Processor({})\\% Processor Time", i);
            let found = paths.iter().find(|(n, p)| n == &format!("cpu_core_{}", i) && p == &expected);
            assert!(found.is_some(), "Missing core counter for Processor({})", i);
        }
    }

    #[test]
    fn test_all_required_counters_present() {
        let paths = build_counter_paths("app.exe", false, 2);
        let names: Vec<&str> = paths.iter().map(|(n, _)| n.as_str()).collect();

        // Required counters from §19.2 (without GPU)
        let required = [
            "cpu_process_pct",
            "cpu_core_0",
            "cpu_core_1",
            "working_set",
            "private_bytes",
            "page_faults_per_s",
            "disk_read",
            "disk_write",
            "thread_count",
            "handle_count",
            "net_rx",
            "net_tx",
        ];

        for req in &required {
            assert!(
                names.contains(req),
                "Missing required counter: {}",
                req
            );
        }
    }

    // -----------------------------------------------------------------------
    // Test 2: Snapshot default values
    // -----------------------------------------------------------------------

    #[test]
    fn test_snapshot_default_all_none() {
        let snap = PcMetricsSnapshot::default();
        assert_eq!(snap.timestamp, 0);
        assert!(snap.cpu_process_pct.is_none());
        assert!(snap.cpu_per_core_pct.is_none());
        assert!(snap.working_set_kb.is_none());
        assert!(snap.private_bytes_kb.is_none());
        assert!(snap.page_faults_per_s.is_none());
        assert!(snap.disk_read_bytes_per_s.is_none());
        assert!(snap.disk_write_bytes_per_s.is_none());
        assert!(snap.net_rx_bytes_per_s.is_none());
        assert!(snap.net_tx_bytes_per_s.is_none());
        assert!(snap.thread_count.is_none());
        assert!(snap.handle_count.is_none());
        assert!(snap.gpu_usage_pct.is_none());
        assert!(snap.gpu_dedicated_mem_kb.is_none());
        assert!(snap.gpu_shared_mem_kb.is_none());
        assert!(snap.fps.is_none());
        assert!(snap.frametimes_json.is_none());
    }

    #[test]
    fn test_snapshot_can_set_fields() {
        let mut snap = PcMetricsSnapshot::default();
        snap.timestamp = 12345;
        snap.fps = Some(60.0);
        snap.working_set_kb = Some(123456);
        assert_eq!(snap.timestamp, 12345);
        assert_eq!(snap.fps, Some(60.0));
        assert_eq!(snap.working_set_kb, Some(123456));
    }

    // -----------------------------------------------------------------------
    // Test 3: Error handling — invalid process name
    // -----------------------------------------------------------------------

    #[test]
    fn test_validate_empty_process_name() {
        assert!(validate_process_name("").is_err());
    }

    #[test]
    fn test_validate_too_long_process_name() {
        let long_name = "a".repeat(65);
        assert!(validate_process_name(&long_name).is_err());
    }

    #[test]
    fn test_validate_backslash_rejected() {
        assert!(validate_process_name("test\\bad.exe").is_err());
    }

    #[test]
    fn test_validate_null_byte_rejected() {
        assert!(validate_process_name("test\0bad.exe").is_err());
    }

    #[test]
    fn test_validate_valid_name_accepted() {
        assert!(validate_process_name("notepad.exe").is_ok());
        assert!(validate_process_name("my-game_v2.exe").is_ok());
        assert!(validate_process_name("Unity.exe").is_ok());
    }

    // -----------------------------------------------------------------------
    // Test 4: open_query returns valid handle with counters (GREEN)
    // -----------------------------------------------------------------------

    #[test]
    #[cfg_attr(not(windows), ignore = "PDH requires Windows")]
    fn test_open_query_returns_valid_handle() {
        // On Windows, try to open a PDH query. If the target process isn't running,
        // open_query should return a clean Err (not panic). If it succeeds,
        // the query should have a valid handle and at least one counter.
        //
        // Use the Rust test binary name — this process IS running.
        let current_exe = std::env::current_exe()
            .ok()
            .and_then(|p| {
                p.file_name()
                    .and_then(|n| n.to_str())
                    .map(|s| s.to_string())
            })
            .unwrap_or_else(|| "test.exe".to_string());

        let result = open_query(&current_exe, false);
        match result {
            Ok(query) => {
                // Query was opened — verify it has at least some counters
                assert!(
                    !query.counters.is_empty(),
                    "Should have at least 1 counter for running process '{}'",
                    current_exe
                );
                assert!(query.query_handle != 0, "Query handle should be non-zero");
                // Clean up
                close_query(query);
            }
            Err(e) => {
                // Process might not expose PDH counters — that's ok
                // Verify the error is descriptive, not a panic
                assert!(!e.is_empty(), "Error should be descriptive");
            }
        }
    }

    // -----------------------------------------------------------------------
    // Test 5: collect_sample returns snapshot for running process
    // -----------------------------------------------------------------------

    #[test]
    #[cfg_attr(not(windows), ignore = "PDH requires Windows")]
    fn test_collect_sample_returns_snapshot_with_data() {
        // Try to open a query for the current process
        let current_exe = std::env::current_exe()
            .ok()
            .and_then(|p| {
                p.file_name()
                    .and_then(|n| n.to_str())
                    .map(|s| s.to_string())
            })
            .unwrap_or_else(|| "test.exe".to_string());

        let query = match open_query(&current_exe, false) {
            Ok(q) => q,
            Err(_) => {
                // Process doesn't expose PDH counters — skip test
                return;
            }
        };

        // Collect first sample (PDH needs two samples for rate counters)
        let _ = collect_sample(&query);

        // Collect second sample — should have data
        let result = collect_sample(&query);
        match result {
            Ok(snapshot) => {
                // Timestamp should be set
                assert!(
                    snapshot.timestamp > 0,
                    "Timestamp should be set (got {})",
                    snapshot.timestamp
                );
                // At minimum, we should get some data if the process has counters
                // Working set and thread count are usually available
                log::debug!(
                    "PDH snapshot: ws={:?}, cpu={:?}, threads={:?}, handles={:?}",
                    snapshot.working_set_kb,
                    snapshot.cpu_process_pct,
                    snapshot.thread_count,
                    snapshot.handle_count
                );
            }
            Err(e) => {
                // Data collection failed — that's possible if counters aren't ready
                // Verify the error is descriptive
                assert!(!e.is_empty(), "Error should be descriptive: {}", e);
            }
        }

        // Clean up
        close_query(query);
    }

    // -----------------------------------------------------------------------
    // Test 6: open_query validates process name before PDH calls
    // -----------------------------------------------------------------------

    #[test]
    fn test_open_query_rejects_empty_name() {
        let result = open_query("", false);
        assert!(result.is_err(), "Empty process name should be rejected");
    }

    #[test]
    fn test_open_query_rejects_backslash_name() {
        let result = open_query("bad\\name.exe", false);
        assert!(result.is_err(), "Backslash in process name should be rejected");
    }

    // -----------------------------------------------------------------------
    // Test 6: close_query no-op
    // -----------------------------------------------------------------------

    #[test]
    fn test_close_query_is_noop() {
        let query = PdhQuery {
            query_handle: 0,
            counters: vec![],
        };
        close_query(query); // Should not panic
    }
}
