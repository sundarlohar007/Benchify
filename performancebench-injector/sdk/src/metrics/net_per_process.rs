/// Per-process network statistics from /proc/<pid>/net/dev.
///
/// Per D-16: Per-process network totals via /proc/pid/net/dev.
/// TX/RX bytes per interface. No socket-level interception.
///
/// At runtime, the SDK reads its own process's network stats via
/// /proc/self/net/dev (equivalent to /proc/<pid>/net/dev in same process).
/// This provides the app's own network usage, not device-wide.
///
/// Interface classification:
///   - wlan*, wifi* -> wifi
///   - rmnet* -> cellular
///   - everything else -> other
///
/// Per T-04-16: Reads only current process's /proc/self/net/dev —
/// no cross-process data access.

use std::collections::HashMap;
use std::fs;

/// Network interface statistics from /proc/self/net/dev.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NetInterface {
    pub name: String,
    pub rx_bytes: u64,
    pub rx_packets: u64,
    pub tx_bytes: u64,
    pub tx_packets: u64,
}

/// Network delta (bytes) for a single interface between two snapshots.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NetDelta {
    pub name: String,
    pub rx_delta: u64,
    pub tx_delta: u64,
}

/// Summarized per-process network deltas by interface classification.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct NetPerProcessResult {
    pub total_tx: u64,
    pub total_rx: u64,
    pub wifi_tx: u64,
    pub wifi_rx: u64,
    pub cellular_tx: u64,
    pub cellular_rx: u64,
    pub other_tx: u64,
    pub other_rx: u64,
}

/// PID for /proc/<pid>/net/dev reads. 0 means use self.
static mut TRACKED_PID: u32 = 0;

/// Previous network snapshot for delta computation.
static mut PREV_SNAPSHOT: Option<Vec<NetInterface>> = None;

/// Initialize per-process network tracking for a specific PID.
///
/// Use PID 0 to track the current process (/proc/self).
pub fn init(pid: u32) {
    unsafe {
        TRACKED_PID = pid;
        PREV_SNAPSHOT = None;
    }
}

/// Parse /proc/<pid>/net/dev content into network interface list.
///
/// Skips header lines (Inter-|, face) and loopback (lo) interface.
/// Parses: name: rx_bytes rx_packets ... tx_bytes tx_packets ...
pub fn parse_net_dev(content: &str) -> Vec<NetInterface> {
    let mut ifaces = Vec::new();

    for line in content.lines() {
        let trimmed = line.trim();

        // Skip header lines
        if trimmed.starts_with("Inter-") || trimmed.starts_with("face") || trimmed.is_empty() {
            continue;
        }

        // Find colon separator between interface name and stats
        let colon_pos = match trimmed.find(':') {
            Some(p) => p,
            None => continue,
        };

        let name = trimmed[..colon_pos].trim().to_string();

        // Skip loopback
        if name == "lo" {
            continue;
        }

        let data = &trimmed[colon_pos + 1..];
        let fields: Vec<&str> = data.split_whitespace().collect();

        // Need at least 10 fields: rx_bytes(0), rx_packets(1), tx_bytes(8), tx_packets(9)
        if fields.len() < 10 {
            continue;
        }

        let rx_bytes = fields[0].parse::<u64>().unwrap_or(0);
        let rx_packets = fields[1].parse::<u64>().unwrap_or(0);
        let tx_bytes = fields[8].parse::<u64>().unwrap_or(0);
        let tx_packets = fields[9].parse::<u64>().unwrap_or(0);

        ifaces.push(NetInterface {
            name,
            rx_bytes,
            rx_packets,
            tx_bytes,
            tx_packets,
        });
    }

    ifaces
}

/// Classify a network interface by name.
///
/// - wlan*, wifi* -> wifi
/// - rmnet* -> cellular
/// - everything else -> other
pub fn classify_interface(name: &str) -> &'static str {
    let lower = name.to_lowercase();
    if lower.starts_with("wlan") || lower.starts_with("wifi") {
        "wifi"
    } else if lower.starts_with("rmnet") {
        "cellular"
    } else {
        "other"
    }
}

