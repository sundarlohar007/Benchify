// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// GPU metrics via PDH counters.
///
/// Uses PDH counters:
/// - `\GPU Engine(*engtype_3D)\Utilization Percentage`
/// - `\GPU Process Memory(*)\Dedicated Usage`
/// - `\GPU Process Memory(*)\Shared Usage`
///
/// All code is `#[cfg(windows)]` gated.

/// GPU metrics extracted from a PDH snapshot.
#[derive(Debug, Clone, Default)]
pub struct PcGpuSnapshot {
    pub usage_pct: Option<f64>,
    pub dedicated_mem_kb: Option<i64>,
    pub shared_mem_kb: Option<i64>,
}

/// Extract GPU metrics from a PDH metrics snapshot.
pub fn read_gpu_from_snapshot(
    usage: Option<f64>,
    dedicated: Option<i64>,
    shared: Option<i64>,
) -> PcGpuSnapshot {
    PcGpuSnapshot {
        usage_pct: usage,
        dedicated_mem_kb: dedicated,
        shared_mem_kb: shared,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_gpu_snapshot_default() {
        let snap = PcGpuSnapshot::default();
        assert!(snap.usage_pct.is_none());
        assert!(snap.dedicated_mem_kb.is_none());
        assert!(snap.shared_mem_kb.is_none());
    }

    #[test]
    fn test_read_gpu_from_snapshot_with_values() {
        let snap = read_gpu_from_snapshot(Some(75.5), Some(2048000), Some(512000));
        assert!((snap.usage_pct.unwrap() - 75.5).abs() < 0.01);
        assert_eq!(snap.dedicated_mem_kb.unwrap(), 2048000);
        assert_eq!(snap.shared_mem_kb.unwrap(), 512000);
    }

    #[test]
    fn test_read_gpu_from_snapshot_none() {
        let snap = read_gpu_from_snapshot(None, None, None);
        assert!(snap.usage_pct.is_none());
        assert!(snap.dedicated_mem_kb.is_none());
        assert!(snap.shared_mem_kb.is_none());
    }
}
