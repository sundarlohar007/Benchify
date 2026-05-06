// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, Process, ProcessSignal;

import '../models/metric_sample.dart';

/// Target platform kind for Apple devices.
///
/// Per 05-02-PLAN Task 2 (D-08):
///   Routes to correct Python collector and applies metric masking.
enum TargetKind {
  ios,
  tvos;

  /// Parse from Python platform field.
  factory TargetKind.fromString(String value) {
    switch (value) {
      case 'tvos':
        return TargetKind.tvos;
      case 'ios':
      default:
        return TargetKind.ios;
    }
  }

  /// Fields that should be hidden in UI for this platform.
  Set<String> get hiddenFields {
    switch (this) {
      case TargetKind.ios:
        return {};
      case TargetKind.tvos:
        return {
          'battery_pct',
          'battery_ma',
          'battery_mv',
          'battery_temp_c',
          'charging',
          'net_cellular_tx_bytes',
          'net_cellular_rx_bytes',
        };
    }
  }

  /// Power source label for this platform.
  String get powerLabel {
    switch (this) {
      case TargetKind.ios:
        return 'Battery';
      case TargetKind.tvos:
        return 'Mains';
    }
  }
}

/// Data class for an Apple device discovered via pyidevice.
///
/// Supports both iOS and tvOS targets.
class IosDevice {
  final String udid;
  final String name;
  final String model;
  final String osVersion;
  final bool connected;
  final TargetKind targetKind;
  final List<String> warnings;

  const IosDevice({
    required this.udid,
    required this.name,
    required this.model,
    required this.osVersion,
    required this.connected,
    this.targetKind = TargetKind.ios,
    this.warnings = const [],
  });

