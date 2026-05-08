// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

//! Per-interface network metrics via PDH counters.
//!
//! Uses PDH counters:
//! - `\Network Interface(*)\Bytes Received/sec`
//! - `\Network Interface(*)\Bytes Sent/sec`
//!
//! Values are cumulative; rate calculation deferred to consumer.
//!
//! All code is `#[cfg(windows)]` gated.

/// Network metrics extracted from a PDH snapshot.
#[derive(Debug, Clone, Default)]
pub struct PcNetworkSnapshot {
    pub rx_bytes: i64,
    pub tx_bytes: i64,
}

/// Extract network metrics from a PDH metrics snapshot.
pub fn read_network_from_snapshot(rx: Option<i64>, tx: Option<i64>) -> PcNetworkSnapshot {
    PcNetworkSnapshot {
        rx_bytes: rx.unwrap_or(0),
        tx_bytes: tx.unwrap_or(0),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_network_snapshot_default() {
        let snap = PcNetworkSnapshot::default();
        assert_eq!(snap.rx_bytes, 0);
        assert_eq!(snap.tx_bytes, 0);
    }

    #[test]
    fn test_read_network_from_snapshot_some() {
        let snap = read_network_from_snapshot(Some(50000), Some(20000));
        assert_eq!(snap.rx_bytes, 50000);
        assert_eq!(snap.tx_bytes, 20000);
    }

    #[test]
    fn test_read_network_from_snapshot_none() {
        let snap = read_network_from_snapshot(None, None);
        assert_eq!(snap.rx_bytes, 0);
        assert_eq!(snap.tx_bytes, 0);
    }
}
