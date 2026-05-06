// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// MetricSample model — matches `metric_samples` table in Appendix C exactly.
/// All 48 columns: id, session_id, timestamp, fps/jank columns, cpu columns,
/// memory PSS columns, battery columns, network columns, thermal/gpu/disk columns,
/// environment columns.
class MetricSample {
  final int? id; // autoincrement, null on insert
  final String sessionId;
  final int timestamp; // Unix ms

  // FPS / Jank
  final double? fps;
  final int? jankCount;
  final int? jankSmallCount;
  final int? jankBigCount;
  final int? jankRatioCount;
  final String? frametimesJson;

  // CPU
  final double? cpuSystemPct;
  final double? cpuAppPct;
  final double? cpuAppPctFreqNorm;
  final String? cpuCores;
  final String? cpuCoreStatesJson;
  final String? cpuCoreFreqsJson;
  final String? cpuThreadsTopJson;

  // Memory (PSS subsections)
  final int? memoryPssKb;
  final int? memoryJavaKb;
  final int? memoryNativeKb;
  final int? memoryGraphicsKb;
  final int? memoryStackKb;
  final int? memoryCodeKb;
  final int? memorySystemKb;
  final int? memoryWebviewKb;

  // Battery
  final int? batteryPct;
  final double? batteryMa;
  final double? batteryMv;
  final double? batteryTempC;
  final int charging;
  final String? chargingSource;

  // Connectivity
  final int? wifiActive;

  // Network (cumulative bytes)
  final int? netTxBytes;
  final int? netRxBytes;
  final int? netWifiTxBytes;
  final int? netWifiRxBytes;
  final int? netCellularTxBytes;
  final int? netCellularRxBytes;
  final int? netOtherTxBytes;
  final int? netOtherRxBytes;

  // Thermal / GPU / Disk
  final int? thermalStatus;
  final double? gpuPct;
  final double? gpuFreqMhz;
  final int? gpuMemKb;
  final double? diskReadKb;
  final double? diskWriteKb;

  // Environment
  final int? screenBrightness;
  final int? volumePct;

  // -----------------------------------------------------------------------
  // PC-specific fields (v3.0, §19.6) — all nullable for mobile compatibility
  // -----------------------------------------------------------------------

  /// Handle count (Windows only)
  final int? pcHandleCount;

  /// Thread count (Windows only)
  final int? pcThreadCount;

  /// Page faults per second (Windows only)
  final double? pcPageFaultsPerS;

  /// GPU dedicated memory in KB (Windows only)
  final int? pcGpuDedicatedMemKb;

  /// GPU shared memory in KB (Windows only)
  final int? pcGpuSharedMemKb;

  /// JSON array of per-core CPU % (Windows only)
  final String? pcPerCoreCpuJson;

  /// JSON array of per-thread CPU data (Windows only):
  /// [{"tid": 123, "name": "UnityMain", "cpu_pct": 18.2}, ...]
  final String? pcThreadCpuJson;

  const MetricSample({
    this.id,
    required this.sessionId,
    required this.timestamp,
    this.fps,
    this.jankCount,
    this.jankSmallCount,
    this.jankBigCount,
    this.jankRatioCount,
    this.frametimesJson,
    this.cpuSystemPct,
    this.cpuAppPct,
    this.cpuAppPctFreqNorm,
    this.cpuCores,
    this.cpuCoreStatesJson,
    this.cpuCoreFreqsJson,
    this.cpuThreadsTopJson,
    this.memoryPssKb,
    this.memoryJavaKb,
    this.memoryNativeKb,
    this.memoryGraphicsKb,
    this.memoryStackKb,
    this.memoryCodeKb,
    this.memorySystemKb,
    this.memoryWebviewKb,
    this.batteryPct,
    this.batteryMa,
    this.batteryMv,
    this.batteryTempC,
    this.charging = 0,
    this.chargingSource,
    this.wifiActive,
    this.netTxBytes,
    this.netRxBytes,
    this.netWifiTxBytes,
    this.netWifiRxBytes,
    this.netCellularTxBytes,
    this.netCellularRxBytes,
    this.netOtherTxBytes,
    this.netOtherRxBytes,
    this.thermalStatus,
    this.gpuPct,
    this.gpuFreqMhz,
    this.gpuMemKb,
    this.diskReadKb,
    this.diskWriteKb,
    this.screenBrightness,
    this.volumePct,
    this.pcHandleCount,
    this.pcThreadCount,
    this.pcPageFaultsPerS,
    this.pcGpuDedicatedMemKb,
    this.pcGpuSharedMemKb,
    this.pcPerCoreCpuJson,
    this.pcThreadCpuJson,
  });

