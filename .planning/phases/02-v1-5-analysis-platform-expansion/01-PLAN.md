---
phase: 02-v1-5-analysis-platform-expansion
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - performancebench/lib/core/database/database.dart
  - performancebench/lib/core/database/detected_issue_dao.dart
  - performancebench/lib/core/database/collection_dao.dart
  - performancebench/lib/core/database/video_dao.dart
  - performancebench/lib/core/database/region_stats_dao.dart
  - performancebench/lib/core/models/collection.dart
  - performancebench/lib/core/models/detected_issue.dart
  - performancebench/lib/core/models/video.dart
  - performancebench/lib/core/models/region_stats.dart
  - performancebench/lib/shared/widgets/metric_chart.dart
  - performancebench/lib/core/analytics/analytics_service.dart
  - performancebench/lib/core/parsers/disk_io_parser.dart
  - performancebench/lib/core/collector/metric_collector.dart
  - performancebench/lib/features/session_detail/region_tab.dart
  - performancebench/lib/features/session_detail/detail_screen.dart
  - performancebench/lib/core/sdk/sdk_state.dart
  - performancebench/test/core/parsers/disk_io_parser_test.dart
  - performancebench/test/core/analytics/region_stats_test.dart
  - performancebench/test/core/database/migration_v2_test.dart
autonomous: true
requirements:
  - V15-01
  - V15-02
  - V15-13

must_haves:
  truths:
    - "User can drag-select a region on a session replay chart and see a blue overlay spanning the selected time range"
    - "Per-region stats appear in same format as per-marker stats (MarkerStats model fields)"
    - "Disk I/O chart (disk_read_kb / disk_write_kb) appears during live profiling on Android devices"
    - "Schema v2 tables (collections, detected_issues, videos) exist in SQLite database"
  artifacts:
    - path: "performancebench/lib/core/parsers/disk_io_parser.dart"
      provides: "Disk I/O parser per UNIFIED-SPEC §5.8 — reads /proc/diskstats, computes delta KB/s"
      exports: ["DiskIoParser class", "DiskIoResult with readKbPerSec, writeKbPerSec"]
      min_lines: 40
    - path: "performancebench/lib/core/database/database.dart"
      provides: "Schema migration v2 (onUpgrade from version 1 to 2)"
      contains: ["_migrateV2", "collections", "detected_issues", "videos", "region_stats"]
    - path: "performancebench/lib/shared/widgets/metric_chart.dart"
      provides: "Drag-region selection with blue overlay on replay charts"
      contains: ["onDragSelection", "GestureDetector.onHorizontalDragStart"]
  key_links:
    - from: "metric_chart.dart drag handler"
      to: "region_tab.dart RegionStatsDisplay"
      via: "onDragSelection callback emitting (startIndex, endIndex)"
      pattern: "onDragSelection.*startIndex.*endIndex"
    - from: "region_tab.dart"
      to: "analytics_service.dart computeRegionStats()"
      via: "Method call with MetricSample list"
      pattern: "computeRegionStats"
    - from: "disk_io_parser.dart"
      to: "metric_collector.dart _sampleTick()"
      via: "DiskIoParser.parse() called each tick, result assigned to MetricSample.diskReadKb/diskWriteKb"
      pattern: "diskIoParser\\.parse"
    - from: "database.dart _migrateV2()"
      to: "onUpgrade callback"
      via: "runMigrations() switch case 2"
      pattern: "case 2.*_migrateV2"
---

<objective>
Foundation for Phase 2: Schema migration to v2, drag-region selection on replay charts with per-region stats, and Disk I/O parser activation.

Purpose: All subsequent Phase 2 features depend on the v2 schema (collections, detected_issues, videos tables), the region stats computation pattern, and the disk_io parser integration into MetricCollector. Without these, Waves 2-5 cannot proceed.

