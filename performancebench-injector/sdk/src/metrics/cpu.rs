//! CPU metric collection via /proc/self/stat and /proc/stat.
//!
//! Read utime + stime from fields 14-15 (1-indexed) of /proc/self/stat.
//! Compute delta per second, divide by clock ticks (_SC_CLK_TCK via libc::sysconf),
//! normalize to percentage.
//! Read /proc/stat for system-wide CPU time to compute cpu_system_pct.
//!
//! Output fields: cpu_app_pct, cpu_system_pct, cpu_app_pct_freq_norm,
//! cpu_cores, cpu_core_states_json, cpu_core_freqs_json.

//! Parse /proc/self/stat line and extract utime and stime.
//! Fields 14 = utime, 15 = stime (1-indexed).
//! The process name (field 2) may contain spaces enclosed in parentheses.
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
/// We sum ALL columns (up to 10 numeric fields) to capture steal/guest time
/// on virtualized kernels.
pub fn parse_proc_stat_total(content: &str) -> u64 {
    for line in content.lines() {
        if line.starts_with("cpu ") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 5 {
                return parts[1..]
                    .iter()
                    .filter_map(|s| s.parse::<u64>().ok())
                    .sum();
            }
        }
    }
    0
}

/// Parse idle ticks from /proc/stat (field 5 = idle, 1-indexed including label).
/// Used for `cpu_system_pct = ((Δtotal - Δidle) / Δtotal) × 100`.
pub fn parse_idle_ticks(content: &str) -> u64 {
    for line in content.lines() {
        if line.starts_with("cpu ") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            // parts[0] = "cpu", parts[4] = idle (user=1, nice=2, system=3, idle=4)
            if parts.len() >= 5 {
                return parts[4].parse::<u64>().unwrap_or(0);
            }
        }
    }
    0
}

/// Compute app CPU percentage from per-process and total tick deltas.
///
/// Per UNIFIED-SPEC §5.2 line 647:
///   cpu_app_pct = (Δpid_ticks / Δtotal_ticks) × 100.0
///
/// Returns None if total_delta is zero (would be division by zero).
pub fn compute_app_cpu_pct(pid_ticks_delta: u64, total_ticks_delta: u64) -> Option<f64> {
    if total_ticks_delta == 0 {
        return None;
    }
    let pct = (pid_ticks_delta as f64 / total_ticks_delta as f64) * 100.0;
    Some(pct.clamp(0.0, 100.0))
}

/// Compute system-wide CPU percentage.
///
/// Per UNIFIED-SPEC §5.2 line 648:
///   cpu_system_pct = ((Δtotal_ticks − Δidle_ticks) / Δtotal_ticks) × 100.0
///
/// Returns None if total_delta is zero.
#[allow(dead_code)] // called from transport.rs on non-windows targets
pub fn compute_system_cpu_pct(total_delta: u64, idle_delta: u64) -> Option<f64> {
    if total_delta == 0 {
        return None;
    }
    let busy = total_delta.saturating_sub(idle_delta);
    let pct = (busy as f64 / total_delta as f64) * 100.0;
    Some(pct.clamp(0.0, 100.0))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_proc_self_stat_normal() {
        // /proc/self/stat fields (1-indexed per proc(5)):
        //   1=pid 2=comm 3=state 4=ppid 5=pgrp 6=session 7=tty 8=tpgid 9=flags
        //   10=minflt 11=cminflt 12=majflt 13=cmajflt 14=utime 15=stime
        let line = "12345 (my.app) S 1 12345 12345 0 -1 4194304 1234 56 78 90 100 50 25 20 15 0 0 0 12345 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0";
        let (utime, stime) = parse_proc_self_stat(line);
        assert_eq!(utime, 100);
        assert_eq!(stime, 50);
    }

    #[test]
    fn test_parse_proc_self_stat_spaces_in_name() {
        let line = "42 (My Cool App) S 1 42 42 0 -1 1073741824 500 0 0 100 200 300 400 50 60 0 0 0 1000 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0";
        let (utime, stime) = parse_proc_self_stat(line);
        assert_eq!(utime, 200);
        assert_eq!(stime, 300);
    }

    #[test]
    fn test_parse_proc_stat_total() {
        // 10 fields: user nice system idle iowait irq softirq steal guest guest_nice
        let content = "cpu  1120345 4533 345678 9876543 12345 0 2345 100 50 25\ncpu0 112034 453 34567 987654 1234 0 234 0 0 0\n";
        let expected: u64 = 1120345 + 4533 + 345678 + 9876543 + 12345 + 0 + 2345 + 100 + 50 + 25;
        assert_eq!(parse_proc_stat_total(content), expected);
    }

    #[test]
    fn test_parse_proc_stat_total_7_fields() {
        // Older kernels may have only 7 fields
        let content = "cpu  1120345 4533 345678 9876543 12345 0 2345\ncpu0 112034 453 34567 987654 1234 0 234\n";
        let expected: u64 = 1120345 + 4533 + 345678 + 9876543 + 12345 + 0 + 2345;
        assert_eq!(parse_proc_stat_total(content), expected);
    }

    #[test]
    fn test_parse_idle_ticks() {
        let content = "cpu  1120345 4533 345678 9876543 12345 0 2345 0 0 0\n";
        assert_eq!(parse_idle_ticks(content), 9876543);
    }

    #[test]
    fn test_compute_app_cpu_pct() {
        // Δpid = 500, Δtotal = 1000 → 50%
        let pct = compute_app_cpu_pct(500, 1000);
        assert!((pct.unwrap() - 50.0).abs() < 0.01);
    }

    #[test]
    fn test_compute_app_cpu_pct_zero_total() {
        assert!(compute_app_cpu_pct(50, 0).is_none());
    }

    #[test]
    fn test_compute_app_cpu_pct_clamped() {
        // More pid ticks than total (impossible in reality but test clamping)
        let pct = compute_app_cpu_pct(2000, 1000);
        assert!((pct.unwrap() - 100.0).abs() < 0.01);
    }

    #[test]
    fn test_compute_system_cpu_pct() {
        // Δtotal = 1000, Δidle = 400 → busy = 600 → 60%
        let pct = compute_system_cpu_pct(1000, 400);
        assert!((pct.unwrap() - 60.0).abs() < 0.01);
    }

    #[test]
    fn test_compute_system_cpu_pct_zero_total() {
        assert!(compute_system_cpu_pct(0, 0).is_none());
    }
}
