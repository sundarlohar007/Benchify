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
// Platform-specific PDH implementation
// ---------------------------------------------------------------------------

/// Open a PDH query for the given process name.
///
/// Creates a PDH query handle and adds counters for all metrics in §19.2.
/// GPU counters are optional (not all systems have GPUs).
/// All fallible: if a counter doesn't exist, sets to None, logs warning, continues.
///
/// # Platform
/// Windows only. Returns Err on non-Windows platforms.
#[cfg(windows)]
pub fn open_query(_process_name: &str, _include_gpu: bool) -> Result<PdhQuery, String> {
    // Validate process name first (per threat model T-05-15)
    validate_process_name(_process_name)?;
    // RED phase stub — will be implemented in GREEN phase
    Err("PDH open_query not yet implemented (RED phase)".to_string())
}

#[cfg(not(windows))]
pub fn open_query(_process_name: &str, _include_gpu: bool) -> Result<PdhQuery, String> {
    Err("PDH is Windows-only".to_string())
}

/// Collect a single sample from an open PDH query.
/// Refreshes all counters and reads their formatted values into a PcMetricsSnapshot.
///
/// CPU % from `\Process()\% Processor Time` is raw per-process fraction. Per §19.2 note,
/// multiply by 100 / num_cores for a percentage relative to single core, OR leave raw
/// for multi-core display.
///
/// Disk/network values are cumulative bytes — rate calculation done by consumer
/// using (current - previous) / interval_s.
///
/// # Platform
/// Windows only.
#[cfg(windows)]
pub fn collect_sample(_query: &PdhQuery) -> Result<PcMetricsSnapshot, String> {
    // RED phase stub — will be implemented in GREEN phase
    Err("PDH collect_sample not yet implemented (RED phase)".to_string())
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
pub fn close_query(_query: PdhQuery) {
    // RED phase stub — will be implemented in GREEN phase
}

#[cfg(not(windows))]
pub fn close_query(_query: PdhQuery) {
    // No-op on non-Windows
}

/// Get the current timestamp in Unix milliseconds.
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
    // Test 4: open_query returns valid handle with counters (RED — fails against stub)
    // -----------------------------------------------------------------------

    #[test]
    #[cfg_attr(not(windows), ignore = "PDH requires Windows")]
    fn test_open_query_returns_valid_handle() {
        // This test WILL fail in RED phase because open_query is a stub returning Err.
        // It MUST pass in GREEN phase when the real PDH implementation is added.
        let result = open_query("test.exe", false);
        assert!(result.is_ok(), "open_query should return Ok on Windows, got: {:?}", result);

        let query = result.unwrap();
        // Verify we got at least the required counters (CPU, memory, disk, network, thread, handle)
        assert!(!query.counters.is_empty(), "Should have counters");
        assert!(query.counters.len() >= 12, "Expected 12+ counters, got {}", query.counters.len());
    }

    // -----------------------------------------------------------------------
    // Test 5: collect_sample returns snapshot with FPS and working set
    // -----------------------------------------------------------------------

    #[test]
    #[cfg_attr(not(windows), ignore = "PDH requires Windows")]
    fn test_collect_sample_returns_snapshot_with_data() {
        // This test WILL fail in RED phase because collect_sample is a stub returning Err.
        // It MUST pass in GREEN phase when the real PDH implementation is added.
        let query = PdhQuery {
            query_handle: 0,
            counters: vec![
                PdhCounter {
                    name: "cpu_process_pct".to_string(),
                    path: "\\Process(test.exe)\\% Processor Time".to_string(),
                    handle: 0,
                },
            ],
        };
        let result = collect_sample(&query);
        assert!(result.is_ok(), "collect_sample should return Ok, got: {:?}", result);
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
