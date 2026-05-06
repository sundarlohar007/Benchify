/// Memory metric collection via ActivityManager JNI and /proc/self/status.
///
/// Primary: ActivityManager.getProcessMemoryInfo([pid]) via JNI.
/// Fallback: Read /proc/self/status VmRSS if ActivityManager unavailable.
///
/// Maps to: memory_pss_kb (totalPss), memory_java_kb (dalvikPss),
/// memory_native_kb (nativePss), memory_system_kb (otherPss).

/// Memory information from ActivityManager or /proc fallback.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MemoryInfo {
    pub total_pss: i32,
    pub dalvik_pss: i32,
    pub native_pss: i32,
    pub other_pss: i32,
}

/// Parse VmRSS (resident set size in kB) from /proc/self/status.
/// Format: "VmRSS:    12345 kB"
pub fn parse_vmrss(status_content: &str) -> Option<i64> {
    for line in status_content.lines() {
        if line.starts_with("VmRSS:") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 2 {
                return parts[1].parse::<i64>().ok();
            }
        }
    }
    None
}

/// Parse VmSize from /proc/self/status.
pub fn parse_vmsize(status_content: &str) -> Option<i64> {
    for line in status_content.lines() {
        if line.starts_with("VmSize:") {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 2 {
                return parts[1].parse::<i64>().ok();
            }
        }
    }
    None
}

/// Build MemoryInfo from /proc/self/status content (fallback path).
/// total_pss = VmRSS; other_pss = VmSize - VmRSS (approximation).
pub fn parse_memory_from_status(status_content: &str) -> MemoryInfo {
    let total_pss = parse_vmrss(status_content).unwrap_or(0) as i32;
    let vmsize = parse_vmsize(status_content).unwrap_or(0);
    let other_pss = (vmsize as i32).saturating_sub(total_pss).max(0);

    MemoryInfo {
        total_pss,
        dalvik_pss: 0,
        native_pss: 0,
        other_pss,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_vmrss() {
        let status = "Name:   com.example.app\nState:  R\nVmSize:   100000 kB\nVmRSS:     45678 kB\n";
        assert_eq!(parse_vmrss(status), Some(45678));
    }

    #[test]
    fn test_parse_vmrss_not_found() {
        assert_eq!(parse_vmrss("Name: test"), None);
    }

    #[test]
    fn test_parse_vmsize() {
        let status = "VmSize:   100000 kB\nVmRSS:     45678 kB\n";
        assert_eq!(parse_vmsize(status), Some(100000));
    }

    #[test]
    fn test_memory_info_struct() {
        let info = MemoryInfo { total_pss: 245760, dalvik_pss: 45000, native_pss: 120000, other_pss: 80760 };
        assert_eq!(info.total_pss, 245760);
        assert_eq!(info.other_pss, 80760);
    }
}
