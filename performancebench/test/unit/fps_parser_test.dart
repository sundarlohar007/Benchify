// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/parsers/fps_parser.dart';

void main() {
  group('FpsParser', () {
    group('null and empty input', () {
      test('null input returns null for all fields', () {
        final result = FpsParser.parse(null);
        expect(result.fps, isNull);
        expect(result.jankSmallCount, isNull);
        expect(result.jankCount, isNull);
        expect(result.jankBigCount, isNull);
        expect(result.jankRatioCount, isNull);
        expect(result.frametimesJson, isNull);
      });

      test('empty string input returns fps=0.0, all jank counts=0', () {
        final result = FpsParser.parse('');
        expect(result.fps, 0.0);
        expect(result.jankSmallCount, 0);
        expect(result.jankCount, 0);
        expect(result.jankBigCount, 0);
        expect(result.jankRatioCount, 0);
        expect(result.frametimesJson, isNull);
      });

      test('fewer than 3 lines returns fps=0.0', () {
        final result = FpsParser.parse('16666666\n123');
        expect(result.fps, 0.0);
        expect(result.jankSmallCount, 0);
        expect(result.jankCount, 0);
        expect(result.jankBigCount, 0);
      });
    });

    group('FPS computation', () {
      test('10 valid frames averaging 16.67ms returns fps within +/-2% of 60.0', () {
        const refreshNs = 16666666; // 60Hz refresh
        final lines = StringBuffer();
        lines.writeln(refreshNs);
        // 10 frames at exactly 16.67ms intervals
        // actual_present_ns starts at 1,666,666,667 and increments by 16,666,667 each frame
        const baseNs = 1666666667;
        for (var i = 0; i < 10; i++) {
          final presentNs = baseNs + (i * 16666667);
          lines.writeln('0\t$presentNs\t0');
        }
        final result = FpsParser.parse(lines.toString());
        expect(result.fps, isNotNull);
        expect(result.fps!, greaterThan(60.0 * 0.98));
        expect(result.fps!, lessThan(60.0 * 1.02));
      });

      test('no valid frames returns fps=0.0', () {
        const refreshNs = 16666666;
        final lines = StringBuffer();
        lines.writeln(refreshNs);
        // All timestamps <= 0
        lines.writeln('0\t0\t0');
        lines.writeln('0\t0\t0');
        lines.writeln('0\t-1\t0');
        final result = FpsParser.parse(lines.toString());
        expect(result.fps, 0.0);
      });
    });

    group('3-tier jank classification', () {
      test('frame delta of 130ms triggers big_jank, jank, and small_jank', () {
        const refreshNs = 16666666; // ~16.67ms refresh
        final lines = StringBuffer();
        lines.writeln(refreshNs);
        // First frame at 1s
        lines.writeln('0\t1000000000\t0');
        // Second frame at 1s + 130ms = 130ms delta (>125ms threshold for big jank)
        lines.writeln('0\t1130000000\t0');
        final result = FpsParser.parse(lines.toString());
        expect(result.jankBigCount, 1);
        expect(result.jankCount, 1);
        expect(result.jankSmallCount, 1);
      });

      test('frame delta of 90ms triggers jank and small_jank but NOT big_jank', () {
        const refreshNs = 16666666;
        final lines = StringBuffer();
        lines.writeln(refreshNs);
        lines.writeln('0\t1000000000\t0');
        lines.writeln('0\t1090000000\t0'); // 90ms delta (>83.3ms for jank, <125ms for big)
        final result = FpsParser.parse(lines.toString());
        expect(result.jankBigCount, 0);
        expect(result.jankCount, 1);
        expect(result.jankSmallCount, 1);
      });

      test('frame delta of 20ms on 60Hz triggers small_jank only', () {
        const refreshNs = 16666666; // 16.67ms refresh
        final lines = StringBuffer();
        lines.writeln(refreshNs);
        lines.writeln('0\t1000000000\t0');
        lines.writeln('0\t1020000000\t0'); // 20ms delta (>16.67ms refresh, <83.3ms jank)
        final result = FpsParser.parse(lines.toString());
        expect(result.jankSmallCount, 1);
        expect(result.jankCount, 0);
        expect(result.jankBigCount, 0);
      });

      test('frame delta of 150ms excluded by outlier filter (>=150ms for jank)', () {
        const refreshNs = 16666666;
        final lines = StringBuffer();
        lines.writeln(refreshNs);
        lines.writeln('0\t1000000000\t0');
        lines.writeln('0\t1150000000\t0'); // 150ms delta, excluded from jank (>= 150)
        // Second delta must be <= refresh_period to avoid triggering any jank
        // refresh_period = 16.666666ms; delta must be <= that
        lines.writeln('0\t1166666666\t0'); // 16.66666ms delta (<= refresh)
        final result = FpsParser.parse(lines.toString());
        expect(result.jankBigCount, 0);
        expect(result.jankCount, 0);
        expect(result.jankSmallCount, 0);
      });
    });

    group('frame ratio jank model (gamma=L/R)', () {
      test('frame ratio changes 1->2->1->2 over 4 deltas produces jank_ratio_count=3', () {
        const refreshNs = 16666666; // R = 16.67ms refresh
        final lines = StringBuffer();
        lines.writeln(refreshNs);
        // 5 timestamps → 4 deltas with gamma pattern 1, 2, 1, 2
        // Gamma transitions: 1→2, 2→1, 1→2 = 3 ratio changes
        lines.writeln('0\t1000000000\t0');  // Frame 1
        lines.writeln('0\t1016666667\t0');  // Frame 2: delta ~16.67ms, gamma = ceil(16.67/16.67) = 1 (initial)
        lines.writeln('0\t1050000000\t0');  // Frame 3: delta ~33.33ms, gamma = ceil(33.33/16.67) = 2, 1→2 count=1
        lines.writeln('0\t1066666667\t0');  // Frame 4: delta ~16.67ms, gamma = ceil(16.67/16.67) = 1, 2→1 count=2
        lines.writeln('0\t1100000000\t0');  // Frame 5: delta ~33.33ms, gamma = ceil(33.33/16.67) = 2, 1→2 count=3
        final result = FpsParser.parse(lines.toString());
        expect(result.jankRatioCount, 3);
      });
    });

    group('frametimes JSON', () {
      test('frametimes_json contains valid delta values as JSON array', () {
        const refreshNs = 16666666;
        final lines = StringBuffer();
        lines.writeln(refreshNs);
        // 3 valid frames at known intervals
        lines.writeln('0\t1000000000\t0');
        lines.writeln('0\t1016666667\t0'); // ~16.67ms
        lines.writeln('0\t1033333334\t0'); // ~16.67ms
        final result = FpsParser.parse(lines.toString());
        expect(result.frametimesJson, isNotNull);
        final frametimes = result.frametimesJson!;
        // Should be a valid JSON array of doubles
        expect(frametimes, contains('[16.'));
        expect(frametimes, contains(']'));
        // Parse the JSON to verify it's valid and has correct values
        final decoded = (jsonDecode(frametimes) as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList();
        expect(decoded.length, 2);
        // Each value should be close to 16.67ms
        for (final v in decoded) {
          expect(v, greaterThan(15));
          expect(v, lessThan(18));
        }
      });
    });

    group('edge cases', () {
      test('malformed numeric values are skipped gracefully', () {
        const refreshNs = 16666666;
        final lines = StringBuffer();
        lines.writeln(refreshNs);
        lines.writeln('0\tabc\t0'); // non-numeric
        lines.writeln('0\t1000000000\t0');
        lines.writeln('0\t1016666667\t0');
        final result = FpsParser.parse(lines.toString());
        // Should still work with the valid frames
        expect(result.fps, isNotNull);
        expect(result.fps!, greaterThan(0));
      });
    });
  });
}
