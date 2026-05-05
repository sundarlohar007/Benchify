// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, Process, ProcessSignal;

import 'package:meta/meta.dart';

import '../models/metric_sample.dart';
import 'ios_service.dart'; // For IosDevice, IosAppInfo models

/// Manages tidevice subprocess for iOS profiling on Windows.
///
/// Follows same subprocess lifecycle as IosService (Process.start, LineSplitter,
/// SIGTERM/SIGKILL). tidevice provides ~8 metrics with documented gaps for
/// GPU%, thermal status, battery mA/mV (per D-09).
class TideviceService {
  final String python3Path;
  final String agentsDir;

  Process? _process;
  StreamController<MetricSample>? _controller;
  bool _stopped = false;

  TideviceService({
    this.python3Path = 'python3',
    required this.agentsDir,
  });

  /// tidevice works on all platforms (Windows, macOS, Linux).
  static bool get isSupported => true; // Different from IosService (macOS-only)

  /// Discover connected iOS devices via tidevice.
  Future<List<IosDevice>> discoverDevices() async {
    try {
      final result = await Process.run(
        python3Path,
        ['-m', 'tidevice', 'list', '--json'],
      );
      if (result.exitCode != 0) return [];
      final json = jsonDecode(result.stdout as String);
      if (json is! List) return [];
      return json.map((e) => IosDevice.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// List installed third-party apps on a device via tidevice.
  Future<List<IosAppInfo>> listApps(String udid) async {
    try {
      final result = await Process.run(
        python3Path,
        ['-m', 'tidevice', '--udid', udid, 'applist', '--json'],
      );
      if (result.exitCode != 0) return [];
      final json = jsonDecode(result.stdout as String);
      if (json is! List) return [];
      return json.map((e) => IosAppInfo.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Start streaming iOS metrics from tidevice_collector.py.
  /// Returns broadcast Stream<MetricSample> — same interface as IosService.
  Stream<MetricSample> start(String udid, String bundleId) {
    _controller = StreamController<MetricSample>.broadcast();
    _stopped = false;
    _spawnCollector(udid, bundleId);
    return _controller!.stream;
  }

  Future<void> _spawnCollector(String udid, String bundleId) async {
    try {
      _process = await Process.start(
        python3Path,
        ['$agentsDir/tidevice_collector.py', udid, bundleId],
      );

      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(onLine, onDone: () => _controller?.close());

      _process!.stderr.transform(utf8.decoder).listen((line) {
        // ignore: avoid_print
        print('[tidevice_service stderr] $line');
      });

      _process!.exitCode.then((code) {
        if (code != 0 && !_stopped) {
          _controller?.addError('tidevice collector exited with code $code');
        }
        _controller?.close();
      });
    } catch (e) {
      _controller?.addError(e);
      _controller?.close();
    }
  }

  /// Parse JSON line from tidevice_collector.py stdout.
  @visibleForTesting
  void onLine(String line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      if (json.containsKey('error')) {
        _controller?.addError(json['error']);
        stop();
        return;
      }
      if (json['status'] == 'stopped') {
        stop();
        return;
      }

      final ts = json['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch;
      final sample = MetricSample(
        sessionId: '',
        timestamp: ts,
        fps: (json['fps'] as num?)?.toDouble(),
        cpuAppPct: (json['cpu'] as num?)?.toDouble(),
        memoryPssKb: json['mem_kb'] as int?,
        batteryPct: json['bat_pct'] as int?,
        netTxBytes: json['net_tx'] as int?,
        netRxBytes: json['net_rx'] as int?,
        // Documented gaps from tidevice (D-09):
        gpuPct: null,
        thermalStatus: null,
        batteryMa: null,
        batteryMv: null,
        batteryTempC: null,
        gpuFreqMhz: null,
        gpuMemKb: null,
      );
      _controller?.add(sample);
    } catch (_) {
      // Malformed JSON — skip (per §5.10)
    }
  }

  /// Stop collection. Sends SIGTERM, waits 3s, then SIGKILL.
  void stop() {
    _stopped = true;
    if (_process != null) {
      _process!.kill(ProcessSignal.sigterm);
      Future.delayed(const Duration(seconds: 3), () {
        if (_process != null) {
          _process!.kill(ProcessSignal.sigkill);
        }
        _process = null;
      });
    }
    _controller?.close();
    _controller = null;
  }
}
