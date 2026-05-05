// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/parsers/disk_io_parser.dart';

/// Disk I/O parser tests per UNIFIED-SPEC §5.8.
///
/// /proc/diskstats field layout (split by whitespace):
///   0=major  1=minor  2=name  3=reads  4=reads_merged
///   5=sectors_read  6=ms_reading  7=writes  8=writes_merged
///   9=sectors_written  10=ms_writing  11=ios_in_progress
///   12=ms_doing_io  13=weighted_ms
///
/// Algorithm (spec §5.8):
/// 1. Find line where field[2] is sda, mmcblk0, or vda (first match)
/// 2. read_sectors = field[5], write_sectors = field[9] (cumulative)
/// 3. sectors * 512 = bytes; delta / interval_s -> bytes/s -> KB/s
void main() {
  group('DiskIoParser', () {
    late DiskIoParser parser;

    setUp(() {
      parser = DiskIoParser();
    });

    // -------------------------------------------------------------------------
    // Test 1: Empty string returns null values
    // -------------------------------------------------------------------------
    test('empty string returns null for both fields', () {
      final result = parser.parse('');
      expect(result.readKbPerSec, isNull);
      expect(result.writeKbPerSec, isNull);
    });

    test('null/empty input returns null for both fields', () {
      final result = parser.parse('');
      expect(result.readKbPerSec, isNull);
      expect(result.writeKbPerSec, isNull);
    });

    // -------------------------------------------------------------------------
    // Test 2: Valid /proc/diskstats with sda line
    //        First call returns null (no prior sample), second computes delta
    // -------------------------------------------------------------------------
    test('sda line: first call returns null (no prior sample)', () {
      // sectors_read at field[5]=1234, sectors_written at field[9]=5678
      const diskstats = '8 0 sda 0 0 1234 0 0 0 5678 0 0 0 0 0';
      final result = parser.parse(diskstats, timestampMs: 1000);
      expect(result.isFirstSample, isTrue);
      expect(result.readKbPerSec, isNull);
      expect(result.writeKbPerSec, isNull);
    });

    test('sda line: second call with read +200 sectors, write +100 over 1.0s', () {
      // First call: sectors_read=1000, sectors_written=2000
      parser.parse(
        '8 0 sda 0 0 1000 0 0 0 2000 0 0 0 0 0',
        timestampMs: 1000,
      );

      // Second call: sectors_read=1200, sectors_written=2100
      // delta = +200 read sectors, +100 write sectors over 1.0s
      final result = parser.parse(
        '8 0 sda 0 0 1200 0 0 0 2100 0 0 0 0 0',
        timestampMs: 2000,
      );

      // 200 sectors * 512 / 1024 = 100 KB; / 1.0s = 100 KB/s read
      // 100 sectors * 512 / 1024 = 50 KB;  / 1.0s = 50 KB/s write
      expect(result.readKbPerSec, closeTo(100.0, 0.01));
      expect(result.writeKbPerSec, closeTo(50.0, 0.01));
      expect(result.isFirstSample, isFalse);
    });

    // -------------------------------------------------------------------------
    // Test 3: mmcblk0 line selected when present (field[2] match)
    // -------------------------------------------------------------------------
    test('mmcblk0 line selected: computes correct delta KB/s', () {
      // First call: sectors_read=100, sectors_written=200 at t=1000
      parser.parse(
        '179 0 mmcblk0 0 0 100 0 0 0 200 0 0 0 0 0',
        timestampMs: 1000,
      );

      // Second call: +50 read sectors, +30 write sectors over 0.5s
      final result = parser.parse(
        '179 0 mmcblk0 0 0 150 0 0 0 230 0 0 0 0 0',
        timestampMs: 1500,
      );

      // 50 sectors * 512 / 1024 = 25 KB; / 0.5s = 50 KB/s read
      // 30 sectors * 512 / 1024 = 15 KB; / 0.5s = 30 KB/s write
      expect(result.readKbPerSec, closeTo(50.0, 0.1));
      expect(result.writeKbPerSec, closeTo(30.0, 0.1));
    });

    // -------------------------------------------------------------------------
    // Test 4: vda line selected when sda and mmcblk0 absent (fallback device)
    // -------------------------------------------------------------------------
    test('vda line selected when sda and mmcblk0 absent', () {
      // Only vda device present — field[2] == 'vda'
      const diskstats = '253 0 vda 0 0 100 0 0 0 200 0 0 0 0 0';
      final result = parser.parse(diskstats, timestampMs: 1000);
      // First sample, should return empty with isFirstSample=true
      expect(result.isFirstSample, isTrue);
    });

    // -------------------------------------------------------------------------
    // Test 5: Two consecutive parse calls compute correct delta KB/s
    // -------------------------------------------------------------------------
    test('two consecutive parse calls compute correct KB/s delta', () {
      // Baseline at t=0: sectors_read=5000, sectors_written=3000
      parser.parse(
        '8 0 sda 0 0 5000 0 0 0 3000 0 0 0 0 0',
        timestampMs: 0,
      );

      // At t=2000ms: sectors_read=5400 (+400), sectors_written=3200 (+200)
      final result = parser.parse(
        '8 0 sda 0 0 5400 0 0 0 3200 0 0 0 0 0',
        timestampMs: 2000,
      );

      // 400 sectors * 512 / 1024 = 200 KB; / 2.0s = 100 KB/s read
      // 200 sectors * 512 / 1024 = 100 KB; / 2.0s = 50 KB/s write
      expect(result.readKbPerSec, closeTo(100.0, 0.01));
      expect(result.writeKbPerSec, closeTo(50.0, 0.01));
    });

    // -------------------------------------------------------------------------
    // Test 6: No matching disk device returns null
    // -------------------------------------------------------------------------
    test('no matching disk device (sda/mmcblk0/vda) returns null', () {
      // Only ram0 and loop0 — neither matches sda/mmcblk0/vda
      const diskstats = '1 0 ram0 0 0 0 0 0 0 0 0 0 0 0 0\n'
          '7 0 loop0 0 0 0 0 0 0 0 0 0 0 0 0';

      final result = parser.parse(diskstats);
      expect(result.readKbPerSec, isNull);
      expect(result.writeKbPerSec, isNull);
    });

    // -------------------------------------------------------------------------
    // Test 7a: Malformed line (wrong field count) returns null
    // -------------------------------------------------------------------------
    test('malformed line with wrong field count returns null', () {
      // Only 5 fields — needs >= 10
      const diskstats = '8 0 sda 1234 0';

      final result = parser.parse(diskstats);
      expect(result.readKbPerSec, isNull);
      expect(result.writeKbPerSec, isNull);
    });

    // -------------------------------------------------------------------------
    // Test 7b: Non-numeric field values at sector positions returns null
    // -------------------------------------------------------------------------
    test('non-numeric sector values returns null', () {
      // fields[5] = "abc" (non-numeric) — int.tryParse returns null
      const diskstats = '8 0 sda 0 0 abc 0 0 0 0 0 0 0 0 0';

      final result = parser.parse(diskstats, timestampMs: 1000);
      // Cannot parse sectors — returns empty
      expect(result.readKbPerSec, isNull);
      expect(result.writeKbPerSec, isNull);
    });

    // -------------------------------------------------------------------------
    // Test: reset() clears internal state
    // -------------------------------------------------------------------------
    test('reset() clears internal state so next call is first sample', () {
      parser.parse(
        '8 0 sda 0 0 1000 0 0 0 2000 0 0 0 0 0',
        timestampMs: 1000,
      );
      parser.parse(
        '8 0 sda 0 0 1200 0 0 0 2100 0 0 0 0 0',
        timestampMs: 2000,
      );

      parser.reset();

      final result = parser.parse(
        '8 0 sda 0 0 1300 0 0 0 2200 0 0 0 0 0',
        timestampMs: 3000,
      );
      expect(result.isFirstSample, isTrue);
      expect(result.readKbPerSec, isNull);
    });
  });
}
