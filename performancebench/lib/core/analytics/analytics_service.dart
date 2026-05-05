// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:math' as math;

import '../database/marker_dao.dart';
import '../database/marker_stats_dao.dart';
import '../database/metric_dao.dart';
import '../database/region_stats_dao.dart';
import '../database/session_stats_dao.dart';
import '../models/marker_stats.dart';
import '../models/metric_sample.dart';
import '../models/region_stats.dart';
import '../models/session_stats.dart';
import 'fps_analytics.dart';

/// Post-session analytics engine per UNIFIED-SPEC §6.
///
/// Computes session-level stats (FPS, CPU, memory, battery/power, jank,
/// network, thermal, GPU) and per-marker stats from saved metric_samples.
class AnalyticsService {
  final MetricDao _metricDao;
  final SessionStatsDao _sessionStatsDao;
  final MarkerDao _markerDao;
  final MarkerStatsDao _markerStatsDao;
  final RegionStatsDao _regionStatsDao;

  AnalyticsService({
    required MetricDao metricDao,
    required SessionStatsDao sessionStatsDao,
    required MarkerDao markerDao,
    required MarkerStatsDao markerStatsDao,
    required RegionStatsDao regionStatsDao,
  })  : _metricDao = metricDao,
        _sessionStatsDao = sessionStatsDao,
        _markerDao = markerDao,
        _markerStatsDao = markerStatsDao,
        _regionStatsDao = regionStatsDao;

