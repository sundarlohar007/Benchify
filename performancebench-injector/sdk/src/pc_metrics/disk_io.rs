// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

//! Disk I/O per process via PDH counters.
//!
//! Uses PDH `\Process(exe)\IO Read Bytes/sec` and `\IO Write Bytes/sec` counters.
//! Values are cumulative; rate calculation deferred to consumer.
//!
//! All code is `#[cfg(windows)]` gated.

/// Snapshot of disk I/O for a process (cumulative bytes).
#[derive(Debug, Clone, Default)]
pub struct PcDiskSnapshot {
    pub read_bytes: i64,
    pub write_bytes: i64,
}

/// Extract disk I/O from a PDH metrics snapshot.
///
/// Reads disk_read_bytes_per_s and disk_write_bytes_per_s from the snapshot.
/// These are cumulative — rate calculation done by consumer.
pub fn read_disk_io_from_snapshot(disk_read: Option<i64>, disk_write: Option<i64>) -> PcDiskSnapshot {
    PcDiskSnapshot {
        read_bytes: disk_read.unwrap_or(0),
        write_bytes: disk_write.unwrap_or(0),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_disk_snapshot_default() {
        let snap = PcDiskSnapshot::default();
        assert_eq!(snap.read_bytes, 0);
        assert_eq!(snap.write_bytes, 0);
    }

    #[test]
    fn test_read_disk_io_from_snapshot_some() {
        let snap = read_disk_io_from_snapshot(Some(1000), Some(500));
        assert_eq!(snap.read_bytes, 1000);
        assert_eq!(snap.write_bytes, 500);
    }

    #[test]
    fn test_read_disk_io_from_snapshot_none() {
        let snap = read_disk_io_from_snapshot(None, None);
        assert_eq!(snap.read_bytes, 0);
        assert_eq!(snap.write_bytes, 0);
    }
}