Output: 4 new database tables, 4 new model classes, extended MetricChart widget, disk_io parser, region stats analytics method, region tab in session detail.
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
@UNIFIED-SPEC.md §5.8 (Disk I/O parser algorithm + acceptance criteria)
@UNIFIED-SPEC.md §8 + Appendix C (Schema DDL for collections, detected_issues, regions, videos tables — lines 3500-3660)
@UNIFIED-SPEC.md §9.7.2 (Charts Tab replay — drag-region interaction)
@UNIFIED-SPEC.md Appendix D (ADB diskstats command reference)

### Codebase context
@performancebench/lib/core/database/database.dart (current schema v1 — extend to v2)
@performancebench/lib/core/database/marker_stats_dao.dart (reference DAO pattern for new DAOs)
@performancebench/lib/core/models/marker_stats.dart (model pattern — RegionStats follows same structure)
@performancebench/lib/core/models/metric_sample.dart (disk_read_kb / disk_write_kb fields already exist in model — activate in collector)
@performancebench/lib/shared/widgets/metric_chart.dart (extend with drag-selection handler)
@performancebench/lib/core/analytics/analytics_service.dart (add computeRegionStats method — reuses same stat computation logic as computeMarkerStats)
@performancebench/lib/features/session_detail/detail_screen.dart (add 6th tab: Regions)
@performancebench/lib/features/session_detail/replay_charts_tab.dart (wire drag-selection to region stats)
</context>

<tasks>

