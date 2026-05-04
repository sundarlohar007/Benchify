---
phase: 02-v1-5-analysis-platform-expansion
plan: 02
type: execute
wave: 2
depends_on:
  - 01
files_modified:
  - performancebench/lib/core/analytics/detected_issues_service.dart
  - performancebench/lib/core/database/detected_issue_dao.dart
  - performancebench/lib/core/models/detected_issue.dart
  - performancebench/lib/core/database/session_dao.dart
  - performancebench/lib/core/models/session.dart
  - performancebench/lib/features/session_detail/scorecard_tab.dart
  - performancebench/lib/features/session_detail/detail_screen.dart
  - performancebench/lib/features/history/history_screen.dart
  - performancebench/lib/features/app_picker/app_picker_screen.dart
  - performancebench/test/core/analytics/detected_issues_service_test.dart
  - performancebench/test/core/database/collection_dao_test.dart
  - performancebench/test/core/database/session_search_test.dart
autonomous: true
requirements:
  - V15-03
  - V15-04
  - V15-05

must_haves:
  truths:
    - "Auto-detected issues appear in session detail after session completion — rule IDs, severity color-coded, messages shown"
    - "User can create a named collection and assign sessions to it during session start and post-hoc"
    - "User can filter session history by tag, device model, app package, and chipset"
    - "Search input filters sessions in real-time by title, app name, or package substring match"
  artifacts:
    - path: "performancebench/lib/core/analytics/detected_issues_service.dart"
      provides: "Post-session pass scanning session_stats/marker_stats and writing detected_issues per §6.9 rules"
      exports: ["DetectedIssuesService", "runAllRules method"]
      min_lines: 120
    - path: "performancebench/lib/core/database/session_dao.dart"
      provides: "Extended session queries with tag/project/device/chipset filtering and text search"
      contains: ["searchByFilter", "text_search", "tag_filter", "chipset_filter"]
    - path: "performancebench/lib/features/history/history_screen.dart"
      provides: "Enhanced history screen with filter bar, tag chips, search input, and project dropdown"
      contains: ["FilterBar", "TagChip", "SearchInput"]
  key_links:
    - from: "detected_issues_service.dart runAllRules()"
      to: "session_stats_dao getBySessionId()"
      via: "Reads session_stats for fps_median, variability_index, memory_growth etc."
      pattern: "sessionStatsDao\\.getBySessionId"
    - from: "detected_issues_service.dart"
      to: "detected_issue_dao.dart insert()"
      via: "Writes DetectedIssue rows to detected_issues table"
      pattern: "detectedIssueDao\\.insert"
    - from: "history_screen.dart search field"
      to: "session_dao.dart searchByFilter()"
      via: "Debounced text input → DAO query with LIKE clauses"
      pattern: "searchByFilter.*LIKE"
</objective>

<objective>
Analysis features: Auto-detected issues engine (§6.9), session collections with flat tags + project_id, and enhanced session search/filter.

Purpose: Gives users organizational tools (collections, full-text search, filter by device/chipset/tag) and a post-session issues scan that auto-flags problems. These features build on Wave 1 (schema v2 tables, region stats computation patterns).

Output: DetectedIssuesService, enhanced SessionDao with search/filter, updated history screen with filter bar, collection management on AppPicker and session detail.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/02-v1-5-analysis-platform-expansion/02-CONTEXT.md

### Spec references (MUST READ during execution)
@UNIFIED-SPEC.md §6.9 (Auto-Detected Issues — all 12 rules, schema, baseline lookup, acceptance criteria, lines 1439-1488)
@UNIFIED-SPEC.md §6.7 (Memory analytics — trend detection used by MEMORY_TRENDING_UP rule)
@UNIFIED-SPEC.md §9.6 (Session History Screen — filter bar, tag badges, table layout)

