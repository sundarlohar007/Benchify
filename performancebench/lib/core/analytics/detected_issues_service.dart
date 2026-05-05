// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import '../../core/database/session_stats_dao.dart';
import '../../core/database/session_dao.dart';
import '../../core/database/detected_issue_dao.dart';
import '../../core/models/detected_issue.dart';
import '../../core/models/session_stats.dart';

/// Post-session pass that scans session_stats and writes flagged issues to
/// the detected_issues table per UNIFIED-SPEC §6.9.
///
/// Implements all 12 detection rules with correct thresholds and severity
/// levels. Feature-flag guarded (default-off, user opts in per D-03).
class DetectedIssuesService {
  final SessionStatsDao _sessionStatsDao;
  final SessionDao _sessionDao;
  final DetectedIssueDao _detectedIssueDao;

  DetectedIssuesService({
    required dynamic sessionStatsDao,
    required dynamic sessionDao,
    required dynamic detectedIssueDao,
  })  : _sessionStatsDao = sessionStatsDao as SessionStatsDao,
        _sessionDao = sessionDao as SessionDao,
        _detectedIssueDao = detectedIssueDao as DetectedIssueDao;

  /// Run all 12 detection rules after session completion.
  /// Writes flagged issues to the detected_issues table.
  /// Returns the list of detected issues (empty if feature flag is off or no issues found).
  Future<List<DetectedIssue>> runAllRules({
    required String sessionId,
    required String appPackage,
    required String deviceId,
    bool? featureFlagEnabled,
  }) async {
    if (featureFlagEnabled != true) return [];

    final stats = await _sessionStatsDao.getBySessionId(sessionId);
    if (stats == null) return [];

    final issues = <DetectedIssue>[];
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // ── Rule 1: LOW_FPS — fps_median < 30 → severity high ──
    if ((stats.fpsMedian ?? 0) < 30) {
      issues.add(DetectedIssue(
        sessionId: sessionId,
        ruleId: 'LOW_FPS',
        severity: 'high',
        metric: 'fps_median',
        observedValue: stats.fpsMedian,
        thresholdValue: 30,
        message: 'FPS median ${stats.fpsMedian?.toStringAsFixed(1)} below 30 threshold',
        createdAt: nowMs,
      ));
    }

    // ── Rule 2: FPS_REGRESSION — >15% drop vs baseline (needs >= 3 baseline sessions) ──
    final baselineFps = await _getBaselineFps(appPackage, deviceId);
    if (baselineFps != null && (stats.fpsMedian ?? 0) > 0) {
      final drop = (baselineFps - (stats.fpsMedian ?? 0)) / baselineFps;
      if (drop > 0.15) {
        issues.add(DetectedIssue(
          sessionId: sessionId,
          ruleId: 'FPS_REGRESSION',
          severity: 'high',
          metric: 'fps_median',
          observedValue: stats.fpsMedian,
          thresholdValue: baselineFps * 0.85,
          message:
              'FPS dropped ${(drop * 100).toStringAsFixed(0)}% from baseline ${baselineFps.toStringAsFixed(1)}',
          createdAt: nowMs,
        ));
      }
    }

    // ── Rule 3: HIGH_VARIABILITY — variability_index > 10 → severity medium ──
    if ((stats.variabilityIndex ?? 0) > 10) {
      issues.add(DetectedIssue(
        sessionId: sessionId,
        ruleId: 'HIGH_VARIABILITY',
        severity: 'medium',
        metric: 'variability_index',
        observedValue: stats.variabilityIndex,
        thresholdValue: 10,
        message:
            'Variability index ${stats.variabilityIndex?.toStringAsFixed(1)} exceeds 10',
        createdAt: nowMs,
      ));
    }

    // ── Rule 4: MEMORY_TRENDING_UP — slope > 100 KB/min AND session >= 5 min → severity high ──
    if ((stats.memTrendSlopeKbPerMin ?? 0) > 100 && (stats.durationMs ?? 0) >= 300000) {
      issues.add(DetectedIssue(
        sessionId: sessionId,
        ruleId: 'MEMORY_TRENDING_UP',
        severity: 'high',
        metric: 'mem_trend_slope_kb_per_min',
        observedValue: stats.memTrendSlopeKbPerMin,
        thresholdValue: 100,
        message:
            'Memory trending up at ${stats.memTrendSlopeKbPerMin?.toStringAsFixed(0)} KB/min',
        createdAt: nowMs,
      ));
    }

    // ── Rule 5: MEMORY_LEAK_SUSPECTED — slope > 500 KB/min AND session >= 10 min → critical ──
    if ((stats.memTrendSlopeKbPerMin ?? 0) > 500 && (stats.durationMs ?? 0) >= 600000) {
      issues.add(DetectedIssue(
        sessionId: sessionId,
        ruleId: 'MEMORY_LEAK_SUSPECTED',
        severity: 'critical',
        metric: 'mem_trend_slope_kb_per_min',
        observedValue: stats.memTrendSlopeKbPerMin,
        thresholdValue: 500,
        message:
            'Possible memory leak: ${stats.memTrendSlopeKbPerMin?.toStringAsFixed(0)} KB/min over ${((stats.durationMs ?? 0) / 60000).toStringAsFixed(0)} min',
        createdAt: nowMs,
      ));
    }

    // ── Rule 6: HIGH_CPU — cpu_avg_pct_freq_norm > 80 → severity medium ──
    if ((stats.cpuAvgPctFreqNorm ?? 0) > 80) {
      issues.add(DetectedIssue(
        sessionId: sessionId,
        ruleId: 'HIGH_CPU',
        severity: 'medium',
        metric: 'cpu_avg_pct_freq_norm',
        observedValue: stats.cpuAvgPctFreqNorm,
        thresholdValue: 80,
        message:
            'CPU avg (freq-norm) at ${stats.cpuAvgPctFreqNorm?.toStringAsFixed(1)}%',
        createdAt: nowMs,
      ));
    }

    // ── Rule 7: THERMAL_THROTTLING — thermal_peak >= 1 (LIGHT) → severity high ──
    if ((stats.thermalPeak ?? 0) >= 1) {
      issues.add(DetectedIssue(
        sessionId: sessionId,
        ruleId: 'THERMAL_THROTTLING',
        severity: 'high',
        metric: 'thermal_peak',
        observedValue: (stats.thermalPeak ?? 0).toDouble(),
        thresholdValue: 0,
        message: 'Thermal throttling detected (peak severity ${stats.thermalPeak})',
        createdAt: nowMs,
      ));
    }

    // ── Rule 8: LAUNCH_TIME_INCREASE — >20% increase vs baseline → severity medium ──
    final baselineLaunch = await _getBaselineLaunchMs(appPackage, deviceId);
    if (baselineLaunch != null && (stats.launchCompleteMs ?? 0) > 0) {
      final increase = ((stats.launchCompleteMs ?? 0) - baselineLaunch) / baselineLaunch;
      if (increase > 0.20) {
        issues.add(DetectedIssue(
          sessionId: sessionId,
          ruleId: 'LAUNCH_TIME_INCREASE',
          severity: 'medium',
          metric: 'launch_complete_ms',
          observedValue: (stats.launchCompleteMs ?? 0).toDouble(),
          thresholdValue: baselineLaunch * 1.20,
          message:
              'Launch time ${stats.launchCompleteMs}ms increased ${(increase * 100).toStringAsFixed(0)}% from baseline ${baselineLaunch}ms',
          createdAt: nowMs,
        ));
      }
    }

    // ── Rule 9: BATTERY_DRAIN_HIGH — > 30%/hr → severity medium ──
    if ((stats.batteryDrainPerHour ?? 0) > 30) {
      issues.add(DetectedIssue(
        sessionId: sessionId,
        ruleId: 'BATTERY_DRAIN_HIGH',
        severity: 'medium',
        metric: 'battery_drain_per_hour',
        observedValue: stats.batteryDrainPerHour,
        thresholdValue: 30,
        message:
            'Battery drain ${stats.batteryDrainPerHour?.toStringAsFixed(1)}%/hr',
        createdAt: nowMs,
      ));
    }

    // ── Rule 10: BIG_JANK_SPIKE — > 5 big janks/min → severity high ──
    final durMinutes = (stats.durationMs ?? 1) / 60000.0;
    final bigJankPerMin = (stats.jankBigTotal ?? 0) / durMinutes;
    if (bigJankPerMin > 5) {
      issues.add(DetectedIssue(
        sessionId: sessionId,
        ruleId: 'BIG_JANK_SPIKE',
        severity: 'high',
        metric: 'jank_big_total',
        observedValue: bigJankPerMin,
        thresholdValue: 5,
        message: '${bigJankPerMin.toStringAsFixed(1)} big janks/min',
        createdAt: nowMs,
      ));
    }

    // ── Rule 11: LOW_STABILITY — fps_stability < 60% → severity medium ──
    if ((stats.fpsStability ?? 100) < 60) {
      issues.add(DetectedIssue(
        sessionId: sessionId,
        ruleId: 'LOW_STABILITY',
        severity: 'medium',
        metric: 'fps_stability',
        observedValue: stats.fpsStability,
        thresholdValue: 60,
        message:
            'FPS stability ${stats.fpsStability?.toStringAsFixed(0)}%',
        createdAt: nowMs,
      ));
    }

    // ── Rule 12: CELLULAR_HEAVY_USE — cellular session + > 50 MB → severity informational ──
    final cellularTotalKb =
        (stats.netCellularTotalRxKb ?? 0) + (stats.netCellularTotalTxKb ?? 0);
    if (cellularTotalKb > 51200) {
      issues.add(DetectedIssue(
        sessionId: sessionId,
        ruleId: 'CELLULAR_HEAVY_USE',
        severity: 'informational',
        metric: 'net_cellular_total',
        observedValue: cellularTotalKb,
        thresholdValue: 51200,
        message:
            '${(cellularTotalKb / 1024).toStringAsFixed(0)} MB over cellular',
        createdAt: nowMs,
      ));
    }

    // Batch insert all detected issues via transaction for atomicity
    if (issues.isNotEmpty) {
      await _detectedIssueDao.batchInsert(issues);
    }

    return issues;
  }

