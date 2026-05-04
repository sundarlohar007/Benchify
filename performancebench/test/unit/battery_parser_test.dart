// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/parsers/battery_parser.dart';

/// Helper: build realistic dumpsys battery output.
String _makeDumpsysBattery({
  int level = 87,
  int temperature = 312,
  int voltage = 3850,
  bool acPowered = false,
  bool usbPowered = false,
  bool wirelessPowered = false,
  int status = 3, // 3 = Discharging
}) {
  return '''
Current Battery Service state:
  AC powered: $acPowered
  USB powered: $usbPowered
  Wireless powered: $wirelessPowered
  Max charging current: 500000
  Max charging voltage: 5000000
  Charge counter: 2400000
  status: $status
  health: 2
  present: true
  level: $level
  scale: 100
  voltage: $voltage
  temperature: $temperature
  technology: Li-ion
''';
}

void main() {
  group('BatteryParser', () {
    group('dumpsys battery parsing', () {
      test('level: 87 extracts battery_pct=87', () {
        final output = _makeDumpsysBattery(level: 87);
        final result = BatteryParser.parseDumpsysBattery(output);
        expect(result.batteryPct, 87);
      });

      test('temperature: 312 extracts battery_temp_c=31.2', () {
        final output = _makeDumpsysBattery(temperature: 312);
        final result = BatteryParser.parseDumpsysBattery(output);
        expect(result.batteryTempC, closeTo(31.2, 0.01));
      });

      test('voltage: 3850 extracts battery_mv=3850.0', () {
        final output = _makeDumpsysBattery(voltage: 3850);
        final result = BatteryParser.parseDumpsysBattery(output);
        expect(result.batteryMv, closeTo(3850.0, 0.01));
      });

      test('AC powered: true => charging=true, charging_source="ac"', () {
        final output = _makeDumpsysBattery(acPowered: true, status: 3);
        final result = BatteryParser.parseDumpsysBattery(output);
        expect(result.charging, true);
        expect(result.chargingSource, 'ac');
      });

      test('USB powered: true, wireless=false => charging_source="usb"', () {
        final output = _makeDumpsysBattery(usbPowered: true);
        final result = BatteryParser.parseDumpsysBattery(output);
        expect(result.charging, true);
        expect(result.chargingSource, 'usb');
      });

      test('Wireless powered: true => charging_source="wireless"', () {
        final output = _makeDumpsysBattery(wirelessPowered: true);
        final result = BatteryParser.parseDumpsysBattery(output);
        expect(result.charging, true);
        expect(result.chargingSource, 'wireless');
      });

      test('status: 5 (Full) => charging=true', () {
        final output = _makeDumpsysBattery(status: 5);
        final result = BatteryParser.parseDumpsysBattery(output);
        expect(result.charging, true);
      });

      test('status: 2 (Charging) => charging=true', () {
        final output = _makeDumpsysBattery(status: 2);
        final result = BatteryParser.parseDumpsysBattery(output);
        expect(result.charging, true);
      });

      test('status: 3 (Discharging), all powered: false => charging=false', () {
        final output = _makeDumpsysBattery(
          status: 3,
          acPowered: false,
          usbPowered: false,
          wirelessPowered: false,
        );
        final result = BatteryParser.parseDumpsysBattery(output);
        expect(result.charging, false);
        expect(result.chargingSource, 'none');
      });
    });

    group('sysfs current_now parsing', () {
      test('current_now=-540000 => battery_ma=540.0 (absolute value)', () {
        final result = BatteryParser.parseCurrentNow('-540000');
        expect(result.batteryMa, closeTo(540.0, 0.01));
      });

      test('missing current_now file => null, no exception', () {
        final result = BatteryParser.parseCurrentNow(null);
        expect(result.batteryMa, isNull);
      });

      test('malformed current_now returns null', () {
        final result = BatteryParser.parseCurrentNow('not a number');
        expect(result.batteryMa, isNull);
      });
    });

    group('sysfs voltage_now parsing', () {
      test('voltage_now=3850000 => battery_mv=3850.0', () {
        final result = BatteryParser.parseVoltageNow('3850000');
        expect(result.batteryMv, closeTo(3850.0, 0.01));
      });

      test('missing voltage_now file => null, no exception', () {
        final result = BatteryParser.parseVoltageNow(null);
        expect(result.batteryMv, isNull);
      });
    });

    group('WiFi state parsing', () {
      test('connectivity output with WIFI type => wifi_active=true', () {
        final output = 'Active default network: 100\n  NetworkInfo: type: WIFI';
        final result = BatteryParser.parseWifiState(output);
        expect(result.wifiActive, true);
      });

      test('connectivity with MOBILE type => wifi_active=false', () {
        final output =
            'Active default network: 100\n  NetworkInfo: type: MOBILE';
        final result = BatteryParser.parseWifiState(output);
        expect(result.wifiActive, false);
      });

      test('fallback: "Wi-Fi is enabled" => wifi_active=true', () {
        final result = BatteryParser.parseWifiState('Wi-Fi is enabled');
        expect(result.wifiActive, true);
      });

      test('fallback: "Wi-Fi is disabled" => wifi_active=false', () {
        final result = BatteryParser.parseWifiState('Wi-Fi is disabled');
        expect(result.wifiActive, false);
      });

      test('neither connectivity nor wifi parse succeeds => null', () {
        final result = BatteryParser.parseWifiState('some unrelated output');
        expect(result.wifiActive, isNull);
      });
    });

    group('null/malformed input', () {
      test('null dumpsys battery returns all null', () {
        final result = BatteryParser.parseDumpsysBattery(null);
        expect(result.batteryPct, isNull);
        expect(result.charging, isNull);
      });

      test('empty dumpsys battery returns all null', () {
        final result = BatteryParser.parseDumpsysBattery('');
        expect(result.batteryPct, isNull);
      });
    });
  });
}