  factory IosDevice.fromJson(Map<String, dynamic> json) {
    final platform = json['platform'] as String? ?? 'ios';
    return IosDevice(
      udid: json['udid'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      model: json['model'] as String? ?? '',
      osVersion: json['os_version'] as String? ?? '',
      connected: json['connected'] as bool? ?? true,
      targetKind: TargetKind.fromString(platform),
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

/// Data class for an iOS app discovered via installation_proxy.
class IosAppInfo {
  final String bundleId;
  final String name;
  final String version;
  final String build;

  const IosAppInfo({
    required this.bundleId,
    required this.name,
    required this.version,
    required this.build,
  });

  factory IosAppInfo.fromJson(Map<String, dynamic> json) {
    return IosAppInfo(
      bundleId: json['bundle_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      version: json['version'] as String? ?? '',
      build: json['build'] as String? ?? '',
    );
  }
}

/// Manages Python pyidevice subprocess lifecycle for iOS device profiling.
///
/// Spawns collector.py as a Process, parses newline-delimited JSON from stdout,
/// and maps fields to MetricSample per UNIFIED-SPEC §5.10.
///
/// Only works on macOS. Guards with Platform.isMacOS check.
class IosService {
  final String python3Path;
  final String agentsDir;

  Process? _process;
  StreamController<MetricSample>? _controller;
  bool _stopped = false;
  TargetKind _targetKind = TargetKind.ios;

  /// The current session's target platform kind (ios or tvos).
  TargetKind get targetKind => _targetKind;

  /// Whether a metric field should be shown in UI for the given platform.
  ///
  /// tvOS hides battery and cellular fields (mains-powered, WiFi-only).
  static bool shouldShowField(String fieldName, TargetKind kind) {
    return !kind.hiddenFields.contains(fieldName);
  }

  /// Creates an IosService instance.
  ///
  /// [python3Path] is the path to python3 (e.g., '/usr/bin/python3').
  /// [agentsDir] is the directory containing collector.py, device_list.py, etc.
  IosService({
    this.python3Path = '/usr/bin/python3',
    required this.agentsDir,
  });

  /// Whether the current platform supports iOS profiling.
  static bool get isSupported => Platform.isMacOS;

  /// Discover connected iOS and tvOS devices.
  ///
  /// Runs device_list.py first, then tvos_collector.py --list-devices for tvOS.
  /// Returns combined device list with targetKind set per platform.
  ///
  /// Returns an empty list on non-macOS or if pyidevice is not installed.
  Future<List<IosDevice>> discoverDevices() async {
    if (!isSupported) return [];

    final devices = <IosDevice>[];

    // Discover iOS devices
    try {
      final result = await Process.run(
        python3Path,
        ['$agentsDir/device_list.py'],
      );
      if (result.exitCode == 0) {
        final json = jsonDecode(result.stdout as String);
        if (json is List) {
          for (final e in json) {
            final entry = Map<String, dynamic>.from(e as Map);
            entry['platform'] = 'ios';
            devices.add(IosDevice.fromJson(entry));
          }
        }
      }
    } catch (_) {
      // iOS discovery failed — continue to tvOS
    }

    // Discover tvOS devices
    try {
      final result = await Process.run(
        python3Path,
        ['$agentsDir/tvos_collector.py', '--list-devices'],
      );
      if (result.exitCode == 0) {
        final json = jsonDecode(result.stdout as String);
        if (json is List) {
          for (final e in json) {
            devices.add(IosDevice.fromJson(Map<String, dynamic>.from(e as Map)));
          }
        }
      }
    } catch (_) {
      // tvOS discovery failed — return iOS devices only
    }

    return devices;
  }

  /// List installed third-party apps on a device.
  Future<List<IosAppInfo>> listApps(String udid) async {
    if (!isSupported) return [];

    try {
      final result = await Process.run(
        python3Path,
        ['$agentsDir/app_list.py', udid],
      );
      if (result.exitCode != 0) return [];
      final json = jsonDecode(result.stdout as String);
      if (json is! List) return [];
      return json.map((e) => IosAppInfo.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Start streaming metrics from the appropriate Python collector.
  ///
  /// Routes to collector.py for iOS, tvos_collector.py for tvOS.
  ///
  /// Returns a broadcast [Stream<MetricSample>] emitting one sample per second.
  /// Call [stop] to end collection.
  ///
  /// Throws [StateError] if not on macOS.
  Stream<MetricSample> start(String udid, String bundleId,
      {TargetKind targetKind = TargetKind.ios}) {
    if (!isSupported) {
      throw StateError('Apple device profiling requires macOS host');
    }

    _targetKind = targetKind;
    _controller = StreamController<MetricSample>.broadcast();
    _stopped = false;

    _spawnCollector(udid, bundleId, targetKind: targetKind);

    return _controller!.stream;
  }

  Future<void> _spawnCollector(String udid, String bundleId,
      {TargetKind targetKind = TargetKind.ios}) async {
    try {
      final scriptName = targetKind == TargetKind.tvos
          ? 'tvos_collector.py'
          : 'collector.py';

      _process = await Process.start(
        python3Path,
        ['$agentsDir/$scriptName', '--udid', udid],
      );

      // Read stdout line by line
      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        _onLine,
        onDone: () {
          _controller?.close();
        },
      );

      // Capture stderr for diagnostics
      _process!.stderr.transform(utf8.decoder).listen((line) {
        // Log stderr but don't surface to UI
        // ignore: avoid_print
        print('[ios_service stderr] $line');
      });

      // Handle process exit
      _process!.exitCode.then((code) {
        if (code != 0 && !_stopped) {
          _controller?.addError('iOS collector exited with code $code');
        }
        _controller?.close();
      });
    } catch (e) {
      _controller?.addError(e);
      _controller?.close();
    }
  }

  /// Parse a single JSON line from collector.py stdout.
  void _onLine(String line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;

      // Track platform from collector output
      if (json.containsKey('platform')) {
        final platform = json['platform'] as String? ?? 'ios';
        _targetKind = TargetKind.fromString(platform);
      }

      // Error from collector
      if (json.containsKey('error')) {
        _controller?.addError(json['error']);
        stop();
        return;
      }

      // Normal stop signal
      if (json['status'] == 'stopped') {
        stop();
        return;
      }

      // Map to MetricSample (§5.10)
      final ts = json['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch;
      final fps = (json['fps'] as num?)?.toDouble();

      // Jank
      final jank = json['jank'] as Map<String, dynamic>?;
      final jankSmall = jank?['small'] as int?;
      final jankCount = jank?['jank'] as int?;
      final jankBig = jank?['big'] as int?;
      final jankRatio = jank?['ratio'] as int?;

      // Frametimes
      final frametimes = json['frametimes'] as List?;
      final frametimesJson = frametimes != null ? jsonEncode(frametimes) : null;

      // CPU (NOT normalized per core — §5.2 iOS difference)
      final cpuAppPct = (json['cpu'] as num?)?.toDouble();

      // CPU threads
      final cpuThreads = json['cpu_threads'] as List?;
      final cpuThreadsJson = cpuThreads != null ? jsonEncode(cpuThreads) : null;

      // Memory (mem_bytes / 1024 → memory_pss_kb)
      final memBytes = json['mem_bytes'] as int?;
      final memoryPssKb = memBytes != null ? (memBytes ~/ 1024) : null;

      // Memory subsections
      final memSub = json['mem_subsections'] as Map<String, dynamic>?;
      final memJavaKb = _toKb(memSub?['app']);
      final memSystemKb = _toKb(memSub?['other']);

      // Battery
      final batPct = json['bat_pct'] as int?;
      final batMa = (json['bat_ma'] as num?)?.toDouble();
      final batMv = (json['bat_mv'] as num?)?.toDouble();
      final batTempC = (json['bat_temp_c'] as num?)?.toDouble();
      final charging = json['charging'] == true ? 1 : 0;
      final chargingSource = json['charging_source'] as String?;

      // WiFi
      final wifiActive = json['wifi'] == true ? 1 : 0;

      // Network (cumulative bytes)
      final netTx = json['net_tx'] as int?;
      final netRx = json['net_rx'] as int?;

      // Thermal
      final thermal = json['thermal'] as int?;

      // GPU
      final gpuPct = (json['gpu_pct'] as num?)?.toDouble();

      final sample = MetricSample(
        sessionId: '', // Filled by caller
        timestamp: ts,
        fps: fps,
        jankSmallCount: jankSmall,
        jankCount: jankCount,
        jankBigCount: jankBig,
        jankRatioCount: jankRatio,
        frametimesJson: frametimesJson,
        cpuAppPct: cpuAppPct,
        cpuThreadsTopJson: cpuThreadsJson,
        memoryPssKb: memoryPssKb,
        memoryJavaKb: memJavaKb,
        memorySystemKb: memSystemKb,
        batteryPct: batPct,
        batteryMa: batMa,
        batteryMv: batMv,
        batteryTempC: batTempC,
        charging: charging,
        chargingSource: chargingSource,
        wifiActive: wifiActive,
        netTxBytes: netTx,
        netRxBytes: netRx,
        thermalStatus: thermal,
        gpuPct: gpuPct,
      );

      _controller?.add(sample);
    } catch (_) {
      // Malformed JSON — skip this line, continue (§5.10)
    }
  }

  int? _toKb(dynamic val) {
    if (val == null) return null;
    final n = (val is int) ? val : int.tryParse(val.toString());
    return n != null ? (n ~/ 1024) : null;
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
      });
      _process = null;
    }
    _controller?.close();
    _controller = null;
  }
}
