// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// Result of a disk I/O parse operation per UNIFIED-SPEC §5.8.
class DiskIoResult {
  /// Delta read rate in KB/s between samples.
  final double? readKbPerSec;
  /// Delta write rate in KB/s between samples.
  final double? writeKbPerSec;
  /// Whether this was the first sample (no delta available).
  final bool isFirstSample;

  const DiskIoResult({
    this.readKbPerSec,
    this.writeKbPerSec,
    this.isFirstSample = false,
  });

  static const empty = DiskIoResult(
    readKbPerSec: null,
    writeKbPerSec: null,
    isFirstSample: true,
  );
}

/// Parses `/proc/diskstats` output per UNIFIED-SPEC §5.8.
///
/// Algorithm:
/// 1. Find first line where field[2] is `sda`, `mmcblk0`, or `vda`
/// 2. read_sectors = field[5], write_sectors = field[9] (cumulative)
/// 3. sectors * 512 = bytes; compute delta between samples;
///    divide by sample_interval_s -> bytes/s -> store as KB/s
///
/// First call returns null values (no prior sample). Subsequent calls
/// compute delta KB/s between consecutive samples.
/// Mitigates T-02-01: validates field count >= 10, uses int.tryParse guards.
class DiskIoParser {
  int? _prevReadSectors;
  int? _prevWriteSectors;
  int? _prevTimestampMs;

  /// Parse `/proc/diskstats` output. Returns null values on first call
  /// (no prior sample) and on subsequent calls computes delta KB/s between
  /// consecutive samples.
  DiskIoResult parse(String diskstatsOutput, {int? timestampMs}) {
    final lines = diskstatsOutput.split('\n');

    // 1. Find matching line — first sda, mmcblk0, or vda match wins
    String? targetLine;
    for (final line in lines) {
      final fields = line.trim().split(RegExp(r'\s+'));
      if (fields.length < 10) continue;
      final device = fields[2];
      if (device == 'sda' || device == 'mmcblk0' || device == 'vda') {
        targetLine = line.trim();
        break; // First match wins
      }
    }
    if (targetLine == null) return DiskIoResult.empty;

    final fields = targetLine.split(RegExp(r'\s+'));
    if (fields.length < 10) return DiskIoResult.empty;

    final readSectors = int.tryParse(fields[5]);
    final writeSectors = int.tryParse(fields[9]);
    if (readSectors == null || writeSectors == null) return DiskIoResult.empty;

    final ts = timestampMs ?? DateTime.now().millisecondsSinceEpoch;

    // First sample — store baselines, return null delta
    if (_prevReadSectors == null || _prevTimestampMs == null) {
      _prevReadSectors = readSectors;
      _prevWriteSectors = writeSectors;
      _prevTimestampMs = ts;
      return const DiskIoResult(isFirstSample: true);
    }

    // Compute delta
    final dtSec = (ts - _prevTimestampMs!) / 1000.0;
    if (dtSec <= 0) return DiskIoResult.empty;

    final deltaReadSectors = readSectors - _prevReadSectors!;
    final deltaWriteSectors = writeSectors - _prevWriteSectors!;
    // sectors * 512 bytes / 1024 = KB; / dt = KB/s
    final readKbPerSec = (deltaReadSectors * 512) / 1024.0 / dtSec;
    final writeKbPerSec = (deltaWriteSectors * 512) / 1024.0 / dtSec;

    // Store for next call
    _prevReadSectors = readSectors;
    _prevWriteSectors = writeSectors;
    _prevTimestampMs = ts;

    return DiskIoResult(
      readKbPerSec: deltaReadSectors >= 0 ? readKbPerSec : 0,
      writeKbPerSec: deltaWriteSectors >= 0 ? writeKbPerSec : 0,
    );
  }

  /// Reset internal state (call when session ends).
  void reset() {
    _prevReadSectors = null;
    _prevWriteSectors = null;
    _prevTimestampMs = null;
  }
}