<task type="tdd" tdd="true">
  <name>Task 1: Schema migration v2 — Database.onUpgrade to version 2</name>
  <files>
    performancebench/lib/core/database/database.dart
    performancebench/lib/core/models/collection.dart
    performancebench/lib/core/models/detected_issue.dart
    performancebench/lib/core/models/video.dart
    performancebench/lib/core/models/region_stats.dart
    performancebench/lib/core/database/detected_issue_dao.dart
    performancebench/lib/core/database/collection_dao.dart
    performancebench/lib/core/database/video_dao.dart
    performancebench/lib/core/database/region_stats_dao.dart
    performancebench/test/core/database/migration_v2_test.dart
  </files>

  <read_first>
  - Read `UNIFIED-SPEC.md` lines 3500-3660 for exact DDL of collections, detected_issues, videos tables and migration strategy
  - Read `UNIFIED-SPEC.md` lines 5768-5793 for videos table DDL including ALTER TABLE sessions ADD COLUMN has_video
  - Read `UNIFIED-SPEC.md` lines 1460-1475 for detected_issues DDL and indexes
  - Read `performancebench/lib/core/database/database.dart` (current v1 migration — target onUpgrade path)
  - Read `performancebench/lib/core/database/marker_stats_dao.dart` for DAO pattern reference
  - Read `performancebench/lib/core/models/marker_stats.dart` for model pattern reference
  </read_first>

  <behavior>
    Database migration v2 test expectations (migration_v2_test.dart):
    Test 1: Create temp in-memory DB at version 1, trigger upgrade to v2, verify 4 new tables exist (collections, detected_issues, videos, region_stats)
    Test 2: Verify collections table has columns: id TEXT PK, name TEXT NOT NULL, description TEXT, color TEXT, created_at INTEGER NOT NULL
    Test 3: Verify detected_issues table has columns: id INTEGER PK AUTOINCREMENT, session_id TEXT FK, rule_id TEXT NOT NULL, severity TEXT NOT NULL, metric TEXT, observed_value REAL, threshold_value REAL, message TEXT NOT NULL, created_at INTEGER NOT NULL
    Test 4: Verify videos table has columns per §32.8 DDL (session_id PK, filepath, codec, container, width_px, height_px, target_fps, actual_avg_fps, bitrate_kbps, duration_ms, file_size_bytes, chunks_json, gaps_json, has_audio, recording_overhead_estimate_pct, started_at, ended_at, created_at)
    Test 5: Verify sessions table has new `has_video INTEGER DEFAULT 0` column after migration
    Test 6: Verify indexes exist: idx_issues_session, idx_issues_severity, idx_videos_session
    Test 7: Insert a collection row, query it back, verify all fields round-trip
  </behavior>

  <action>
  **Step 1 — Create models** (reference: MarkerStats model pattern in `performancebench/lib/core/models/marker_stats.dart`):

  `performancebench/lib/core/models/collection.dart`:
  ```dart
  class Collection {
    final String id;        // UUID
    final String name;
    final String? description;
    final String? color;
    final int createdAt;    // Unix ms

    const Collection({required this.id, required this.name, this.description, this.color, this.createdAt = 0});
    factory Collection.fromMap(Map<String, dynamic> map) { /* standard fromMap */ }
    Map<String, dynamic> toMap() { /* standard toMap */ }
  }
  ```

  `performancebench/lib/core/models/detected_issue.dart`:
  ```dart
  class DetectedIssue {
    final int? id;
    final String sessionId;
    final String ruleId;           // e.g., 'LOW_FPS', 'MEMORY_TRENDING_UP'
    final String severity;         // 'informational' | 'medium' | 'high' | 'critical'
    final String? metric;          // e.g., 'fps_median', 'memory_pss_kb'
    final double? observedValue;
    final double? thresholdValue;
    final String message;
    final int createdAt;

    // constructor, fromMap, toMap — same DAO pattern
  }
  ```

  **Step 2 — Create DAOs** (reference: `performancebench/lib/core/database/marker_stats_dao.dart`):

  `performancebench/lib/core/database/collection_dao.dart` — CRUD for collections: insert(), getAll(), getById(String id), update(), delete()
  `performancebench/lib/core/database/detected_issue_dao.dart` — insert() batch, getBySessionId(), getByRuleId(), deleteBySessionId()
  `performancebench/lib/core/database/video_dao.dart` — insert(), getBySessionId(), update(), deleteBySessionId()
  `performancebench/lib/core/database/region_stats_dao.dart` — insert(), getBySessionId(), deleteBySessionId() (same structure as marker_stats_dao but keyed by region label + start/end timestamps)

  **Step 3 — Migration** (in `performancebench/lib/core/database/database.dart`):

  In `initDatabase()`:
  ```dart
  final db = await databaseFactory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 2,  // CHANGED from 1 to 2
      onCreate: (db, version) async {
        await runMigrations(db, fromVersion: 0, toVersion: version);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await runMigrations(db, fromVersion: oldVersion, toVersion: newVersion);
      },
    ),
  );
  ```

  In `runMigrations()`: Add `case 2:` calling `await _migrateV2(db);`

  In `_migrateV2()`: Execute EXACT DDL from UNIFIED-SPEC.md Appendix C:

  ```sql
  -- 1. collections table (v1.5)
  CREATE TABLE IF NOT EXISTS collections (
      id          TEXT    PRIMARY KEY,
      name        TEXT    NOT NULL,
      description TEXT,
      color       TEXT,
      created_at  INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
  );

  -- 2. detected_issues table (6.9)
  CREATE TABLE IF NOT EXISTS detected_issues (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id      TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
      rule_id         TEXT NOT NULL,
      severity        TEXT NOT NULL,
      metric          TEXT,
      observed_value  REAL,
      threshold_value REAL,
      message         TEXT NOT NULL,
      created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
  );
  CREATE INDEX IF NOT EXISTS idx_issues_session  ON detected_issues(session_id);
  CREATE INDEX IF NOT EXISTS idx_issues_severity ON detected_issues(severity);

  -- 3. videos table (32.8)
  CREATE TABLE IF NOT EXISTS videos (
      session_id          TEXT    PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,
      filepath            TEXT    NOT NULL,
      codec               TEXT    NOT NULL DEFAULT 'h264',
      container           TEXT    NOT NULL DEFAULT 'mp4',
      width_px            INTEGER NOT NULL,
      height_px           INTEGER NOT NULL,
      target_fps          INTEGER,
      actual_avg_fps      REAL,
      bitrate_kbps        INTEGER,
      duration_ms         INTEGER NOT NULL,
      file_size_bytes     INTEGER NOT NULL,
      chunks_json         TEXT,
      gaps_json           TEXT,
      has_audio           INTEGER DEFAULT 0,
      recording_overhead_estimate_pct REAL,
      started_at          INTEGER NOT NULL,
      ended_at            INTEGER NOT NULL,
      created_at          INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
  );

  -- 4. sessions table addition
  ALTER TABLE sessions ADD COLUMN has_video INTEGER DEFAULT 0;
  ```
  Use `db.execute()` with `IF NOT EXISTS` guards.

  **Step 4 — Test** (`performancebench/test/core/database/migration_v2_test.dart`):
  Create an in-memory sqflite_common_ffi DB at version 1, insert sample data, trigger upgrade, then verify all 4 new tables and columns exist.

  **Step 5 — Update services to receive new DAOs:**
  Wherever `AnalyticsService`, `SessionService`, or riverpod providers create DAOs, add `CollectionDao`, `DetectedIssueDao`, `VideoDao`, `RegionStatsDao` as constructor parameters (DI pattern).

  After tests pass, commit: `docs(02-01): schema migration v2 — collections, detected_issues, videos, region_stats tables`
  </action>

  <verify>
    <automated>cd D:/OpenCode/Benchify && dart test test/core/database/migration_v2_test.dart</automated>
  </verify>

  <done>
  - 4 new tables exist in database after upgrade from v1 to v2
  - 4 model classes with fromMap/toMap exist
  - 4 DAO classes with CRUD operations exist
  - migration_v2_test.dart passes all 7 behavior test cases
  </done>
