// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/parsers/network_parser.dart';

/// Build a synthetic /proc/net/dev output.
String _makeProcNetDev(List<_NetIface> interfaces) {
  final buf = StringBuffer();
  buf.writeln('Inter-|   Receive                                                |  Transmit');
  buf.writeln(' face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed');
  for (final iface in interfaces) {
    buf.writeln('${iface.name}: ${iface.rxBytes} 0 0 0 0 0 0 0 ${iface.txBytes} 0 0 0 0 0 0 0');
  }
  return buf.toString();
}

class _NetIface {
  final String name;
  final int rxBytes;
  final int txBytes;
  const _NetIface(this.name, this.rxBytes, this.txBytes);
}

void main() {
  group('NetworkParser', () {
    group('interface classification', () {
      test('two interfaces classified correctly: wlan0->WiFi, rmnet0->Cellular', () {
        final output = _makeProcNetDev([
          const _NetIface('wlan0', 2048, 1024),
          const _NetIface('rmnet0', 128, 512),
        ]);
        final result = NetworkParser.parse(output);
        expect(result.netWifiRxBytes, 2048);
        expect(result.netWifiTxBytes, 1024);
        expect(result.netCellularRxBytes, 128);
        expect(result.netCellularTxBytes, 512);
        // Aggregated totals
        expect(result.netRxBytes, 2048 + 128);
        expect(result.netTxBytes, 1024 + 512);
      });

      test('loopback (lo) excluded from all totals', () {
        final output = _makeProcNetDev([
          const _NetIface('wlan0', 1024, 512),
          const _NetIface('lo', 9999, 9999),
        ]);
        final result = NetworkParser.parse(output);
        expect(result.netWifiRxBytes, 1024);
        expect(result.netWifiTxBytes, 512);
        // lo should be excluded
        expect(result.netRxBytes, 1024); // NOT 1024+9999
        expect(result.netTxBytes, 512);
      });

      test('WiFi off (no wlan*) => net_wifi_* = 0 cumulative, not null', () {
        final output = _makeProcNetDev([
          const _NetIface('rmnet0', 256, 128),
        ]);
        final result = NetworkParser.parse(output);
        expect(result.netWifiRxBytes, 0);
        expect(result.netWifiTxBytes, 0);
        expect(result.netCellularRxBytes, 256);
      });

      test('other interfaces classified as "other"', () {
        final output = _makeProcNetDev([
          const _NetIface('eth0', 512, 256),
          const _NetIface('usb0', 128, 64),
        ]);
        final result = NetworkParser.parse(output);
        expect(result.netOtherRxBytes, 512 + 128);
        expect(result.netOtherTxBytes, 256 + 64);
      });
    });

    group('null/malformed input', () {
      test('null input returns all null', () {
        final result = NetworkParser.parse(null);
        expect(result.netRxBytes, isNull);
        expect(result.netTxBytes, isNull);
      });

      test('empty input returns all null', () {
        final result = NetworkParser.parse('');
        expect(result.netRxBytes, isNull);
      });
    });
  });
}
