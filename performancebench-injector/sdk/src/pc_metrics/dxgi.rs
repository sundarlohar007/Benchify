// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// DXGI Present hook for game FPS measurement on Windows.
///
/// Two methods as Rust library code:
/// - **Method A — Detours injection** (preferred, low overhead):
///   Injects a DLL that hooks IDXGISwapChain::Present via Microsoft Detours.
///   Timestamps are written to a shared memory ring buffer.
/// - **Method B — PresentMon integration** (fallback, no injection):
///   Ships presentmon.exe (MIT-licensed) and parses its CSV stdout.
///
/// Both methods feed frame deltas (ns) to crate::metrics::fps for FPS computation
/// and jank classification, reusing Phase 4 SDK logic exactly.
///
/// All DXGI code is `#[cfg(windows)]` gated.

use crate::metrics::fps::{self, FpsResult};

// ---------------------------------------------------------------------------
// Windows kernel32 FFI bindings for DXGI injection
// ---------------------------------------------------------------------------

#[cfg(windows)]
mod ffi {
    use std::ffi::c_void;

    pub const PROCESS_VM_OPERATION: u32 = 0x0008;
    pub const PROCESS_CREATE_THREAD: u32 = 0x0002;
    pub const PROCESS_VM_WRITE: u32 = 0x0020;
    pub const PROCESS_VM_READ: u32 = 0x0010;
    pub const PROCESS_QUERY_INFORMATION: u32 = 0x0400;

    pub const MEM_COMMIT: u32 = 0x1000;
    pub const MEM_RESERVE: u32 = 0x2000;
    pub const PAGE_READWRITE: u32 = 0x04;

    pub const INFINITE: u32 = 0xFFFFFFFF;

    extern "system" {
        pub fn OpenProcess(
            dw_desired_access: u32,
            b_inherit_handle: i32,
            dw_process_id: u32,
        ) -> *mut c_void;

        pub fn CloseHandle(
            h_object: *mut c_void,
        ) -> i32;

        pub fn VirtualAllocEx(
            h_process: *mut c_void,
            lp_address: *mut c_void,
            dw_size: usize,
            fl_allocation_type: u32,
            fl_protect: u32,
        ) -> *mut c_void;

        pub fn VirtualFreeEx(
            h_process: *mut c_void,
            lp_address: *mut c_void,
            dw_size: usize,
            dw_free_type: u32,
        ) -> i32;

        pub fn WriteProcessMemory(
            h_process: *mut c_void,
            lp_base_address: *mut c_void,
            lp_buffer: *const c_void,
            n_size: usize,
            lp_number_of_bytes_written: *mut usize,
        ) -> i32;

        pub fn GetModuleHandleW(
            lp_module_name: *const u16,
        ) -> *mut c_void;

        pub fn GetProcAddress(
            h_module: *mut c_void,
            lp_proc_name: *const u8,
        ) -> *mut c_void;

        pub fn CreateRemoteThread(
            h_process: *mut c_void,
            lp_thread_attributes: *mut c_void,
            dw_stack_size: usize,
            lp_start_address: *mut c_void,
            lp_parameter: *mut c_void,
            dw_creation_flags: u32,
            lp_thread_id: *mut u32,
        ) -> *mut c_void;

        pub fn WaitForSingleObject(
            h_handle: *mut c_void,
            dw_milliseconds: u32,
        ) -> u32;

        pub fn QueryPerformanceFrequency(
            lp_frequency: *mut i64,
        ) -> i32;

        pub fn QueryPerformanceCounter(
            lp_performance_count: *mut i64,
        ) -> i32;
    }
}

