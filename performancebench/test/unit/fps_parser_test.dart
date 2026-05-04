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

      test('frame delta of 150ms excluded by outlier filter (>=100ms)', () {
        const refreshNs = 16666666;
        final lines = StringBuffer();
        lines.writeln(refreshNs);
        lines.writeln('0\t1000000000\t0');
        lines.writeln('0\t1150000000\t0'); // 150ms delta, >=100ms outlier filter
        lines.writeln('0\t1166666667\t0'); // 16.67ms valid frame
        final result = FpsParser.parse(lines.toString());
        // The 150ms frame is excluded; the 16.67ms frame is valid
        // FPS should be ~60.0 from the single valid frame
        expect(result.fps, isNotNull);
        // janks should not count the outlier
        expect(result.jankBigCount, 0);
        expect(result.jankCount, 0);
        expect(result.jankSmallCount, 0);
      });
    });

    group('frame ratio jank model (gamma=L/R)', () {
      test('frame ratio changes 1->2->1->2 over 4 frames produces jank_ratio_count=3', () {
        const refreshNs = 16666666; // R = 16.67ms refresh
        final lines = StringBuffer();
        lines.writeln(refreshNs);
        // Frame 1: normal, L = 16ms (1 refresh period), gamma = ceil(16/16.67) = 1
        lines.writeln('0\t1000000000\t0');
        // Frame 2: slow, L = 33ms (~2 refresh periods), gamma = ceil(33/16.67) = 2
        // Gamma 1->2: ratio change => jank_ratio_count++
        lines.writeln('0\t1033000000\t0');
        // Frame 3: back to normal, L = 16ms, gamma = 1
        // Gamma 2->1: ratio change => jank_ratio_count++
        lines.writeln('0\t1049000000\t0');
        // Frame 4: slow again, L = 33ms, gamma = 2
        // Gamma 1->2: ratio change => jank_ratio_count++
        lines.writeln('0\t1082000000\t0');
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
        // Should be a valid JSON array of doubles
        final frametimes = result.frametimesJson!;
        expect(frametimes, contains('[16.'));
        expect(frametimes, contains(']'));
        // Parsing should succeed
        final parsed = double.parse is List
            ? null
            : null; // just check it's valid JSON
        // Actually check it's parseable
        final decoded = List<double>.from(
            // ignore: avoid_dynamic_calls
            (RegExp(r'^\[(.*)\]$').firstMatch(frametimes)?.group(1) ?? '')
                .split(',')
                .where((s) => s.trim().isNotEmpty)
                .map((s) => double.tryParse(s.trim()) ?? 0.0));
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
