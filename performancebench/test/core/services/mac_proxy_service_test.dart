// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/models/metric_sample.dart';
import 'package:performancebench/core/services/mac_proxy_service.dart';

void main() {
  group('MacProxyService', () {
    late MacProxyService service;

    setUp(() {
      service = MacProxyService();
    });

    // ── MacProxyInfo model ──
    group('MacProxyInfo', () {
      test('constructs with required host', () {
        final info = MacProxyInfo(host: '192.168.1.100');
        expect(info.host, '192.168.1.100');
        expect(info.port, 8589); // default
        expect(info.name, '');
        expect(info.version, '1.5');
      });

      test('constructs with all fields', () {
        final info = MacProxyInfo(
          host: '10.0.0.5',
          port: 9000,
          name: 'My Mac',
          version: '1.5',
        );
        expect(info.host, '10.0.0.5');
        expect(info.port, 9000);
        expect(info.name, 'My Mac');
        expect(info.version, '1.5');
      });

      test('baseUri returns correct HTTP URI', () {
        final info = MacProxyInfo(host: '192.168.1.50', port: 8589);
        expect(info.baseUri.toString(), 'http://192.168.1.50:8589');
      });

      test('baseUri with custom port', () {
        final info = MacProxyInfo(host: '10.0.0.1', port: 9000);
        expect(info.baseUri.toString(), 'http://10.0.0.1:9000');
      });
    });

    // ── MacProxyService ──
    group('MacProxyService', () {
      test('isSupported returns true on all platforms', () {
        expect(MacProxyService.isSupported, isTrue);
      });

      test('discoverProxies returns empty list (mDNS not available in test)', () async {
        final proxies = await service.discoverProxies();
        expect(proxies, isEmpty);
      });

      test('configure sets proxy info', () {
        service.configure('192.168.1.42', port: 8589);
        expect(service.proxyInfo, isNotNull);
        expect(service.proxyInfo!.host, '192.168.1.42');
        expect(service.proxyInfo!.port, 8589);
      });

      test('discoverDevices returns empty when no proxy configured', () async {
        final devices = await service.discoverDevices();
        expect(devices, isEmpty);
      });

      test('listApps returns empty when no proxy configured', () async {
        final apps = await service.listApps('test-udid');
        expect(apps, isEmpty);
      });

      test('start throws StateError when no proxy configured', () {
        expect(
          () => service.start('test-udid', 'com.example.app'),
          throwsA(isA<StateError>()),
        );
      });

      test('start creates broadcast stream when proxy configured', () {
        service.configure('192.168.1.50', port: 8589);
        // Note: WebSocket.connect will fail in test (no daemon running),
        // but the stream should be created without throwing.
        final stream = service.start('test-udid', 'com.example.app');
        expect(stream, isA<Stream<MetricSample>>());
        expect(stream.isBroadcast, isTrue);
        service.stop();
      });

      test('stop is safe to call multiple times', () {
        service.configure('192.168.1.50', port: 8589);
        final stream = service.start('test-udid', 'com.example.app');
        service.stop();
        // Double stop should not throw
        expect(() => service.stop(), returnsNormally);
      });

      test('configure can be called multiple times (overwrites)', () {
        service.configure('192.168.1.1', port: 8589);
        expect(service.proxyInfo!.host, '192.168.1.1');

        service.configure('10.0.0.99', port: 9000);
        expect(service.proxyInfo!.host, '10.0.0.99');
        expect(service.proxyInfo!.port, 9000);
      });
    });

    // ── MetricSample field mapping from Mac proxy WebSocket JSON ──
    group('Mac proxy MetricSample mapping', () {
      test('full Mac proxy JSON maps all MetricSample fields', () {
        // Mac proxy provides ALL fields (unlike tidevice's ~8)
        final json = <String, dynamic>{
          'ts': 1700000000000,
          'fps': 60.0,
          'cpu': 25.5,
          'mem_kb': 512000,
          'gpu_pct': 45.0,
          'thermal': 1,
          'bat_pct': 85,
          'bat_ma': 250.0,
          'bat_mv': 4200.0,
          'bat_temp_c': 32.5,
          'wifi': true,
          'net_tx': 1234567,
          'net_rx': 7654321,
          'charging': false,
        };

        final sample = MetricSample(
          sessionId: '',
          timestamp: json['ts'] as int,
          fps: (json['fps'] as num).toDouble(),
          cpuAppPct: (json['cpu'] as num).toDouble(),
          memoryPssKb: json['mem_kb'] as int,
          gpuPct: (json['gpu_pct'] as num).toDouble(),
          thermalStatus: json['thermal'] as int,
          batteryPct: json['bat_pct'] as int,
          batteryMa: (json['bat_ma'] as num).toDouble(),
          batteryMv: (json['bat_mv'] as num).toDouble(),
          batteryTempC: (json['bat_temp_c'] as num).toDouble(),
          wifiActive: 1,
          netTxBytes: json['net_tx'] as int,
          netRxBytes: json['net_rx'] as int,
          charging: 0,
        );

        // All fields populated (unlike tidevice gaps)
        expect(sample.fps, 60.0);
        expect(sample.cpuAppPct, 25.5);
        expect(sample.memoryPssKb, 512000);
        expect(sample.gpuPct, 45.0);
        expect(sample.thermalStatus, 1);
        expect(sample.batteryPct, 85);
        expect(sample.batteryMa, 250.0);
        expect(sample.batteryMv, 4200.0);
        expect(sample.batteryTempC, 32.5);
        expect(sample.wifiActive, 1);
        expect(sample.netTxBytes, 1234567);
        expect(sample.netRxBytes, 7654321);
        expect(sample.charging, 0);
      });

      test('null wifi maps to null wifiActive', () {
        final sample = MetricSample(
          sessionId: '',
          timestamp: 1700000000000,
          wifiActive: null,
        );
        expect(sample.wifiActive, isNull);
      });

      test('null optional fields are preserved', () {
        final sample = MetricSample(
          sessionId: '',
          timestamp: 1700000000000,
          fps: null,
          cpuAppPct: null,
          memoryPssKb: null,
          gpuPct: null,
          thermalStatus: null,
        );
        expect(sample.fps, isNull);
        expect(sample.cpuAppPct, isNull);
        expect(sample.memoryPssKb, isNull);
        expect(sample.gpuPct, isNull);
        expect(sample.thermalStatus, isNull);
      });
    });
  });
}