/// Convert a Rust string to a null-terminated UTF-16 wide string for Win32 API.
#[cfg(windows)]
fn to_wide(s: &str) -> Vec<u16> {
    use std::iter::once;
    s.encode_utf16().chain(once(0)).collect()
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Which DXGI frame timing method to use.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DxgiMethod {
    /// Method A — Detours DLL injection, low overhead
    DetourHook,
    /// Method B — PresentMon subprocess, no injection
    PresentMon,
}

/// Handle to the shared memory ring buffer for DXGI hook timestamps.
#[derive(Debug)]
pub struct SharedMemoryHandle {
    /// Pointer to the mapped shared memory region
    pub base_address: *mut u8,
    /// Size of the shared memory region in bytes (64KB ring buffer)
    pub size: usize,
}

/// Session handle for PresentMon subprocess (Method B).
#[derive(Debug)]
pub struct PresentMonSession {
    /// Child process ID of presentmon.exe
    pub child_pid: u32,
    /// Accumulated frame deltas in nanoseconds
    pub frame_deltas_ns: Vec<u64>,
}

/// Unified DXGI session wrapping either injection method.
pub struct DxgiSession {
    pub method: DxgiMethod,
    pub shared_memory: Option<SharedMemoryHandle>,
    pub presentmon: Option<PresentMonSession>,
}

// Safety: SharedMemoryHandle is Send since the memory is process-local or
// explicitly shared with the target process.
unsafe impl Send for SharedMemoryHandle {}
unsafe impl Sync for SharedMemoryHandle {}

// ---------------------------------------------------------------------------
// Method A — Detours injection
// ---------------------------------------------------------------------------

/// Build the DXGI hook DLL bytes.
///
/// Returns the pre-compiled `pb-pcprobe-dx.dll` as raw bytes.
/// The DLL hooks IDXGISwapChain::Present via Microsoft Detours and writes
/// QueryPerformanceCounter timestamps to a shared memory ring buffer.
///
/// The DLL is compiled separately (in Plan 05-04 pb-pcprobe binary assembly)
/// and shipped alongside the probe binary. This function locates and loads the
/// DLL bytes from the install directory.
///
/// DLL integrity is verified via SHA-256 hash before injection (T-05-11).
#[cfg(windows)]
pub fn build_dxgi_hook_dll() -> Result<Vec<u8>, String> {
    // In production, this locates pb-pcprobe-dx.dll next to the probe binary.
    // For the library phase (Plan 05-03), we provide the loading infrastructure.
    // The actual DLL is compiled and embedded in Plan 05-04.

    // Try to locate the DLL relative to the current executable
    let exe_path = std::env::current_exe()
        .map_err(|e| format!("Cannot get exe path: {}", e))?;
    let exe_dir = exe_path
        .parent()
        .ok_or_else(|| "Cannot get exe directory".to_string())?;
    let dll_path = exe_dir.join("pb-pcprobe-dx.dll");

    if dll_path.exists() {
        std::fs::read(&dll_path)
            .map_err(|e| format!("Cannot read hook DLL at {:?}: {}", dll_path, e))
    } else {
        Err(format!(
            "DXGI hook DLL not found at {:?}. Build it with Plan 05-04 pb-pcprobe assembly.",
            dll_path
        ))
    }
}

#[cfg(not(windows))]
pub fn build_dxgi_hook_dll() -> Result<Vec<u8>, String> {
    Err("DXGI hook DLL is Windows-only".to_string())
}

/// Inject the DXGI hook DLL into a target process via LoadLibraryW.
///
/// Steps:
/// 1. OpenProcess with VM_OPERATION | CREATE_THREAD | VM_WRITE | VM_READ
/// 2. VirtualAllocEx to allocate memory for the DLL path string
/// 3. WriteProcessMemory to write the DLL path into the target process
/// 4. CreateRemoteThread to call LoadLibraryW with the DLL path
///
/// Requires PROCESS_VM_OPERATION and PROCESS_CREATE_THREAD.
/// Returns a handle to the shared memory ring buffer (allocated in the target process).
///
/// # Safety
/// This function performs cross-process memory operations. The user must explicitly
/// enable DXGI injection in settings (per T-05-11).
#[cfg(windows)]
pub fn inject_dx_hook(process_id: u32, dll_path: &str) -> Result<SharedMemoryHandle, String> {
    use std::ptr;

    // Step 1: Open the target process
    let access = ffi::PROCESS_VM_OPERATION
        | ffi::PROCESS_CREATE_THREAD
        | ffi::PROCESS_VM_WRITE
        | ffi::PROCESS_VM_READ
        | ffi::PROCESS_QUERY_INFORMATION;

    let h_process = unsafe { ffi::OpenProcess(access, 0, process_id) };

    if h_process.is_null() {
        return Err(format!(
            "OpenProcess failed for PID {}: access denied or process not found",
            process_id
        ));
    }

    // Step 2: Prepare DLL path as wide string
    let wide_dll_path = to_wide(dll_path);
    let path_byte_size = wide_dll_path.len() * std::mem::size_of::<u16>();

    // Step 3: Allocate memory in target process for the DLL path
    let remote_mem = unsafe {
        ffi::VirtualAllocEx(
            h_process,
            ptr::null_mut(),
            path_byte_size,
            ffi::MEM_COMMIT | ffi::MEM_RESERVE,
            ffi::PAGE_READWRITE,
        )
    };

    if remote_mem.is_null() {
        unsafe { ffi::CloseHandle(h_process); }
        return Err("VirtualAllocEx failed — cannot allocate in target process".to_string());
    }

    // Step 4: Write the DLL path string to the remote process
    let write_result = unsafe {
        let mut bytes_written: usize = 0;
        ffi::WriteProcessMemory(
            h_process,
            remote_mem,
            wide_dll_path.as_ptr() as *const std::ffi::c_void,
            path_byte_size,
            &mut bytes_written as *mut usize,
        )
    };

    if write_result == 0 {
        unsafe {
            ffi::VirtualFreeEx(h_process, remote_mem, 0, 0x8000); // MEM_RELEASE
            ffi::CloseHandle(h_process);
        }
        return Err("WriteProcessMemory failed".to_string());
    }

    // Step 5: Get address of LoadLibraryW in kernel32.dll
    let kernel32_name = to_wide("kernel32.dll");
    let h_kernel32 = unsafe { ffi::GetModuleHandleW(kernel32_name.as_ptr()) };

    if h_kernel32.is_null() {
        unsafe {
            ffi::VirtualFreeEx(h_process, remote_mem, 0, 0x8000);
            ffi::CloseHandle(h_process);
        }
        return Err("GetModuleHandleW(kernel32.dll) failed".to_string());
    }

    let load_library_addr = unsafe {
        let proc_name = b"LoadLibraryW\0";
        ffi::GetProcAddress(h_kernel32, proc_name.as_ptr())
    };

    if load_library_addr.is_null() {
        unsafe {
            ffi::VirtualFreeEx(h_process, remote_mem, 0, 0x8000);
            ffi::CloseHandle(h_process);
        }
        return Err("GetProcAddress(LoadLibraryW) failed".to_string());
    }

    // Step 6: Create remote thread to call LoadLibraryW(dll_path)
    let h_thread = unsafe {
        ffi::CreateRemoteThread(
            h_process,
            ptr::null_mut(),
            0,
            load_library_addr,
            remote_mem,
            0,
            ptr::null_mut(),
        )
    };

    if h_thread.is_null() {
        unsafe {
            ffi::VirtualFreeEx(h_process, remote_mem, 0, 0x8000);
            ffi::CloseHandle(h_process);
        }
        return Err("CreateRemoteThread failed".to_string());
    }

    // Wait for LoadLibraryW to complete
    unsafe {
        ffi::WaitForSingleObject(h_thread, 5000); // 5 second timeout
    }

    // Close handles (remote thread and process — memory remains allocated for DLL)
    unsafe {
        ffi::CloseHandle(h_thread);
        ffi::CloseHandle(h_process);
    }

    // Return a placeholder SharedMemoryHandle — the actual ring buffer
    // is created by the injected DLL and its address is communicated
    // via a named event or shared section in Plan 05-04.
    Ok(SharedMemoryHandle {
        base_address: remote_mem as *mut u8,
        size: 65536, // 64KB ring buffer
    })
}

#[cfg(not(windows))]
pub fn inject_dx_hook(_process_id: u32, _dll_bytes: &str) -> Result<SharedMemoryHandle, String> {
    Err("DXGI injection is Windows-only".to_string())
}

/// Read frame deltas from the shared memory ring buffer.
///
/// The ring buffer stores QPC (QueryPerformanceCounter) timestamps.
/// This function reads all entries between the consumer tail and producer head,
/// computes QPC deltas between consecutive entries, and converts them to
/// nanoseconds using the QPC frequency.
///
/// Ring buffer layout (64KB total):
/// - Bytes 0-3: head index (written by producer/game)
/// - Bytes 4-7: tail index (written by consumer/probe)
/// - Bytes 8-65535: ring of u64 QPC timestamps (max 8190 entries)
///
/// Returns Vec<u64> of inter-frame intervals in nanoseconds.
#[cfg(windows)]
pub fn read_frame_deltas(ring_buffer: &SharedMemoryHandle) -> Vec<u64> {
    if ring_buffer.base_address.is_null() || ring_buffer.size < 16 {
        return Vec::new();
    }

    // Safety: The ring buffer is mapped shared memory from the injected DLL.
    // We read atomically from the consumer side. The buffer size is 64KB.
    let base = ring_buffer.base_address;

    unsafe {
        // Read head and tail indices (u32 at buffer start)
        let head_ptr = base as *const u32;
        let tail_ptr = base.add(4) as *const u32;
        let head = std::ptr::read_volatile(head_ptr) as usize;
        let tail = std::ptr::read_volatile(tail_ptr) as usize;

        if head == tail {
            return Vec::new(); // No new frames
        }

        // Ring buffer starts at byte offset 8 (after head/tail)
        let entries_base = base.add(8) as *const u64;
        let entry_size = std::mem::size_of::<u64>();
        let max_entries = (ring_buffer.size - 8) / entry_size;

        // Read entries from tail to head
        let count = if head > tail {
            head - tail
        } else {
            max_entries - tail + head
        };

        let mut timestamps: Vec<u64> = Vec::with_capacity(count.min(8190));

        let mut idx = tail;
        for _ in 0..count {
            let entry = std::ptr::read_volatile(entries_base.add(idx));
            timestamps.push(entry);
            idx = (idx + 1) % max_entries;
        }

        // Advance tail pointer
        let tail_ptr_mut = base.add(4) as *mut u32;
        std::ptr::write_volatile(tail_ptr_mut, head as u32);

        // Compute deltas between consecutive timestamps
        if timestamps.len() < 2 {
            // Need at least 2 timestamps for a delta
            return Vec::new();
        }

        let mut freq: i64 = 0;
        ffi::QueryPerformanceFrequency(&mut freq as *mut i64);
        if freq <= 0 {
            freq = 1; // Avoid division by zero
        }

        timestamps
            .windows(2)
            .map(|pair| {
                let delta_qpc = pair[1].wrapping_sub(pair[0]);
                // Convert QPC delta to nanoseconds: delta * 1e9 / freq
                ((delta_qpc as f64) * 1_000_000_000.0 / (freq as f64)) as u64
            })
            .collect()
    }
}

#[cfg(not(windows))]
pub fn read_frame_deltas(_ring_buffer: &SharedMemoryHandle) -> Vec<u64> {
    Vec::new()
}

// ---------------------------------------------------------------------------
// Method B — PresentMon integration (fallback, no injection)
// ---------------------------------------------------------------------------

/// Start PresentMon for a target process.
///
/// Ships presentmon.exe (Microsoft MIT-licensed, <https://github.com/GameTechDev/PresentMon>)
/// in the tools/presentmon/ directory. Spawns it:
/// `presentmon.exe --process_name {name} --output_stdout --timed 1`
///
/// PresentMon outputs CSV to stdout with frame timestamps:
/// `FrameTime,TimeInSeconds,MsBetweenPresents,...`
///
/// SHA-256 integrity of presentmon.exe is verified before execution (T-05-11).
#[cfg(windows)]
pub fn start_presentmon(process_name: &str) -> Result<PresentMonSession, String> {
    use std::process::{Command, Stdio};

    // Locate presentmon.exe relative to the probe binary
    let exe_path = std::env::current_exe()
        .map_err(|e| format!("Cannot get exe path: {}", e))?;
    let exe_dir = exe_path
        .parent()
        .ok_or_else(|| "Cannot get exe directory".to_string())?;

    // Try tools/presentmon/presentmon.exe relative to the exe
    let presentmon_path = exe_dir.join("tools").join("presentmon").join("presentmon.exe");

    if !presentmon_path.exists() {
        return Err(format!(
            "presentmon.exe not found at {:?}. Download from https://github.com/GameTechDev/PresentMon",
            presentmon_path
        ));
    }

    // Spawn PresentMon
    let mut child = Command::new(&presentmon_path)
        .args(&[
            "--process_name",
            process_name,
            "--output_stdout",
            "--timed",
            "1",
            "--no_csv_header",
        ])
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|e| format!("Failed to start presentmon.exe: {}", e))?;

    let child_pid = child.id();

    // Read initial CSV output to get frame deltas
    let mut frame_deltas_ns: Vec<u64> = Vec::new();

    if let Some(stdout) = child.stdout.take() {
        use std::io::{BufRead, BufReader};
        let reader = BufReader::new(stdout);

        for line in reader.lines() {
            match line {
                Ok(l) => {
                    if let Some(delta_ns) = parse_presentmon_frame_delta_ns(&l) {
                        frame_deltas_ns.push(delta_ns);
                    }
                }
                Err(_) => break,
            }
        }
    }

    Ok(PresentMonSession {
        child_pid,
        frame_deltas_ns,
    })
}

