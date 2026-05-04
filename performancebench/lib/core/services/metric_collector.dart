import 'dart:async';

import '../models/metric_sample.dart';
import '../parsers/battery_parser.dart';
import '../parsers/cpu_parser.dart';
import '../parsers/fps_parser.dart';
import '../parsers/gpu_parser.dart';
import '../parsers/memory_parser.dart';
import '../parsers/network_parser.dart';
import '../parsers/thermal_parser.dart';
import 'adb_service.dart';

/// Collects performance metrics from an Android device at 1Hz.
///
/// Wires all 7 metric parsers (FPS, CPU, Memory, Battery, Network, Thermal, GPU)
/// into a single [Stream<MetricSample>] driven by a periodic timer.
/// Maintains a 300-sample ring buffer (60 seconds at 1Hz).
///
/// Threat mitigations (T-01-07, T-01-08):
/// - 3-second timeout on every ADB call.
/// - Hard cap at 300 entries in ring buffer (evict oldest).
/// - After 5 consecutive total failures, stops collection and emits error.
class MetricCollector {
  final AdbService _adbService;
  final String _deviceSerial;
  final String _packageName;
  final String _sessionId;

  /// Cached PID of the target app process.
  int? _pid;

  /// Discovered SurfaceFlinger layer name for the target app.
  String? _surfaceFlingerLayer;

  /// CPU parser with internal state for delta computation.
  final CpuParser _cpuParser = CpuParser();

  /// Ring buffer — max 300 entries.
  final List<MetricSample> _buffer = [];
  static const int _maxBufferSize = 300;

  /// Consecutive total failure counter.
  int _consecutiveFailures = 0;

  Timer? _timer;
  StreamController<MetricSample>? _controller;

  /// Creates a collector for the given device and target app.
  MetricCollector({
    required AdbService adbService,
    required String deviceSerial,
    required String packageName,
    required String sessionId,
  })  : _adbService = adbService,
        _deviceSerial = deviceSerial,
        _packageName = packageName,
        _sessionId = sessionId;

  /// The in-memory ring buffer (newest at end).
  List<MetricSample> get buffer => List.unmodifiable(_buffer);

