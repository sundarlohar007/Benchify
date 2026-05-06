/// CPU metric collection via /proc/self/stat and /proc/stat.
///
/// Read utime + stime from fields 14-15 (1-indexed) of /proc/self/stat.
/// Compute delta per second, divide by clock ticks (_SC_CLK_TCK via libc::sysconf),
/// normalize to percentage.
/// Read /proc/stat for system-wide CPU time to compute cpu_system_pct.
///
/// Output fields: cpu_app_pct, cpu_system_pct, cpu_app_pct_freq_norm,
/// cpu_cores, cpu_core_states_json, cpu_core_freqs_json.

/// Parse /proc/self/stat line and extract utime and stime.
/// Fields 14 = utime, 15 = stime (1-indexed).
/// The process name (field 2) may contain spaces enclosed in parentheses.
pub fn parse_proc_self_stat(line: &str) -> (u64, u64) {
    let close_paren = match line.rfind(')') {
        Some(pos) => pos,
        None => return (0, 0),
    };

    let after_name = &line[close_paren + 2..];
    let fields: Vec<&str> = after_name.split_whitespace().collect();

    if fields.len() < 13 {
        return (0, 0);
    }

    let utime = fields[11].parse::<u64>().unwrap_or(0);
    let stime = fields[12].parse::<u64>().unwrap_or(0);

    (utime, stime)
}

/// Parse /proc/stat first line to get total CPU time across all cores.
/// Format: cpu user nice system idle iowait irq softirq steal guest guest_nice
pub fn parse_proc_stat_total(content: &str) -> u64 {
    for line in content.lines() {
        if line.starts_with("cpu ") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 8 {
                return parts[1..8]
                    .iter()
                    .filter_map(|s| s.parse::<u64>().ok())
                    .sum();
            }
        }
    }
    0
}

/// Compute app CPU percentage from a CPU time delta (in seconds).
/// Normalizes to percentage: delta_secs * 100, clamped to [0, 100].
pub fn compute_app_cpu_pct(cpu_time_delta_secs: f64) -> Option<f64> {
    let pct = cpu_time_delta_secs * 100.0;
    Some(pct.clamp(0.0, 100.0))
}

/// Compute system-wide CPU percentage from a total CPU time delta in jiffies.
/// Normalizes using _SC_CLK_TCK.
pub fn compute_system_cpu_pct(total_delta: u64) -> Option<f64> {
    let clock_ticks = unsafe { libc::sysconf(libc::_SC_CLK_TCK) } as f64;
    if clock_ticks <= 0.0 {
        return None;
    }
    let delta_secs = total_delta as f64 / clock_ticks;
    Some((delta_secs / 1.0).clamp(0.0, 100.0))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_proc_self_stat_normal() {
        let line = "12345 (my.app) S 1 12345 12345 0 -1 4194304 1234 56 78 90 100 50 25 20 15 0 0 0 12345 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0";
        let (utime, stime) = parse_proc_self_stat(line);
        assert_eq!(utime, 50);
        assert_eq!(stime, 25);
    }

    #[test]
    fn test_parse_proc_self_stat_spaces_in_name() {
        let line = "42 (My Cool App) S 1 42 42 0 -1 1073741824 500 0 0 100 200 300 400 50 60 0 0 0 1000 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0";
        let (utime, stime) = parse_proc_self_stat(line);
        assert_eq!(utime, 300);
        assert_eq!(stime, 400);
    }

    #[test]
    fn test_parse_proc_stat_total() {
        let content = "cpu  1120345 4533 345678 9876543 12345 0 2345 0 0 0\ncpu0 112034 453 34567 987654 1234 0 234 0 0 0\n";
        let expected: u64 = 1120345 + 4533 + 345678 + 9876543 + 12345 + 0 + 2345;
        assert_eq!(parse_proc_stat_total(content), expected);
    }

    #[test]
    fn test_compute_app_cpu_pct() {
        let pct = compute_app_cpu_pct(0.5);
        assert!((pct.unwrap() - 50.0).abs() < 0.01);
    }

    #[test]
    fn test_compute_app_cpu_pct_clamped() {
        let pct = compute_app_cpu_pct(2.0);
        assert!((pct.unwrap() - 100.0).abs() < 0.01);
    }
}