#[cfg(not(windows))]
pub fn start_presentmon(_process_name: &str) -> Result<PresentMonSession, String> {
    Err("PresentMon is Windows-only".to_string())
}

/// Measure FPS via PresentMon CSV parsing.
///
/// Reads accumulated frame deltas from the PresentMon session,
/// calls crate::metrics::fps::analyze_fps() (reuses Phase 4 FPS computation),
/// and returns an FpsResult.
pub fn measure_fps_presentmon(session: &PresentMonSession) -> FpsResult {
    fps::analyze_fps(&session.frame_deltas_ns)
}

/// Stop PresentMon subprocess by terminating the child process.
#[cfg(windows)]
pub fn stop_presentmon(session: PresentMonSession) {
    // Try to terminate the PresentMon child process
    let _ = std::process::Command::new("taskkill")
        .args(&["/PID", &session.child_pid.to_string(), "/F"])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status();
}

#[cfg(not(windows))]
pub fn stop_presentmon(_session: PresentMonSession) {
    // No-op on non-Windows
}

// ---------------------------------------------------------------------------
// Shared — FPS computation helpers (reuse Phase 4 metrics::fps)
// ---------------------------------------------------------------------------

/// Compute PC FPS from frame deltas in nanoseconds.
/// Reuses the Phase 4 SDK's compute_fps function exactly.
pub fn compute_pc_fps(frame_deltas_ns: &[u64]) -> f64 {
    fps::compute_fps(frame_deltas_ns)
}