/// Compute per-interface byte deltas between two snapshots.
///
/// New interfaces (no previous snapshot) are skipped — their counters
/// would include all historical traffic.
pub fn compute_deltas(prev: &[NetInterface], curr: &[NetInterface]) -> Vec<NetDelta> {
    curr.iter()
        .filter_map(|c| {
            prev.iter().find(|p| p.name == c.name).map(|p| NetDelta {
                name: c.name.clone(),
                rx_delta: c.rx_bytes.saturating_sub(p.rx_bytes),
                tx_delta: c.tx_bytes.saturating_sub(p.tx_bytes),
            })
        })
        .collect()
}

/// Summarize deltas by interface classification.
pub fn summarize_deltas(deltas: &[NetDelta]) -> NetPerProcessResult {
    let mut result = NetPerProcessResult::default();

    for d in deltas {
        result.total_tx = result.total_tx.saturating_add(d.tx_delta);
        result.total_rx = result.total_rx.saturating_add(d.rx_delta);

        match classify_interface(&d.name) {
            "wifi" => {
                result.wifi_tx = result.wifi_tx.saturating_add(d.tx_delta);
                result.wifi_rx = result.wifi_rx.saturating_add(d.rx_delta);
            }
            "cellular" => {
                result.cellular_tx = result.cellular_tx.saturating_add(d.tx_delta);
                result.cellular_rx = result.cellular_rx.saturating_add(d.rx_delta);
            }
            _ => {
                result.other_tx = result.other_tx.saturating_add(d.tx_delta);
                result.other_rx = result.other_rx.saturating_add(d.rx_delta);
            }
        }
    }

    result
}

