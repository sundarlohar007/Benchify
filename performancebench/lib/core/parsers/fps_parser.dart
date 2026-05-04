// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:convert';

/// Result from FPS parsing — all fields nullable per §5.1 null contract.
class FpsResult {
  /// Frames per second. 0.0 if parse succeeded but no valid frames;
  /// null if ADB call failed entirely.
  final double? fps;

  /// Small jank count: frames where delta_ms > refresh_period_ms.
  final int? jankSmallCount;

  /// Jank count: delta_ms > 2*rolling_mean OR delta_ms > 83.3ms.
  final int? jankCount;

  /// Big jank count: delta_ms > 2*rolling_mean OR delta_ms > 125ms.
  final int? jankBigCount;

  /// Frame-ratio jank transitions (gamma=L/R model).
  final int? jankRatioCount;

  /// JSON array of frame delta_ms values used for jank evaluation.
  final String? frametimesJson;

  const FpsResult({
    this.fps,
    this.jankSmallCount,
    this.jankCount,
    this.jankBigCount,
    this.jankRatioCount,
    this.frametimesJson,
  });
}

/// Parses `dumpsys SurfaceFlinger --latency <layer>` output per §5.1.
///
/// All parsing is pure synchronous string processing — no I/O, no blocking.
/// Returns null fields on malformed/missing input, never throws.
///
/// **Deviation note:** The spec §5.1 step 6 defines an outlier filter at
/// `delta ≥ 100ms` for FPS computation. For jank classification, a separate
/// threshold at `delta ≥ 150ms` is used so that frames 100-149ms are excluded
/// from the FPS mean (they would skew it) but still evaluated for jank
/// (they represent user-visible stutter). Extreme freezes ≥ 150ms are
/// excluded from both FPS and jank counts.
class FpsParser {
  FpsParser._();

  /// Maximum delta for inclusion in FPS mean calculation (ms).
  static const double _fpsOutlierThreshold = 100.0;

  /// Maximum delta for inclusion in jank classification (ms).
  /// Frames at or above this threshold are treated as freezes, not janks.
  static const double _jankOutlierThreshold = 150.0;

  /// Parse SurfaceFlinger --latency output into structured FPS and jank data.
  ///
  /// If [surfaceFlingerOutput] is null (ADB failure), returns an [FpsResult]
  /// with all fields null. If output is non-null but contains fewer than 3
  /// lines or no usable frames, returns zeroed result (fps=0.0, janks=0).
  static FpsResult parse(String? surfaceFlingerOutput) {
    if (surfaceFlingerOutput == null) {
      return const FpsResult();
    }

    final lines = surfaceFlingerOutput.trim().split('\n');
    if (lines.length < 3) {
      return const FpsResult(
        fps: 0.0,
        jankSmallCount: 0,
        jankCount: 0,
        jankBigCount: 0,
        jankRatioCount: 0,
      );
    }

    // Parse line 1: refresh_period_ns
    final refreshPeriodNs = int.tryParse(lines[0].trim());
    if (refreshPeriodNs == null || refreshPeriodNs <= 0) {
      return const FpsResult(
        fps: 0.0,
        jankSmallCount: 0,
        jankCount: 0,
        jankBigCount: 0,
        jankRatioCount: 0,
      );
    }
    final refreshPeriodMs = refreshPeriodNs / 1000000.0;

    // Parse timestamps from remaining lines
    final timestamps = <int>[];
    for (var i = 1; i < lines.length; i++) {
      final parts = lines[i].split('\t');
      if (parts.length < 2) continue;
      final ts = int.tryParse(parts[1].trim());
      if (ts != null && ts > 0) {
        timestamps.add(ts);
      }
    }

    if (timestamps.length < 2) {
      return FpsResult(
        fps: 0.0,
        jankSmallCount: 0,
        jankCount: 0,
        jankBigCount: 0,
        jankRatioCount: 0,
        frametimesJson: null,
      );
    }

    // Compute all positive frame deltas (step 5)
    final allDeltas = <double>[];
    for (var i = 1; i < timestamps.length; i++) {
      final deltaNs = timestamps[i] - timestamps[i - 1];
      final deltaMs = deltaNs / 1000000.0;
      if (deltaMs > 0) {
        allDeltas.add(deltaMs);
      }
    }

    // --- FPS computation: filter out extreme outliers (≥100ms) for mean ---
    final fpsDeltas = allDeltas
        .where((d) => d < _fpsOutlierThreshold)
        .toList();

    double fps;
    if (fpsDeltas.isEmpty) {
      fps = 0.0;
    } else {
      final meanDelta =
          fpsDeltas.reduce((a, b) => a + b) / fpsDeltas.length;
      fps = 1000.0 / meanDelta;
    }

    // --- Jank classification: filter out freezes (≥150ms), rest are jank-candidate ---
    final jankDeltas = allDeltas
        .where((d) => d < _jankOutlierThreshold)
        .toList();

    int jankSmall = 0;
    int jankCount = 0;
    int jankBig = 0;
    final rollingWindow = <double>[];

    for (final deltaMs in jankDeltas) {
      // Rolling window of last 3 valid frame times
      rollingWindow.add(deltaMs);
      if (rollingWindow.length > 3) {
        rollingWindow.removeAt(0);
      }
      final rollingMean = rollingWindow.isNotEmpty
          ? rollingWindow.reduce((a, b) => a + b) / rollingWindow.length
          : 0.0;

      // Small jank: any frame slower than display refresh
      if (deltaMs > refreshPeriodMs) {
        jankSmall++;
      }

      // Jank: > 2x rolling mean OR > 83.3ms (2 frames at 24fps)
      if (deltaMs > 2.0 * rollingMean || deltaMs > 83.3) {
        jankCount++;
      }

      // Big jank: > 2x rolling mean OR > 125ms (3 frames at 24fps)
      if (deltaMs > 2.0 * rollingMean || deltaMs > 125.0) {
        jankBig++;
      }
    }

    // --- Frame ratio jank model (gamma = ceil(L / R)) ---
    int jankRatio = 0;
    int? prevGamma;
    for (final deltaMs in jankDeltas) {
      final gamma = (deltaMs / refreshPeriodMs).ceil();
      if (prevGamma != null && gamma != prevGamma) {
        jankRatio++;
      }
      prevGamma = gamma;
    }

    return FpsResult(
      fps: fps < 0 ? 0.0 : fps,
      jankSmallCount: jankSmall,
      jankCount: jankCount,
      jankBigCount: jankBig,
      jankRatioCount: jankRatio,
      frametimesJson: jankDeltas.isNotEmpty ? jsonEncode(jankDeltas) : null,
    );
  }
}
