---
phase: "01"
plan: "05"
type: execute
wave: 5
depends_on: ["01-03", "01-04"]
files_modified:
  - lib/features/session_history/history_screen.dart
  - lib/features/session_history/session_list_item.dart
  - lib/features/session_detail/detail_screen.dart
  - lib/features/session_detail/scorecard_tab.dart
  - lib/features/session_detail/replay_charts_tab.dart
  - lib/features/session_detail/fps_analysis_tab.dart
  - lib/features/session_detail/markers_detail_tab.dart
  - lib/features/comparison/comparison_screen.dart
  - lib/core/services/export_service.dart
  - lib/shared/widgets/scorecard_widget.dart
  - lib/shared/widgets/marker_stats_table.dart
  - lib/shared/widgets/comparison_delta_table.dart
  - test/unit/export_service_test.dart
autonomous: true
requirements: [MVP-18, MVP-19, MVP-20]

must_haves:
  truths:
    - "Session history screen shows all saved sessions sorted by date with table columns: Date, App, Device, Duration, FPS, Tags"
    - "Session history supports filtering by platform, device, app, and free-text search"
    - "Session detail screen has 5 tabs: Scorecard, Charts (replay), FPS Analysis, Markers, Screenshots — all populated from SQLite"
    - "Session comparison shows two sessions side-by-side with overlaid charts and delta table highlighting regressions"
    - "Export produces valid JSON with all session data and CSV with matching column count and header row"
  artifacts:
    - path: "lib/core/services/export_service.dart"
      provides: "JSON and CSV export of session data"
      exports: ["class ExportService", "Future<String> exportJson(String sessionId)", "Future<String> exportCsv(String sessionId)"]
    - path: "lib/features/session_history/history_screen.dart"
      provides: "Sortable, filterable session list table with hover preview"
    - path: "lib/features/comparison/comparison_screen.dart"
      provides: "Side-by-side session comparison with overlaid charts and delta table"
  key_links:
    - from: "lib/features/session_detail/detail_screen.dart"
      to: "lib/core/database/session_stats_dao.dart"
      via: "load session_stats for scorecard display"
      pattern: "sessionStatsDao"
    - from: "lib/features/comparison/comparison_screen.dart"
      to: "lib/core/analytics/comparison_analytics.dart"
      via: "compare() for delta computation"
      pattern: "ComparisonAnalytics"
    - from: "lib/core/services/export_service.dart"
      to: "lib/core/database/metric_dao.dart"
      via: "query all metric_samples for export"
      pattern: "metricDao"
---

<objective>
Build session history with sorting/filtering/search, session detail with 5-tab replay (scorecard, charts, FPS analysis, markers, screenshots), side-by-side session comparison with delta table and regression highlighting, and JSON + CSV export service. All data loaded from SQLite — no recomputation during display.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@UNIFIED-SPEC.md lines 2151-2279 (§9.6 Session History Screen, §9.7 Session Detail — Scorecard/Charts/FPS Analysis/Markers tabs)
@UNIFIED-SPEC.md lines 2280-2310 (§9.8 Session Comparison Screen)
@UNIFIED-SPEC.md lines 1286-1303 (§6.4 Session Comparison Delta — regression rules)

