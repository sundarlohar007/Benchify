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

/// Get CPU frequency in MHz from Win32_Processor WMI or fallback.
///
/// WMI query: SELECT MaxClockSpeed FROM Win32_Processor
/// May fail due to user permissions — returns None gracefully.
#[cfg(windows)]
pub fn get_cpu_frequency_mhz() -> Option<f64> {
    // RED phase stub — will be implemented in GREEN phase
    None
}

#[cfg(not(windows))]
pub fn get_cpu_frequency_mhz() -> Option<f64> {
    None
}

/// Collect CPU metrics for a process by PID.
///
/// Process CPU % from PDH counter.
/// Per-core % from PDH Processor counters.
/// Per-thread CPU from CreateToolhelp32Snapshot + QueryThreadCycleTime.
/// CPU frequency from Win32_Processor WMI.
#[cfg(windows)]
pub fn collect_cpu(_process_id: u32, _num_cores: u32) -> Result<PcCpuSnapshot, String> {
    // RED phase stub — will be implemented in GREEN phase
    Err("PC CPU collection not yet implemented".to_string())
}

#[cfg(not(windows))]
pub fn collect_cpu(_process_id: u32, _num_cores: u32) -> Result<PcCpuSnapshot, String> {
    Err("PC CPU collection is Windows-only".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pc_cpu_snapshot_default() {
        let snap = PcCpuSnapshot::default();
        assert!(snap.process_pct.is_none());
        assert!(snap.per_core_pct.is_empty());
        assert!(snap.thread_data.is_empty());
        assert!(snap.frequency_mhz.is_none());
    }

    #[test]
    fn test_thread_cpu_construction() {
        let tc = ThreadCpu {
            tid: 1234,
            name: "UnityMain".to_string(),
            cpu_pct: 18.5,
        };
        assert_eq!(tc.tid, 1234);
        assert_eq!(tc.name, "UnityMain");
        assert!((tc.cpu_pct - 18.5).abs() < 0.01);
    }

    #[test]
    #[cfg_attr(not(windows), ignore = "CPU collection requires Windows")]
    fn test_collect_cpu_returns_thread_data() {
        // This test FAILS in RED because collect_cpu is a stub returning Err.
        // In GREEN, it should return Ok with thread data for the current process.
        let result = collect_cpu(std::process::id(), 4);
        assert!(
            result.is_ok(),
            "collect_cpu should return Ok for current process, got: {:?}",
            result
        );

        let snap = result.unwrap();
        // Should have at least the main thread
        assert!(
            !snap.thread_data.is_empty(),
            "Should have at least 1 thread for a running process"
        );
    }

    #[test]
    #[cfg_attr(not(windows), ignore = "CPU frequency requires Windows")]
    fn test_get_cpu_frequency_returns_some_or_none() {
        // This test checks that get_cpu_frequency_mhz() exists and doesn't panic.
        // It may return None if the stub is active (RED) or if WMI is unavailable.
        let freq = get_cpu_frequency_mhz();
        // In RED: always None (stub)
        // In GREEN: may be Some(freq) or None if WMI unavailable
        if let Some(mhz) = freq {
            assert!(mhz > 0.0, "CPU frequency should be positive, got {}", mhz);
            assert!(mhz < 10000.0, "CPU frequency should be reasonable, got {}", mhz);
        }
    }
}
