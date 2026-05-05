---
phase: 02-v1-5-analysis-platform-expansion
plan: 01
subsystem: core-database
tags: [schema-migration, drag-region, disk-io, analytics]
requires: []
provides: [v2-schema, region-stats, disk-io-parser]
affects: [metric-collector, analytics-service, metric-chart, session-detail]
tech-stack:
  added: [disk_io_parser.dart, sdk_state.dart]
  patterns: [TDD, DAO, CustomPainter, GestureDetector-drag]
key-files:
  created:
    - performancebench/lib/core/models/collection.dart
    - performancebench/lib/core/models/detected_issue.dart
    - performancebench/lib/core/models/video.dart
    - performancebench/lib/core/models/region_stats.dart
    - performancebench/lib/core/database/collection_dao.dart
    - performancebench/lib/core/database/detected_issue_dao.dart
    - performancebench/lib/core/database/video_dao.dart
    - performancebench/lib/core/database/region_stats_dao.dart
    - performancebench/lib/core/parsers/disk_io_parser.dart
    - performancebench/lib/core/sdk/sdk_state.dart
    - performancebench/lib/features/session_detail/region_tab.dart
    - performancebench/test/unit/migration_v2_test.dart
    - performancebench/test/unit/region_stats_test.dart
    - performancebench/test/unit/disk_io_parser_test.dart
  modified:
    - performancebench/lib/core/database/database.dart
    - performancebench/lib/core/analytics/analytics_service.dart
    - performancebench/lib/shared/widgets/metric_chart.dart
    - performancebench/lib/features/session_detail/detail_screen.dart
    - performancebench/lib/features/session_detail/replay_charts_tab.dart
    - performancebench/lib/core/services/metric_collector.dart
decisions:
  - D-v2-region-stats-table: "Added a separate region_stats table (4th new table) to store per-region computed analytics, following the marker_stats pattern. This resolves a plan inconsistency where the action only created 3 tables but the test expected 4."
  - D-test-location: "Placed tests in test/unit/ following existing project convention rather than the plan-specified test/core/* paths. dart test discovers tests anywhere under test/."
metrics:
  duration: 10m
  completed_date: 2026-05-05
---

# Phase 2 Plan 1: Schema v2 + Drag-Region + Disk I/O Summary

Schema migration to v2 with 4 new tables, drag-region selection on replay charts with per-region stats, and Disk I/O parser activation in MetricCollector.

## Tasks Executed

| # | Task | Type | Status | Commit |
|---|------|------|--------|--------|
| 1 | Schema migration v2 | TDD | Complete | test: e4dbe69, feat: 799795d |
| 2 | Drag-region selection + region stats | TDD | Complete | test: b2b39d3, feat: 6c56afa |
| 3 | Disk I/O parser activation | TDD | Complete | feat: fcbf1b7 (combined) |

## What Was Built

### Task 1: Schema Migration v2
- **4 new database tables**: `collections`, `detected_issues`, `videos`, `region_stats`
- **1 new column**: `sessions.has_video INTEGER DEFAULT 0`
- **4 model classes**: Collection, DetectedIssue, Video, RegionStats (each with fromMap/toMap)
- **4 DAO classes**: CollectionDao, DetectedIssueDao, VideoDao, RegionStatsDao (parameterized queries, CRUD operations)
- **Database.onUpgrade v1 to v2**: `runMigrations()` case 2 calls `_migrateV2()` with exact DDL from UNIFIED-SPEC.md Appendix C
- **Indexes**: `idx_issues_session`, `idx_issues_severity`, `idx_videos_session`, `idx_region_stats_session`
- **7 migration tests**: table existence, column schemas, index presence, collection row round-trip

### Task 2: Drag-Region Selection + Region Stats
- **MetricChart extended** with `onDragSelection` callback, `enableDragSelection` bool, `selectedRegion` record
- **Drag gesture handlers**: `onHorizontalDragStart/Update/End` with index-to-spot mapping and bounds clamping
- **Blue overlay**: `_DragOverlayPainter` CustomPainter rendering semi-transparent `accentBlue.withOpacity(0.15)` rectangle
- **computeRegionStats()**: Same computation as computeMarkerStats (FPS via FpsAnalytics, CPU mean, memory peak, GPU mean, battery drain, mAh trapezoidal, jank totals). Saves to region_stats table.
- **RegionTab widget**: DataTable with 11 stat columns (Label, Duration, FPS Med/Min/1%Low/Stability, CPU Avg, Mem Peak, GPU Avg, Battery, Jank/min)
- **SessionDetailScreen**: 6th tab "Regions" added
- **ReplayChartsTab**: Wired with real data loading from MetricDao, 5 replay charts (FPS, CPU, Memory, GPU, Battery) with `enableDragSelection: true`
- **7 region stats tests**: empty samples, FPS stats, CPU avg, memory peak, 100-sample comparison, callback signature, overlay color

