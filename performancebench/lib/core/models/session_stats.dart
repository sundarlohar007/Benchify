/// SessionStats model — matches `session_stats` table in Appendix C exactly.
/// Per-session analytics summary computed post-session. 56 fields.
class SessionStats {
  final String sessionId; // PK, FK to sessions

  // FPS
  final double? fpsMedian;
  final double? fpsMin;
  final double? fpsMax;
  final double? fps1pctLow;
  final double? fpsStability;
  final double? frameTimeP95;
  final String? fpsHistogram; // JSON
  final double? variabilityIndex;
  final int? frameRatioJankTotal;

  // CPU
  final double? cpuAvgPct;
  final double? cpuPeakPct;
  final double? cpuAvgPctFreqNorm;
  final double? cpuPeakPctFreqNorm;

  // Memory
  final int? memoryAvgKb;
  final int? memoryPeakKb;
  final int? memJavaAvgKb;
  final int? memJavaPeakKb;
  final int? memNativeAvgKb;
  final int? memNativePeakKb;
  final int? memGraphicsAvgKb;
  final int? memGraphicsPeakKb;
  final int? memStackAvgKb;
  final int? memCodeAvgKb;
  final int? memSystemAvgKb;
  final int? memWebviewAvgKb;
  final int? memGrowthKb;
  final double? memTrendSlopeKbPerMin;

  // GPU
  final double? gpuAvgPct;
  final double? gpuPeakPct;

  // Battery + Power
  final double? batteryDrainPct;
  final double? batteryDrainPerHour;
  final double? batteryTempMaxC;
  final double? mahConsumed;
  final double? avgPowerMw;
  final double? totalPowerMwh;
  final double? estimatedPlaytimeH;
  final int hasChargingPeriod;

  // Jank
  final int? jankTotal;
  final int? jankSmallTotal;
  final int? jankBigTotal;
  final int? jankRatioTotal;
  final double? jankPerMin;

  // Network per-interface
  final double? netTotalTxKb;
  final double? netTotalRxKb;
  final double? netWifiTotalTxKb;
  final double? netWifiTotalRxKb;
  final double? netCellularTotalTxKb;
  final double? netCellularTotalRxKb;
  final double? netOtherTotalTxKb;
  final double? netOtherTotalRxKb;
  final double? netWifiAvgKbps;
  final double? netCellularAvgKbps;

  // Thermal
  final int? thermalPeak;

  // Timing
  final int? launchCompleteMs;
  final int? durationMs;

  const SessionStats({
    required this.sessionId,
    this.fpsMedian,
    this.fpsMin,
    this.fpsMax,
    this.fps1pctLow,
    this.fpsStability,
    this.frameTimeP95,
    this.fpsHistogram,
    this.variabilityIndex,
    this.frameRatioJankTotal,
    this.cpuAvgPct,
    this.cpuPeakPct,
    this.cpuAvgPctFreqNorm,
    this.cpuPeakPctFreqNorm,
    this.memoryAvgKb,
    this.memoryPeakKb,
    this.memJavaAvgKb,
    this.memJavaPeakKb,
    this.memNativeAvgKb,
    this.memNativePeakKb,
    this.memGraphicsAvgKb,
    this.memGraphicsPeakKb,
    this.memStackAvgKb,
    this.memCodeAvgKb,
    this.memSystemAvgKb,
    this.memWebviewAvgKb,
    this.memGrowthKb,
    this.memTrendSlopeKbPerMin,
    this.gpuAvgPct,
    this.gpuPeakPct,
    this.batteryDrainPct,
    this.batteryDrainPerHour,
    this.batteryTempMaxC,
    this.mahConsumed,
    this.avgPowerMw,
    this.totalPowerMwh,
    this.estimatedPlaytimeH,
    this.hasChargingPeriod = 0,
    this.jankTotal,
    this.jankSmallTotal,
    this.jankBigTotal,
    this.jankRatioTotal,
    this.jankPerMin,
    this.netTotalTxKb,
    this.netTotalRxKb,
    this.netWifiTotalTxKb,
    this.netWifiTotalRxKb,
    this.netCellularTotalTxKb,
    this.netCellularTotalRxKb,
    this.netOtherTotalTxKb,
    this.netOtherTotalRxKb,
    this.netWifiAvgKbps,
    this.netCellularAvgKbps,
    this.thermalPeak,
    this.launchCompleteMs,
    this.durationMs,
  });

