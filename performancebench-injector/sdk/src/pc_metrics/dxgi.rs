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
/// In a full deployment, this would embed a pre-compiled DLL. For now,
/// this is a library function that returns a placeholder — the actual DLL
/// is compiled separately and shipped alongside pb-pcprobe.
#[cfg(windows)]
pub fn build_dxgi_hook_dll() -> Result<Vec<u8>, String> {
    // RED phase stub — will be implemented in GREEN phase
    Err("DXGI hook DLL not yet implemented (RED phase)".to_string())
}

#[cfg(not(windows))]
pub fn build_dxgi_hook_dll() -> Result<Vec<u8>, String> {
    Err("DXGI hook DLL is Windows-only".to_string())
}

/// Inject the DXGI hook DLL into a target process.
///
/// Uses OpenProcess + VirtualAllocEx + WriteProcessMemory + CreateRemoteThread
/// to inject the DLL via LoadLibraryW.
///
/// Requires PROCESS_VM_OPERATION and PROCESS_CREATE_THREAD.
/// Returns a handle to the shared memory ring buffer.
#[cfg(windows)]
pub fn inject_dx_hook(_process_id: u32, _dll_bytes: &[u8]) -> Result<SharedMemoryHandle, String> {
    // RED phase stub — will be implemented in GREEN phase
    Err("DXGI injection not yet implemented (RED phase)".to_string())
}

#[cfg(not(windows))]
pub fn inject_dx_hook(_process_id: u32, _dll_bytes: &[u8]) -> Result<SharedMemoryHandle, String> {
    Err("DXGI injection is Windows-only".to_string())
}

/// Read frame deltas from the shared memory ring buffer.
///
/// Reads from head to tail, computes QPC deltas between consecutive entries,
/// and converts QPC deltas to nanoseconds using QueryPerformanceFrequency.
///
/// Returns Vec<u64> of inter-frame intervals in nanoseconds.
#[cfg(windows)]
pub fn read_frame_deltas(_ring_buffer: &SharedMemoryHandle) -> Vec<u64> {
    // RED phase stub — will be implemented in GREEN phase
    Vec::new()
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
/// Ships presentmon.exe (Microsoft MIT-licensed) and spawns it:
/// `presentmon.exe --process_name {name} --output_stdout --timed 1`
///
/// PresentMon outputs CSV to stdout with frame timestamps:
/// `FrameTime,TimeInSeconds,MsBetweenPresents,...`
#[cfg(windows)]
pub fn start_presentmon(_process_name: &str) -> Result<PresentMonSession, String> {
    // RED phase stub — will be implemented in GREEN phase
    Err("PresentMon not yet implemented (RED phase)".to_string())
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

/// Stop PresentMon subprocess.
#[cfg(windows)]
pub fn stop_presentmon(_session: PresentMonSession) {
    // RED phase stub — will be implemented in GREEN phase
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