</task>

<task type="tdd" tdd="true">
  <name>Task 2: Drag-region selection on MetricChart + per-region stats in AnalyticsService</name>
  <files>
    performancebench/lib/shared/widgets/metric_chart.dart
    performancebench/lib/core/analytics/analytics_service.dart
    performancebench/lib/core/models/region_stats.dart
    performancebench/lib/core/database/region_stats_dao.dart
    performancebench/lib/features/session_detail/region_tab.dart
    performancebench/lib/features/session_detail/detail_screen.dart
    performancebench/lib/features/session_detail/replay_charts_tab.dart
    performancebench/test/core/analytics/region_stats_test.dart
  </files>

  <read_first>
  - Read `performancebench/lib/shared/widgets/metric_chart.dart` (current GestureDetector double-tap handler — extend with drag)
  - Read `performancebench/lib/core/analytics/analytics_service.dart` (computeMarkerStats() method — region stats follow identical pattern)
  - Read `performancebench/lib/core/models/marker_stats.dart` and `performancebench/lib/core/models/metric_sample.dart`
  - Read `performancebench/lib/features/session_detail/detail_screen.dart` (current 5-tab layout — add 6th tab)
  - Read `performancebench/lib/features/session_detail/replay_charts_tab.dart` (current placeholder — wire region selection)
  </read_first>

  <behavior>
    Region stats test expectations (region_stats_test.dart):
    Test 1: Empty samples list → region stats returns null for all computed fields, 0 for durationMs
    Test 2: 10 FPS samples [60, 60, 60, 30, 30, 30, 60, 60, 60, 60] → fpsMedian = 60.0, fpsMin = 30.0, fpsMax = 60.0, durationMs matches timestamp range
    Test 3: Same 10 samples → CPU avg matches manual average of cpuAppPct values
    Test 4: Same 10 samples → Memory peak matches max memoryPssKb
    Test 5: Compute region stats for 100 samples and compare to marker stats computed for same range → all fields within 0.01 tolerance (identical computation path)
    Test 6: MetricChart onDragSelection callback fires with (startIndex: 10, endIndex: 50) when user drags from index 10 to 50
    Test 7: MetricChart shows blue overlay between startIndex and endIndex during drag — Container with Colors.blue.withOpacity(0.15) positioned between those x-coordinates
  </behavior>

  <action>
  **Part A — Extend MetricChart with drag-region selection (per D-01):**

  Add to `MetricChart` widget class these new properties:
  ```dart
  /// Called when user completes a drag-region selection on the chart.
  /// Returns (startIndex, endIndex) relative to spot array indices.
  final void Function(int startIndex, int endIndex)? onDragSelection;

  /// Whether drag-selection is active (replay mode only — live charts don't support it).
  final bool enableDragSelection;

  /// Currently selected region start/end indices (null = no selection active).
  final (int, int)? selectedRegion;
  ```

  In `_MetricChartState`, add:
  ```dart
  // Drag-selection state
  int? _dragStartIndex;
  int? _dragEndIndex;
  bool _isDraggingRegion = false;
  ```

  Wrap the chart in `GestureDetector`:
  ```dart
  GestureDetector(
    onHorizontalDragStart: widget.enableDragSelection ? _onDragStart : null,
    onHorizontalDragUpdate: widget.enableDragSelection ? _onDragUpdate : null,
    onHorizontalDragEnd: widget.enableDragSelection ? _onDragEnd : null,
    child: ClipRect(child: LineChart(...)),
  )
  ```

  `_onDragStart(DragStartDetails d)`: Convert local X position to chart X coordinate → nearest _spots index → set _dragStartIndex
  `_onDragUpdate(DragUpdateDetails d)`: Convert local X to nearest spot index → set _dragEndIndex → trigger `setState()` to redraw blue overlay
  `_onDragEnd(DragEndDetails d)`: Call `widget.onDragSelection?.call(start, end)` → reset _dragStartIndex/_dragEndIndex

  **Blue overlay rendering**: When _dragStartIndex and _dragEndIndex are non-null during drag, render a semi-transparent blue rectangle covering the x-range between those spot indices. Use a Positioned widget or draw on top of the chart using a Stack:
  ```dart
  if (_dragStartIndex != null && _dragEndIndex != null) {
    // Calculate pixel positions from spot indices
    // Render Container with color: AppColors.accentBlue.withOpacity(0.15)
    // with left-margin at startIndex X position, width covering to endIndex
  }
  ```

  **Part B — Add computeRegionStats() to AnalyticsService (per D-02):**

  Region stats format matches per-marker stats format EXACTLY (same fields, same computation). Add method:
  ```dart
  /// Compute statistics for an arbitrary time region (drag-selected area).
  /// Uses the same computation shared with computeMarkerStats for consistency.
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
      return RegionStats(sessionId: sessionId, label: label ?? '', startMs: startMs, endMs: endMs, durationMs: 0);
    }
    // Reuse EXACT SAME stat computation as computeMarkerStats:
    // - FPS: fpsStats = FpsAnalytics.compute(fpsValues)
    // - CPU: cpuAvg = mean of cpuAppPct
    // - Memory: memPeak = max of memoryPssKb
    // - GPU: gpuAvg = mean of gpuPct
    // - Jank: sum fields across samples, compute per-min rate
    // - Battery: first - last batteryPct
    // - mAh: trapezoidal integration
    // - durationMs: endMs - startMs
    final stats = RegionStats(
      sessionId: sessionId,
      label: label ?? 'Region',
      startMs: startMs,
      endMs: endMs,
      durationMs: endMs - startMs,
      fpsMedian: fpsStats.median,
      fpsMin: fpsStats.min,
      // ... all same fields as MarkerStats
    );
    await _regionStatsDao.insert(stats);
    return stats;
  }
  ```

  **Part C — RegionStats model** (`performancebench/lib/core/models/region_stats.dart`):
  Same fields as MarkerStats, plus: `label: String`, `startMs: int`, `endMs: int`, `color: String?`, `id: int?`.
  (Uses existing `regions` table in schema — update the DAO to map RegionStats model to the `regions` table.)

  **Part D — RegionStatsDao** (`performancebench/lib/core/database/region_stats_dao.dart`):
  ```dart
  class RegionStatsDao {
    final Database _db;
    RegionStatsDao(this._db);
    Future<int> insert(RegionStats stats) async { /* insert into regions table */ }
    Future<List<RegionStats>> getBySessionId(String sessionId) async { /* query regions where session_id = ? */ }
    Future<int> deleteBySessionId(String sessionId) async { /* delete */ }
  }
  ```

  **Part E — Add Regions tab to SessionDetailScreen**:
  In `detail_screen.dart`:
  - Change `DefaultTabController(length: 5)` → `length: 6`
  - Add `Tab(text: 'Regions')` to tab list
  - Add `RegionTab(sessionId: sessionId)` to TabBarView children
  - Update `markers_detail_tab.dart` if markers row click → highlight on replay chart already works, extend to also scroll regions

  `region_tab.dart`: New widget showing a table of saved region stats for the session, columns matching marker stats table format (per D-02: "same columns, same computation"):
  ```dart
  class RegionTab extends StatefulWidget {
    final String sessionId;
    // Load RegionStats from RegionStatsDao, display in DataTable
  }
  ```
  - Columns: Label | Duration | FPS Med | FPS Min | 1% Low | Stability | CPU Avg | Mem Peak | GPU Avg | Battery Drain | Jank/min
  - Each row clickable → scrolls ReplayChartsTab timeline to that region's time range + highlights span in blue

  **Part F — Wire drag-selection in ReplayChartsTab**:
  Update `replay_charts_tab.dart` to:
  - Load metric_samples from MetricDao for the session (NOT a placeholder)
  - Create individual MetricChart widgets that use pre-loaded data streams
  - Pass `enableDragSelection: true` and `onDragSelection: (start, end) async { ... }` to MetricChart
  - On drag complete: call `analyticsService.computeRegionStats(sessionId, startMs, endMs)` → save to DB → refresh RegionTab

  After tests pass, commit: `docs(02-01): add drag-region selection, region stats, and regions tab`
  </action>

  <verify>
    <automated>cd D:/OpenCode/Benchify && dart test test/core/analytics/region_stats_test.dart</automated>
  </verify>

  <done>
  - MetricChart accepts drag to select a time region with blue overlay visible during drag
  - onDragSelection callback fires with correct (startIndex, endIndex) from the spot array
  - computeRegionStats() produces identical results to computeMarkerStats() for same time range
  - SessionDetailScreen has 6 tabs including Regions
  - RegionTab displays per-region stats in same format as Markers tab
  - All tests pass
  </done>