### Task 3: Disk I/O Parser Activation
- **DiskIoParser**: Parses `/proc/diskstats` per UNIFIED-SPEC §5.8. Finds sda/mmcblk0/vda device line, computes delta sectors between samples, converts to KB/s
- **DiskIoResult**: `readKbPerSec`, `writeKbPerSec`, `isFirstSample` fields
- **T-02-01 mitigated**: field count >= 10 validation, int.tryParse guards on all field accesses, null return on malformed input
- **MetricCollector wired**: `_collectDiskIo()` called each tick via Future.wait, populates `diskReadKb`/`diskWriteKb` in MetricSample. Controlled by `SdkState.diskIoSdkEnabled` flag
- **Parser reset**: `_diskIoParser.reset()` called on session stop
- **11 parser tests**: empty/null input, sda/mmcblk0/vda device detection, delta computation, missing devices, malformed input, non-numeric values, reset behavior

## Verification Results

| Test Suite | Tests | Passed | Skipped |
|-----------|-------|--------|---------|
| migration_v2_test.dart | 7 | 7 | 0 |
| region_stats_test.dart | 7 | 7 | 0 |
| disk_io_parser_test.dart | 11 | 11 | 0 |
| All existing tests | 100 | 100 | 0 |
| Integration tests | 6 | 0 | 6 |
| **Total** | **131** | **125** | **6** |

- **dart analyze**: 0 errors, 8 warnings (all pre-existing `withOpacity` deprecation)
- **No regressions**: All 100 existing tests still pass

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Region stats test data field positions incorrect**
- **Found during**: Task 3 RED test execution
- **Issue**: Test data placed sector counts at wrong field indices in `/proc/diskstats` format. `sectors_read` is at split index 5 and `sectors_written` at index 9, but test data had them at indices 3 and 4.
- **Fix**: Rewrote all test data with correct 14-field /proc/diskstats lines matching the kernel format
- **Files modified**: `test/unit/disk_io_parser_test.dart`
- **Commit**: fcbf1b7

**2. [Rule 2 - Missing] Region_stats table not in plan DDL but needed for test compliance**
- **Found during**: Task 1 GREEN implementation
- **Issue**: Plan's test expected "4 new tables" but the migration SQL only created 3. The RegionStats model with full stat fields needed a proper table matching the marker_stats pattern.
- **Fix**: Added `region_stats` table with same columns as `marker_stats` plus label/start_ms/end_ms/color. This is the 4th new table.
- **Files modified**: `lib/core/database/database.dart` (_migrateV2)
- **Commit**: 799795d

**3. [Rule 3 - Blocking] sdk_state.dart file path doesn't exist**
- **Found during**: Task 3 GREEN implementation
- **Issue**: Plan references `performancebench/lib/core/sdk/sdk_state.dart` but `core/sdk/` directory doesn't exist in the project.
- **Fix**: Created `core/sdk/` directory and `sdk_state.dart` with SdkState class containing `diskIoSdkEnabled` flag
- **Files modified**: `lib/core/sdk/sdk_state.dart` (new)
- **Commit**: fcbf1b7

### Architectural Decisions

**D-v2-region-stats-table**: Chose to create a separate `region_stats` analytics table (mirroring `marker_stats`) rather than overloading the existing `regions` time-range table. This keeps the time-range definition and computed analytics separated, matching the markers/marker_stats pattern.

## TDD Gate Compliance

| Task | RED Commit | GREEN Commit | Compliance |
|------|-----------|-------------|------------|
| 1 | e4dbe69 test(...) | 799795d feat(...) | PASS |
| 2 | b2b39d3 test(...) | 6c56afa feat(...) | PASS |
| 3 | — combined in fcbf1b7 | fcbf1b7 feat(...) | WARN: no separate test commit |

Task 3's RED and GREEN phases were committed together because the test imports a file that doesn't exist before the parser is created. The test and implementation were developed in a tight loop but committed as a single unit.

## Threat Flags

No new threat surfaces beyond the plan's threat model. All 5 mitigations from the plan's STRIDE register are implemented:
- T-02-01: disk_io_parser.dart field count and int.tryParse guards
- T-02-02: All data stays local SQLite, no network calls in migration
- T-02-03: Drag indices clamped to `[0, _spots.length - 1]`
- T-02-04: Migration uses `CREATE TABLE IF NOT EXISTS` (additive, no data loss)
- T-02-05: detected_issue_dao.dart validates severity against allowed enum

## Known Stubs

None. All created components are functional: schema migration creates tables, drag-region selection renders overlay and fires callbacks, region stats computation mirrors marker stats, disk IO parser computes correct deltas.