  /// Baseline = mean of last 5 sessions for same app_package + device_id combo.
  /// Returns null if < 3 prior sessions with valid stats exist (skip regression rules).
  Future<double?> _getBaselineFps(String appPackage, String deviceId) async {
    final sessions = await _sessionDao.getRecentSessionsByAppDevice(
      appPackage,
      deviceId,
      limit: 5,
    );
    if (sessions.length < 3) return null;

    final statsList = <SessionStats>[];
    for (final s in sessions) {
      final st = await _sessionStatsDao.getBySessionId(s.id);
      if (st != null && st.fpsMedian != null) {
        statsList.add(st);
      }
    }
    if (statsList.length < 3) return null;
    return statsList.map((s) => s.fpsMedian!).reduce((a, b) => a + b) / statsList.length;
  }

  Future<int?> _getBaselineLaunchMs(String appPackage, String deviceId) async {
    final sessions = await _sessionDao.getRecentSessionsByAppDevice(
      appPackage,
      deviceId,
      limit: 5,
    );
    if (sessions.length < 3) return null;

    final launchTimes = <int>[];
    for (final s in sessions) {
      final st = await _sessionStatsDao.getBySessionId(s.id);
      if (st != null && st.launchCompleteMs != null) {
        launchTimes.add(st.launchCompleteMs!);
      }
    }
    if (launchTimes.length < 3) return null;
    return (launchTimes.reduce((a, b) => a + b) / launchTimes.length).round();
  }
}
