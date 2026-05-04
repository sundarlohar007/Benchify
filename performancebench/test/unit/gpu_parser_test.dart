import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/parsers/gpu_parser.dart';

void main() {
  group('GpuParser', () {
    group('Adreno path', () {
      test('Adreno output "4823 10000" => gpu_pct=48.23', () {
        final result = GpuParser.parseAdreno('4823 10000');
        expect(result.gpuPct, closeTo(48.23, 0.01));
      });

      test('Adreno output with extra whitespace', () {
        final result = GpuParser.parseAdreno('  1000   2000  ');
        expect(result.gpuPct, closeTo(50.0, 0.01));
      });

      test('Adreno output with only one number returns null', () {
        final result = GpuParser.parseAdreno('4823');
        expect(result.gpuPct, isNull);
      });
    });

    group('Mali path', () {
      test('Mali utilization integer 75 => gpu_pct=75.0', () {
        final result = GpuParser.parseMaliUtil('75');
        expect(result.gpuPct, closeTo(75.0, 0.01));
      });

      test('Mali utilization with whitespace', () {
        final result = GpuParser.parseMaliUtil(' 50 ');
        expect(result.gpuPct, closeTo(50.0, 0.01));
      });

      test('Mali utilization out of range clamped', () {
        final result = GpuParser.parseMaliUtil('150'); // > 100 → null
        // Values > 100 should not be treated as valid GPU utilization
        expect(result.gpuPct, isNull);
      });
    });

    group('parseAny (auto-detect)', () {
      test('detects Adreno format', () {
        final result = GpuParser.parseAny('5000 10000');
        expect(result.gpuPct, closeTo(50.0, 0.01));
      });

      test('detects Mali format', () {
        final result = GpuParser.parseAny('42');
        expect(result.gpuPct, closeTo(42.0, 0.01));
      });

      test('all paths fail => null, no crash', () {
        final result = GpuParser.parseAny('not valid gpu output');
        expect(result.gpuPct, isNull);
      });

      test('null input => null', () {
        final result = GpuParser.parseAny(null);
        expect(result.gpuPct, isNull);
        expect(GpuParser.parseAdreno(null).gpuPct, isNull);
        expect(GpuParser.parseMaliUtil(null).gpuPct, isNull);
      });
    });
  });
}