</task>

<task type="tdd" tdd="true">
  <name>Task 3: Disk I/O parser activation — DiskIoParser + MetricCollector wiring</name>
  <files>
    performancebench/lib/core/parsers/disk_io_parser.dart
    performancebench/lib/core/collector/metric_collector.dart
    performancebench/lib/core/sdk/sdk_state.dart
    performancebench/test/core/parsers/disk_io_parser_test.dart
  </files>

  <read_first>
  - Read `UNIFIED-SPEC.md` lines 969-981 (§5.8 Disk I/O parser algorithm, ADB command, return type, acceptance criteria)
  - Read `UNIFIED-SPEC.md` lines 3685 (Appendix D ADB command: `adb shell cat /proc/diskstats`)
  - Read `performancebench/lib/core/models/metric_sample.dart` (disk_read_kb / disk_write_kb fields already exist — just need activation)
  - Read any existing parser in `performancebench/lib/core/parsers/` (e.g., `thermal_parser.dart`) for TDD pattern reference
  - Read `performancebench/lib/core/collector/metric_collector.dart` (find where parsers are called in _sampleTick loop — add DiskIoParser call)
  - Read `performancebench/lib/core/sdk/sdk_state.dart` (add diskIoSdkEnabled flag per §F — feature flag pattern)
  </read_first>

  <behavior>
    Disk I/O parser test expectations (disk_io_parser_test.dart):
    Test 1: Empty string → readKbPerSec null, writeKbPerSec null
    Test 2: Valid /proc/diskstats with sda line: "8 0 sda 1234 0 5678 0 0 0 0 0 0 0 0" → first call returns null (no prior sample), second call returns computed delta KB/s
    Test 3: mmcblk0 line: "179 0 mmcblk0 100 0 200 0 0 0 0 0 0 0 0" → parser finds mmcblk0 first (field[2] match), uses fields[5] and fields[9]
    Test 4: vda line (virtual disk) selected when sda and mmcblk0 absent
    Test 5: Two consecutive parse calls with sda sectors increasing by 200 read, 100 write over 1.0s interval → readKbPerSec = 200*512/1024 = 100.0 KB/s, writeKbPerSec = 100*512/1024 = 50.0 KB/s
    Test 6: No matching disk device (sda/mmcblk0/vda all absent) → returns null for both fields
    Test 7: Malformed line (wrong field count) → returns null
  </behavior>

  <action>
  **Create `performancebench/lib/core/parsers/disk_io_parser.dart`** per §5.8:

  ```dart
  /// Result of a disk I/O parse operation.
  class DiskIoResult {
    /// Delta read rate in KB/s between samples.
    final double? readKbPerSec;
    /// Delta write rate in KB/s between samples.
    final double? writeKbPerSec;
    /// Whether this was the first sample (no delta available).
    final bool isFirstSample;

    const DiskIoResult({this.readKbPerSec, this.writeKbPerSec, this.isFirstSample = false});

    static const empty = DiskIoResult(readKbPerSec: null, writeKbPerSec: null, isFirstSample: true);
  }

  class DiskIoParser {
    int? _prevReadSectors;
    int? _prevWriteSectors;
    int? _prevTimestampMs;

    /// Parse /proc/diskstats output. Returns null values on first call (no prior
    /// sample) and on subsequent calls computes delta KB/s between consecutive
    /// samples. Algorithm per UNIFIED-SPEC §5.8:
    /// 1. Find first line where field[2] is 'sda', 'mmcblk0', or 'vda'
    /// 2. read_sectors = field[5], write_sectors = field[9] (cumulative)
    /// 3. sectors × 512 = bytes; delta / interval_s → bytes/s → KB/s
    DiskIoResult parse(String diskstatsOutput, {int? timestampMs}) {
      // 1. Find matching line
      final lines = diskstatsOutput.split('\n');
      String? targetLine;
      for (final line in lines) {
        final fields = line.trim().split(RegExp(r'\s+'));
        if (fields.length < 10) continue;
        final device = fields[2];
        if (device == 'sda' || device == 'mmcblk0' || device == 'vda') {
          targetLine = line.trim();
          break; // First match wins
        }
      }
      if (targetLine == null) return DiskIoResult.empty;

      final fields = targetLine.split(RegExp(r'\s+'));
      if (fields.length < 10) return DiskIoResult.empty;

      final readSectors = int.tryParse(fields[5]);
      final writeSectors = int.tryParse(fields[9]);
      if (readSectors == null || writeSectors == null) return DiskIoResult.empty;

      final ts = timestampMs ?? DateTime.now().millisecondsSinceEpoch;

      // First sample — store baselines, return null delta
      if (_prevReadSectors == null || _prevTimestampMs == null) {
        _prevReadSectors = readSectors;
        _prevWriteSectors = writeSectors;
        _prevTimestampMs = ts;
        return const DiskIoResult(isFirstSample: true);
      }

      // Compute delta
      final dtSec = (ts - _prevTimestampMs!) / 1000.0;
      if (dtSec <= 0) return DiskIoResult.empty;

      final deltaReadSectors = readSectors - _prevReadSectors!;
      final deltaWriteSectors = writeSectors - _prevWriteSectors!;
      // sectors × 512 bytes / 1024 = KB; / dt = KB/s
      final readKbPerSec = (deltaReadSectors * 512) / 1024.0 / dtSec;
      final writeKbPerSec = (deltaWriteSectors * 512) / 1024.0 / dtSec;

      // Store for next call
      _prevReadSectors = readSectors;
      _prevWriteSectors = writeSectors;
      _prevTimestampMs = ts;

      return DiskIoResult(
        readKbPerSec: deltaReadSectors >= 0 ? readKbPerSec : 0,
        writeKbPerSec: deltaWriteSectors >= 0 ? writeKbPerSec : 0,
      );
    }

    /// Reset internal state (call when session ends).
    void reset() {
      _prevReadSectors = null;
      _prevWriteSectors = null;
      _prevTimestampMs = null;
    }
  }
  ```

  **Wire into MetricCollector** (`performancebench/lib/core/collector/metric_collector.dart`):

  In the MetricCollector class:
  1. Add field: `final DiskIoParser _diskIoParser = DiskIoParser();`
  2. Add ADB command call in `_sampleTick()`:
  ```dart
  // Inside _sampleTick() loop, after other parsers:
  if (_sdkState.diskIoSdkEnabled) {  // Feature flag
    final diskstatsOutput = await _adbService.runShellCommand(
      _deviceSerial, 'cat /proc/diskstats',
      timeout: const Duration(seconds: 3),
    );
    if (diskstatsOutput != null) {
      final diskResult = _diskIoParser.parse(diskstatsOutput, timestampMs: DateTime.now().millisecondsSinceEpoch);
      if (!diskResult.isFirstSample) {
        sample = MetricSample(
          // ... copy existing fields ...
          diskReadKb: diskResult.readKbPerSec,
          diskWriteKb: diskResult.writeKbPerSec,
        );
      }
    }
  }
  ```
  3. In `stop()`: Call `_diskIoParser.reset()`

  **Add SDK state flag** (`performancebench/lib/core/sdk/sdk_state.dart`):
  ```dart
  /// Whether Disk I/O parsing is enabled (feature flag — default on for Android in v1.5).
  bool diskIoSdkEnabled = true;
  ```

  **Create test** (`performancebench/test/core/parsers/disk_io_parser_test.dart`):
  - Cover all 7 test cases from behavior spec above
  - First call → isFirstSample = true, null values
  - Second call with offset → computed KB/s values

  After tests pass, commit: `docs(02-01): add DiskIoParser + wire into MetricCollector`
  </action>

  <verify>
    <automated>cd D:/OpenCode/Benchify && dart test test/core/parsers/disk_io_parser_test.dart</automated>
  </verify>

  <done>
  - DiskIoParser.parse() computes correct delta KB/s from /proc/diskstats per §5.8 formula
  - MetricCollector.sampleTick() calls DiskIoParser each tick and populates diskReadKb/diskWriteKb
  - SDK state flag controls disk I/O activation
  - All 7 test cases pass
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| ADB shell → Parser | Raw `/proc/diskstats` text crosses boundary |
| User drag input → Chart widget | Gesture coordinates interpreted as data indices |
| SQL migration → Existing data | Schema changes applied to live user database |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-01 | Tampering | disk_io_parser.dart parse() | mitigate | Validate field count >= 10 before indexing; int.tryParse guards on all field accesses; null return on malformed input |
| T-02-02 | Information Disclosure | database.dart _migrateV2() | mitigate | All data stays local SQLite per privacy contract; no network calls in migration |
| T-02-03 | Denial of Service | metric_chart.dart drag handler | mitigate | Clamp drag indices to [0, _spots.length - 1] bounds; reject drags with < 2 samples span |
| T-02-04 | Elevation of Privilege | database.dart onUpgrade | accept | Migration is additive (CREATE TABLE IF NOT EXISTS) — cannot destroy existing data; no privilege escalation path |
| T-02-05 | Tampering | detected_issue_dao.dart insert() | mitigate | Parameterized queries throughout; severity field validated against allowed enum values before insert |
</threat_model>

<verification>
1. Run migration test: `cd D:/OpenCode/Benchify && dart test test/core/database/migration_v2_test.dart`
2. Run region stats test: `cd D:/OpenCode/Benchify && dart test test/core/analytics/region_stats_test.dart`
3. Run disk I/O parser test: `cd D:/OpenCode/Benchify && dart test test/core/parsers/disk_io_parser_test.dart`
4. Run full test suite: `cd D:/OpenCode/Benchify && dart test`
5. Verify: `cd D:/OpenCode/Benchify && dart analyze` shows 0 errors
</verification>

<success_criteria>
1. Database upgrades from v1 to v2 without data loss — all 4 new tables created with correct columns per Appendix C DDL
2. User can drag-select a region on replay chart, see blue overlay during drag, and per-region stats appear in Regions tab matching per-marker stats format
3. Disk I/O metric (disk_read_kb + disk_write_kb) populates in MetricSample during live profiling on Android devices
4. 100% branch coverage on DiskIoParser, region stats computation, and migration path
5. All existing 100+ tests still pass (schema migration is additive, no behavior changes)
</success_criteria>

<output>
After completion, create `.planning/phases/02-v1-5-analysis-platform-expansion/02-01-SUMMARY.md`
</output>
