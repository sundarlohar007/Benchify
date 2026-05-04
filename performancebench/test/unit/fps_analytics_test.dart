// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/analytics/fps_analytics.dart';

void main() {
  group('FpsAnalytics', () {
    test('empty list returns all zeros', () {
      final stats = FpsAnalytics.compute([]);
      expect(stats.median, 0.0);
      expect(stats.min, 0.0);
      expect(stats.max, 0.0);
      expect(stats.onePercentLow, 0.0);
      expect(stats.p95FrameTimeMs, 0.0);
      expect(stats.stabilityPct, 0.0);
      expect(stats.histogram, isEmpty);
      expect(stats.variabilityIndex, 0.0);
    });

    test('one percent low: 99x60fps + 1x5fps => 1% low ~5.0', () {
      final samples = <double>[
        ...List.filled(99, 60.0),
        5.0,
      ];
      final stats = FpsAnalytics.compute(samples);
      expect(stats.onePercentLow, closeTo(5.0, 0.1));
    });

    test('p95 frame time: 5x30fps + 95x60fps => p95 ~33.3ms', () {
      final samples = <double>[
        ...List.filled(5, 30.0),
        ...List.filled(95, 60.0),
      ];
      final stats = FpsAnalytics.compute(samples);
      // 5th percentile FPS = 30.0, frame time = 1000/30 = 33.3ms
      expect(stats.p95FrameTimeMs, closeTo(33.3, 1.0));
    });

    test('stability: all 60fps => 100% stable', () {
      final samples = List.filled(100, 60.0);
      final stats = FpsAnalytics.compute(samples);
      expect(stats.stabilityPct, closeTo(100.0, 0.1));
    });

    test('histogram: 58, 59, 62 => 5fps buckets correct', () {
      final samples = [58.0, 59.0, 62.0];
      final stats = FpsAnalytics.compute(samples);
      // (58/5).floor()*5 = 55, (59/5).floor()*5 = 55, (62/5).floor()*5 = 60
      expect(stats.histogram[55], 2);
      expect(stats.histogram[60], 1);
    });

    test('min and max from [20, 30, 60]', () {
      final stats = FpsAnalytics.compute([20.0, 30.0, 60.0]);
      expect(stats.min, closeTo(20.0, 0.01));
      expect(stats.max, closeTo(60.0, 0.01));
    });

    test('variability index: all 60fps => 0.0', () {
      final stats = FpsAnalytics.compute([60.0, 60.0, 60.0, 60.0, 60.0]);
      expect(stats.variabilityIndex, closeTo(0.0, 0.01));
    });

    test('variability index: [60, 30, 60, 30, 60] => ~30.0', () {
      final samples = [60.0, 30.0, 60.0, 30.0, 60.0];
      final stats = FpsAnalytics.compute(samples);
      // diffs: 30, 30, 30, 30 = 120/4 = 30
      expect(stats.variabilityIndex, closeTo(30.0, 0.01));
    });
  });
}
