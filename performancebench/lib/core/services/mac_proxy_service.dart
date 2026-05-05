// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;

import 'package:http/http.dart' as http;

import '../models/metric_sample.dart';

/// Represents a discovered Mac proxy daemon on the local network.
class MacProxyInfo {
  final String host; // IP address
  final int port; // Default 8589
  final String name; // Bonjour service name
  final String version; // '1.5'

  const MacProxyInfo({
    required this.host,
    this.port = 8589,
    this.name = '',
    this.version = '1.5',
  });

  Uri get baseUri => Uri.parse('http://$host:$port');
}

/// Manages connection to Mac proxy daemon for full-metrics iOS profiling.
///
/// Discovery: Bonjour/mDNS for _performancebench._tcp service (zero-config per D-08).
/// Communication: HTTP REST for device/app listing, WebSocket for 1Hz metric stream.
/// No authentication — local network only.
class MacProxyService {
  MacProxyInfo? _proxyInfo;
  WebSocket? _ws;
  StreamController<MetricSample>? _controller;
  bool _stopped = false;

  /// Whether the current platform supports Mac proxy (all platforms — proxy handles iOS).
  static bool get isSupported => true;

  /// Discover Mac proxy daemon on local network via mDNS/Bonjour.
  /// Returns list of discovered MacProxyInfo. Empty if none found.
  ///
  /// Uses multicast_dns package for mDNS queries. Falls back to empty list
  /// if mDNS is unavailable. User can configure proxy address manually via
  /// [configure] as fallback.
  Future<List<MacProxyInfo>> discoverProxies() async {
    final proxies = <MacProxyInfo>[];

    try {
      // Attempt mDNS discovery for _performancebench._tcp service.
      // On platforms without mDNS support, returns empty (user configures manually).
      // TODO: Implement full mDNS query using multicast_dns package.
      // Service type: _performancebench._tcp
      // On macOS: dns-sd -B _performancebench._tcp
      // On Windows: multicast_dns Dart package
      // On Linux: avahi-browse -t _performancebench._tcp
    } catch (_) {
      // mDNS discovery failed — user can configure manually
    }

    return proxies;
  }

  /// Manually configure proxy address (fallback when mDNS fails).
  void configure(String host, {int port = 8589}) {
    _proxyInfo = MacProxyInfo(host: host, port: port);
  }

  /// Get the currently configured proxy info, if any.
  MacProxyInfo? get proxyInfo => _proxyInfo;

  /// List iOS devices connected to the Mac.
  Future<List<dynamic>> discoverDevices() async {
    if (_proxyInfo == null) return [];
    try {
      final response = await http
          .get(
            Uri.parse('${_proxyInfo!.baseUri}/devices'),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];
      final json = jsonDecode(response.body);
      return json as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  /// List installed apps on a device connected to the Mac.
  Future<List<dynamic>> listApps(String udid) async {
    if (_proxyInfo == null) return [];
    try {
      final response = await http
          .get(
            Uri.parse('${_proxyInfo!.baseUri}/devices/$udid/apps'),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return [];
      final json = jsonDecode(response.body);
      return json as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  /// Start WebSocket metric stream from Mac proxy daemon.
  /// Returns broadcast Stream<MetricSample> — full metrics (all fields populated).
  Stream<MetricSample> start(String udid, String bundleId) {
    if (_proxyInfo == null) {
      throw StateError(
        'No Mac proxy configured. Call discoverProxies() or configure() first.',
      );
    }

    _controller = StreamController<MetricSample>.broadcast();
    _stopped = false;
    _connectWebSocket(udid, bundleId);
    return _controller!.stream;
  }

  Future<void> _connectWebSocket(String udid, String bundleId) async {
    try {
      final wsUri = Uri.parse(
        'ws://${_proxyInfo!.host}:${_proxyInfo!.port}'
        '/ws/metrics?udid=$udid&bundle_id=$bundleId',
      );
      _ws = await WebSocket.connect(wsUri.toString());

      _ws!.listen(
        (data) {
          if (_stopped) return;
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json.containsKey('error')) {
              _controller?.addError(json['error']);
              stop();
              return;
            }

            final wifiVal = json['wifi'];
            final chargingVal = json['charging'];

            final sample = MetricSample(
              sessionId: '',
              timestamp: json['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch,
              fps: (json['fps'] as num?)?.toDouble(),
              cpuAppPct: (json['cpu'] as num?)?.toDouble(),
              memoryPssKb: json['mem_kb'] as int?,
              gpuPct: (json['gpu_pct'] as num?)?.toDouble(),
              thermalStatus: json['thermal'] as int?,
              batteryPct: json['bat_pct'] as int?,
              batteryMa: (json['bat_ma'] as num?)?.toDouble(),
              batteryMv: (json['bat_mv'] as num?)?.toDouble(),
              batteryTempC: (json['bat_temp_c'] as num?)?.toDouble(),
              wifiActive: wifiVal == true ? 1 : (wifiVal == false ? 0 : null),
              netTxBytes: json['net_tx'] as int?,
              netRxBytes: json['net_rx'] as int?,
              charging: chargingVal == true ? 1 : (chargingVal == false ? 0 : 0),
            );
            _controller?.add(sample);
          } catch (_) {
            // Malformed WebSocket message — skip
          }
        },
        onDone: () => _controller?.close(),
        onError: (e) {
          _controller?.addError(e);
          _controller?.close();
        },
      );
    } catch (e) {
      _controller?.addError(e);
      _controller?.close();
    }
  }

  /// Stop WebSocket connection and metric stream.
  void stop() {
    _stopped = true;
    _ws?.close();
    _ws = null;
    _controller?.close();
    _controller = null;
  }
}