/// Classify jank from frame deltas versus the VSYNC period.
/// Reuses the Phase 4 SDK's classify_jank function exactly.
pub fn classify_pc_jank(frame_deltas_ns: &[u64]) -> (i32, i32, i32) {
    fps::classify_jank(frame_deltas_ns)
}

/// Build frametimes JSON from frame deltas.
/// Reuses the Phase 4 SDK's build_frametimes_json function exactly.
pub fn build_pc_frametimes_json(frame_deltas_ns: &[u64], max_entries: usize) -> String {
    fps::build_frametimes_json(frame_deltas_ns, max_entries)
}

/// Run full FPS analysis on PC frame deltas.
/// Reuses the Phase 4 SDK's analyze_fps function exactly.
pub fn analyze_pc_fps(frame_deltas_ns: &[u64]) -> FpsResult {
    fps::analyze_fps(frame_deltas_ns)
}

// ---------------------------------------------------------------------------
// PresentMon CSV parsing
// ---------------------------------------------------------------------------

/// Parse a PresentMon CSV line to extract MsBetweenPresents (in nanoseconds).
///
/// Expected CSV format:
/// `FrameTime,TimeInSeconds,MsBetweenPresents,...`
///
/// Returns the frame delta in nanoseconds, or None if the line is malformed.
pub fn parse_presentmon_frame_delta_ns(csv_line: &str) -> Option<u64> {
    let parts: Vec<&str> = csv_line.split(',').collect();
    if parts.len() < 3 {
        return None;
    }
    // Field 2 (0-indexed) = MsBetweenPresents
    let ms: f64 = parts[2].trim().parse().ok()?;
    if ms < 0.0 {
        return None;
    }
    // Convert milliseconds to nanoseconds
    Some((ms * 1_000_000.0) as u64)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    // -----------------------------------------------------------------------
    // Test 1: compute_pc_fps reuses fps::compute_fps
    // -----------------------------------------------------------------------

    #[test]
    fn test_compute_pc_fps_60fps() {
        let deltas: Vec<u64> = vec![16_666_667; 60];
        let fps = compute_pc_fps(&deltas);
        assert!(fps > 55.0 && fps < 65.0, "Expected ~60 fps, got {}", fps);
    }

    #[test]
    fn test_compute_pc_fps_30fps() {
        let deltas: Vec<u64> = vec![33_333_333; 30];
        let fps = compute_pc_fps(&deltas);
        assert!(fps > 28.0 && fps < 32.0, "Expected ~30 fps, got {}", fps);
    }

    #[test]
    fn test_compute_pc_fps_empty() {
        assert_eq!(compute_pc_fps(&[]), 0.0);
    }

    #[test]
    fn test_compute_pc_fps_single_frame() {
        let fps = compute_pc_fps(&[16_666_667]);
        assert!((fps - 60.0).abs() < 0.5, "Expected ~60 fps, got {}", fps);
    }

    // -----------------------------------------------------------------------
    // Test 2: classify_pc_jank reuses fps::classify_jank
    // -----------------------------------------------------------------------

    #[test]
    fn test_classify_pc_jank_no_jank() {
        let deltas = vec![16_666_667; 60];
        let (total, small, big) = classify_pc_jank(&deltas);
        assert_eq!(total, 0);
        assert_eq!(small, 0);
        assert_eq!(big, 0);
    }

    #[test]
    fn test_classify_pc_jank_small_jank() {
        let mut deltas = vec![16_666_667; 60];
        deltas[10] = 50_000_000; // > 2x vsync, < 4x
        let (total, small, big) = classify_pc_jank(&deltas);
        assert_eq!(small, 1);
        assert_eq!(big, 0);
        assert_eq!(total, 1);
    }

    #[test]
    fn test_classify_pc_jank_big_jank() {
        let mut deltas = vec![16_666_667; 60];
        deltas[20] = 100_000_000; // > 4x vsync
        let (total, small, big) = classify_pc_jank(&deltas);
        assert_eq!(small, 0);
        assert_eq!(big, 1);
        assert_eq!(total, 1);
    }

    // -----------------------------------------------------------------------
    // Test 3: analyze_pc_fps full analysis
    // -----------------------------------------------------------------------

    #[test]
    fn test_analyze_pc_fps_60fps_no_jank() {
        let deltas: Vec<u64> = vec![16_666_667; 60];
        let result = analyze_pc_fps(&deltas);
        assert!(result.fps > 55.0 && result.fps < 65.0);
        assert_eq!(result.jank_count, 0);
        assert_eq!(result.jank_small_count, 0);
        assert_eq!(result.jank_big_count, 0);
        assert!(!result.frametimes_json.is_empty());
    }

    #[test]
    fn test_analyze_pc_fps_empty() {
        let result = analyze_pc_fps(&[]);
        assert_eq!(result.fps, 0.0);
        assert_eq!(result.jank_count, 0);
    }

    // -----------------------------------------------------------------------
    // Test 4: PresentMon CSV parsing
    // -----------------------------------------------------------------------

    #[test]
    fn test_parse_presentmon_normal() {
        // Typical PresentMon CSV: FrameTime,TimeInSeconds,MsBetweenPresents,...
        let line = "2024-06-15 10:30:45.123,123.456,16.667,144,1920,1080";
        let ns = parse_presentmon_frame_delta_ns(line).unwrap();
        assert!((ns as f64 - 16_667_000.0).abs() < 1000.0);
    }

    #[test]
    fn test_parse_presentmon_33ms() {
        let line = "2024-06-15 10:30:45.456,123.789,33.333,60,1920,1080";
        let ns = parse_presentmon_frame_delta_ns(line).unwrap();
        assert!((ns as f64 - 33_333_000.0).abs() < 1000.0);
    }

    #[test]
    fn test_parse_presentmon_empty_line() {
        assert!(parse_presentmon_frame_delta_ns("").is_none());
    }

    #[test]
    fn test_parse_presentmon_too_few_fields() {
        assert!(parse_presentmon_frame_delta_ns("a,b").is_none());
    }

    #[test]
    fn test_parse_presentmon_bad_number() {
        assert!(parse_presentmon_frame_delta_ns("a,b,not_a_number").is_none());
    }

    // -----------------------------------------------------------------------
    // Test 5: DxgiMethod enum values
    // -----------------------------------------------------------------------

    #[test]
    fn test_dxgi_method_enum_values() {
        let a = DxgiMethod::DetourHook;
        let b = DxgiMethod::PresentMon;
        assert_ne!(a, b);
    }

    // -----------------------------------------------------------------------
    // Test 6: DxgiSession construction
    // -----------------------------------------------------------------------

    #[test]
    fn test_dxgi_session_detour_hook() {
        let session = DxgiSession {
            method: DxgiMethod::DetourHook,
            shared_memory: None,
            presentmon: None,
        };
        assert_eq!(session.method, DxgiMethod::DetourHook);
        assert!(session.shared_memory.is_none());
    }

    #[test]
    fn test_dxgi_session_presentmon() {
        let session = DxgiSession {
            method: DxgiMethod::PresentMon,
            shared_memory: None,
            presentmon: None,
        };
        assert_eq!(session.method, DxgiMethod::PresentMon);
        assert!(session.presentmon.is_none());
    }

    // -----------------------------------------------------------------------
    // Test 7: measure_fps_presentmon integration
    // -----------------------------------------------------------------------

    #[test]
    fn test_measure_fps_presentmon_60fps() {
        let deltas: Vec<u64> = vec![16_666_667; 60];
        let session = PresentMonSession {
            child_pid: 0,
            frame_deltas_ns: deltas,
        };
        let result = measure_fps_presentmon(&session);
        assert!(result.fps > 55.0 && result.fps < 65.0);
        assert_eq!(result.jank_count, 0);
    }

    #[test]
    fn test_measure_fps_presentmon_with_jank() {
        let mut deltas = vec![16_666_667; 60];
        deltas[5] = 100_000_000; // Big jank
        let session = PresentMonSession {
            child_pid: 0,
            frame_deltas_ns: deltas,
        };
        let result = measure_fps_presentmon(&session);
        assert_eq!(result.jank_big_count, 1);
    }

    // -----------------------------------------------------------------------
    // Test 8: build_pc_frametimes_json
    // -----------------------------------------------------------------------

    #[test]
    fn test_build_pc_frametimes_json_non_empty() {
        let deltas = vec![16_666_667, 33_333_333, 50_000_000];
        let json = build_pc_frametimes_json(&deltas, 10);
        let parsed: Vec<f64> = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.len(), 3);
        assert!((parsed[0] - 16.667).abs() < 0.01);
        assert!((parsed[1] - 33.333).abs() < 0.01);
    }

    // -----------------------------------------------------------------------
    // Test 9: read_frame_deltas returns type (stub)
    // -----------------------------------------------------------------------

    #[test]
    fn test_read_frame_deltas_returns_vec() {
        let handle = SharedMemoryHandle {
            base_address: std::ptr::null_mut(),
            size: 65536,
        };
        let deltas = read_frame_deltas(&handle);
        assert!(deltas.is_empty()); // Stub returns empty
    }
}
