// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// PC memory metrics: working set, private bytes, GPU committed memory.
///
/// Per D-11 and §19.2: PC-appropriate memory metrics, not forced mobile parity.
/// Uses GetProcessMemoryInfo (working set, private bytes) and PDH counters
/// for GPU committed memory.
///
/// All code is `#[cfg(windows)]` gated.

/// Snapshot of PC memory metrics for a single process.
#[derive(Debug, Clone, Default)]
pub struct PcMemorySnapshot {
    pub working_set_kb: Option<i64>,
    pub private_bytes_kb: Option<i64>,
    pub gpu_dedicated_mem_kb: Option<i64>,
    pub gpu_shared_mem_kb: Option<i64>,
    pub page_faults_per_s: Option<f64>,
}

/// Collect memory metrics for a process by PID.
///
/// Uses GetProcessMemoryInfo for working set and private bytes.
/// GPU committed memory from PDH snapshots (cached from pdh.rs).
#[cfg(windows)]
pub fn collect_memory(_process_id: u32) -> Result<PcMemorySnapshot, String> {
    // RED phase stub — will be implemented in GREEN phase
    Err("PC memory collection not yet implemented".to_string())
}

#[cfg(not(windows))]
pub fn collect_memory(_process_id: u32) -> Result<PcMemorySnapshot, String> {
    Err("PC memory collection is Windows-only".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pc_memory_snapshot_default() {
        let snap = PcMemorySnapshot::default();
        assert!(snap.working_set_kb.is_none());
        assert!(snap.private_bytes_kb.is_none());
    }

    #[test]
    #[cfg_attr(not(windows), ignore = "Memory collection requires Windows")]
    fn test_collect_memory_returns_data_for_current_process() {
        // This test FAILS in RED because collect_memory is a stub returning Err.
        // In GREEN, it should return Ok with memory data for the current process.
        let result = collect_memory(std::process::id());
        assert!(
            result.is_ok(),
            "collect_memory should return Ok for current process, got: {:?}",
            result
        );

        let snap = result.unwrap();
        // Working set should be non-zero for a running process
        assert!(snap.working_set_kb.is_some(), "Working set should be present");
        assert!(
            snap.working_set_kb.unwrap() > 0,
            "Working set should be > 0 KB for a running process"
        );
    }

    #[test]
    #[cfg_attr(not(windows), ignore = "Memory collection requires Windows")]
    fn test_collect_memory_returns_private_bytes() {
        let result = collect_memory(std::process::id());
        assert!(result.is_ok(), "collect_memory should return Ok");
        let snap = result.unwrap();
        assert!(snap.private_bytes_kb.is_some(), "Private bytes should be present");
        assert!(
            snap.private_bytes_kb.unwrap() > 0,
            "Private bytes should be > 0 KB"
        );
    }
}