<interfaces>
Already exist:
- SessionDao: query all, query by id, query by filters (from lib/core/database/session_dao.dart)
- SessionStatsDao: query by session_id (from lib/core/database/session_stats_dao.dart)
- MarkerStatsDao: query by session_id (from lib/core/database/marker_stats_dao.dart)
- ScreenshotDao: queryBySession() (from lib/core/database/screenshot_dao.dart)
- MetricDao: queryBySession(), queryBySessionAndTimeRange() (from lib/core/database/metric_dao.dart)
- MarkerDao: query by session_id (from lib/core/database/marker_dao.dart)
- ComparisonAnalytics.compare() (from lib/core/analytics/comparison_analytics.dart)
- MetricChart, FpsHistogramChart, ScorecardWidget, MarkerStatsTable, ComparisonDeltaTable (from lib/shared/widgets/)
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Build Session History screen with sorting, filtering, search, and hover preview</name>
  <files>
    lib/features/session_history/history_screen.dart
    lib/features/session_history/session_list_item.dart
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 2151-2180 (§9.6 Session History Screen — table layout, filters, hover preview)
  </read_first>
  <action>
    1. Flesh out `lib/features/session_history/history_screen.dart`:
       - Loads sessions from SessionDao on init, ordered by started_at DESC.
       - Table layout per §9.6:
         - Columns: Date, App, Device, Duration, FPS, Tags.
         - VS Code file-explorer aesthetic: no heavy borders, alternating subtle row backgrounds (`bg.hover` at 50% opacity every other row).
         - Platform column: Android robot icon or Apple logo (colored).
         - FPS value color: ≥55 → accent.success, 30-54 → accent.warning, <30 → accent.danger.
         - Duration format: "4m 21s", "12m 01s", "2h 14m".
         - Date format: "Today 14:32", "Yesterday", "Jan 15".
         - Tags: small rounded pills, `bg.input` bg, `text.secondary` text.
       - Filter bar above table:
         - Platform dropdown: All / Android / iOS.
         - Device dropdown: populated from distinct device_ids in sessions.
         - App dropdown: populated from distinct app_packages in sessions.
         - Free-text search: filters by app_name, title, notes, tags (case-insensitive contains).
         - Active filters shown as chips below filter bar, dismissible with ×.
         - Filter state managed via Riverpod StateProvider.
       - Sort: clickable column headers, show sort direction arrow. Sort by Date (default), Duration, FPS.
       - Row click: opens Session Detail in new tab via GoRouter.
       - Hover preview (on row hover): tooltip-style card (300px wide, anchored to row) showing FPS sparkline (mini line chart of session) + key stats (median FPS, duration, device). Loads data via Future on first hover, cached.
       - Empty state: "No sessions recorded yet. Connect a device and start profiling." with icon.
       - Session count: "234 sessions" shown in top-right.
    
    2. Create `lib/features/session_history/session_list_item.dart`:
       - A single table row widget.
       - Props: Session + SessionStats (optional, for FPS value).
       - Renders Date cell, App cell (app_name + package subtitle), Device cell (platform icon + device name), Duration cell, FPS cell (colored), Tags cell (pill badges).
       - onTap callback.
       - onHover callback (for hover preview).
    
    DO NOT: Load all metric_samples for the list view (perf). Only load session + session_stats summary.
    DO NOT: Use DataTable — use custom table with single `ListView.builder` for performance with 1000+ sessions.
  </action>
  <acceptance_criteria>
    - Session history table shows all sessions with correct Date/App/Device/Duration/FPS/Tags columns
    - Platform filter works: selecting "Android" hides iOS sessions, selecting "iOS" hides Android sessions
    - App filter populated from distinct app_packages in DB
    - Free-text search filters by app_name, title, notes, tags
    - Clicking a row navigates to session detail screen
    - Empty state shows when no sessions exist (no crash)
    - Hover preview card appears on mouse hover over row
    - Row count displayed as "N sessions" in top-right
    - `flutter analyze` — zero errors
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter analyze lib/features/session_history/</automated>
  </verify>
  <done>Session history displays all saved sessions with full sorting, filtering, search, and hover preview. Table renders efficiently for large session counts.</done>
</task>