  factory MetricSample.fromMap(Map<String, dynamic> map) {
    return MetricSample(
      id: map['id'] as int?,
      sessionId: map['session_id'] as String,
      timestamp: map['timestamp'] as int,
      fps: (map['fps'] as num?)?.toDouble(),
      jankCount: map['jank_count'] as int?,
      jankSmallCount: map['jank_small_count'] as int?,
      jankBigCount: map['jank_big_count'] as int?,
      jankRatioCount: map['jank_ratio_count'] as int?,
      frametimesJson: map['frametimes_json'] as String?,
      cpuSystemPct: (map['cpu_system_pct'] as num?)?.toDouble(),
      cpuAppPct: (map['cpu_app_pct'] as num?)?.toDouble(),
      cpuAppPctFreqNorm: (map['cpu_app_pct_freq_norm'] as num?)?.toDouble(),
      cpuCores: map['cpu_cores'] as String?,
      cpuCoreStatesJson: map['cpu_core_states_json'] as String?,
      cpuCoreFreqsJson: map['cpu_core_freqs_json'] as String?,
      cpuThreadsTopJson: map['cpu_threads_top_json'] as String?,
      memoryPssKb: map['memory_pss_kb'] as int?,
      memoryJavaKb: map['memory_java_kb'] as int?,
      memoryNativeKb: map['memory_native_kb'] as int?,
      memoryGraphicsKb: map['memory_graphics_kb'] as int?,
      memoryStackKb: map['memory_stack_kb'] as int?,
      memoryCodeKb: map['memory_code_kb'] as int?,
      memorySystemKb: map['memory_system_kb'] as int?,
      memoryWebviewKb: map['memory_webview_kb'] as int?,
      batteryPct: map['battery_pct'] as int?,
      batteryMa: (map['battery_ma'] as num?)?.toDouble(),
      batteryMv: (map['battery_mv'] as num?)?.toDouble(),
      batteryTempC: (map['battery_temp_c'] as num?)?.toDouble(),
      charging: (map['charging'] as int?) ?? 0,
      chargingSource: map['charging_source'] as String?,
      wifiActive: map['wifi_active'] as int?,
      netTxBytes: map['net_tx_bytes'] as int?,
      netRxBytes: map['net_rx_bytes'] as int?,
      netWifiTxBytes: map['net_wifi_tx_bytes'] as int?,
      netWifiRxBytes: map['net_wifi_rx_bytes'] as int?,
      netCellularTxBytes: map['net_cellular_tx_bytes'] as int?,
      netCellularRxBytes: map['net_cellular_rx_bytes'] as int?,
      netOtherTxBytes: map['net_other_tx_bytes'] as int?,
      netOtherRxBytes: map['net_other_rx_bytes'] as int?,
      thermalStatus: map['thermal_status'] as int?,
      gpuPct: (map['gpu_pct'] as num?)?.toDouble(),
      gpuFreqMhz: (map['gpu_freq_mhz'] as num?)?.toDouble(),
      gpuMemKb: map['gpu_mem_kb'] as int?,
      diskReadKb: (map['disk_read_kb'] as num?)?.toDouble(),
      diskWriteKb: (map['disk_write_kb'] as num?)?.toDouble(),
      screenBrightness: map['screen_brightness'] as int?,
      volumePct: map['volume_pct'] as int?,
      pcHandleCount: map['pc_handle_count'] as int?,
      pcThreadCount: map['pc_thread_count'] as int?,
      pcPageFaultsPerS: (map['pc_page_faults_per_s'] as num?)?.toDouble(),
      pcGpuDedicatedMemKb: map['pc_gpu_dedicated_mem_kb'] as int?,
      pcGpuSharedMemKb: map['pc_gpu_shared_mem_kb'] as int?,
      pcPerCoreCpuJson: map['pc_per_core_cpu_json'] as String?,
      pcThreadCpuJson: map['pc_thread_cpu_json'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'session_id': sessionId,
      'timestamp': timestamp,
      'fps': fps,
      'jank_count': jankCount,
      'jank_small_count': jankSmallCount,
      'jank_big_count': jankBigCount,
      'jank_ratio_count': jankRatioCount,
      'frametimes_json': frametimesJson,
      'cpu_system_pct': cpuSystemPct,
      'cpu_app_pct': cpuAppPct,
      'cpu_app_pct_freq_norm': cpuAppPctFreqNorm,
      'cpu_cores': cpuCores,
      'cpu_core_states_json': cpuCoreStatesJson,
      'cpu_core_freqs_json': cpuCoreFreqsJson,
      'cpu_threads_top_json': cpuThreadsTopJson,
      'memory_pss_kb': memoryPssKb,
      'memory_java_kb': memoryJavaKb,
      'memory_native_kb': memoryNativeKb,
      'memory_graphics_kb': memoryGraphicsKb,
      'memory_stack_kb': memoryStackKb,
      'memory_code_kb': memoryCodeKb,
      'memory_system_kb': memorySystemKb,
      'memory_webview_kb': memoryWebviewKb,
      'battery_pct': batteryPct,
      'battery_ma': batteryMa,
      'battery_mv': batteryMv,
      'battery_temp_c': batteryTempC,
      'charging': charging,
      'charging_source': chargingSource,
      'wifi_active': wifiActive,
      'net_tx_bytes': netTxBytes,
      'net_rx_bytes': netRxBytes,
      'net_wifi_tx_bytes': netWifiTxBytes,
      'net_wifi_rx_bytes': netWifiRxBytes,
      'net_cellular_tx_bytes': netCellularTxBytes,
      'net_cellular_rx_bytes': netCellularRxBytes,
      'net_other_tx_bytes': netOtherTxBytes,
      'net_other_rx_bytes': netOtherRxBytes,
      'thermal_status': thermalStatus,
      'gpu_pct': gpuPct,
      'gpu_freq_mhz': gpuFreqMhz,
      'gpu_mem_kb': gpuMemKb,
      'disk_read_kb': diskReadKb,
      'disk_write_kb': diskWriteKb,
      'screen_brightness': screenBrightness,
      'volume_pct': volumePct,
      'pc_handle_count': pcHandleCount,
      'pc_thread_count': pcThreadCount,
      'pc_page_faults_per_s': pcPageFaultsPerS,
      'pc_gpu_dedicated_mem_kb': pcGpuDedicatedMemKb,
      'pc_gpu_shared_mem_kb': pcGpuSharedMemKb,
      'pc_per_core_cpu_json': pcPerCoreCpuJson,
      'pc_thread_cpu_json': pcThreadCpuJson,
    };
    if (id != null) map['id'] = id;
    return map;
  }
}