### Codebase context
@performancebench/lib/core/analytics/analytics_service.dart (computeSessionStats — reference for accessing session_stats)
@performancebench/lib/core/database/session_dao.dart (current queries — extend with search/filter methods)
@performancebench/lib/core/database/detected_issue_dao.dart (created in Wave 1 — use for inserting detected issues)
@performancebench/lib/core/database/collection_dao.dart (created in Wave 1 — use for CRUD)
@performancebench/lib/features/history/history_screen.dart (current history table — add filter bar, search, tag display)
@performancebench/lib/features/session_detail/detail_screen.dart (add Issues tab)
</context>

<tasks>

<task type="tdd" tdd="true">
  <name>Task 1: Auto-detected issues engine (V15-03)</name>
  <files>
    performancebench/lib/core/analytics/detected_issues_service.dart
    performancebench/lib/core/database/detected_issue_dao.dart
    performancebench/lib/core/models/detected_issue.dart
    performancebench/lib/features/session_detail/detail_screen.dart
    performancebench/lib/features/session_detail/issues_tab.dart
    performancebench/test/core/analytics/detected_issues_service_test.dart
  </files>

  <read_first>
  - Read `UNIFIED-SPEC.md` lines 1439-1488 (§6.9 — full Auto-Detected Issues spec: 12 rules, severity levels, schema, baseline lookup, acceptance criteria)
  - Read `UNIFIED-SPEC.md` lines 1402-1414 (§6.7 Memory Trend Detection — slope > 100 KB/min for MEMORY_TRENDING_UP rule)
  - Read `UNIFIED-SPEC.md` lines 1477-1478 (baseline lookup: mean of last 5 sessions for same app_id + device_id combo)
  - Read `performancebench/lib/core/analytics/analytics_service.dart` (computeSessionStats — reference for accessing session_stats fields)
  - Read `performancebench/lib/core/database/session_stats_dao.dart` (getBySessionId query)
  - Read `performancebench/lib/core/database/session_dao.dart` (getByAppDevice combo for baseline lookup)
  - Read `performancebench/lib/core/database/detected_issue_dao.dart` (created in Wave 1 — insert pattern)
  - Read `performancebench/lib/features/session_detail/detail_screen.dart` (add 7th tab: Issues)
  </read_first>

  <behavior>
    Auto-detected issues test expectations (detected_issues_service_test.dart):
    Test 1: Session with fps_median = 25, target_fps = 60 → LOW_FPS rule fires with severity 'high'
    Test 2: Session with fps_median = 55, target_fps = 60 → LOW_FPS does NOT fire (threshold is < 30, not <-15 from target)
    Test 3: Session with variability_index = 12 → HIGH_VARIABILITY rule fires, severity 'medium'
    Test 4: Session with memGrowthKb = 150000 (150MB) over 5 min → MEMORY_TRENDING_UP fires (slope must be > 100 KB/min)
    Test 5: Session with cpuAvgPct = 85, cpuAvgPctFreqNorm = 82 → HIGH_CPU fires (uses post-norm-to-freq value)
    Test 6: Session with cpuAvgPctFreqNorm = 75 → HIGH_CPU does NOT fire
    Test 7: Session with batteryDrainPerHour = 35 → BATTERY_DRAIN_HIGH fires, severity 'medium'
    Test 8: Session with thermalPeak = 1 (LIGHT) → THERMAL_THROTTLING fires, severity 'high'
    Test 9: Session with bigJankTotal = 300, durationMs = 60000 (1 minute) → jank rate = 5/min → BIG_JANK_SPIKE fires (threshold >5)
    Test 10: Session with fpsStability = 55 → LOW_STABILITY fires, severity 'medium'
    Test 11: Session with netCellularRxKb > 51200 (50MB) during cellular session → CELLULAR_HEAVY_USE fires, severity 'informational'
    Test 12: Empty session (no samples) → ZERO rules fire (no false positives)
    Test 13: FPS_REGRESSION — 5 prior baseline sessions averaging fps_median=60, current fps_median=48 (20% drop) → fires
    Test 14: FPS_REGRESSION — < 3 prior sessions → rule skipped (insufficient baseline)
    Test 15: LAUNCH_TIME_INCREASE — baseline launch 4000ms, current 5000ms (>20% increase) → fires
    Test 16: MEMORY_LEAK_SUSPECTED — slope 600 KB/min, session ≥ 10min → fires with severity 'critical'
  </behavior>

  <action>
  **Create `performancebench/lib/core/analytics/detected_issues_service.dart`:**

  ```dart
  class DetectedIssueRule {
    final String ruleId;
    final String Function(SessionStats stats, {double? baselineFpsMedian, int? baselineLaunchMs, bool isCellularSession, int bigJankTotal, int durationMs})? checker;
    // checker returns null if rule doesn't fire, a message string if it does
    final String severity;       // 'informational' | 'medium' | 'high' | 'critical'
    final String? metric;        // optional metric field name
    final double? threshold;
  }

  class DetectedIssuesService {
    final SessionStatsDao _sessionStatsDao;
    final SessionDao _sessionDao;
    final DetectedIssueDao _detectedIssueDao;

    /// Run all 12 detection rules after session completion.
    /// Writes flagged issues to detected_issues table.
    Future<List<DetectedIssue>> runAllRules({
      required String sessionId,
      required String appPackage,
      required String deviceId,
      bool? featureFlagEnabled,  // per D-03 note: feature flag default-off
    }) async {
      if (featureFlagEnabled != true) return [];  // Feature flag guard

      final stats = await _sessionStatsDao.getBySessionId(sessionId);
      if (stats == null) return [];

      final issues = <DetectedIssue>[];

      // Rule: LOW_FPS
      if ((stats.fpsMedian ?? 0) < 30) {
        issues.add(_issue(sessionId, 'LOW_FPS', 'high', 'fps_median',
          stats.fpsMedian ?? 0, 30, 'FPS median ${stats.fpsMedian?.toStringAsFixed(1)} below 30 threshold'));
      }

      // Rule: FPS_REGRESSION (needs >= 3 baseline sessions)
      final baselineFps = await _getBaselineFps(appPackage, deviceId);
      if (baselineFps != null && (stats.fpsMedian ?? 0) > 0) {
        final drop = (baselineFps - (stats.fpsMedian ?? 0)) / baselineFps;
        if (drop > 0.15) {
          issues.add(_issue(sessionId, 'FPS_REGRESSION', 'high', 'fps_median',
            stats.fpsMedian ?? 0, baselineFps * 0.85,
            'FPS dropped ${(drop * 100).toStringAsFixed(0)}% from baseline ${baselineFps.toStringAsFixed(1)}'));
        }
      }

      // Rule: HIGH_VARIABILITY
      if ((stats.variabilityIndex ?? 0) > 10) {
        issues.add(_issue(sessionId, 'HIGH_VARIABILITY', 'medium', 'variability_index',
          stats.variabilityIndex ?? 0, 10, 'Variability index ${stats.variabilityIndex?.toStringAsFixed(1)} exceeds 10'));
      }

      // Rule: MEMORY_TRENDING_UP (slope > 100 KB/min AND session >= 5 min)
      if ((stats.memTrendSlopeKbPerMin ?? 0) > 100 && (stats.durationMs ?? 0) >= 300000) {
        issues.add(_issue(sessionId, 'MEMORY_TRENDING_UP', 'high', 'mem_trend_slope_kb_per_min',
          stats.memTrendSlopeKbPerMin ?? 0, 100, 'Memory trending up at ${stats.memTrendSlopeKbPerMin?.toStringAsFixed(0)} KB/min'));
      }

      // Rule: MEMORY_LEAK_SUSPECTED (slope > 500 KB/min AND session >= 10 min)
      if ((stats.memTrendSlopeKbPerMin ?? 0) > 500 && (stats.durationMs ?? 0) >= 600000) {
        issues.add(_issue(sessionId, 'MEMORY_LEAK_SUSPECTED', 'critical', 'mem_trend_slope_kb_per_min',
          stats.memTrendSlopeKbPerMin ?? 0, 500, 'Possible memory leak: ${stats.memTrendSlopeKbPerMin?.toStringAsFixed(0)} KB/min over ${((stats.durationMs ?? 0) / 60000).toStringAsFixed(0)} min'));
      }

      // Rule: HIGH_CPU (post-norm-to-freq > 80)
      if ((stats.cpuAvgPctFreqNorm ?? 0) > 80) {
        issues.add(_issue(sessionId, 'HIGH_CPU', 'medium', 'cpu_avg_pct_freq_norm',
          stats.cpuAvgPctFreqNorm ?? 0, 80, 'CPU avg (freq-norm) at ${stats.cpuAvgPctFreqNorm?.toStringAsFixed(1)}%'));
      }

      // Rule: THERMAL_THROTTLING (thermalPeak >= 1 = LIGHT throttling)
      if ((stats.thermalPeak ?? 0) >= 1) {
        issues.add(_issue(sessionId, 'THERMAL_THROTTLING', 'high', 'thermal_peak',
          (stats.thermalPeak ?? 0).toDouble(), 0, 'Thermal throttling detected (peak severity ${stats.thermalPeak})'));
      }

      // Rule: LAUNCH_TIME_INCREASE (vs baseline)
      final baselineLaunch = await _getBaselineLaunchMs(appPackage, deviceId);
      if (baselineLaunch != null && (stats.launchCompleteMs ?? 0) > 0) {
        final increase = ((stats.launchCompleteMs ?? 0) - baselineLaunch) / baselineLaunch;
        if (increase > 0.20) {
          issues.add(_issue(sessionId, 'LAUNCH_TIME_INCREASE', 'medium', 'launch_complete_ms',
            (stats.launchCompleteMs ?? 0).toDouble(), baselineLaunch * 1.20,
            'Launch time ${stats.launchCompleteMs}ms increased ${(increase * 100).toStringAsFixed(0)}% from baseline ${baselineLaunch}ms'));
        }
      }

      // Rule: BATTERY_DRAIN_HIGH (> 30%/hr)
      if ((stats.batteryDrainPerHour ?? 0) > 30) {
        issues.add(_issue(sessionId, 'BATTERY_DRAIN_HIGH', 'medium', 'battery_drain_per_hour',
          stats.batteryDrainPerHour ?? 0, 30, 'Battery drain ${stats.batteryDrainPerHour?.toStringAsFixed(1)}%/hr'));
      }

      // Rule: BIG_JANK_SPIKE (> 5 big janks/min)
      final durMinutes = (stats.durationMs ?? 1) / 60000.0;
      final bigJankPerMin = (stats.jankBigTotal ?? 0) / durMinutes;
      if (bigJankPerMin > 5) {
        issues.add(_issue(sessionId, 'BIG_JANK_SPIKE', 'high', 'jank_big_total',
          bigJankPerMin, 5, '${bigJankPerMin.toStringAsFixed(1)} big janks/min'));
      }

      // Rule: LOW_STABILITY (< 60%)
      if ((stats.fpsStability ?? 100) < 60) {
        issues.add(_issue(sessionId, 'LOW_STABILITY', 'medium', 'fps_stability',
          stats.fpsStability ?? 0, 60, 'FPS stability ${stats.fpsStability?.toStringAsFixed(0)}%'));
      }

      // Rule: CELLULAR_HEAVY_USE (cellular session + > 50MB)
      // Determined from wifiActive values in samples; simplified: check cellular totals
      final cellularTotalKb = (stats.netCellularTotalRxKb ?? 0) + (stats.netCellularTotalTxKb ?? 0);
      if (cellularTotalKb > 51200) {
        issues.add(_issue(sessionId, 'CELLULAR_HEAVY_USE', 'informational', 'net_cellular_total',
          cellularTotalKb, 51200, '${(cellularTotalKb / 1024).toStringAsFixed(0)} MB over cellular'));
      }

      // Batch insert all detected issues
      for (final issue in issues) {
        await _detectedIssueDao.insert(issue);
      }
      return issues;
    }

    DetectedIssue _issue(String sessionId, String ruleId, String severity, String? metric, double observed, double threshold, String message) {
      return DetectedIssue(
        sessionId: sessionId,
        ruleId: ruleId,
        severity: severity,
        metric: metric,
        observedValue: observed,
        thresholdValue: threshold,
        message: message,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    }

    /// Baseline = mean of last 5 sessions for same app_id + device_id combo.
    /// Returns null if < 3 prior sessions exist (skip regression rules).
    Future<double?> _getBaselineFps(String appPackage, String deviceId) async {
      final sessions = await _sessionDao.getRecentSessionsByAppDevice(appPackage, deviceId, limit: 5);
      if (sessions.length < 3) return null;
      final statsList = <SessionStats>[];
      for (final s in sessions) {
        final st = await _sessionStatsDao.getBySessionId(s.id);
        if (st != null && st.fpsMedian != null) statsList.add(st);
      }
      if (statsList.length < 3) return null;
      return statsList.map((s) => s.fpsMedian!).reduce((a, b) => a + b) / statsList.length;
    }

    Future<int?> _getBaselineLaunchMs(String appPackage, String deviceId) async {
      final sessions = await _sessionDao.getRecentSessionsByAppDevice(appPackage, deviceId, limit: 5);
      if (sessions.length < 3) return null;
      final launchTimes = <int>[];
      for (final s in sessions) {
        final st = await _sessionStatsDao.getBySessionId(s.id);
        if (st != null && st.launchCompleteMs != null) launchTimes.add(st.launchCompleteMs!);
      }
      if (launchTimes.length < 3) return null;
      return (launchTimes.reduce((a, b) => a + b) / launchTimes.length).round();
    }
  }
  ```

  **Wire into session stop flow:**
  In the session stop handler (where `AnalyticsService.computeSessionStats()` is called), add:
  ```dart
  await _detectedIssuesService.runAllRules(
    sessionId: sessionId,
    appPackage: session.appPackage,
    deviceId: session.deviceId,
    featureFlagEnabled: true, // Read from SDK state / SharedPreferences
  );
  ```

  **Add Issues tab to SessionDetailScreen** (`detail_screen.dart`):
  - Change `DefaultTabController(length: 6)` → `length: 7`
  - Add `Tab(text: 'Issues')` to tab list (after Regions, before Screenshots if desired)
  - Add `IssuesTab(sessionId: sessionId)` to TabBarView children

  **Create `issues_tab.dart`:**
  ```dart
  class IssuesTab extends StatefulWidget {
    final String sessionId;
    // Load DetectedIssues from DetectedIssueDao, display in DataTable:
    // Columns: Rule ID | Severity (color-coded pill) | Metric | Observed | Threshold | Message
    // severity pill colors: informational=blue, medium=yellow/orange, high=red, critical=dark red
    // Empty state: "No issues detected" with green checkmark icon
  }
  ```

  **Create test** (`performancebench/test/core/analytics/detected_issues_service_test.dart`):
  - Test all 16 behavior cases above
  - Mock DAOs to return controlled SessionStats values
  - Verify correct ruleIds fire (or don't fire) per threshold

  After tests pass, commit: `docs(02-02): add auto-detected issues engine (12 rules)`
  </action>

  <verify>
    <automated>cd D:/OpenCode/Benchify && dart test test/core/analytics/detected_issues_service_test.dart</automated>
  </verify>

  <done>
  - All 12 detection rules implemented per §6.9 with correct thresholds
  - Detected issues written to detected_issues table on session stop
  - Issues tab in session detail shows color-coded severity pills and messages
  - Feature flag guards entire system (default-off, user opts in per D-03 context note)
  - 16 test cases pass covering all rules, thresholds, and edge cases
  </done>
</task>

<task type="tdd" tdd="true">
  <name>Task 2: Session collections + search + filter (V15-04, V15-05)</name>
  <files>
    performancebench/lib/core/database/session_dao.dart
    performancebench/lib/core/database/collection_dao.dart
    performancebench/lib/core/models/collection.dart
    performancebench/lib/features/history/history_screen.dart
    performancebench/lib/features/app_picker/app_picker_screen.dart
    performancebench/lib/features/session_detail/detail_screen.dart
    performancebench/test/core/database/session_search_test.dart
  </files>

  <read_first>
  - Read `performancebench/lib/core/database/session_dao.dart` (current queries — extend with search/filter)
  - Read `performancebench/lib/core/models/metric_sample.dart` and `session.dart` (check if collection_id and project_id fields exist on sessions table)
  - Read `performancebench/lib/features/history/history_screen.dart` (current layout — add filter bar, search, tag chips)
  - Read `performancebench/lib/features/app_picker/app_picker_screen.dart` (add collection/project dropdown per D-13)
  - Read `performancebench/lib/core/database/collection_dao.dart` (created in Wave 1 — use for CRUD)
  - Read `UNIFIED-SPEC.md` lines 2151-2179 (§9.6 Session History Screen spec — filter bar, tag badges, sort columns)
  </read_first>

  <behavior>
    Session search/filter test expectations (session_search_test.dart):
    Test 1: searchSessions("example") returns sessions where app_package contains "example" OR app_name contains "example" OR title contains "example"
    Test 2: searchSessions with empty string returns all sessions
    Test 3: filterByTag("release") returns sessions where tags field contains "release" (JSON or comma-separated)
    Test 4: filterByDevice("Pixel 8 Pro") returns sessions where device name matches
    Test 5: filterByChipset("snapdragon") returns sessions where device chipset field matches via JOIN
    Test 6: filterByProject("proj-123") returns sessions where project_id = "proj-123"
    Test 7: Combined filter: tag="release" + device="Pixel" + app="com.example" returns intersection
    Test 8: Collections: insert Collection, assign session to it via session_dao.updateCollection(), verify getByCollectionId returns correct sessions
    Test 9: Collection CRUD: insert, getById, update name, delete
  </behavior>

  <action>
  **Part A — Enhanced SessionDao queries (V15-05):**

  Add to `performancebench/lib/core/database/session_dao.dart`:

  ```dart
  /// Search sessions by text (app_package, app_name, title).
  Future<List<Session>> searchSessions(String query) async {
    if (query.trim().isEmpty) return getAll();
    final pattern = '%$query%';
    final rows = await _db.rawQuery('''
      SELECT s.*, d.name as device_name, d.model as device_model, d.chipset as device_chipset
      FROM sessions s
      JOIN devices d ON s.device_id = d.id
      WHERE s.app_package LIKE ? OR s.app_name LIKE ? OR s.title LIKE ?
      ORDER BY s.started_at DESC
    ''', [pattern, pattern, pattern]);
    return rows.map(_sessionFromRow).toList();
  }

  /// Filter sessions by tag, device, app, chipset, project — all optional.
  Future<List<Session>> filterSessions({
    String? tag,
    String? deviceModel,
    String? appPackage,
    String? chipset,
    String? projectId,
    String? collectionId,
    int limit = 100,
  }) async {
    final conditions = <String>[];
    final params = <dynamic>[];

    if (tag != null && tag.isNotEmpty) {
      conditions.add('(s.tags LIKE ? OR s.tags_kv_json LIKE ? OR EXISTS (SELECT 1 FROM session_tags st WHERE st.session_id = s.id AND st.tag = ?))');
      params.addAll(['%$tag%', '%$tag%', tag]);
    }
    if (deviceModel != null && deviceModel.isNotEmpty) {
      conditions.add('(d.model LIKE ? OR d.name LIKE ?)');
      params.addAll(['%$deviceModel%', '%$deviceModel%']);
    }
    if (appPackage != null && appPackage.isNotEmpty) {
      conditions.add('s.app_package LIKE ?');
      params.add('%$appPackage%');
    }
    if (chipset != null && chipset.isNotEmpty) {
      conditions.add('d.chipset LIKE ?');
      params.add('%$chipset%');
    }
    if (projectId != null && projectId.isNotEmpty) {
      conditions.add('s.project_id = ?');
      params.add(projectId);
    }
    if (collectionId != null && collectionId.isNotEmpty) {
      conditions.add('s.collection_id = ?');
      params.add(collectionId);
    }

    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final rows = await _db.rawQuery('''
      SELECT s.*, d.name as device_name, d.model as device_model,
             d.chipset as device_chipset, d.manufacturer as device_manufacturer
      FROM sessions s
      JOIN devices d ON s.device_id = d.id
      $where
      ORDER BY s.started_at DESC
      LIMIT ?
    ''', [...params, limit]);
    return rows.map(_sessionFromRow).toList();
  }

  /// Assign session to a collection (post-hoc per D-13).
  Future<int> setCollection(String sessionId, String collectionId) async {
    return _db.update('sessions', {'collection_id': collectionId},
      where: 'id = ?', whereArgs: [sessionId]);
  }

  /// Assign project to a session.
  Future<int> setProject(String sessionId, String projectId) async {
    return _db.update('sessions', {'project_id': projectId},
      where: 'id = ?', whereArgs: [sessionId]);
  }

  /// Update tags on a session (post-hoc per D-13).
  Future<int> setTags(String sessionId, String tags) async {
    return _db.update('sessions', {'tags': tags},
      where: 'id = ?', whereArgs: [sessionId]);
  }

  /// Get recent sessions for same app + device (for baseline computation).
  Future<List<Session>> getRecentSessionsByAppDevice(String appPackage, String deviceId, {int limit = 5}) async {
    final rows = await _db.query('sessions',
      where: 'app_package = ? AND device_id = ?',
      whereArgs: [appPackage, deviceId],
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(_sessionFromRow).toList();
  }
  ```

  **Part B — Collection CRUD in CollectionDao (V15-04):**

  Extend `performancebench/lib/core/database/collection_dao.dart` (created in Wave 1):
  ```dart
  class CollectionDao {
    final Database _db;
    CollectionDao(this._db);

    Future<void> insert(Collection c) async { await _db.insert('collections', c.toMap()); }
    Future<List<Collection>> getAll() async {
      final rows = await _db.query('collections', orderBy: 'created_at DESC');
      return rows.map(Collection.fromMap).toList();
    }
    Future<Collection?> getById(String id) async {
      final rows = await _db.query('collections', where: 'id = ?', whereArgs: [id], limit: 1);
      return rows.isEmpty ? null : Collection.fromMap(rows.first);
    }
    Future<int> update(Collection c) async {
      return _db.update('collections', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    }
    Future<int> delete(String id) async {
      return _db.delete('collections', where: 'id = ?', whereArgs: [id]);
    }
    Future<List<Session>> getSessionsByCollection(String collectionId) async {
      // Query sessions joined on collection_id
    }
  }
  ```

  **Part C — Enhanced History Screen UI (V15-05):**

  Update `performancebench/lib/features/history/history_screen.dart`:

  Add filter bar above the session table:
  ```dart
  // Filter bar state
  String _searchQuery = '';
  String? _filterTag;
  String? _filterDevice;
  String? _filterApp;
  String? _filterChipset;
  String? _filterCollection;

  // Filter bar UI (below AppBar title area):
  Row(
    children: [
      // Search input (debounced, 300ms)
      Expanded(
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Filter sessions...',
            prefixIcon: Icon(Icons.search, size: 16),
          ),
          onChanged: (v) => _debounceSearch(v),
        ),
      ),
      // Tag filter dropdown (populated from all unique tags)
      DropdownButton<String?>(hint: Text('Tag'), ...),
      // Platform filter (Android / iOS)
      DropdownButton<String?>(hint: Text('Platform'), ...),
      // Device filter dropdown
      DropdownButton<String?>(hint: Text('Device'), ...),
      // App filter dropdown
      DropdownButton<String?>(hint: Text('App'), ...),
      // Chipset filter dropdown
      DropdownButton<String?>(hint: Text('Chipset'), ...),
    ],
  ),
  // Active filter chips (dismissible):
  if (_filterTag != null) Chip(label: Text('Tag: $_filterTag'), onDeleted: () => setState(() => _filterTag = null)),

  // Session count display
  Text('${_sessions.length} sessions', style: ...),
  ```

  Session table row additions:
  - Show collection name badge next to app name
  - Show tag badges as small rounded pills (per §9.6 spec: "small rounded pill, bg.input background, text.secondary text")
  - FPS value colored by quality per spec

  **Part D — Collection/project assignment on AppPicker (V15-04, D-13):**

  Update `performancebench/lib/features/app_picker/app_picker_screen.dart`:

  Add two dropdowns below the app list, before the "Start Session" button:
  ```dart
  // Collection dropdown (existing collections, or "None")
  DropdownButton<String?>(
    value: _selectedCollectionId,
    hint: Text('Collection (optional)'),
    items: [DropdownMenuItem(value: null, child: Text('None')),
      ...collections.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))],
    onChanged: (v) => setState(() => _selectedCollectionId = v),
  ),

  // Project tag input (free-text)
  TextField(
    decoration: InputDecoration(hintText: 'Project tag (optional, e.g., v1.4.2)'),
    onChanged: (v) => _projectId = v,
  ),

  // Tags input (comma-separated per D-12: flat tags)
  TextField(
    decoration: InputDecoration(hintText: 'Tags (comma-separated, e.g., release, boss-fight)'),
    onChanged: (v) => _tags = v,
  ),
  ```

  Pass `collection_id`, `project_id`, and `tags` to the session creation flow so they're stored in the sessions table.

  **Part E — Post-hoc editing in SessionDetail (D-13):**

  In `detail_screen.dart` header area, add editable fields:
  - Tags: Editable chips with + button to add, x to remove
  - Collection: Dropdown to reassign
  - Project: Editable text field
  - Save button (calls `sessionDao.setTags()`, `sessionDao.setCollection()`, `sessionDao.setProject()`)

  **Create test** (`performancebench/test/core/database/session_search_test.dart`):
  - Test all 9 behavior cases
  - Use in-memory SQLite with sample sessions and devices data
  - Verify search/filter returns correct intersections

  After tests pass, commit: `docs(02-02): add session collections, search, and multi-filter`
  </action>

  <verify>
    <automated>cd D:/OpenCode/Benchify && dart test test/core/database/session_search_test.dart</automated>
  </verify>

  <done>
  - Session history supports text search across app_package, app_name, title
  - History filter bar works for tag, device model, app package, chipset, collection
  - Collections CRUD works (create, list, assign, reassign)
  - Tags and collection can be assigned during session start AND edited post-hoc
  - 9 search/filter test cases pass
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| User search input → SQL query | Free-text search crosses into parameterized SQL |
| User tags input → Database | Tag strings stored in sessions.tags field |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-06 | Injection | session_dao.dart searchSessions() | mitigate | Use parameterized `LIKE ?` queries with `%$query%` pattern — never string interpolation into SQL |
| T-02-07 | Information Disclosure | detected_issues_service.dart baseline lookup | accept | Baseline lookup reads local session_stats only — no data leaves host; all local DB reads |
| T-02-08 | Spoofing | history_screen.dart filter inputs | mitigate | Filter values passed as parameters to prepared statements; dropdown values bound to known collections/devices |
| T-02-09 | Denial of Service | detected_issues_service.dart runAllRules() | mitigate | Rules run post-session only (not during profiling); batch insert with explicit commit; limit baseline queries to 5 sessions |
</threat_model>

<verification>
1. Run detected issues test: `cd D:/OpenCode/Benchify && dart test test/core/analytics/detected_issues_service_test.dart`
2. Run session search/filter test: `cd D:/OpenCode/Benchify && dart test test/core/database/session_search_test.dart`
3. Run full test suite: `cd D:/OpenCode/Benchify && dart test`
4. Verify: `cd D:/OpenCode/Benchify && dart analyze` shows 0 errors
</verification>

<success_criteria>
1. Session with fps_median < 30 → LOW_FPS issue auto-detected and stored in detected_issues table
2. Session details screen shows Issues tab with color-coded severity pills and rule messages
3. User can create a collection, assign sessions to it during start and edit post-hoc
4. History screen filter bar supports search, tag, device, app, chipset, and collection filters with correct intersection logic
5. All 25+ new tests pass, 0 analyzer errors
</success_criteria>

<output>
After completion, create `.planning/phases/02-v1-5-analysis-platform-expansion/02-02-SUMMARY.md`
</output>