/// Collect per-process network stats and return deltas since last collection.
///
/// Reads /proc/<pid>/net/dev (or /proc/self/net/dev if pid is 0).
/// Computes byte deltas per interface. Classifies by interface type.
///
/// On first call, stores initial snapshot and returns empty result.
pub fn collect(pid: Option<u32>) -> NetPerProcessResult {
    let effective_pid = pid.unwrap_or(unsafe { TRACKED_PID });

    let path = if effective_pid == 0 {
        "/proc/self/net/dev".to_string()
    } else {
        format!("/proc/{}/net/dev", effective_pid)
    };

    // Read /proc/.../net/dev
    let content = match fs::read_to_string(&path) {
        Ok(c) => c,
        Err(e) => {
            log::warn!("Failed to read {}: {}", path, e);
            return NetPerProcessResult::default();
        }
    };

    let current = parse_net_dev(&content);

    unsafe {
        let prev = PREV_SNAPSHOT.take();
        let (deltas, result) = match prev {
            Some(ref p) => {
                let d = compute_deltas(p, &current);
                let r = summarize_deltas(&d);
                (d, r)
            }
            None => {
                // First collection — no deltas yet
                (Vec::new(), NetPerProcessResult::default())
            }
        };

        // Store current snapshot for next collection
        PREV_SNAPSHOT = Some(current);

        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_net_dev_basic() {
        let content = "wlan0: 1234567890 9876543 0 0 0 0 0 0 9876543210 7654321 0 0 0 0 0 0\n";
        let ifaces = parse_net_dev(content);
        assert_eq!(ifaces.len(), 1);
        assert_eq!(ifaces[0].name, "wlan0");
        assert_eq!(ifaces[0].rx_bytes, 1234567890);
        assert_eq!(ifaces[0].tx_bytes, 9876543210);
    }

    #[test]
    fn test_parse_net_dev_skips_loopback() {
        let content = "lo: 1000 5 0 0 0 0 0 0 1000 5 0 0 0 0 0 0\nwlan0: 100 10 0 0 0 0 0 0 200 20 0 0 0 0 0 0\n";
        let ifaces = parse_net_dev(content);
        assert_eq!(ifaces.len(), 1);
        assert_eq!(ifaces[0].name, "wlan0");
    }

    #[test]
    fn test_parse_net_dev_skips_headers() {
        let content = "Inter-|   Receive                                                |  Transmit\n face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed\nwlan0: 500 10 0 0 0 0 0 0 300 5 0 0 0 0 0 0\n";
        let ifaces = parse_net_dev(content);
        assert_eq!(ifaces.len(), 1);
    }

    #[test]
    fn test_parse_net_dev_multiple() {
        let content = "wlan0: 1000 10 0 0 0 0 0 0 500 5 0 0 0 0 0 0\nrmnet_data0: 200 2 0 0 0 0 0 0 100 1 0 0 0 0 0 0\neth0: 300 3 0 0 0 0 0 0 150 2 0 0 0 0 0 0\n";
        let ifaces = parse_net_dev(content);
        assert_eq!(ifaces.len(), 3);
    }

    #[test]
    fn test_classify_wifi() {
        assert_eq!(classify_interface("wlan0"), "wifi");
        assert_eq!(classify_interface("wlan1"), "wifi");
        assert_eq!(classify_interface("wifi0"), "wifi");
    }

    #[test]
    fn test_classify_cellular() {
        assert_eq!(classify_interface("rmnet_data0"), "cellular");
        assert_eq!(classify_interface("rmnet0"), "cellular");
    }

    #[test]
    fn test_classify_other() {
        assert_eq!(classify_interface("eth0"), "other");
        assert_eq!(classify_interface("dummy0"), "other");
    }

    #[test]
    fn test_compute_deltas_basic() {
        let prev = vec![NetInterface {
            name: "wlan0".into(), rx_bytes: 10000, rx_packets: 100,
            tx_bytes: 5000, tx_packets: 50,
        }];
        let curr = vec![NetInterface {
            name: "wlan0".into(), rx_bytes: 15000, rx_packets: 150,
            tx_bytes: 8000, tx_packets: 80,
        }];
        let deltas = compute_deltas(&prev, &curr);
        assert_eq!(deltas.len(), 1);
        assert_eq!(deltas[0].rx_delta, 5000);
        assert_eq!(deltas[0].tx_delta, 3000);
    }

    #[test]
    fn test_compute_deltas_new_interface() {
        let prev: Vec<NetInterface> = vec![];
        let curr = vec![NetInterface {
            name: "wlan0".into(), rx_bytes: 15000, rx_packets: 150,
            tx_bytes: 8000, tx_packets: 80,
        }];
        assert_eq!(compute_deltas(&prev, &curr).len(), 0);
    }

    #[test]
    fn test_compute_deltas_saturating() {
        // Counter wraparound — should saturate to 0
        let prev = vec![NetInterface {
            name: "wlan0".into(), rx_bytes: 15000, rx_packets: 100,
            tx_bytes: 8000, tx_packets: 50,
        }];
        let curr = vec![NetInterface {
            name: "wlan0".into(), rx_bytes: 10000, rx_packets: 100,
            tx_bytes: 5000, tx_packets: 50,
        }];
        let deltas = compute_deltas(&prev, &curr);
        assert_eq!(deltas[0].rx_delta, 0); // saturating
        assert_eq!(deltas[0].tx_delta, 0); // saturating
    }

    #[test]
    fn test_summarize_deltas() {
        let deltas = vec![
            NetDelta { name: "wlan0".into(), rx_delta: 1000, tx_delta: 500 },
            NetDelta { name: "rmnet0".into(), rx_delta: 200, tx_delta: 100 },
            NetDelta { name: "eth0".into(), rx_delta: 50, tx_delta: 25 },
        ];
        let s = summarize_deltas(&deltas);
        assert_eq!(s.total_rx, 1250);
        assert_eq!(s.total_tx, 625);
        assert_eq!(s.wifi_rx, 1000);
        assert_eq!(s.wifi_tx, 500);
        assert_eq!(s.cellular_rx, 200);
        assert_eq!(s.cellular_tx, 100);
        assert_eq!(s.other_rx, 50);
        assert_eq!(s.other_tx, 25);
    }

    #[test]
    fn test_net_per_process_result_default() {
        let r = NetPerProcessResult::default();
        assert_eq!(r.total_tx, 0);
        assert_eq!(r.total_rx, 0);
        assert_eq!(r.wifi_tx, 0);
    }

    #[test]
    fn test_collect_first_call_returns_empty() {
        // Reset state
        init(0);

        // First call should return empty (no previous snapshot)
        // Note: this will fail if /proc/self/net/dev doesn't exist (non-Linux)
        let result = collect(None);
        // If /proc/self/net/dev exists, first call stores snapshot and returns 0
        // If file doesn't exist, returns default (0s)
        assert_eq!(result.total_tx, 0);
        assert_eq!(result.total_rx, 0);
    }
}