  /// Compute and upsert session-level statistics.
  Future<SessionStats> computeSessionStats(String sessionId) async {
    final samples = await _metricDao.getBySessionId(sessionId);
    if (samples.isEmpty) {
      final emptyStats = SessionStats(sessionId: sessionId, durationMs: 0);
      await _sessionStatsDao.upsert(emptyStats);
      return emptyStats;
    }

    // Duration
    final firstTs = samples.first.timestamp;
    final lastTs = samples.last.timestamp;
    final durationMs = lastTs - firstTs;

    // FPS
    final fpsValues = samples.map((s) => s.fps).whereType<double>().toList();
    final fpsStats = FpsAnalytics.compute(fpsValues);

    // CPU
    final cpuValues = samples.map((s) => s.cpuAppPct).whereType<double>().toList();
    final cpuAvg = cpuValues.isEmpty ? null : cpuValues.reduce((a, b) => a + b) / cpuValues.length;
    final cpuPeak = cpuValues.isEmpty ? null : cpuValues.reduce(math.max);
    final cpuFreqNormValues = samples.map((s) => s.cpuAppPctFreqNorm).whereType<double>().toList();
    final cpuAvgFreqNorm = cpuFreqNormValues.isEmpty
        ? null
        : cpuFreqNormValues.reduce((a, b) => a + b) / cpuFreqNormValues.length;
    final cpuPeakFreqNorm = cpuFreqNormValues.isEmpty ? null : cpuFreqNormValues.reduce(math.max);

    // Memory
    final memValues = samples.map((s) => s.memoryPssKb).whereType<int>().toList();
    final memAvg = memValues.isEmpty ? null : (memValues.reduce((a, b) => a + b) / memValues.length).round();
    final memPeak = memValues.isEmpty ? null : memValues.reduce(math.max);
    final memGrowth = memValues.isNotEmpty && memValues.length > 1
        ? memValues.last - memValues.first
        : null;

    // Memory subsections
    int? avgOrNull(List<int?> vals) {
      final nonNull = vals.whereType<int>().toList();
      return nonNull.isEmpty ? null : (nonNull.reduce((a, b) => a + b) / nonNull.length).round();
    }
    int? peakOrNull(List<int?> vals) {
      final nonNull = vals.whereType<int>().toList();
      return nonNull.isEmpty ? null : nonNull.reduce(math.max);
    }

    // Memory trend slope (linear regression on PSS vs time, KB/min)
    double? memTrend;
    if (memValues.length >= 2) {
      final n = memValues.length;
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for (var i = 0; i < n; i++) {
        final x = (samples[i].timestamp - firstTs) / 1000.0; // seconds
        final y = memValues[i].toDouble();
        sumX += x;
        sumY += y;
        sumXY += x * y;
        sumX2 += x * x;
      }
      final denom = n * sumX2 - sumX * sumX;
      if (denom != 0) {
        final slopeKbPerSec = (n * sumXY - sumX * sumY) / denom;
        memTrend = slopeKbPerSec * 60; // KB/min
      }
    }

    // GPU
    final gpuValues = samples.map((s) => s.gpuPct).whereType<double>().toList();
    final gpuAvg = gpuValues.isEmpty ? null : gpuValues.reduce((a, b) => a + b) / gpuValues.length;
    final gpuPeak = gpuValues.isEmpty ? null : gpuValues.reduce(math.max);

    // Battery / Power (§6.6)
    final nonCharging = samples.where((s) => s.charging != 1).toList();
    final hasCharging = samples.any((s) => s.charging == 1);

    double? batteryDrainPct;
    double? batteryDrainPerHour;
    double? batteryTempMax;
    double? mahConsumed;
    double? avgPowerMw;
    double? totalPowerMwh;
    double? estimatedPlaytimeH;

    final batPctValues = nonCharging.map((s) => s.batteryPct).whereType<int>().toList();
    if (batPctValues.isNotEmpty) {
      batteryDrainPct = (batPctValues.first - batPctValues.last).toDouble().clamp(0, 100).toDouble();
      final hours = durationMs / (1000.0 * 3600.0);
      batteryDrainPerHour = hours > 0 ? batteryDrainPct! / hours : 0;
    }

    final tempValues = samples.map((s) => s.batteryTempC).whereType<double>().toList();
    batteryTempMax = tempValues.isEmpty ? null : tempValues.reduce(math.max);

    // Trapezoidal integration for mAh and mWh
    if (nonCharging.length >= 2) {
      double mahSum = 0;
      double mwhSum = 0;
      for (var i = 1; i < nonCharging.length; i++) {
        final dt = (nonCharging[i].timestamp - nonCharging[i - 1].timestamp) / 1000.0; // seconds
        final mA1 = (nonCharging[i - 1].batteryMa ?? 0).abs();
        final mA2 = (nonCharging[i].batteryMa ?? 0).abs();
        final mV1 = (nonCharging[i - 1].batteryMv ?? 0);
        final mV2 = (nonCharging[i].batteryMv ?? 0);

        mahSum += (mA1 + mA2) / 2 * dt / 3600.0;
        mwhSum += (mA1 * mV1 + mA2 * mV2) / 2 * dt / 3600.0 / 1000.0;
      }
      mahConsumed = mahSum;
      totalPowerMwh = mwhSum;

      // Average power
      final totalDt = (nonCharging.last.timestamp - nonCharging.first.timestamp) / 1000.0;
      avgPowerMw = totalDt > 0 ? mwhSum * 1000.0 / (totalDt / 3600.0) : 0;

      // Estimated playtime
      final avgMa = mahSum > 0 && totalDt > 0
          ? mahSum / (totalDt / 3600.0) * 1000.0
          : 0.0;
      // Assume typical 4000 mAh battery
      estimatedPlaytimeH = avgMa > 0 ? 4000.0 / avgMa : null;
    }

    // Jank
    final jankTotal = _sumIntField(samples, (s) => s.jankCount);
    final jankSmallTotal = _sumIntField(samples, (s) => s.jankSmallCount);
    final jankBigTotal = _sumIntField(samples, (s) => s.jankBigCount);
    final jankRatioTotal = _sumIntField(samples, (s) => s.jankRatioCount);
    final durationMinutes = durationMs / (1000.0 * 60.0);
    final jankPerMin = durationMinutes > 0 ? (jankTotal ?? 0) / durationMinutes : null;

    // Network (§6.8)
    double? netDelta(int? Function(MetricSample) getter) {
      final vals = samples.map(getter).whereType<int>().toList();
      if (vals.length < 2) return null;
      return (vals.last - vals.first).toDouble() / 1024.0;
    }
    final netTx = netDelta((s) => s.netTxBytes);
    final netRx = netDelta((s) => s.netRxBytes);
    final netWifiTx = netDelta((s) => s.netWifiTxBytes);
    final netWifiRx = netDelta((s) => s.netWifiRxBytes);
    final netCellularTx = netDelta((s) => s.netCellularTxBytes);
    final netCellularRx = netDelta((s) => s.netCellularRxBytes);
    final netOtherTx = netDelta((s) => s.netOtherTxBytes);
    final netOtherRx = netDelta((s) => s.netOtherRxBytes);

    final durationSec = durationMs / 1000.0;
    final netWifiAvgKbps = durationSec > 0 ? ((netWifiTx ?? 0) + (netWifiRx ?? 0)) / durationSec : null;
    final netCellularAvgKbps = durationSec > 0 ? ((netCellularTx ?? 0) + (netCellularRx ?? 0)) / durationSec : null;

    // Thermal
    final thermalValues = samples.map((s) => s.thermalStatus).whereType<int>().toList();
    final thermalPeak = thermalValues.isEmpty ? null : thermalValues.reduce(math.max);

    // Launch complete
    final launchMarker = await _markerDao.getLaunchComplete(sessionId);
    final launchCompleteMs = launchMarker != null ? launchMarker.startedAt - firstTs : null;

    final stats = SessionStats(
      sessionId: sessionId,
      fpsMedian: fpsStats.median,
      fpsMin: fpsStats.min,
      fpsMax: fpsStats.max,
      fps1pctLow: fpsStats.onePercentLow,
      fpsStability: fpsStats.stabilityPct,
      frameTimeP95: fpsStats.p95FrameTimeMs,
      fpsHistogram: fpsStats.histogramJson,
      variabilityIndex: fpsStats.variabilityIndex,
      frameRatioJankTotal: jankRatioTotal,
      cpuAvgPct: cpuAvg,
      cpuPeakPct: cpuPeak,
      cpuAvgPctFreqNorm: cpuAvgFreqNorm,
      cpuPeakPctFreqNorm: cpuPeakFreqNorm,
      memoryAvgKb: memAvg,
      memoryPeakKb: memPeak,
      memJavaAvgKb: avgOrNull(samples.map((s) => s.memoryJavaKb).toList()),
      memJavaPeakKb: peakOrNull(samples.map((s) => s.memoryJavaKb).toList()),
      memNativeAvgKb: avgOrNull(samples.map((s) => s.memoryNativeKb).toList()),
      memNativePeakKb: peakOrNull(samples.map((s) => s.memoryNativeKb).toList()),
      memGraphicsAvgKb: avgOrNull(samples.map((s) => s.memoryGraphicsKb).toList()),
      memGraphicsPeakKb: peakOrNull(samples.map((s) => s.memoryGraphicsKb).toList()),
      memStackAvgKb: avgOrNull(samples.map((s) => s.memoryStackKb).toList()),
      memCodeAvgKb: avgOrNull(samples.map((s) => s.memoryCodeKb).toList()),
      memSystemAvgKb: avgOrNull(samples.map((s) => s.memorySystemKb).toList()),
      memWebviewAvgKb: avgOrNull(samples.map((s) => s.memoryWebviewKb).toList()),
      memGrowthKb: memGrowth,
      memTrendSlopeKbPerMin: memTrend,
      gpuAvgPct: gpuAvg,
      gpuPeakPct: gpuPeak,
      batteryDrainPct: batteryDrainPct,
      batteryDrainPerHour: batteryDrainPerHour,
      batteryTempMaxC: batteryTempMax,
      mahConsumed: mahConsumed,
      avgPowerMw: avgPowerMw,
      totalPowerMwh: totalPowerMwh,
      estimatedPlaytimeH: estimatedPlaytimeH,
      hasChargingPeriod: hasCharging ? 1 : 0,
      jankTotal: jankTotal,
      jankSmallTotal: jankSmallTotal,
      jankBigTotal: jankBigTotal,
      jankRatioTotal: jankRatioTotal,
      jankPerMin: jankPerMin,
      netTotalTxKb: netTx,
      netTotalRxKb: netRx,
      netWifiTotalTxKb: netWifiTx,
      netWifiTotalRxKb: netWifiRx,
      netCellularTotalTxKb: netCellularTx,
      netCellularTotalRxKb: netCellularRx,
      netOtherTotalTxKb: netOtherTx,
      netOtherTotalRxKb: netOtherRx,
      netWifiAvgKbps: netWifiAvgKbps,
      netCellularAvgKbps: netCellularAvgKbps,
      thermalPeak: thermalPeak,
      launchCompleteMs: launchCompleteMs,
      durationMs: durationMs,
    );

    await _sessionStatsDao.upsert(stats);
    return stats;
  }

