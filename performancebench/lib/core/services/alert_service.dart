// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import '../models/marker.dart';
import '../models/metric_sample.dart';

/// Configuration for a single threshold alert rule (per D-05: all default-off).
class ThresholdConfig {
  final bool enabled;
  final double threshold;
  final int windowSamples;
  final String label;
  final String metricField;

  const ThresholdConfig({
    this.enabled = false,
    required this.threshold,
    required this.windowSamples,
    required this.label,
    required this.metricField,
  });
}

/// Threshold alert service integrated into MetricCollector tick loop.
///
/// Checks FPS sliding window, CPU sliding window, and memory growth over window.
/// Fire-and-forget marker insertion via [onMarkerInsert] callback.
/// Breach notifications via [onBreachCallback].
class AlertService {
  final Future<int> Function(Marker marker) _onMarkerInsert;
  final void Function(int totalBreaches, String latestBreachLabel)? _onBreachCallback;

  ThresholdConfig _fpsConfig;
  ThresholdConfig _cpuConfig;
  ThresholdConfig _memoryConfig;

  /// Ring buffer of recent MetricSamples (shared with MetricCollector).
  final List<MetricSample> _recentSamples = [];
  static const int _maxRecent = 30;

  /// Current breach state — prevents repeated markers for same sustained breach.
  bool _fpsBreached = false;
  bool _cpuBreached = false;
  bool _memoryBreached = false;

  int _totalBreachCount = 0;

  AlertService({
    required Future<int> Function(Marker marker) onMarkerInsert,
    void Function(int totalBreaches, String latestBreachLabel)? onBreachCallback,
    ThresholdConfig fpsConfig = const ThresholdConfig(
      threshold: 30.0,
      windowSamples: 10,
      label: 'FPS < 30',
      metricField: 'fps',
    ),
    ThresholdConfig cpuConfig = const ThresholdConfig(
      threshold: 85.0,
      windowSamples: 5,
      label: 'CPU > 85%',
      metricField: 'cpuAppPct',
    ),
    ThresholdConfig memoryConfig = const ThresholdConfig(
      threshold: 102400.0,
      windowSamples: 30,
      label: 'Memory +100MB',
      metricField: 'memoryPssKb',
    ),
  })  : _onMarkerInsert = onMarkerInsert,
        _onBreachCallback = onBreachCallback,
        _fpsConfig = fpsConfig,
        _cpuConfig = cpuConfig,
        _memoryConfig = memoryConfig;

  /// Called by MetricCollector each tick with the latest sample.
  void checkThresholds(MetricSample sample, {required String sessionId}) {
    _recentSamples.add(sample);
    while (_recentSamples.length > _maxRecent) {
      _recentSamples.removeAt(0);
    }

    if (_fpsConfig.enabled) _checkFps(sessionId);
    if (_cpuConfig.enabled) _checkCpu(sessionId);
    if (_memoryConfig.enabled) _checkMemory(sessionId);
  }

  void _checkFps(String sessionId) {
    final window = _recentSamples.where((s) => s.fps != null).toList();
    if (window.length < _fpsConfig.windowSamples) return;

    final recentWindow = window.sublist(window.length - _fpsConfig.windowSamples);
    final allBelow = recentWindow.every((s) => (s.fps ?? 999) < _fpsConfig.threshold);

    if (allBelow && !_fpsBreached) {
      _fpsBreached = true;
      final avgFps = recentWindow
              .map((s) => s.fps ?? 0)
              .reduce((a, b) => a + b) /
          recentWindow.length;
      _fireBreach(sessionId, _fpsConfig.label, _fpsConfig.threshold, avgFps);
    } else if (!allBelow && _fpsBreached) {
      _fpsBreached = false;
    }
  }

  void _checkCpu(String sessionId) {
    final window = _recentSamples.where((s) => s.cpuAppPct != null).toList();
    if (window.length < _cpuConfig.windowSamples) return;

    final recentWindow = window.sublist(window.length - _cpuConfig.windowSamples);
    final allAbove =
        recentWindow.every((s) => (s.cpuAppPct ?? 0) > _cpuConfig.threshold);

    if (allAbove && !_cpuBreached) {
      _cpuBreached = true;
      final avgCpu = recentWindow
              .map((s) => s.cpuAppPct ?? 0)
              .reduce((a, b) => a + b) /
          recentWindow.length;
      _fireBreach(sessionId, _cpuConfig.label, _cpuConfig.threshold, avgCpu);
    } else if (!allAbove && _cpuBreached) {
      _cpuBreached = false;
    }
  }

  void _checkMemory(String sessionId) {
    if (_recentSamples.length < _memoryConfig.windowSamples) return;

    final recentWindow = _recentSamples.sublist(
      _recentSamples.length - _memoryConfig.windowSamples,
    );
    final firstMem = recentWindow.first.memoryPssKb;
    final lastMem = recentWindow.last.memoryPssKb;

    if (firstMem != null && lastMem != null) {
      final growth = lastMem - firstMem;
      final growthMb = growth / 1024.0;

      if (growth > _memoryConfig.threshold && !_memoryBreached) {
        _memoryBreached = true;
        _fireBreach(sessionId, _memoryConfig.label, _memoryConfig.threshold, growthMb);
      } else if (growth <= _memoryConfig.threshold && _memoryBreached) {
        _memoryBreached = false;
      }
    }
  }

  void _fireBreach(String sessionId, String label, double threshold, double observedValue) {
    _totalBreachCount++;
    _onBreachCallback?.call(_totalBreachCount, label);

    final marker = Marker(
      sessionId: sessionId,
      label: 'Alert: $label',
      startedAt: DateTime.now().millisecondsSinceEpoch,
      endedAt: null,
      autoScreenshot: 0,
      notes: 'Threshold: $threshold, Observed: ${observedValue.toStringAsFixed(1)}',
    );
    // Fire-and-forget marker insert
    _onMarkerInsert(marker);
  }

  /// Update threshold config from Settings (per D-05).
  void updateConfig({
    bool? fpsEnabled,
    double? fpsMin,
    int? fpsWindow,
    bool? cpuEnabled,
    double? cpuMax,
    int? cpuWindow,
    bool? memoryEnabled,
    double? memoryGrowthMb,
    int? memoryWindow,
  }) {
    _fpsConfig = ThresholdConfig(
      enabled: fpsEnabled ?? _fpsConfig.enabled,
      threshold: fpsMin ?? _fpsConfig.threshold,
      windowSamples: fpsWindow ?? _fpsConfig.windowSamples,
      label: 'FPS < ${fpsMin?.toInt() ?? 30}',
      metricField: 'fps',
    );
    _cpuConfig = ThresholdConfig(
      enabled: cpuEnabled ?? _cpuConfig.enabled,
      threshold: cpuMax ?? _cpuConfig.threshold,
      windowSamples: cpuWindow ?? _cpuConfig.windowSamples,
      label: 'CPU > ${cpuMax?.toInt() ?? 85}%',
      metricField: 'cpuAppPct',
    );
    _memoryConfig = ThresholdConfig(
      enabled: memoryEnabled ?? _memoryConfig.enabled,
      threshold: (memoryGrowthMb ?? 100) * 1024,
      windowSamples: memoryWindow ?? _memoryConfig.windowSamples,
      label: 'Memory +${memoryGrowthMb?.toInt() ?? 100}MB',
      metricField: 'memoryPssKb',
    );
  }

  /// Reset breach state at session start.
  void reset() {
    _recentSamples.clear();
    _fpsBreached = false;
    _cpuBreached = false;
    _memoryBreached = false;
    _totalBreachCount = 0;
  }
}
