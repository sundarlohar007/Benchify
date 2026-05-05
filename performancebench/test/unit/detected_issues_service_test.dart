// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter_test/flutter_test.dart';

import 'package:performancebench/core/analytics/detected_issues_service.dart';
import 'package:performancebench/core/models/detected_issue.dart';
import 'package:performancebench/core/models/session.dart';
import 'package:performancebench/core/models/session_stats.dart';

/// Minimal fake DAOs for testing DetectedIssuesService.
/// Returns controlled values so each rule can be tested in isolation.

class _FakeSessionStatsDao {
  final Map<String, SessionStats> _store = {};

  void put(SessionStats stats) => _store[stats.sessionId] = stats;
  Future<SessionStats?> getBySessionId(String id) async => _store[id];
}

class _FakeSessionDao {
  final List<Session> _sessions = [];

  void add(Session s) => _sessions.add(s);

  Future<List<Session>> getRecentSessionsByAppDevice(
    String appPackage,
    String deviceId, {
    int limit = 5,
  }) async {
    final filtered = _sessions
        .where((s) => s.appPackage == appPackage && s.deviceId == deviceId)
        .toList();
    filtered.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return filtered.take(limit).toList();
  }
}

class _FakeDetectedIssueDao {
  final List<DetectedIssue> inserted = [];

  Future<int> insert(DetectedIssue issue) async {
    inserted.add(issue);
    return inserted.length;
  }

  Future<void> batchInsert(List<DetectedIssue> issues) async {
    inserted.addAll(issues);
  }
}

/// Helper to build a SessionStats with defaults (all absent).
SessionStats _stats({
  required String sessionId,
  double? fpsMedian,
  int? targetFps,
  double? variabilityIndex,
  double? memTrendSlopeKbPerMin,
  int? durationMs,
  double? cpuAvgPctFreqNorm,
  int? thermalPeak,
  int? launchCompleteMs,
  double? batteryDrainPerHour,
  int? jankBigTotal,
  double? fpsStability,
  double? netCellularTotalRxKb,
  double? netCellularTotalTxKb,
}) {
  return SessionStats(
    sessionId: sessionId,
    fpsMedian: fpsMedian,
    variabilityIndex: variabilityIndex,
    memTrendSlopeKbPerMin: memTrendSlopeKbPerMin,
    durationMs: durationMs ?? 0,
    cpuAvgPctFreqNorm: cpuAvgPctFreqNorm,
    thermalPeak: thermalPeak,
    launchCompleteMs: launchCompleteMs,
    batteryDrainPerHour: batteryDrainPerHour,
    jankBigTotal: jankBigTotal,
    fpsStability: fpsStability,
    netCellularTotalRxKb: netCellularTotalRxKb,
    netCellularTotalTxKb: netCellularTotalTxKb,
  );
}

/// Helper to build a Session for baseline queries.
Session _session({
  required String id,
  required String appPackage,
  required String deviceId,
  int startedAt = 0,
}) {
  return Session(
    id: id,
    deviceId: deviceId,
    platform: 'android',
    appPackage: appPackage,
    startedAt: startedAt,
  );
}

