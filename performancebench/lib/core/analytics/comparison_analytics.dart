// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import '../models/session_stats.dart';

/// A single metric delta between two sessions.
class MetricDelta {
  final String metric;
  final double valueA;
  final double valueB;
  final double delta;
  final double deltaPercent;
  final bool isRegression;

  const MetricDelta({
    required this.metric,
    required this.valueA,
    required this.valueB,
    required this.delta,
    required this.deltaPercent,
    required this.isRegression,
  });
}

/// Computes per-metric deltas between two sessions per UNIFIED-SPEC §6.4.
///
/// Regression rules:
/// - FPS lower = regression
/// - CPU / Memory / Jank higher = regression
/// - Stability lower = regression
class ComparisonAnalytics {
  /// Metrics where a LOWER value in session B is a regression.
  static const _lowerIsRegression = {
    'FPS Median',
    'FPS 1% Low',
    'FPS Stability',
  };

  /// Metrics compared between two sessions.
  static const _comparedMetrics = [
    'FPS Median',
    'FPS 1% Low',
    'FPS Stability',
    'Frame Time P95',
    'CPU Avg',
    'Memory Peak',
    'Jank/min',
    'Big Jank Total',
    'GPU Avg',
  ];

  static List<MetricDelta> compare(SessionStats a, SessionStats b) {
    final deltas = <MetricDelta>[];

    for (final metric in _comparedMetrics) {
      final va = _getValue(a, metric);
      final vb = _getValue(b, metric);
      final delta = vb - va;
      final deltaPercent = va != 0 ? (delta / va) * 100.0 : 0.0;
      final isLowerRegression = _lowerIsRegression.contains(metric);
      final isRegression = isLowerRegression ? vb < va : vb > va;

      deltas.add(MetricDelta(
        metric: metric,
        valueA: va,
        valueB: vb,
        delta: delta,
        deltaPercent: deltaPercent,
        isRegression: isRegression,
      ));
    }

    return deltas;
  }

  static double _getValue(SessionStats s, String metric) {
    switch (metric) {
      case 'FPS Median':
        return s.fpsMedian ?? 0;
      case 'FPS 1% Low':
        return s.fps1pctLow ?? 0;
      case 'FPS Stability':
        return s.fpsStability ?? 0;
      case 'Frame Time P95':
        return s.frameTimeP95 ?? 0;
      case 'CPU Avg':
        return s.cpuAvgPct ?? 0;
      case 'Memory Peak':
        return (s.memoryPeakKb ?? 0).toDouble();
      case 'Jank/min':
        return s.jankPerMin ?? 0;
      case 'Big Jank Total':
        return (s.jankBigTotal ?? 0).toDouble();
      case 'GPU Avg':
        return s.gpuAvgPct ?? 0;
      default:
        return 0;
    }
  }
}
