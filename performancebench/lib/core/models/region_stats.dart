// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// RegionStats model — matches `region_stats` table.
/// Per-region computed analytics, same computation as MarkerStats.
/// Keyed by label + start/end timestamps instead of markerId.
class RegionStats {
  final int? id; // autoincrement, null on insert
  final String sessionId;
  final String label;
  final int startMs;
  final int endMs;
  final String? color;
  final int? durationMs;
  final double? fpsMedian;
  final double? fpsMin;
  final double? fpsMax;
  final double? fps1pctLow;
  final double? fpsStability;
  final double? frameTimeP95;
  final double? variabilityIndex;
  final double? cpuAvgPct;
  final double? cpuAvgPctFreqNorm;
  final int? memoryPeakKb;
  final int? memGraphicsPeakKb;
  final double? gpuAvgPct;
  final double? batteryDrainPct;
  final double? mahConsumed;
  final int? jankTotal;
  final int? jankSmallTotal;
  final int? jankBigTotal;
  final int? jankRatioTotal;
  final double? jankPerMin;

  const RegionStats({
    this.id,
    required this.sessionId,
    required this.label,
    required this.startMs,
    required this.endMs,
    this.color,
    this.durationMs,
    this.fpsMedian,
    this.fpsMin,
    this.fpsMax,
    this.fps1pctLow,
    this.fpsStability,
    this.frameTimeP95,
    this.variabilityIndex,
    this.cpuAvgPct,
    this.cpuAvgPctFreqNorm,
    this.memoryPeakKb,
    this.memGraphicsPeakKb,
    this.gpuAvgPct,
    this.batteryDrainPct,
    this.mahConsumed,
    this.jankTotal,
    this.jankSmallTotal,
    this.jankBigTotal,
    this.jankRatioTotal,
    this.jankPerMin,
  });

  factory RegionStats.fromMap(Map<String, dynamic> map) {
    return RegionStats(
      id: map['id'] as int?,
      sessionId: map['session_id'] as String,
      label: map['label'] as String,
      startMs: map['start_ms'] as int,
      endMs: map['end_ms'] as int,
      color: map['color'] as String?,
      durationMs: map['duration_ms'] as int?,
      fpsMedian: (map['fps_median'] as num?)?.toDouble(),
      fpsMin: (map['fps_min'] as num?)?.toDouble(),
      fpsMax: (map['fps_max'] as num?)?.toDouble(),
      fps1pctLow: (map['fps_1pct_low'] as num?)?.toDouble(),
      fpsStability: (map['fps_stability'] as num?)?.toDouble(),
      frameTimeP95: (map['frame_time_p95'] as num?)?.toDouble(),
      variabilityIndex: (map['variability_index'] as num?)?.toDouble(),
      cpuAvgPct: (map['cpu_avg_pct'] as num?)?.toDouble(),
      cpuAvgPctFreqNorm: (map['cpu_avg_pct_freq_norm'] as num?)?.toDouble(),
      memoryPeakKb: map['memory_peak_kb'] as int?,
      memGraphicsPeakKb: map['mem_graphics_peak_kb'] as int?,
      gpuAvgPct: (map['gpu_avg_pct'] as num?)?.toDouble(),
      batteryDrainPct: (map['battery_drain_pct'] as num?)?.toDouble(),
      mahConsumed: (map['mah_consumed'] as num?)?.toDouble(),
      jankTotal: map['jank_total'] as int?,
      jankSmallTotal: map['jank_small_total'] as int?,
      jankBigTotal: map['jank_big_total'] as int?,
      jankRatioTotal: map['jank_ratio_total'] as int?,
      jankPerMin: (map['jank_per_min'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'session_id': sessionId,
      'label': label,
      'start_ms': startMs,
      'end_ms': endMs,
      'color': color,
      'duration_ms': durationMs,
      'fps_median': fpsMedian,
      'fps_min': fpsMin,
      'fps_max': fpsMax,
      'fps_1pct_low': fps1pctLow,
      'fps_stability': fpsStability,
      'frame_time_p95': frameTimeP95,
      'variability_index': variabilityIndex,
      'cpu_avg_pct': cpuAvgPct,
      'cpu_avg_pct_freq_norm': cpuAvgPctFreqNorm,
      'memory_peak_kb': memoryPeakKb,
      'mem_graphics_peak_kb': memGraphicsPeakKb,
      'gpu_avg_pct': gpuAvgPct,
      'battery_drain_pct': batteryDrainPct,
      'mah_consumed': mahConsumed,
      'jank_total': jankTotal,
      'jank_small_total': jankSmallTotal,
      'jank_big_total': jankBigTotal,
      'jank_ratio_total': jankRatioTotal,
      'jank_per_min': jankPerMin,
    };
    if (id != null) map['id'] = id;
    return map;
  }
}