  /// Start collecting metrics at 1Hz.
  ///
  /// Returns a broadcast [Stream<MetricSample>] that emits one sample per second.
  /// First CPU sample returns null for cpu_app_pct/cpu_system_pct (no delta yet).
  /// Call [stop] to end collection.
  Stream<MetricSample> start() {
    _controller = StreamController<MetricSample>.broadcast();

    // Discover PID and SurfaceFlinger layer before starting the loop
    _initSession().then((_) {
      // Initial discovery may have failed; loop will retry once per tick
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        _tick();
      });
    });

    return _controller!.stream;
  }

  /// Stop metric collection and clean up.
  ///
  /// Returns the list of all collected samples.
  List<MetricSample> stop() {
    _timer?.cancel();
    _timer = null;
    _controller?.close();
    _controller = null;
    return List.unmodifiable(_buffer);
  }

  // ---------------------------------------------------------------------------
  // Session Initialization
  // ---------------------------------------------------------------------------

  /// Discover the target app PID and SurfaceFlinger layer name.
  Future<void> _initSession() async {
    await _discoverPid();
    await _discoverSurfaceFlingerLayer();
  }

  /// Discover the PID of the target package.
  ///
  /// Tries `pidof <package>` first, then falls back to `ps -A | grep <package>`.
  Future<void> _discoverPid() async {
    // Try pidof first (faster, exact match)
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

    // Fallback: ps -A | grep
    output = await _adbService.runShellCommand(
      _deviceSerial,
      'ps -A | grep $_packageName',
    );
    if (output != null && output.trim().isNotEmpty) {
      // ps output: USER PID PPID VSZ RSS WCHAN ADDR S NAME
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

  /// Discover the SurfaceFlinger layer name for FPS profiling.
  ///
  /// Strategy: try package name directly, then scan SurfaceFlinger output.
  Future<void> _discoverSurfaceFlingerLayer() async {
    // Strategy 1: Use package name directly
    _surfaceFlingerLayer = _packageName;

    // Strategy 2: Scan full SurfaceFlinger output for matching layer
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
      // Strategy 3: Topmost visible layer (fallback)
      final lines = output.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty &&
            trimmed.startsWith('SurfaceView') ||
            trimmed.contains('Window')) {
          _surfaceFlingerLayer = trimmed;
          return;
        }
      }
    }
  }

  /// Attempt to rediscover PID if the target process died.
  Future<void> _rediscoverPid() async {
    _pid = null;
    await _discoverPid();
  }

  // ---------------------------------------------------------------------------
  // Per-Tick Collection
  // ---------------------------------------------------------------------------

  /// Run one collection cycle — all 7 parsers, emit one MetricSample.
  Future<void> _tick() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Run all metric commands in parallel where possible
      final results = await Future.wait([
        _collectFps(),
        _collectCpu(),
        _collectMemory(),
        _collectBattery(),
        _collectNetwork(),
        _collectThermal(),
        _collectGpu(),
      ]);

      final fpsResult = results[0] as FpsResult?;
      final cpuResult = results[1] as CpuResult?;
      final memResult = results[2] as MemoryResult?;
      final batResult = results[3] as BatteryResult?;
      final netResult = results[4] as NetworkResult?;
      final thermalResult = results[5] as ThermalResult?;
      final gpuResult = results[6] as GpuResult?;

      // Check for total failure (all null)
      final anyNonNull = fpsResult != null ||
          cpuResult != null ||
          memResult != null ||
          batResult != null ||
          netResult != null ||
          thermalResult != null ||
          gpuResult != null;

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

      // Build MetricSample from all parsed results
      final sample = MetricSample(
        sessionId: _sessionId,
        timestamp: timestamp,
        // FPS
        fps: fpsResult?.fps,
        jankCount: fpsResult?.jankCount,
        jankSmallCount: fpsResult?.jankSmallCount,
        jankBigCount: fpsResult?.jankBigCount,
        jankRatioCount: fpsResult?.jankRatioCount,
        frametimesJson: fpsResult?.frametimesJson,
        // CPU
        cpuAppPct: cpuResult?.cpuAppPct,
        cpuSystemPct: cpuResult?.cpuSystemPct,
        cpuAppPctFreqNorm: cpuResult?.cpuAppPctFreqNorm,
        cpuCores: cpuResult?.cpuCores,
        cpuCoreStatesJson: cpuResult?.cpuCoreStatesJson,
        cpuCoreFreqsJson: cpuResult?.cpuCoreFreqsJson,
        // Memory
        memoryPssKb: memResult?.memoryPssKb,
        memoryJavaKb: memResult?.memoryJavaKb,
        memoryNativeKb: memResult?.memoryNativeKb,
        memoryGraphicsKb: memResult?.memoryGraphicsKb,
        memoryStackKb: memResult?.memoryStackKb,
        memoryCodeKb: memResult?.memoryCodeKb,
        memorySystemKb: memResult?.memorySystemKb,
        // Battery
        batteryPct: batResult?.batteryPct,
        batteryMa: batResult?.batteryMa,
        batteryMv: batResult?.batteryMv,
        batteryTempC: batResult?.batteryTempC,
        charging: batResult?.charging == true ? 1 : 0,
        chargingSource: batResult?.chargingSource,
        wifiActive: batResult?.wifiActive == true
            ? 1
            : (batResult?.wifiActive == false ? 0 : null),
        // Network
        netTxBytes: netResult?.netTxBytes,
        netRxBytes: netResult?.netRxBytes,
        netWifiTxBytes: netResult?.netWifiTxBytes,
        netWifiRxBytes: netResult?.netWifiRxBytes,
        netCellularTxBytes: netResult?.netCellularTxBytes,
        netCellularRxBytes: netResult?.netCellularRxBytes,
        netOtherTxBytes: netResult?.netOtherTxBytes,
        netOtherRxBytes: netResult?.netOtherRxBytes,
        // Thermal / GPU
        thermalStatus: thermalResult?.thermalStatus,
        gpuPct: gpuResult?.gpuPct,
      );

      // Add to ring buffer (evict oldest if full)
      _buffer.add(sample);
      while (_buffer.length > _maxBufferSize) {
        _buffer.removeAt(0);
      }

      _controller?.add(sample);
    } catch (_) {
      // Individual tick failure — don't crash, just try again next tick
      _consecutiveFailures++;
    }
  }

  // ---------------------------------------------------------------------------
  // Individual Metric Collectors
  // ---------------------------------------------------------------------------

  /// Collect FPS data via SurfaceFlinger.
  Future<FpsResult?> _collectFps() async {
    if (_surfaceFlingerLayer == null) return null;
    final output = await _adbService.runShellCommand(
      _deviceSerial,
      'dumpsys SurfaceFlinger --latency "$_surfaceFlingerLayer"',
    );
    return FpsParser.parse(output);
  }

  /// Collect CPU data via /proc/pid/stat and /proc/stat.
  Future<CpuResult?> _collectCpu() async {
    // Rediscover PID if lost
    if (_pid == null) {
      await _rediscoverPid();
    }
    if (_pid == null) return null;

    // Combined command: cat /proc/<pid>/stat && echo --- && cat /proc/stat
    final combinedOutput = await _adbService.runShellCommand(
      _deviceSerial,
      'cat /proc/$_pid/stat && echo --- && cat /proc/stat',
    );
    if (combinedOutput == null) return null;

    // Split on --- separator
    final parts = combinedOutput.split('---');
    if (parts.length < 2) return null;

    final pidStat = parts[0].trim();
    final procStat = parts[1].trim();

    var cpuResult = _cpuParser.parse(pidStat, procStat);

    // Collect core frequency data for normalization
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

  /// Collect memory data via dumpsys meminfo.
  Future<MemoryResult?> _collectMemory() async {
    if (_pid == null) return null;
    final output = await _adbService.runShellCommand(
      _deviceSerial,
      'dumpsys meminfo $_packageName',
    );
    return MemoryParser.parse(output);
  }

  /// Collect battery data via dumpsys + sysfs.
  Future<BatteryResult?> _collectBattery() async {
    // dumpsys battery (level, temp, voltage, charging)
    final dumpsysOutput = await _adbService.runShellCommand(
      _deviceSerial,
      'dumpsys battery',
    );
    final dumpsysResult = BatteryParser.parseDumpsysBattery(dumpsysOutput);

    // sysfs current_now (more precise current)
    final currentOutput = await _adbService.runShellCommand(
      _deviceSerial,
      'cat /sys/class/power_supply/battery/current_now',
    );
    final currentResult = BatteryParser.parseCurrentNow(currentOutput);

    // sysfs voltage_now (more precise voltage, preferred)
    final voltageOutput = await _adbService.runShellCommand(
      _deviceSerial,
      'cat /sys/class/power_supply/battery/voltage_now',
    );
    final voltageResult = BatteryParser.parseVoltageNow(voltageOutput);

    // WiFi state
    final wifiOutput = await _adbService.runShellCommand(
      _deviceSerial,
      'dumpsys connectivity | grep -A2 "Active default network"',
    );
    final wifiResult = BatteryParser.parseWifiState(wifiOutput);

    // Merge results: sysfs values take priority over dumpsys
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

  /// Collect network data via /proc/net/dev.
  Future<NetworkResult?> _collectNetwork() async {
    final output = await _adbService.runShellCommand(
      _deviceSerial,
      'cat /proc/net/dev',
    );
    return NetworkParser.parse(output);
  }

  /// Collect thermal data via dumpsys thermalservice or getprop fallback.
  Future<ThermalResult?> _collectThermal() async {
    // Primary: dumpsys thermalservice
    var output = await _adbService.runShellCommand(
      _deviceSerial,
      'dumpsys thermalservice',
    );
    if (output != null) {
      final result = ThermalParser.parseThermalService(output);
      if (result.thermalStatus != null) return result;
    }

    // Fallback: getprop sys.thermal.state
    output = await _adbService.runShellCommand(
      _deviceSerial,
      'getprop sys.thermal.state',
    );
    if (output != null) {
      return ThermalParser.parseGetprop(output);
    }

    return null;
  }

  /// Collect GPU data via Adreno or Mali sysfs paths.
  Future<GpuResult?> _collectGpu() async {
    // Try Adreno path
    var output = await _adbService.runShellCommand(
      _deviceSerial,
      'cat /sys/class/kgsl/kgsl-3d0/gpubusy',
    );
    if (output != null && output.isNotEmpty) {
      final result = GpuParser.parseAdreno(output);
      if (result.gpuPct != null) return result;
    }

    // Try Mali (Samsung) path
    output = await _adbService.runShellCommand(
      _deviceSerial,
      'cat /sys/class/misc/mali0/device/utilization',
    );
    if (output != null && output.isNotEmpty) {
      final result = GpuParser.parseMaliUtil(output);
      if (result.gpuPct != null) return result;
    }

    // Never fabricate GPU values
    return null;
  }
}
