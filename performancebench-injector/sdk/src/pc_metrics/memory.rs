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
    // RED phase stub — will be implemented in Task 2
    Err("PC memory collection not yet implemented".to_string())
}

#[cfg(not(windows))]
pub fn collect_memory(_process_id: u32) -> Result<PcMemorySnapshot, String> {
    Err("PC memory collection is Windows-only".to_string())
}
