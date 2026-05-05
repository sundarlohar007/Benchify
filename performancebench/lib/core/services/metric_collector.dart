// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';

import '../database/metric_dao.dart';
import '../models/metric_sample.dart';
import '../parsers/battery_parser.dart';
import '../parsers/cpu_parser.dart';
import '../parsers/disk_io_parser.dart';
import '../parsers/fps_parser.dart';
import '../parsers/gpu_parser.dart';
import '../parsers/memory_parser.dart';
import '../parsers/network_parser.dart';
import '../parsers/thermal_parser.dart';
import '../sdk/sdk_state.dart';
import 'adb_service.dart';
import 'alert_service.dart';

/// Collects performance metrics from an Android device at 1Hz.
///
/// Wires all 7 metric parsers (FPS, CPU, Memory, Battery, Network, Thermal, GPU)
/// into a single [Stream<MetricSample>] driven by a periodic timer.
/// Maintains a 300-sample ring buffer (60 seconds at 1Hz).
/// Batch-writes accumulated samples to SQLite every 5 seconds.
class MetricCollector {
  final AdbService _adbService;
  final String _deviceSerial;
  final String _packageName;
  final String _sessionId;
  final MetricDao _metricDao;
  final AlertService _alertService;

  int? _pid;
  String? _surfaceFlingerLayer;
  final CpuParser _cpuParser = CpuParser();
  final DiskIoParser _diskIoParser = DiskIoParser();
  final SdkState _sdkState;

  final List<MetricSample> _buffer = [];
  static const int _maxBufferSize = 300;

  int _consecutiveFailures = 0;

  Timer? _timer;
  StreamController<MetricSample>? _controller;
  StreamController<String>? _statusController;

  // ---- Batch writer state ----
  final List<MetricSample> _pendingBatch = [];
  Timer? _batchTimer;
  bool _lastBatchOk = true;

  MetricCollector({
    required AdbService adbService,
    required String deviceSerial,
    required String packageName,
    required String sessionId,
    required MetricDao metricDao,
    AlertService? alertService,
    SdkState? sdkState,
  })  : _adbService = adbService,
        _deviceSerial = deviceSerial,
        _packageName = packageName,
        _sessionId = sessionId,
        _metricDao = metricDao,
        _alertService = alertService ?? AlertService(
          onMarkerInsert: (_) async => -1,
        ),
        _sdkState = sdkState ?? SdkState();

  List<MetricSample> get buffer => List.unmodifiable(_buffer);