  /// Compute per-marker statistics for all ended range markers in the session.
  Future<void> computeMarkerStats(String sessionId) async {
    final markers = await _markerDao.getBySessionId(sessionId);
    final rangeMarkers = markers.where((m) => m.endedAt != null);

    for (final marker in rangeMarkers) {
      final samples = await _metricDao.getBySessionIdAndTimestampRange(
        sessionId,
        startMs: marker.startedAt,
        endMs: marker.endedAt!,
      );

      if (samples.isEmpty) continue;

      final firstTs = samples.first.timestamp;
      final lastTs = samples.last.timestamp;
      final durationMs = lastTs - firstTs;

      final fpsValues = samples.map((s) => s.fps).whereType<double>().toList();
      final fpsStats = FpsAnalytics.compute(fpsValues);

      final cpuValues = samples.map((s) => s.cpuAppPct).whereType<double>().toList();
      final cpuAvg = cpuValues.isEmpty ? null : cpuValues.reduce((a, b) => a + b) / cpuValues.length;

      final memValues = samples.map((s) => s.memoryPssKb).whereType<int>().toList();
      final memPeak = memValues.isEmpty ? null : memValues.reduce(math.max);

      final gpuValues = samples.map((s) => s.gpuPct).whereType<double>().toList();
      final gpuAvg = gpuValues.isEmpty ? null : gpuValues.reduce((a, b) => a + b) / gpuValues.length;

      // Battery drain over marker range
      final batPctValues = samples.map((s) => s.batteryPct).whereType<int>().toList();
      final batDrain = batPctValues.length >= 2
          ? (batPctValues.first - batPctValues.last).toDouble().clamp(0, 100).toDouble()
          : null;

      // mAh over marker range
      double? markerMah;
      final nonCharging = samples.where((s) => s.charging != 1).toList();
      if (nonCharging.length >= 2) {
        double mahSum = 0;
        for (var i = 1; i < nonCharging.length; i++) {
          final dt = (nonCharging[i].timestamp - nonCharging[i - 1].timestamp) / 1000.0;
          final mA1 = (nonCharging[i - 1].batteryMa ?? 0).abs();
          final mA2 = (nonCharging[i].batteryMa ?? 0).abs();
          mahSum += (mA1 + mA2) / 2 * dt / 3600.0;
        }
        markerMah = mahSum;
      }

      final jankTotal = _sumIntField(samples, (s) => s.jankCount);
      final jankSmallTotal = _sumIntField(samples, (s) => s.jankSmallCount);
      final jankBigTotal = _sumIntField(samples, (s) => s.jankBigCount);
      final jankRatioTotal = _sumIntField(samples, (s) => s.jankRatioCount);
      final durMin = durationMs / (1000.0 * 60.0);
      final jankPerMin = durMin > 0 ? (jankTotal ?? 0) / durMin : null;

      final cpuFreqVals = samples.map((s) => s.cpuAppPctFreqNorm).whereType<double>().toList();
      final cpuFreqAvg = cpuFreqVals.isEmpty ? null : cpuFreqVals.reduce((a, b) => a + b) / cpuFreqVals.length;

      final gfxPeakVals = samples.map((s) => s.memoryGraphicsKb).whereType<int>().toList();
      final gfxPeak = gfxPeakVals.isEmpty ? null : gfxPeakVals.reduce(math.max);

      final stats = MarkerStats(
        markerId: marker.id!,
        sessionId: sessionId,
        durationMs: durationMs,
        fpsMedian: fpsStats.median,
        fpsMin: fpsStats.min,
        fpsMax: fpsStats.max,
        fps1pctLow: fpsStats.onePercentLow,
        fpsStability: fpsStats.stabilityPct,
        frameTimeP95: fpsStats.p95FrameTimeMs,
        variabilityIndex: fpsStats.variabilityIndex,
        cpuAvgPct: cpuAvg,
        cpuAvgPctFreqNorm: cpuFreqAvg,
        memoryPeakKb: memPeak,
        memGraphicsPeakKb: gfxPeak,
        gpuAvgPct: gpuAvg,
        batteryDrainPct: batDrain,
        mahConsumed: markerMah,
        jankTotal: jankTotal,
        jankSmallTotal: jankSmallTotal,
        jankBigTotal: jankBigTotal,
        jankRatioTotal: jankRatioTotal,
        jankPerMin: jankPerMin,
      );

      await _markerStatsDao.insert(stats);
    }
  }