<task type="auto">
  <name>Task 2: Build Session Detail with 5 tabs and Session Comparison screen</name>
  <files>
    lib/features/session_detail/detail_screen.dart
    lib/features/session_detail/scorecard_tab.dart
    lib/features/session_detail/replay_charts_tab.dart
    lib/features/session_detail/fps_analysis_tab.dart
    lib/features/session_detail/markers_detail_tab.dart
    lib/shared/widgets/scorecard_widget.dart
    lib/shared/widgets/marker_stats_table.dart
    lib/shared/widgets/fps_histogram_chart.dart
    lib/features/comparison/comparison_screen.dart
    lib/shared/widgets/comparison_delta_table.dart
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 2182-2279 (§9.7 Session Detail — Scorecard/Charts/FPS Analysis/Markers tabs with exact layouts)
    @UNIFIED-SPEC.md lines 2280-2310 (§9.8 Session Comparison — overlaid charts, delta table, regression indicators)
  </read_first>
  <action>
    1. Flesh out `lib/features/session_detail/detail_screen.dart`:
       - Receives sessionId from GoRouter path parameter.
       - Loads Session, SessionStats, and markers on init.
       - Tab strip: [Scorecard] [Charts] [FPS Analysis] [Markers] [Screenshots].
       - VS Code tab aesthetic: active tab has bottom blue border line (`accent.blue`).
       - Header: app name + device + duration + date + platform + tags.
       - Launch time display: if launch_complete_ms is non-null, show "🚀 Launch Time: X.Xs" in header.

    2. Flesh out `lib/features/session_detail/scorecard_tab.dart` (replace placeholder):
       - Two-column stat grid on `bg.base` per §9.7.1 layout exactly:
         - Column 1: FPS section (Median, Min, Max, 1% Low, 95th Pct, Stability), Memory section (Average, Peak), Battery section (Drain %/hr, Avg mA, Avg mV, Temp Peak), Thermal section (Peak, % Normal).
         - Column 2: Jank section (Small count/min, Standard count/min, Big count/min), CPU section (Average, Peak), GPU section (Average, Peak, Vendor), Network section (TX Total, RX Total, TX Avg, RX Avg).
         - Export buttons at bottom of column 2: [Export JSON] [Export CSV].
       - All stat labels: `text.secondary` 12px. All values: `text.primary` 14px monospace.
       - Section headers: `text.secondary` uppercase 10px, letter-spacing 1.2.

    3. Flesh out `lib/features/session_detail/replay_charts_tab.dart` (replace placeholder):
       - Loads all metric_samples for the session from MetricDao.queryBySession().
       - Reuses MetricChart widget from Wave 3 — same charts but static (no live stream). Feed pre-loaded List<MetricSample>.
       - Full session display (not rolling 60s). Pan/zoom enabled on all charts.
       - Marker events overlaid as vertical lines on all charts simultaneously.
       - Clicking a marker line highlights that timespan across all charts.

    4. Flesh out `lib/features/session_detail/fps_analysis_tab.dart` (replace placeholder):
       - Loads FPS histogram data from session_stats.fps_histogram JSON.
       - Renders FpsHistogramChart (bar chart) per §9.7.3.
       - Shows percentile stats panel: Median, Min, Max, 1% Low, 95th Pct, Stability, Total Janks (small/standard/big), Jank Rate/min.
       - Y-axis: percentage of total samples. Bars: `accent.blue` at 80% opacity.
       - Empty buckets shown as empty space (no zero-height bar).
       - Hover on bar: show exact count + percentage.

    5. Flesh out `lib/features/session_detail/markers_detail_tab.dart` (replace placeholder):
       - Query all markers + their marker_stats rows for this session.
       - Sortable table per §9.7.4:
         - Columns: Marker, Duration, FPS Med, FPS Min, 1% Low, Stability, S.Jank/m, Jank/m, Big/m, CPU, Mem Peak.
         - Launch Complete row: 🚀 icon, shows "Time to Launch" in Duration, all stats show "—" (point marker with no stats).
         - Jank columns: colored (small=grey, standard=orange if >0, big=red if >0).
         - FPS Med: colored (green ≥55, orange 30-54, red <30).
         - Click marker row → timeline scrolls all Charts tab charts to that marker's time range + highlights span.
    
    6. Flesh out `lib/shared/widgets/scorecard_widget.dart`:
       - Reusable stat grid layout used by both active session overlay and session detail.

    7. Flesh out `lib/shared/widgets/marker_stats_table.dart`:
       - Sortable DataTable with marker columns per §9.7.4.

    8. Flesh out `lib/features/comparison/comparison_screen.dart`:
       - Two session selector dropdowns (Session A, Session B) at top. Load session list grouped by date.
       - Below: overlaid chart showing both sessions on same axes:
         - Session A = blue (#569CD6), Session B = orange (#CE9178).
         - Both at 70% opacity so overlap visible.
         - X-axis: synced to t=0 (relative time from session start).
         - Shorter session: null gap from end to longer session's end.
       - Below chart: Metric Delta Table per §6.4 + §9.8:
         - Columns: Metric, Session A, Session B, Δ (delta %), indicator.
         - Regression indicators: 🔴 = ≥5% regression, 🟡 = 1-5% regression, 🟢 = improvement, — = no change.
         - Compared metrics: FPS Median, FPS 1% Low, FPS Stability, Frame Time P95, CPU Avg, Memory Peak, Jank/min, Big Jank Total, GPU Avg, Battery Drain.
         - Uses ComparisonAnalytics.compare() from Wave 4.

    DO NOT: Recompute analytics in the UI layer. All stats loaded from session_stats/marker_stats tables.
    DO NOT: Use blocking queries — all DB loads are async with loading indicators.
  </action>
  <acceptance_criteria>
    - Session detail screen loads with 5 tabs, all populated from SQLite data
    - Scorecard tab shows all stats in 2-column grid matching §9.7.1 layout
    - Charts tab (replay) shows full session with pan/zoom, marker lines overlaid
    - FPS Analysis tab shows histogram bar chart + percentile stats panel
    - Markers tab shows sortable table with per-marker stats, colored jank columns
    - Launch Complete marker shows 🚀 icon and "Time to Launch" in Duration column
    - Comparison screen: two session selectors, overlaid chart, delta table with regression indicators
    - Regression indicators correct: FPS lower=🔴, CPU higher=🔴, stability lower=🔴
    - `flutter analyze` — zero errors
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter analyze lib/features/session_detail/ lib/features/comparison/</automated>
  </verify>
  <done>Session detail renders 5 tabs with full data from SQLite. Session comparison shows overlaid charts and delta table with regression highlighting. All tab navigation works.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Build JSON/CSV export service with TDD</name>
  <files>
    lib/core/services/export_service.dart
    test/unit/export_service_test.dart
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 2860-2886 (§14.1 export service test requirements)
  </read_first>
  <behavior>
    - Test 1: Export JSON for empty session → valid JSON with empty samples array
    - Test 2: Export JSON with 3 samples → JSON array has 3 elements, fps field present in each
    - Test 3: Export CSV → column count matches MetricSample fields, header row present
    - Test 4: Export CSV → first data row matches first sample's fps value (piped through)
  </behavior>
  <action>
    RED phase: Create `test/unit/export_service_test.dart`. Tests must FAIL first.

    GREEN phase — Export Service (`lib/core/services/export_service.dart`):
    1. `ExportService` class takes Database reference.
    2. `Future<String> exportJson(String sessionId)`:
       a. Query session row from sessions table.
       b. Query all metric_samples for session ordered by timestamp.
       c. Query session_stats row.
       d. Query all markers + marker_stats for session.
       e. Build JSON structure:
          ```json
          {
            "session": { ... session fields ... },
            "stats": { ... session_stats fields ... },
            "samples": [ ... metric_samples array ... ],
            "markers": [ ... marker + marker_stats objects ... ],
            "exported_at": "2024-01-15T14:32:00Z"
          }
          ```
       f. Encode as JSON with UTF-8 (no BOM). Pretty-print with 2-space indentation.
       g. Return JSON string (caller writes to file via file_picker).
    
    3. `Future<String> exportCsv(String sessionId)`:
       a. Query all metric_samples for session ordered by timestamp.
       b. Build CSV:
          - Header row: all MetricSample field names (matching model fields, snake_case).
          - Data rows: one row per sample with all field values.
          - Null fields → empty string in CSV.
          - Use `csv` package (already in pubspec.yaml).
       c. Return CSV string.
    
    4. Export flow:
       - User clicks [Export JSON] or [Export CSV] button on session detail.
       - Open file_picker save dialog to choose output path.
       - Call exportJson/exportCsv, write to chosen path.
       - Show success toast: "Exported to <filename>".
       - On write error: show error dialog.
    
    5. Include `exported_at` timestamp in ISO 8601 format (`YYYY-MM-DDTHH:MM:SSZ`) in JSON export.
    
    6. Unix epoch timestamps in JSON (ms). ISO 8601 for human-readable fields.

    REFACTOR: Extract common query logic between JSON and CSV export.

    DO NOT: Export to default location without user choosing (privacy requirement). Manual only.
    DO NOT: Include screenshots binary data in export — only screenshot metadata (filepath, size, dimensions).
    DO NOT: Auto-export on session stop. Manual trigger only.
  </action>
  <acceptance_criteria>
    - `test/unit/export_service_test.dart` passes all 4 test cases
    - JSON export: valid JSON structure with session, stats, samples, markers, exported_at
    - CSV export: header row with all MetricSample field names, data rows with values, null=empty string
    - JSON uses Unix epoch ms for timestamps, ISO 8601 for exported_at
    - Export writes to user-chosen path via file_picker (no default location)
    - JSON encoding is UTF-8 without BOM
    - `flutter test test/unit/export_service_test.dart` — all green
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter test test/unit/export_service_test.dart && flutter analyze lib/core/services/export_service.dart</automated>
  </verify>
  <done>JSON and CSV export working. JSON structure includes session, stats, samples, markers. CSV header matches MetricSample fields. Export writes to user-chosen path only.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Export file write → User-chosen path | User selects export destination via file_picker. File written to user-controlled location. |
| Session data → Export service | Session data from SQLite serialized to JSON/CSV strings in memory. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-18 | Information Disclosure | export_service.dart — file written to user-chosen path | accept | User explicitly chooses export path via file_picker. Export is manual-only. Risk accepted — equivalent to any file save dialog. |
| T-01-19 | Tampering | export_service.dart — CSV injection via metric values | mitigate | CSV fields containing formula-trigger characters (=, +, -, @) are prefixed with single quote (') to prevent spreadsheet formula injection. |
| T-01-20 | Information Disclosure | comparison_screen.dart — session data rendered in UI | accept | All data sourced from local SQLite. No transmission. Same trust domain as the app. |
</threat_model>

<verification>
- Navigate to History screen → verify sessions listed with correct sort/filter
- Click session → detail screen loads with 5 tabs populated
- Compare two sessions → delta table shows correct regressions
- Export session as JSON → valid JSON with all sections
- Export session as CSV → valid CSV with correct header and data rows
</verification>

<success_criteria>
1. Session history shows all sessions with sortable columns, platform/app/search filters, and hover preview
2. Session detail has 5 tabs (Scorecard, Charts, FPS Analysis, Markers, Screenshots) all populated from SQLite
3. Session comparison shows two sessions on overlaid chart with delta table and correct regression indicators
4. JSON export produces valid structured JSON with session, stats, samples, and markers
5. CSV export produces valid CSV with correct header row matching MetricSample fields
6. Export writes only to user-chosen path (manual trigger, no auto-export)
</success_criteria>

<output>
After completion, create `.planning/phases/01-v1-0-external-profiling-mvp/05-SUMMARY.md`
</output>
