// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/parsers/thermal_parser.dart';

void main() {
  group('ThermalParser', () {
    group('dumpsys thermalservice', () {
      test('Status: normal maps to thermal_status=0', () {
        final output = '''
Thermal service state:
  Status: normal
  Current temperatures:
    cpu: 45
''';
        final result = ThermalParser.parseThermalService(output);
        expect(result.thermalStatus, 0);
      });

      test('Status: critical maps to thermal_status=3', () {
        final output = '''
Thermal service state:
  Status: critical
  Current temperatures:
    cpu: 95
''';
        final result = ThermalParser.parseThermalService(output);
        expect(result.thermalStatus, 3);
      });

      test('Status: fair maps to thermal_status=1', () {
        final output = 'Status: fair';
        final result = ThermalParser.parseThermalService(output);
        expect(result.thermalStatus, 1);
      });

      test('Status: serious maps to thermal_status=2', () {
        final output = 'Status: serious';
        final result = ThermalParser.parseThermalService(output);
        expect(result.thermalStatus, 2);
      });
    });

    group('getprop fallback', () {
      test('sys.thermal.state=0 maps to thermal_status=0', () {
        final result = ThermalParser.parseGetprop('0');
        expect(result.thermalStatus, 0);
      });

      test('sys.thermal.state=3 maps to thermal_status=3', () {
        final result = ThermalParser.parseGetprop('3');
        expect(result.thermalStatus, 3);
      });
    });

    group('null/malformed input', () {
      test('null output returns null thermal_status', () {
        final result = ThermalParser.parseThermalService(null);
        expect(result.thermalStatus, isNull);
      });

      test('empty output returns null', () {
        final result = ThermalParser.parseThermalService('');
        expect(result.thermalStatus, isNull);
      });

      test('unrecognized status returns null', () {
        final result =
            ThermalParser.parseThermalService('Status: unknown');
        expect(result.thermalStatus, isNull);
      });

      test('null getprop returns null', () {
        final result = ThermalParser.parseGetprop(null);
        expect(result.thermalStatus, isNull);
      });

      test('malformed getprop returns null', () {
        final result = ThermalParser.parseGetprop('abc');
        expect(result.thermalStatus, isNull);
      });
    });
  });
}