  /// Start collecting metrics at 1Hz.
  ///
  /// Returns a broadcast [Stream<MetricSample>] that emits one sample per second.
  Stream<MetricSample> start() {
    _controller = StreamController<MetricSample>.broadcast();
    _statusController = StreamController<String>.broadcast();

    _startBatchTimer();

    _initSession().then((_) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _tick();
      });
    });

    return _controller!.stream;
  }

  /// Status stream for SQLite write indicator.
  Stream<String> get statusStream => _statusController!.stream;

  /// Stop metric collection, flush remaining batch, and clean up.
  Future<List<MetricSample>> stop() async {
    _timer?.cancel();
    _timer = null;
    _batchTimer?.cancel();
    _batchTimer = null;

    // Reset disk I/O parser state
    _diskIoParser.reset();

    // Final flush
    await _flushBatch();

    _controller?.close();
    _controller = null;
    _statusController?.close();
    _statusController = null;
    return List.unmodifiable(_buffer);
  }

  // ---------------------------------------------------------------------------
  // Batch Writer
  // ---------------------------------------------------------------------------

  void _startBatchTimer() {
    _batchTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _flushBatch();
    });
  }

  Future<void> _flushBatch() async {
    if (_pendingBatch.isEmpty) return;
    final batch = List<MetricSample>.from(_pendingBatch);
    _pendingBatch.clear();
    try {
      await _metricDao.batchInsert(batch);
      _lastBatchOk = true;
    } catch (_) {
      // Retain samples in memory on failure — prepend to next batch
      _pendingBatch.insertAll(0, batch);
      _lastBatchOk = false;
    }
    _emitStatus();
  }

  void _emitStatus() {
    _statusController?.add(_lastBatchOk ? 'SQLite ✓' : 'SQLite ⚠');
  }

  // ---------------------------------------------------------------------------
  // Session Initialization
  // ---------------------------------------------------------------------------

  Future<void> _initSession() async {
    await _discoverPid();
    await _discoverSurfaceFlingerLayer();
    _emitStatus();
  }

  Future<void> _discoverPid() async {
    String? output = await _adbService.runShellCommand(
      _deviceSerial,
      'pidof $_packageName',
    );
    if (output != null && output.trim().isNotEmpty) {
      final pid = int.tryParse(output.trim().split(RegExp(r'\s+')).first);
      if (pid != null && pid > 0) {
        _pid = pid;
        return;
      }
    }

    output = await _adbService.runShellCommand(
      _deviceSerial,
      'ps -A | grep $_packageName',
    );
    if (output != null && output.trim().isNotEmpty) {
      final lines = output.trim().split('\n');
      for (final line in lines) {
        final parts = line.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          final pid = int.tryParse(parts[1]);
          if (pid != null && pid > 0) {
            _pid = pid;
            return;
          }
        }
      }
    }
  }

  Future<void> _discoverSurfaceFlingerLayer() async {
    _surfaceFlingerLayer = _packageName;
    final output = await _adbService.runShellCommand(
      _deviceSerial,
      'dumpsys SurfaceFlinger --list',
    );
    if (output != null) {
      for (final line in output.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.contains(_packageName)) {
          _surfaceFlingerLayer = trimmed;
          return;
        }
      }
      final lines = output.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty &&
            (trimmed.startsWith('SurfaceView') ||
                trimmed.contains('Window'))) {
          _surfaceFlingerLayer = trimmed;
          return;
        }
      }
    }
  }

  Future<void> _rediscoverPid() async {
    _pid = null;
    await _discoverPid();
  }

  // ---------------------------------------------------------------------------
  // Per-Tick Collection
  // ---------------------------------------------------------------------------

  Future<void> _tick() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final results = await Future.wait([
        _collectFps(),
        _collectCpu(),
        _collectMemory(),
        _collectBattery(),
        _collectNetwork(),
        _collectThermal(),
        _collectGpu(),
        _collectDiskIo(),
      ]);

      final fpsResult = results[0] as FpsResult?;
      final cpuResult = results[1] as CpuResult?;
      final memResult = results[2] as MemoryResult?;
      final batResult = results[3] as BatteryResult?;
      final netResult = results[4] as NetworkResult?;
      final thermalResult = results[5] as ThermalResult?;
      final gpuResult = results[6] as GpuResult?;
      final diskResult = results[7] as DiskIoResult?;

      final anyNonNull = fpsResult != null ||
          cpuResult != null ||
          memResult != null ||
          batResult != null ||
          netResult != null ||
          thermalResult != null ||
          gpuResult != null ||
          diskResult != null;

      if (!anyNonNull) {
        _consecutiveFailures++;
        if (_consecutiveFailures >= 5) {
          _controller?.addError(
            'ADB connection lost after 5 consecutive total failures',
          );
          stop();
        }
        return;
      }
      _consecutiveFailures = 0;

      final sample = MetricSample(
        sessionId: _sessionId,
        timestamp: timestamp,
        fps: fpsResult?.fps,
        jankCount: fpsResult?.jankCount,
        jankSmallCount: fpsResult?.jankSmallCount,
        jankBigCount: fpsResult?.jankBigCount,
        jankRatioCount: fpsResult?.jankRatioCount,
        frametimesJson: fpsResult?.frametimesJson,
        cpuAppPct: cpuResult?.cpuAppPct,
        cpuSystemPct: cpuResult?.cpuSystemPct,
        cpuAppPctFreqNorm: cpuResult?.cpuAppPctFreqNorm,
        cpuCores: cpuResult?.cpuCores,
        cpuCoreStatesJson: cpuResult?.cpuCoreStatesJson,
        cpuCoreFreqsJson: cpuResult?.cpuCoreFreqsJson,
        memoryPssKb: memResult?.memoryPssKb,
        memoryJavaKb: memResult?.memoryJavaKb,
        memoryNativeKb: memResult?.memoryNativeKb,
        memoryGraphicsKb: memResult?.memoryGraphicsKb,
        memoryStackKb: memResult?.memoryStackKb,
        memoryCodeKb: memResult?.memoryCodeKb,
        memorySystemKb: memResult?.memorySystemKb,
        batteryPct: batResult?.batteryPct,
        batteryMa: batResult?.batteryMa,
        batteryMv: batResult?.batteryMv,
        batteryTempC: batResult?.batteryTempC,
        charging: batResult?.charging == true ? 1 : 0,
        chargingSource: batResult?.chargingSource,
        wifiActive: batResult?.wifiActive == true
            ? 1
            : (batResult?.wifiActive == false ? 0 : null),
        netTxBytes: netResult?.netTxBytes,
        netRxBytes: netResult?.netRxBytes,
        netWifiTxBytes: netResult?.netWifiTxBytes,
        netWifiRxBytes: netResult?.netWifiRxBytes,
        netCellularTxBytes: netResult?.netCellularTxBytes,
        netCellularRxBytes: netResult?.netCellularRxBytes,
        netOtherTxBytes: netResult?.netOtherTxBytes,
        netOtherRxBytes: netResult?.netOtherRxBytes,
        thermalStatus: thermalResult?.thermalStatus,
        gpuPct: gpuResult?.gpuPct,
        diskReadKb: diskResult?.readKbPerSec,
        diskWriteKb: diskResult?.writeKbPerSec,
      );

      // Threshold alert check per D-03: integrated into tick loop
      _alertService.checkThresholds(sample, sessionId: _sessionId);

      _buffer.add(sample);
      while (_buffer.length > _maxBufferSize) {
        _buffer.removeAt(0);
      }

      _pendingBatch.add(sample);
      _controller?.add(sample);
    } catch (_) {
      _consecutiveFailures++;
    }
  }

  // ---------------------------------------------------------------------------
  // Individual Metric Collectors
  // ---------------------------------------------------------------------------

  Future<FpsResult?> _collectFps() async {
    if (_surfaceFlingerLayer == null) return null;
    final output = await _adbService.runShellCommand(
      _deviceSerial,
      'dumpsys SurfaceFlinger --latency "$_surfaceFlingerLayer"',
    );
    return FpsParser.parse(output);
  }

  Future<CpuResult?> _collectCpu() async {
    if (_pid == null) await _rediscoverPid();
    if (_pid == null) return null;

    final combinedOutput = await _adbService.runShellCommand(
      _deviceSerial,
      'cat /proc/$_pid/stat && echo --- && cat /proc/stat',
    );
    if (combinedOutput == null) return null;

    final parts = combinedOutput.split('---');
    if (parts.length < 2) return null;

    final pidStat = parts[0].trim();
    final procStat = parts[1].trim();

    var cpuResult = _cpuParser.parse(pidStat, procStat);

    final sysfsOutput = await _adbService.runShellCommand(
      _deviceSerial,
      'for c in /sys/devices/system/cpu/cpu[0-9]*; do echo \$c; '
      'cat \$c/online 2>/dev/null; '
      'cat \$c/cpufreq/scaling_cur_freq 2>/dev/null; '
      'cat \$c/cpufreq/cpuinfo_max_freq 2>/dev/null; '
      'echo ---; done',
    );

    if (sysfsOutput != null) {
      final freqResult = _cpuParser.parseCoreFreqs(sysfsOutput);
      double? freqNorm;
      if (cpuResult.cpuAppPct != null) {
        freqNorm = _cpuParser.computeNormalizedCpu(cpuResult.cpuAppPct!);
      }

      cpuResult = CpuResult(
        cpuAppPct: cpuResult.cpuAppPct,
        cpuSystemPct: cpuResult.cpuSystemPct,
        cpuAppPctFreqNorm: freqNorm,
        cpuCores: cpuResult.cpuCores,
        cpuCoreStatesJson: freqResult.cpuCoreStatesJson,
        cpuCoreFreqsJson: freqResult.cpuCoreFreqsJson,
      );
    }

    return cpuResult;
  }

  Future<MemoryResult?> _collectMemory() async {
    if (_pid == null) return null;
    final output = await _adbService.runShellCommand(
      _deviceSerial,
      'dumpsys meminfo $_packageName',
    );
    return MemoryParser.parse(output);
  }

  Future<BatteryResult?> _collectBattery() async {
    final dumpsysOutput = await _adbService.runShellCommand(
      _deviceSerial,
      'dumpsys battery',
    );
    final dumpsysResult = BatteryParser.parseDumpsysBattery(dumpsysOutput);

    final currentOutput = await _adbService.runShellCommand(
      _deviceSerial,
      'cat /sys/class/power_supply/battery/current_now',
    );
    final currentResult = BatteryParser.parseCurrentNow(currentOutput);

    final voltageOutput = await _adbService.runShellCommand(
      _deviceSerial,
      'cat /sys/class/power_supply/battery/voltage_now',
    );
    final voltageResult = BatteryParser.parseVoltageNow(voltageOutput);

    final wifiOutput = await _adbService.runShellCommand(
      _deviceSerial,
      'dumpsys connectivity | grep -A2 "Active default network"',
    );
    final wifiResult = BatteryParser.parseWifiState(wifiOutput);

    return BatteryResult(
      batteryPct: dumpsysResult.batteryPct,
      batteryTempC: dumpsysResult.batteryTempC,
      batteryMv: voltageResult.batteryMv ?? dumpsysResult.batteryMv,
      batteryMa: currentResult.batteryMa,
      charging: dumpsysResult.charging,
      chargingSource: dumpsysResult.chargingSource,
      wifiActive: wifiResult.wifiActive,
    );
  }

  Future<NetworkResult?> _collectNetwork() async {
    final output = await _adbService.runShellCommand(
      _deviceSerial,
      'cat /proc/net/dev',
    );
    return NetworkParser.parse(output);
  }

  Future<ThermalResult?> _collectThermal() async {
    var output = await _adbService.runShellCommand(
      _deviceSerial,
      'dumpsys thermalservice',
    );
    if (output != null) {
      final result = ThermalParser.parseThermalService(output);
      if (result.thermalStatus != null) return result;
    }

    output = await _adbService.runShellCommand(
      _deviceSerial,
      'getprop sys.thermal.state',
    );
    if (output != null) {
      return ThermalParser.parseGetprop(output);
    }

    return null;
  }

  Future<GpuResult?> _collectGpu() async {
    var output = await _adbService.runShellCommand(
      _deviceSerial,
      'cat /sys/class/kgsl/kgsl-3d0/gpubusy',
    );
    if (output != null && output.isNotEmpty) {
      final result = GpuParser.parseAdreno(output);
      if (result.gpuPct != null) return result;
    }

    output = await _adbService.runShellCommand(
      _deviceSerial,
      'cat /sys/class/misc/mali0/device/utilization',
    );
    if (output != null && output.isNotEmpty) {
      final result = GpuParser.parseMaliUtil(output);
      if (result.gpuPct != null) return result;
    }

    return null;
  }

  /// Collect Disk I/O stats from /proc/diskstats per UNIFIED-SPEC §5.8.
  /// Controlled by SdkState.diskIoSdkEnabled feature flag.
  Future<DiskIoResult?> _collectDiskIo() async {
    if (!_sdkState.diskIoSdkEnabled) return null;

    final output = await _adbService.runShellCommand(
      _deviceSerial,
      'cat /proc/diskstats',
    );
    if (output == null || output.trim().isEmpty) return null;

    final result = _diskIoParser.parse(output,
        timestampMs: DateTime.now().millisecondsSinceEpoch);
    if (result.isFirstSample) return null;
    return result;
  }
}
