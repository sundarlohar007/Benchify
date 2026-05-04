import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/analytics/comparison_analytics.dart';
import 'package:performancebench/core/models/session_stats.dart';

void main() {
  group('ComparisonAnalytics', () {
    final sessionA = SessionStats(
      sessionId: 'a',
      fpsMedian: 60.0,
      cpuAvgPct: 20.0,
      fpsStability: 90.0,
    );
    final sessionB = SessionStats(
      sessionId: 'b',
      fpsMedian: 54.0,
      cpuAvgPct: 25.0,
      fpsStability: 85.0,
    );

    test('FPS median regression: 60→54 is regression (-10%)', () {
      final deltas = ComparisonAnalytics.compare(sessionA, sessionB);
      final fpsDelta = deltas.where((d) => d.metric == 'FPS Median').first;
      expect(fpsDelta.isRegression, true);
      expect(fpsDelta.deltaPercent, closeTo(-10.0, 0.1));
    });

    test('CPU avg increase: 20→25 is regression (+25%)', () {
      final deltas = ComparisonAnalytics.compare(sessionA, sessionB);
      final cpuDelta = deltas.where((d) => d.metric == 'CPU Avg').first;
      expect(cpuDelta.isRegression, true);
    });

    test('Stability decrease: 90→85 is regression (-5.6%)', () {
      final deltas = ComparisonAnalytics.compare(sessionA, sessionB);
      final stabDelta =
          deltas.where((d) => d.metric == 'FPS Stability').first;
      expect(stabDelta.isRegression, true);
    });
  });
}
