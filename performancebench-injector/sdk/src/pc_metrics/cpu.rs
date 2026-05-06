// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// PC CPU metrics: per-process CPU time, per-thread CPU %, frequency via WMI.
///
/// Per D-11 and §19.2: PC-appropriate CPU metrics including per-thread breakdown
/// and CPU frequency from Win32_Processor WMI.
///
/// All code is `#[cfg(windows)]` gated.

/// Per-thread CPU data.
#[derive(Debug, Clone)]
pub struct ThreadCpu {
    pub tid: u32,
    pub name: String,
    pub cpu_pct: f64,
}

/// Snapshot of PC CPU metrics for a single process.
#[derive(Debug, Clone, Default)]
pub struct PcCpuSnapshot {
    pub process_pct: Option<f64>,
    pub per_core_pct: Vec<f64>,
    pub thread_data: Vec<ThreadCpu>,
    pub frequency_mhz: Option<f64>,
}

/// Collect CPU metrics for a process by PID.
///
/// Process CPU % from PDH counter.
/// Per-core % from PDH Processor counters.
/// Per-thread CPU from CreateToolhelp32Snapshot + QueryThreadCycleTime.
/// CPU frequency from Win32_Processor WMI.
#[cfg(windows)]
pub fn collect_cpu(_process_id: u32, _num_cores: u32) -> Result<PcCpuSnapshot, String> {
    // RED phase stub — will be implemented in Task 2
    Err("PC CPU collection not yet implemented".to_string())
}

#[cfg(not(windows))]
pub fn collect_cpu(_process_id: u32, _num_cores: u32) -> Result<PcCpuSnapshot, String> {
    Err("PC CPU collection is Windows-only".to_string())
}
