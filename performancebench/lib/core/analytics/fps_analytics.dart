import 'dart:convert';

/// Data class for computed FPS statistics per UNIFIED-SPEC §6.1.
class FpsStats {
  final double median;
  final double min;
  final double max;
  final double onePercentLow;
  final double p95FrameTimeMs;
  final double stabilityPct;
  final Map<int, int> histogram;
  final String histogramJson;
  final double variabilityIndex;

  const FpsStats({
    required this.median,
    required this.min,
    required this.max,
    required this.onePercentLow,
    required this.p95FrameTimeMs,
    required this.stabilityPct,
    required this.histogram,
    required this.histogramJson,
    required this.variabilityIndex,
  });

  static const zero = FpsStats(
    median: 0,
    min: 0,
    max: 0,
    onePercentLow: 0,
    p95FrameTimeMs: 0,
    stabilityPct: 0,
    histogram: {},
    histogramJson: '{}',
    variabilityIndex: 0,
  );
}

/// Computes FPS statistics from a list of FPS values per UNIFIED-SPEC §6.1.
class FpsAnalytics {
  static FpsStats compute(List<double> samples) {
    if (samples.isEmpty) return FpsStats.zero;

    final sorted = List<double>.from(samples)..sort();

    // Median
    final median = _median(sorted);

    // Min / Max
    final min = sorted.first;
    final max = sorted.last;

    // 1% Low
    final onePercentLowCount = (samples.length * 0.01).ceil().clamp(1, samples.length);
    final onePercentLow = sorted.sublist(0, onePercentLowCount).reduce((a, b) => a + b) / onePercentLowCount;

    // 95th percentile frame time: FPS at 5th percentile (1-indexed rank)
    final p5Rank = (samples.length * 0.05).ceil().clamp(1, samples.length);
    final p5Index = p5Rank - 1;
    final fps5th = sorted[p5Index];
    final p95FrameTimeMs = fps5th > 0 ? 1000.0 / fps5th : 0.0;

    // Stability %
    final lo = median * 0.8;
    final hi = median * 1.2;
    final stableCount = samples.where((f) => f >= lo && f <= hi).length;
    final stabilityPct = (stableCount / samples.length) * 100.0;

    // Histogram (5 fps buckets)
    const bucketSize = 5;
    final histogram = <int, int>{};
    for (final fps in samples) {
      final key = (fps ~/ bucketSize) * bucketSize;
      histogram[key] = (histogram[key] ?? 0) + 1;
    }
    final histogramJson = jsonEncode(histogram.map((k, v) => MapEntry(k.toString(), v)));

    // Variability Index
    double variabilityIndex = 0;
    if (samples.length >= 2) {
      double sumDiffs = 0;
      for (var i = 1; i < samples.length; i++) {
        sumDiffs += (samples[i] - samples[i - 1]).abs();
      }
      variabilityIndex = sumDiffs / (samples.length - 1);
    }

    return FpsStats(
      median: median,
      min: min,
      max: max,
      onePercentLow: onePercentLow,
      p95FrameTimeMs: p95FrameTimeMs,
      stabilityPct: stabilityPct,
      histogram: histogram,
      histogramJson: histogramJson,
      variabilityIndex: variabilityIndex,
    );
  }

  static double _median(List<double> sorted) {
    final n = sorted.length;
    if (n.isOdd) return sorted[n ~/ 2];
    return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
  }
}