  factory SessionStats.fromMap(Map<String, dynamic> map) {
    return SessionStats(
      sessionId: map['session_id'] as String,
      fpsMedian: (map['fps_median'] as num?)?.toDouble(),
      fpsMin: (map['fps_min'] as num?)?.toDouble(),
      fpsMax: (map['fps_max'] as num?)?.toDouble(),
      fps1pctLow: (map['fps_1pct_low'] as num?)?.toDouble(),
      fpsStability: (map['fps_stability'] as num?)?.toDouble(),
      frameTimeP95: (map['frame_time_p95'] as num?)?.toDouble(),
      fpsHistogram: map['fps_histogram'] as String?,
      variabilityIndex: (map['variability_index'] as num?)?.toDouble(),
      frameRatioJankTotal: map['frame_ratio_jank_total'] as int?,
      cpuAvgPct: (map['cpu_avg_pct'] as num?)?.toDouble(),
      cpuPeakPct: (map['cpu_peak_pct'] as num?)?.toDouble(),
      cpuAvgPctFreqNorm: (map['cpu_avg_pct_freq_norm'] as num?)?.toDouble(),
      cpuPeakPctFreqNorm: (map['cpu_peak_pct_freq_norm'] as num?)?.toDouble(),
      memoryAvgKb: map['memory_avg_kb'] as int?,
      memoryPeakKb: map['memory_peak_kb'] as int?,
      memJavaAvgKb: map['mem_java_avg_kb'] as int?,
      memJavaPeakKb: map['mem_java_peak_kb'] as int?,
      memNativeAvgKb: map['mem_native_avg_kb'] as int?,
      memNativePeakKb: map['mem_native_peak_kb'] as int?,
      memGraphicsAvgKb: map['mem_graphics_avg_kb'] as int?,
      memGraphicsPeakKb: map['mem_graphics_peak_kb'] as int?,
      memStackAvgKb: map['mem_stack_avg_kb'] as int?,
      memCodeAvgKb: map['mem_code_avg_kb'] as int?,
      memSystemAvgKb: map['mem_system_avg_kb'] as int?,
      memWebviewAvgKb: map['mem_webview_avg_kb'] as int?,
      memGrowthKb: map['mem_growth_kb'] as int?,
      memTrendSlopeKbPerMin:
          (map['mem_trend_slope_kb_per_min'] as num?)?.toDouble(),
      gpuAvgPct: (map['gpu_avg_pct'] as num?)?.toDouble(),
      gpuPeakPct: (map['gpu_peak_pct'] as num?)?.toDouble(),
      batteryDrainPct: (map['battery_drain_pct'] as num?)?.toDouble(),
      batteryDrainPerHour: (map['battery_drain_per_hour'] as num?)?.toDouble(),
      batteryTempMaxC: (map['battery_temp_max_c'] as num?)?.toDouble(),
      mahConsumed: (map['mah_consumed'] as num?)?.toDouble(),
      avgPowerMw: (map['avg_power_mw'] as num?)?.toDouble(),
      totalPowerMwh: (map['total_power_mwh'] as num?)?.toDouble(),
      estimatedPlaytimeH: (map['estimated_playtime_h'] as num?)?.toDouble(),
      hasChargingPeriod: (map['has_charging_period'] as int?) ?? 0,
      jankTotal: map['jank_total'] as int?,
      jankSmallTotal: map['jank_small_total'] as int?,
      jankBigTotal: map['jank_big_total'] as int?,
      jankRatioTotal: map['jank_ratio_total'] as int?,
      jankPerMin: (map['jank_per_min'] as num?)?.toDouble(),
      netTotalTxKb: (map['net_total_tx_kb'] as num?)?.toDouble(),
      netTotalRxKb: (map['net_total_rx_kb'] as num?)?.toDouble(),
      netWifiTotalTxKb: (map['net_wifi_total_tx_kb'] as num?)?.toDouble(),
      netWifiTotalRxKb: (map['net_wifi_total_rx_kb'] as num?)?.toDouble(),
      netCellularTotalTxKb:
          (map['net_cellular_total_tx_kb'] as num?)?.toDouble(),
      netCellularTotalRxKb:
          (map['net_cellular_total_rx_kb'] as num?)?.toDouble(),
      netOtherTotalTxKb: (map['net_other_total_tx_kb'] as num?)?.toDouble(),
      netOtherTotalRxKb: (map['net_other_total_rx_kb'] as num?)?.toDouble(),
      netWifiAvgKbps: (map['net_wifi_avg_kbps'] as num?)?.toDouble(),
      netCellularAvgKbps: (map['net_cellular_avg_kbps'] as num?)?.toDouble(),
      thermalPeak: map['thermal_peak'] as int?,
      launchCompleteMs: map['launch_complete_ms'] as int?,
      durationMs: map['duration_ms'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'fps_median': fpsMedian,
      'fps_min': fpsMin,
      'fps_max': fpsMax,
      'fps_1pct_low': fps1pctLow,
      'fps_stability': fpsStability,
      'frame_time_p95': frameTimeP95,
      'fps_histogram': fpsHistogram,
      'variability_index': variabilityIndex,
      'frame_ratio_jank_total': frameRatioJankTotal,
      'cpu_avg_pct': cpuAvgPct,
      'cpu_peak_pct': cpuPeakPct,
      'cpu_avg_pct_freq_norm': cpuAvgPctFreqNorm,
      'cpu_peak_pct_freq_norm': cpuPeakPctFreqNorm,
      'memory_avg_kb': memoryAvgKb,
      'memory_peak_kb': memoryPeakKb,
      'mem_java_avg_kb': memJavaAvgKb,
      'mem_java_peak_kb': memJavaPeakKb,
      'mem_native_avg_kb': memNativeAvgKb,
      'mem_native_peak_kb': memNativePeakKb,
      'mem_graphics_avg_kb': memGraphicsAvgKb,
      'mem_graphics_peak_kb': memGraphicsPeakKb,
      'mem_stack_avg_kb': memStackAvgKb,
      'mem_code_avg_kb': memCodeAvgKb,
      'mem_system_avg_kb': memSystemAvgKb,
      'mem_webview_avg_kb': memWebviewAvgKb,
      'mem_growth_kb': memGrowthKb,
      'mem_trend_slope_kb_per_min': memTrendSlopeKbPerMin,
      'gpu_avg_pct': gpuAvgPct,
      'gpu_peak_pct': gpuPeakPct,
      'battery_drain_pct': batteryDrainPct,
      'battery_drain_per_hour': batteryDrainPerHour,
      'battery_temp_max_c': batteryTempMaxC,
      'mah_consumed': mahConsumed,
      'avg_power_mw': avgPowerMw,
      'total_power_mwh': totalPowerMwh,
      'estimated_playtime_h': estimatedPlaytimeH,
      'has_charging_period': hasChargingPeriod,
      'jank_total': jankTotal,
      'jank_small_total': jankSmallTotal,
      'jank_big_total': jankBigTotal,
      'jank_ratio_total': jankRatioTotal,
      'jank_per_min': jankPerMin,
      'net_total_tx_kb': netTotalTxKb,
      'net_total_rx_kb': netTotalRxKb,
      'net_wifi_total_tx_kb': netWifiTotalTxKb,
      'net_wifi_total_rx_kb': netWifiTotalRxKb,
      'net_cellular_total_tx_kb': netCellularTotalTxKb,
      'net_cellular_total_rx_kb': netCellularTotalRxKb,
      'net_other_total_tx_kb': netOtherTotalTxKb,
      'net_other_total_rx_kb': netOtherTotalRxKb,
      'net_wifi_avg_kbps': netWifiAvgKbps,
      'net_cellular_avg_kbps': netCellularAvgKbps,
      'thermal_peak': thermalPeak,
      'launch_complete_ms': launchCompleteMs,
      'duration_ms': durationMs,
    };
  }
}