void main() {
  group('DetectedIssuesService', () {
    late _FakeSessionStatsDao statsDao;
    late _FakeSessionDao sessionDao;
    late _FakeDetectedIssueDao issueDao;
    late DetectedIssuesService service;

    setUp(() {
      statsDao = _FakeSessionStatsDao();
      sessionDao = _FakeSessionDao();
      issueDao = _FakeDetectedIssueDao();
      service = DetectedIssuesService(
        sessionStatsDao: statsDao,
        sessionDao: sessionDao,
        detectedIssueDao: issueDao,
      );
    });

    // ──── LOW_FPS tests ────

    test('LOW_FPS fires when fps_median = 25 (below 30 threshold)', () async {
      statsDao.put(_stats(sessionId: 's1', fpsMedian: 25));

      final issues = await service.runAllRules(
        sessionId: 's1',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'LOW_FPS' && i.severity == 'high'), isTrue);
    });

    test('LOW_FPS does NOT fire when fps_median = 55 (above threshold)', () async {
      statsDao.put(_stats(sessionId: 's2', fpsMedian: 55));

      final issues = await service.runAllRules(
        sessionId: 's2',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'LOW_FPS'), isFalse);
    });

    // ──── HIGH_VARIABILITY tests ────

    test('HIGH_VARIABILITY fires when variability_index = 12 (above 10)', () async {
      statsDao.put(_stats(sessionId: 's3', variabilityIndex: 12));

      final issues = await service.runAllRules(
        sessionId: 's3',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'HIGH_VARIABILITY' && i.severity == 'medium'), isTrue);
    });

    // ──── MEMORY_TRENDING_UP tests ────

    test('MEMORY_TRENDING_UP fires when slope > 100 KB/min and duration >= 5 min', () async {
      statsDao.put(_stats(
        sessionId: 's4',
        memTrendSlopeKbPerMin: 150,
        durationMs: 300000, // 5 min
      ));

      final issues = await service.runAllRules(
        sessionId: 's4',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'MEMORY_TRENDING_UP'), isTrue);
    });

    // ──── MEMORY_TRENDING_UP: short session should not fire ────

    test('MEMORY_TRENDING_UP does NOT fire when session < 5 min even with slope > 100', () async {
      statsDao.put(_stats(
        sessionId: 's4b',
        memTrendSlopeKbPerMin: 200,
        durationMs: 200000, // < 5 min
      ));

      final issues = await service.runAllRules(
        sessionId: 's4b',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'MEMORY_TRENDING_UP'), isFalse);
    });

    // ──── HIGH_CPU tests ────

    test('HIGH_CPU fires when cpu_avg_pct_freq_norm = 85 (above 80)', () async {
      statsDao.put(_stats(sessionId: 's5', cpuAvgPctFreqNorm: 85));

      final issues = await service.runAllRules(
        sessionId: 's5',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'HIGH_CPU'), isTrue);
    });

    test('HIGH_CPU does NOT fire when cpu_avg_pct_freq_norm = 75 (below 80)', () async {
      statsDao.put(_stats(sessionId: 's6', cpuAvgPctFreqNorm: 75));

      final issues = await service.runAllRules(
        sessionId: 's6',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'HIGH_CPU'), isFalse);
    });

    // ──── BATTERY_DRAIN_HIGH tests ────

    test('BATTERY_DRAIN_HIGH fires when drain > 30 %/hr', () async {
      statsDao.put(_stats(sessionId: 's7', batteryDrainPerHour: 35));

      final issues = await service.runAllRules(
        sessionId: 's7',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'BATTERY_DRAIN_HIGH' && i.severity == 'medium'), isTrue);
    });

    // ──── THERMAL_THROTTLING tests ────

    test('THERMAL_THROTTLING fires when thermal_peak >= 1 (LIGHT throttling)', () async {
      statsDao.put(_stats(sessionId: 's8', thermalPeak: 1));

      final issues = await service.runAllRules(
        sessionId: 's8',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'THERMAL_THROTTLING' && i.severity == 'high'), isTrue);
    });

    // ──── BIG_JANK_SPIKE tests ────

    test('BIG_JANK_SPIKE fires when > 5 big janks/min', () async {
      statsDao.put(_stats(
        sessionId: 's9',
        jankBigTotal: 300,
        durationMs: 60000, // 1 minute
      ));

      final issues = await service.runAllRules(
        sessionId: 's9',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'BIG_JANK_SPIKE'), isTrue);
    });

    // ──── BIG_JANK_SPIKE: low jank rate ────

    test('BIG_JANK_SPIKE does NOT fire when <= 5 big janks/min', () async {
      statsDao.put(_stats(
        sessionId: 's9b',
        jankBigTotal: 5,
        durationMs: 60000, // 1 minute
      ));

      final issues = await service.runAllRules(
        sessionId: 's9b',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'BIG_JANK_SPIKE'), isFalse);
    });

    // ──── LOW_STABILITY test ────

    test('LOW_STABILITY fires when fps_stability = 55 (< 60)', () async {
      statsDao.put(_stats(sessionId: 's10', fpsStability: 55));

      final issues = await service.runAllRules(
        sessionId: 's10',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'LOW_STABILITY' && i.severity == 'medium'), isTrue);
    });

    // ──── CELLULAR_HEAVY_USE test ────

    test('CELLULAR_HEAVY_USE fires when cellular total > 50 MB', () async {
      statsDao.put(_stats(
        sessionId: 's11',
        netCellularTotalRxKb: 51201, // > 50 MB
        netCellularTotalTxKb: 0,
      ));

      final issues = await service.runAllRules(
        sessionId: 's11',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'CELLULAR_HEAVY_USE' && i.severity == 'informational'),
          isTrue);
    });

    // ──── Empty session (no false positives) ────

    test('Empty session stats → ZERO rules fire (no false positives)', () async {
      statsDao.put(_stats(sessionId: 's12')); // all defaults

      final issues = await service.runAllRules(
        sessionId: 's12',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.isEmpty, isTrue);
    });

    // ──── FPS_REGRESSION tests ────

    test('FPS_REGRESSION fires when current fps 20% below 5-session baseline', () async {
      // Setup: 5 baseline sessions averaging fps_median=60
      for (var i = 1; i <= 5; i++) {
        sessionDao.add(_session(id: 'base$i', appPackage: 'com.test', deviceId: 'd1', startedAt: i));
        statsDao.put(_stats(sessionId: 'base$i', fpsMedian: 60));
      }
      // Current session: fps_median=48 (20% drop from 60)
      statsDao.put(_stats(sessionId: 's13', fpsMedian: 48));

      final issues = await service.runAllRules(
        sessionId: 's13',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'FPS_REGRESSION' && i.severity == 'high'), isTrue);
    });

    // ──── FPS_REGRESSION: insufficient baseline ────

    test('FPS_REGRESSION skipped when < 3 prior sessions', () async {
      // Only 2 baseline sessions
      sessionDao.add(_session(id: 'base1', appPackage: 'com.test', deviceId: 'd1', startedAt: 1));
      statsDao.put(_stats(sessionId: 'base1', fpsMedian: 60));
      sessionDao.add(_session(id: 'base2', appPackage: 'com.test', deviceId: 'd1', startedAt: 2));
      statsDao.put(_stats(sessionId: 'base2', fpsMedian: 60));

      statsDao.put(_stats(sessionId: 's14', fpsMedian: 48));

      final issues = await service.runAllRules(
        sessionId: 's14',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'FPS_REGRESSION'), isFalse);
    });

    // ──── LAUNCH_TIME_INCREASE tests ────

    test('LAUNCH_TIME_INCREASE fires when > 20% increase from baseline', () async {
      for (var i = 1; i <= 5; i++) {
        sessionDao.add(_session(id: 'lt_base$i', appPackage: 'com.test', deviceId: 'd1', startedAt: i));
        statsDao.put(_stats(sessionId: 'lt_base$i', launchCompleteMs: 4000));
      }
      statsDao.put(_stats(sessionId: 's15', launchCompleteMs: 5000));

      final issues = await service.runAllRules(
        sessionId: 's15',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(
          issues.any((i) => i.ruleId == 'LAUNCH_TIME_INCREASE' && i.severity == 'medium'), isTrue);
    });

    test('LAUNCH_TIME_INCREASE does NOT fire when < 20% increase', () async {
      for (var i = 1; i <= 5; i++) {
        sessionDao.add(_session(id: 'lt_base$i', appPackage: 'com.test', deviceId: 'd1', startedAt: i));
        statsDao.put(_stats(sessionId: 'lt_base$i', launchCompleteMs: 4000));
      }
      statsDao.put(_stats(sessionId: 's15b', launchCompleteMs: 4500)); // 12.5% increase

      final issues = await service.runAllRules(
        sessionId: 's15b',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'LAUNCH_TIME_INCREASE'), isFalse);
    });

    // ──── MEMORY_LEAK_SUSPECTED tests ────

    test('MEMORY_LEAK_SUSPECTED fires when slope > 500 KB/min and session >= 10 min', () async {
      statsDao.put(_stats(
        sessionId: 's16',
        memTrendSlopeKbPerMin: 600,
        durationMs: 600000, // 10 min
      ));

      final issues = await service.runAllRules(
        sessionId: 's16',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(
          issues.any((i) => i.ruleId == 'MEMORY_LEAK_SUSPECTED' && i.severity == 'critical'), isTrue);
    });

    test('MEMORY_LEAK_SUSPECTED does NOT fire when slope > 500 but session < 10 min', () async {
      statsDao.put(_stats(
        sessionId: 's16b',
        memTrendSlopeKbPerMin: 600,
        durationMs: 300000, // 5 min
      ));

      final issues = await service.runAllRules(
        sessionId: 's16b',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.any((i) => i.ruleId == 'MEMORY_LEAK_SUSPECTED'), isFalse);
    });

    // ──── Feature flag off ────

    test('Feature flag disabled returns empty list', () async {
      statsDao.put(_stats(sessionId: 's1', fpsMedian: 25));

      final issues = await service.runAllRules(
        sessionId: 's1',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: false,
      );

      expect(issues.isEmpty, isTrue);
    });

    test('Feature flag default (null) returns empty list', () async {
      statsDao.put(_stats(sessionId: 's1', fpsMedian: 25));

      final issues = await service.runAllRules(
        sessionId: 's1',
        appPackage: 'com.test',
        deviceId: 'd1',
      );

      expect(issues.isEmpty, isTrue);
    });

    // ──── No stats found ────

    test('No session_stats found returns empty list', () async {
      final issues = await service.runAllRules(
        sessionId: 'nonexistent',
        appPackage: 'com.test',
        deviceId: 'd1',
        featureFlagEnabled: true,
      );

      expect(issues.isEmpty, isTrue);
    });
  });
}
