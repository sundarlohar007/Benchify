/// GPU utilization via sysfs.
///
/// Read /sys/class/kgsl/kgsl-3d0/gpubusy (Adreno) or
/// /sys/class/misc/mali0/device/utilization (Mali).
/// Output field: gpu_pct.

/// Parse Adreno gpubusy: "<gpu_busy_ns> <total_ns>"
/// GPU % = (gpu_busy / total) * 100.
pub fn parse_adreno_gpubusy(content: &str) -> Option<f64> {
    let parts: Vec<&str> = content.trim().split_whitespace().collect();
    if parts.len() < 2 {
        return None;
    }
    let busy = parts[0].parse::<u64>().ok()?;
    let total = parts[1].parse::<u64>().ok()?;
    if total == 0 {
        return Some(0.0);
    }
    Some((busy as f64 / total as f64) * 100.0)
}

/// Parse Mali utilization: "<gpu_util> <gpu_util_max>" (0-256 range).
/// GPU % = (gpu_util / 256) * 100.
pub fn parse_mali_utilization(content: &str) -> Option<f64> {
    let parts: Vec<&str> = content.trim().split_whitespace().collect();
    if parts.is_empty() {
        return None;
    }
    let util = parts[0].parse::<u64>().ok()?;
    Some((util as f64 / 256.0) * 100.0)
}

/// Parse GPU clock frequency in Hz, return MHz.
pub fn parse_gpu_clock_mhz(content: &str) -> Option<f64> {
    let hz = content.trim().parse::<f64>().ok()?;
    Some(hz / 1_000_000.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_adreno_normal() {
        let pct = parse_adreno_gpubusy("1234567890 9876543210");
        let expected = (1234567890.0 / 9876543210.0) * 100.0;
        assert!((pct.unwrap() - expected).abs() < 0.01);
    }

    #[test]
    fn test_adreno_zero_total() {
        assert_eq!(parse_adreno_gpubusy("0 0"), Some(0.0));
    }

    #[test]
    fn test_adreno_empty() {
        assert_eq!(parse_adreno_gpubusy(""), None);
    }

    #[test]
    fn test_mali_50_percent() {
        let pct = parse_mali_utilization("128 256");
        assert!((pct.unwrap() - 50.0).abs() < 0.01);
    }

    #[test]
    fn test_mali_100_percent() {
        let pct = parse_mali_utilization("256 256");
        assert!((pct.unwrap() - 100.0).abs() < 0.01);
    }

    #[test]
    fn test_gpu_clock_mhz() {
        let mhz = parse_gpu_clock_mhz("650000000");
        assert!((mhz.unwrap() - 650.0).abs() < 0.01);
    }
}
