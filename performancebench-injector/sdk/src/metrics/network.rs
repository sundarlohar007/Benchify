//! Per-process network metrics via /proc/self/net/dev.
//!
//! Per D-16: Track cumulative TX/RX bytes per interface.
//! Compute per-second deltas. Classify: wifi (wlan*), cellular (rmnet*), other.
//!
//! Output fields: net_tx_bytes, net_rx_bytes, net_wifi_tx_bytes, net_wifi_rx_bytes,
//! net_cellular_tx_bytes, net_cellular_rx_bytes, net_other_tx_bytes, net_other_rx_bytes.

/// Network interface statistics from /proc/self/net/dev.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NetInterface {
    pub name: String,
    pub rx_bytes: u64,
    pub rx_packets: u64,
    pub tx_bytes: u64,
    pub tx_packets: u64,
}

/// Network delta (bytes per second) for a single interface.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NetDelta {
    pub name: String,
    pub rx_delta: u64,
    pub tx_delta: u64,
}

/// Summarized network deltas by interface classification.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NetworkSummary {
    pub total_tx: u64,
    pub total_rx: u64,
    pub wifi_tx: u64,
    pub wifi_rx: u64,
    pub cellular_tx: u64,
    pub cellular_rx: u64,
    pub other_tx: u64,
    pub other_rx: u64,
}

/// Parse /proc/self/net/dev content into network interface list.
/// Skips header lines and loopback interface.
pub fn parse_net_dev(content: &str) -> Vec<NetInterface> {
    let mut ifaces = Vec::new();

    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("Inter-") || trimmed.starts_with("face") {
            continue;
        }

        let colon_pos = match trimmed.find(':') {
            Some(p) => p,
            None => continue,
        };

        let name = trimmed[..colon_pos].trim().to_string();
        if name == "lo" {
            continue;
        }

        let data = &trimmed[colon_pos + 1..];
        let fields: Vec<&str> = data.split_whitespace().collect();
        if fields.len() < 10 {
            continue;
        }

        let rx_bytes = fields[0].parse::<u64>().unwrap_or(0);
        let rx_packets = fields[1].parse::<u64>().unwrap_or(0);
        let tx_bytes = fields[8].parse::<u64>().unwrap_or(0);
        let tx_packets = fields[9].parse::<u64>().unwrap_or(0);

        ifaces.push(NetInterface { name, rx_bytes, rx_packets, tx_bytes, tx_packets });
    }

    ifaces
}

/// Compute per-interface byte deltas between two snapshots.
/// New interfaces (no previous snapshot) are skipped.
pub fn compute_network_deltas(prev: &[NetInterface], curr: &[NetInterface]) -> Vec<NetDelta> {
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

fn classify_interface(name: &str) -> &'static str {
    let lower = name.to_lowercase();
    if lower.starts_with("wlan") || lower.starts_with("wifi") || lower.starts_with("nan") {
        "wifi"
    } else if lower.starts_with("rmnet") || lower.starts_with("ccmni")
        || lower.starts_with("pdp") || lower.starts_with("ppp") {
        "cellular"
    } else {
        "other"
    }
}

/// Summarize deltas by interface type.
pub fn summarize_network_deltas(deltas: &[NetDelta]) -> NetworkSummary {
    let mut s = NetworkSummary {
        total_tx: 0, total_rx: 0,
        wifi_tx: 0, wifi_rx: 0,
        cellular_tx: 0, cellular_rx: 0,
        other_tx: 0, other_rx: 0,
    };

    for d in deltas {
        s.total_tx += d.tx_delta;
        s.total_rx += d.rx_delta;
        match classify_interface(&d.name) {
            "wifi" => { s.wifi_tx += d.tx_delta; s.wifi_rx += d.rx_delta; }
            "cellular" => { s.cellular_tx += d.tx_delta; s.cellular_rx += d.rx_delta; }
            _ => { s.other_tx += d.tx_delta; s.other_rx += d.rx_delta; }
        }
    }

    s
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
    fn test_parse_net_dev_multiple() {
        let content = "wlan0: 1000 10 0 0 0 0 0 0 500 5 0 0 0 0 0 0\nrmnet_data0: 200 2 0 0 0 0 0 0 100 1 0 0 0 0 0 0\n";
        let ifaces = parse_net_dev(content);
        assert_eq!(ifaces.len(), 2);
    }

    #[test]
    fn test_compute_deltas() {
        let prev = vec![NetInterface { name: "wlan0".into(), rx_bytes: 1000, rx_packets: 10, tx_bytes: 500, tx_packets: 5 }];
        let curr = vec![NetInterface { name: "wlan0".into(), rx_bytes: 1500, rx_packets: 15, tx_bytes: 800, tx_packets: 8 }];
        let deltas = compute_network_deltas(&prev, &curr);
        assert_eq!(deltas[0].rx_delta, 500);
        assert_eq!(deltas[0].tx_delta, 300);
    }

    #[test]
    fn test_compute_deltas_new_iface() {
        let prev = vec![];
        let curr = vec![NetInterface { name: "wlan0".into(), rx_bytes: 1500, rx_packets: 15, tx_bytes: 800, tx_packets: 8 }];
        assert_eq!(compute_network_deltas(&prev, &curr).len(), 0);
    }

    #[test]
    fn test_classify_wifi_cellular_other() {
        assert_eq!(classify_interface("wlan0"), "wifi");
        assert_eq!(classify_interface("nan0"), "wifi");
        assert_eq!(classify_interface("rmnet_data0"), "cellular");
        assert_eq!(classify_interface("ccmni0"), "cellular");
        assert_eq!(classify_interface("pdp0"), "cellular");
        assert_eq!(classify_interface("ppp0"), "cellular");
        assert_eq!(classify_interface("eth0"), "other");
    }

    #[test]
    fn test_summarize_deltas() {
        let deltas = vec![
            NetDelta { name: "wlan0".into(), rx_delta: 1000, tx_delta: 500 },
            NetDelta { name: "rmnet0".into(), rx_delta: 200, tx_delta: 100 },
        ];
        let s = summarize_network_deltas(&deltas);
        assert_eq!(s.wifi_rx, 1000);
        assert_eq!(s.wifi_tx, 500);
        assert_eq!(s.cellular_rx, 200);
        assert_eq!(s.cellular_tx, 100);
        assert_eq!(s.total_rx, 1200);
        assert_eq!(s.total_tx, 600);
    }
}