  /// Compute statistics for an arbitrary time region (drag-selected area).
  /// Uses the same computation as computeMarkerStats for consistency.
  /// Returns a RegionStats model with all computed fields.
  Future<RegionStats> computeRegionStats(
    String sessionId,
    int startMs,
    int endMs, {
    String? label,
    String? color,
  }) async {
    final samples = await _metricDao.getBySessionIdAndTimestampRange(
      sessionId,
      startMs: startMs,
      endMs: endMs,
    );

    if (samples.isEmpty) {
      final empty = RegionStats(
        sessionId: sessionId,
        label: label ?? '',
        startMs: startMs,
        endMs: endMs,
        durationMs: 0,
      );
      return empty;
    }

    final firstTs = samples.first.timestamp;
    final lastTs = samples.last.timestamp;
    final durationMs = lastTs - firstTs;

    // FPS — same computation as computeMarkerStats
    final fpsValues = samples.map((s) => s.fps).whereType<double>().toList();
    final fpsStats = FpsAnalytics.compute(fpsValues);

    // CPU — mean of cpuAppPct
    final cpuValues = samples.map((s) => s.cpuAppPct).whereType<double>().toList();
    final cpuAvg = cpuValues.isEmpty ? null : cpuValues.reduce((a, b) => a + b) / cpuValues.length;
    final cpuFreqValues = samples.map((s) => s.cpuAppPctFreqNorm).whereType<double>().toList();
    final cpuAvgFreqNorm = cpuFreqValues.isEmpty ? null : cpuFreqValues.reduce((a, b) => a + b) / cpuFreqValues.length;

    // Memory — peak of memoryPssKb
    final memValues = samples.map((s) => s.memoryPssKb).whereType<int>().toList();
    final memPeak = memValues.isEmpty ? null : memValues.reduce((a, b) => a > b ? a : b);
    final gfxPeakValues = samples.map((s) => s.memoryGraphicsKb).whereType<int>().toList();
    final gfxPeak = gfxPeakValues.isEmpty ? null : gfxPeakValues.reduce((a, b) => a > b ? a : b);

    // GPU — mean of gpuPct
    final gpuValues = samples.map((s) => s.gpuPct).whereType<double>().toList();
    final gpuAvg = gpuValues.isEmpty ? null : gpuValues.reduce((a, b) => a + b) / gpuValues.length;

    // Battery drain over region
    final batPctValues = samples.map((s) => s.batteryPct).whereType<int>().toList();
    final batDrain = batPctValues.length >= 2
        ? (batPctValues.first - batPctValues.last).toDouble().clamp(0, 100).toDouble()
        : null;

    // mAh over region (trapezoidal integration)
    double? regionMah;
    final nonCharging = samples.where((s) => s.charging != 1).toList();
    if (nonCharging.length >= 2) {
      double mahSum = 0;
      for (var i = 1; i < nonCharging.length; i++) {
        final dt = (nonCharging[i].timestamp - nonCharging[i - 1].timestamp) / 1000.0;
        final mA1 = (nonCharging[i - 1].batteryMa ?? 0).abs();
        final mA2 = (nonCharging[i].batteryMa ?? 0).abs();
        mahSum += (mA1 + mA2) / 2 * dt / 3600.0;
      }
      regionMah = mahSum;
    }

    // Jank
    final jankTotal = _sumIntField(samples, (s) => s.jankCount);
    final jankSmallTotal = _sumIntField(samples, (s) => s.jankSmallCount);
    final jankBigTotal = _sumIntField(samples, (s) => s.jankBigCount);
    final jankRatioTotal = _sumIntField(samples, (s) => s.jankRatioCount);
    final durMin = durationMs / (1000.0 * 60.0);
    final jankPerMin = durMin > 0 ? (jankTotal ?? 0) / durMin : null;

    final stats = RegionStats(
      sessionId: sessionId,
      label: label ?? 'Region',
      startMs: startMs,
      endMs: endMs,
      color: color,
      durationMs: durationMs,
      fpsMedian: fpsStats.median,
      fpsMin: fpsStats.min,
      fpsMax: fpsStats.max,
      fps1pctLow: fpsStats.onePercentLow,
      fpsStability: fpsStats.stabilityPct,
      frameTimeP95: fpsStats.p95FrameTimeMs,
      variabilityIndex: fpsStats.variabilityIndex,
      cpuAvgPct: cpuAvg,
      cpuAvgPctFreqNorm: cpuAvgFreqNorm,
      memoryPeakKb: memPeak,
      memGraphicsPeakKb: gfxPeak,
      gpuAvgPct: gpuAvg,
      batteryDrainPct: batDrain,
      mahConsumed: regionMah,
      jankTotal: jankTotal,
      jankSmallTotal: jankSmallTotal,
      jankBigTotal: jankBigTotal,
      jankRatioTotal: jankRatioTotal,
      jankPerMin: jankPerMin,
    );

    await _regionStatsDao.insert(stats);
    return stats;
  }

  /// Sum a nullable int field across all samples.
  int? _sumIntField(List<MetricSample> samples, int? Function(MetricSample) getter) {
    var hasAny = false;
    var sum = 0;
    for (final s in samples) {
      final v = getter(s);
      if (v != null) {
        sum += v;
        hasAny = true;
      }
    }
    return hasAny ? sum : null;
  }
}
