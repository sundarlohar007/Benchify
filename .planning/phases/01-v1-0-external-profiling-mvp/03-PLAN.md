---
phase: "01"
plan: "03"
type: execute
wave: 3
depends_on: ["01-02"]
files_modified:
  - lib/features/active_session/charts_tab.dart
  - lib/features/active_session/active_session_screen.dart
  - lib/shared/widgets/metric_chart.dart
  - lib/shared/widgets/fps_histogram_chart.dart
  - test/unit/ring_buffer_test.dart
  - lib/core/database/metric_dao.dart
  - lib/core/services/metric_collector.dart
  - lib/core/services/screenshot_service.dart
  - lib/features/active_session/screenshots_tab.dart
autonomous: true
requirements: [MVP-13, MVP-14, MVP-15]

must_haves:
  truths:
    - "Real-time charts display last 60 seconds of FPS/CPU/Memory/Battery/Network/GPU/Thermal with smooth scrolling at 1Hz"
    - "Ring buffer holds exactly 300 samples, oldest evicted on overflow"
    - "SQLite batch writer flushes accumulated MetricSamples every 5 seconds"
    - "Screenshot pipeline captures 5 sizes (SS0-SS4) via ADB screencap, resizes with Lanczos filter, saves as JPEG"
    - "Chart line colors match per-metric colors from design system (§9.1.1)"
    - "Chart null gaps visible as line breaks (no zero-fill)"
  artifacts:
    - path: "lib/shared/widgets/metric_chart.dart"
      provides: "Reusable fl_chart LineChart wrapper for all metrics"
      exports: ["class MetricChart extends StatefulWidget"]
    - path: "lib/features/active_session/charts_tab.dart"
      provides: "2-column auto-adaptive chart grid with all metric cards during active session"
    - path: "lib/core/services/screenshot_service.dart"
      provides: "ADB screencap → decode PNG → resize 5 sizes via Lanczos → save JPEG"
      exports: ["class ScreenshotService"]
  key_links:
    - from: "lib/features/active_session/charts_tab.dart"
      to: "lib/core/services/metric_collector.dart"
      via: "Stream<MetricSample> subscription"
      pattern: "metricCollector\\.start"
    - from: "lib/features/active_session/charts_tab.dart"
      to: "lib/shared/widgets/metric_chart.dart"
      via: "MetricChart widget instances for each metric"
      pattern: "MetricChart"
    - from: "lib/core/services/metric_collector.dart"
      to: "lib/core/database/metric_dao.dart"
      via: "batch insert every 5 seconds"
      pattern: "metricDao\\.batchInsert"
---

<objective>
Wire real-time fl_chart visualization (FPS/CPU/Memory/Battery/Network/GPU/Thermal cards) fed from the 300-sample ring buffer, implement SQLite batch writer flushing every 5 seconds, and build the 5-size screenshot capture pipeline with ADB screencap + Lanczos resize + JPEG encoding. All charts update at exactly 1Hz with VS Code Dark+ styling.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@UNIFIED-SPEC.md lines 2035-2070 (§9.4 Real-Time Chart Cards — MetricCard anatomy, fl_chart config)
@UNIFIED-SPEC.md lines 2094-2149 (§9.5 Active Session Screen — chart grid layout)
@UNIFIED-SPEC.md lines 1110-1164 (§5.12 Screenshots — sizes, pipeline, settings)
@UNIFIED-SPEC.md lines 2377-2420 (§9.10 Design Implementation Notes — fl_chart config, ring buffer wiring)

<interfaces>
Already exist from prior waves:
- MetricCollector.start() → Stream<MetricSample> with ring buffer (from lib/core/services/metric_collector.dart)
- MetricSample model with all 53 fields (from lib/core/models/metric_sample.dart)
- MetricDao with batchInsert(List<MetricSample>) (from lib/core/database/metric_dao.dart)
- AppColors theme extension with per-metric chart colors (from lib/shared/theme.dart)
- AdbService._runAdb() for shell commands (from lib/core/services/adb_service.dart)
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Build MetricChart widget and wire active session chart grid with ring buffer</name>
  <files>
    lib/shared/widgets/metric_chart.dart
    lib/shared/widgets/fps_histogram_chart.dart
    lib/features/active_session/charts_tab.dart
    lib/features/active_session/active_session_screen.dart
    test/unit/ring_buffer_test.dart
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 2035-2070 (MetricCard anatomy — border, label, value, chart, stat pills, null gaps, tooltip)
    @UNIFIED-SPEC.md lines 2094-2149 (Active Session chart grid — 2-column layout, REC indicator, toolbar, marker timeline)
    @UNIFIED-SPEC.md lines 2377-2391 (fl_chart configuration notes, ring buffer → chart wiring)
  </read_first>
  <action>
    1. Create `lib/shared/widgets/metric_chart.dart` — `MetricChart` StatefulWidget:
       - Constructor params: `String label`, `Color lineColor`, `Stream<MetricSample> stream`, `String Function(MetricSample) valueFormatter`, `List<StatPill> Function(List<MetricSample>) statCalculator`, optional `double targetLineY` (for FPS 60fps guideline), optional `bool showJankRow`.
       - Internally holds `List<FlSpot>` of max 300 points. Listens to stream in `initState()`: `stream.listen((sample) { setState(() { spots.add(newSpot); if (spots.length > 300) spots.removeAt(0); }); })`.
       - Chart rendering per §9.4 spec:
         - Card background: `bg.sidebar` with 4px border radius.
         - Chart area background: `bg.base` (slightly darker inset).
         - Label: `text.secondary`, 11px, uppercase, letter-spacing 0.8.
         - Current value: monospace, 16px, `text.primary`. Updates on setState — no animation.
         - LineChart: 2px solid, smooth curve (`isCurved: true, curveSmoothness: 0.3`), gradient fill (lineColor at 20% opacity → transparent, top to bottom).
         - Grid: horizontal lines only, `border.subtle` at 30% opacity, no vertical gridlines.
         - X-axis: last 60s, auto-scroll, labels at –60s, –45s, –30s, –15s, "now".
         - Y-axis: auto-range with 10% padding top, clamp at 0 minimum.
         - Target line: dashed horizontal at targetLineY (FPS only), color `border.subtle` at 60% opacity.
         - Null gaps: line breaks where data is null (do not connect across gaps — separate `LineChartBarData` segments or insert null `FlSpot`).
         - Data points: hidden by default (`.dotData: FlDotData(show: false)`), 4px circle on hover via `MouseRegion`.
         - Tooltip on hover: dark popup with timestamp + value + unit.
       - Stat pills row below chart: rendered from `statCalculator` callback. Format: `Med 58.3 · 1% 24.1 · Stab 81% · Min 22 · Max 63` in `text.mono.sm` (12px monospace), `text.secondary`.
       - Jank indicator row (FPS only): `◎ Small 89/min   ◉ Jank 14/min   ⬤ Big 2/min` in colored text.
       - Double-click: expands to full-screen overlay.
    
    2. Create `lib/shared/widgets/fps_histogram_chart.dart` — `FpsHistogramChart` StatelessWidget:
       - Takes `Map<int, int> histogram` (bucket_start → count).
       - Renders `fl_chart BarChart`:
         - Bars: `accent.blue` fill at 80% opacity, 2px spacing.
         - Hover: highlight bar, show exact count + % tooltip.
         - Empty buckets: shown as empty space (no bar).
         - Y-axis: percentage of total samples.
         - X-axis: bucket labels at every other bucket.
    
    3. Flesh out `lib/features/active_session/active_session_screen.dart`:
       - Replace placeholder with full implementation.
       - REC indicator: pulsing red dot (`accent.recording`), `AnimationController` + `ScaleTransition`, 1s cycle, infinite repeat.
       - Elapsed timer: counts up from 00:00:00, monospace font, 1Hz update from MetricCollector start time.
       - Toolbar: "Stop Recording" button (primary, red border), "Add Marker" button (Ctrl+Shift+M), "Launch Complete" button (gold, rocket icon, disables after first use), "Screenshot" button (Ctrl+Shift+S).
       - Status bar (bottom 22px): Recording indicator + elapsed time (left), device name + sample rate (center), SQLite write status (right — "SQLite ✓" green, "SQLite ⚠" yellow).
       - Integrates ActiveSessionChartsTab as the main tab content.
    
    4. Flesh out `lib/features/active_session/charts_tab.dart`:
       - `ActiveSessionChartsTab` StatelessWidget takes `Stream<MetricSample>`.
       - Auto-adaptive grid via `LayoutBuilder`: 1 column < 900px, 2 columns 900-1400px, 3 columns > 1400px.
       - Renders MetricChart widgets for each metric:
         a. FPS: lineColor=#569CD6, targetLine=60, showJankRow=true, stat pills: Med/Min/1%Low/Stab. Chart label "FPS".
         b. CPU (App): lineColor=#4EC9B0, stat pills: Avg/Peak. Chart label "CPU (App)".
         c. Memory: lineColor=#CE9178, stat pills: Avg/Peak. Chart label "Memory".
         d. Battery %: lineColor=#DCDCAA, stat pills: Current/Drain/Hourly. Chart label "Battery %".
         e. Battery mA: lineColor=#C586C0, stat pills: Avg mA/Peak mA. Chart label "Battery mA".
         f. Battery mV: lineColor=#9CDCFE. Chart label "Battery mV".
         g. Battery Temp: lineColor=#F44747. Chart label "Battery Temp".
         h. Network: Two lines on same chart (TX=#4FC1FF, RX=#85C1E9). Chart label "Network".
         i. GPU: lineColor=#C586C0. Hidden entirely if gpu_pct=null for all samples. Chart label "GPU".
         j. Thermal: Color bar instead of line chart (categorical 0-3). Background color by level.
       - GPU card conditionally rendered: `if (hasGpuData)` show card, else hide card entirely.
       - Only render Battery mV and Battery Temp cards if data is non-null for at least one sample.
    
    5. Update `test/unit/ring_buffer_test.dart` (placeholder from Wave 1):
       - Test 1: Buffer starts empty → length = 0.
       - Test 2: Add 100 samples → length = 100.
       - Test 3: Add 350 samples → length = 300 (oldest 50 evicted).
       - Test 4: Verify oldest sample is the 51st added after adding 350.
       - Test 5: Verify newest sample is the 350th added after adding 350.
    
    DO NOT: Use StreamBuilder (too many rebuilds). Use stream.listen + setState per §9.10.
    DO NOT: Animate value changes — just set text. Chart scroll animation: `Curves.easeInOut`, not bouncy.
    DO NOT: Block UI thread during chart rendering. Chart updates must stay < 33ms per frame.
  </action>
  <acceptance_criteria>
    - `lib/shared/widgets/metric_chart.dart` renders a complete MetricCard with label, value, fl_chart LineChart, stat pills row, and optional jank row
    - `lib/features/active_session/charts_tab.dart` has 2-column grid with MetricChart for all 7-10 metric types
    - Chart uses `stream.listen` + `setState`, not `StreamBuilder`
    - GPU card hidden when `gpu_pct` is null for all received samples
    - Null gaps visible as line breaks (no connecting line across null data)
    - Double-click MetricChart → full-screen overlay
    - Ring buffer test passes: 350 adds → 300 entries, oldest evicted
    - `flutter test test/unit/ring_buffer_test.dart` — all 5 tests pass
    - `flutter analyze` — zero errors
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter test test/unit/ring_buffer_test.dart && flutter analyze lib/shared/widgets/metric_chart.dart lib/features/active_session/</automated>
  </verify>
  <done>Real-time charts render at 1Hz with correct per-metric colors, ring buffer enforces 300 cap, chart grid auto-adapts columns, null gaps visible as breaks, REC indicator pulses.</done>
</task>

<task type="auto">
  <name>Task 2: Implement SQLite batch writer (flush every 5 seconds)</name>
  <files>
    lib/core/database/metric_dao.dart
    lib/core/services/metric_collector.dart
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 1671-1829 (§8 Database Schema — metric_samples table key columns)
    @UNIFIED-SPEC.md lines 400-402 (§4.1 SQLite batch write concept)
  </read_first>
  <action>
    1. Update `lib/core/database/metric_dao.dart`:
       - Add `Future<void> batchInsert(List<MetricSample> samples, Database db)` method.
       - Uses `db.transaction((txn) { for sample in samples { txn.insert('metric_samples', sample.toMap()); } })`.
       - Returns silently if samples list is empty.
       - Handles duplicate session_id+timestamp gracefully (INSERT OR IGNORE pattern — first write wins).
    
    2. Update `lib/core/services/metric_collector.dart` MetricCollector:
       - Add internal `List<MetricSample> _pendingBatch = []`.
       - Add `Timer _batchTimer` that fires every 5 seconds.
       - On timer tick: if `_pendingBatch` is non-empty, call `metricDao.batchInsert(_pendingBatch)`, then clear `_pendingBatch`.
       - Also flush on session stop (call `_batchTimer.cancel()`, flush remaining samples).
       - Status bar SQLite indicator: emit status updates on a separate stream — "SQLite ✓" when last flush succeeded, "SQLite ⚠" when last flush failed.
       - Add error handling: if batch insert fails, log error, keep samples in memory, retry next cycle (do not discard data).
    
    DO NOT: Block the 1Hz collection loop during batch writes. Run batch insert asynchronously.
    DO NOT: Write every sample individually (performance). Always batch.
    DO NOT: Lose samples on write failure — keep in memory and retry.
  </action>
  <acceptance_criteria>
    - `metricDao.batchInsert()` uses `db.transaction()` for atomic batch write
    - MetricCollector flushes pending batch every 5 seconds via Timer
    - On session stop, all remaining samples flushed before session marked complete
    - Batch write failure: samples retained in memory, retried next cycle, status shows "SQLite ⚠"
    - 60-second session produces 12 batch writes (at 5s intervals) — verify via debug log or test
    - `flutter test` — any existing tests still pass
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter analyze lib/core/database/metric_dao.dart lib/core/services/metric_collector.dart</automated>
  </verify>
  <done>MetricSamples batch-inserted to SQLite every 5 seconds during active session. Final flush on session stop captures all remaining data. Write failures handled gracefully with retry.</done>
</task>

<task type="auto">
  <name>Task 3: Build screenshot capture pipeline (5 sizes via ADB + Lanczos resize + JPEG save)</name>
  <files>
    lib/core/services/screenshot_service.dart
    lib/core/database/screenshot_dao.dart
    lib/features/active_session/screenshots_tab.dart
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 1110-1164 (§5.12 Screenshots — 5 sizes SS0-SS4, capture pipeline, settings UI)
  </read_first>
  <action>
    1. Create `lib/core/services/screenshot_service.dart` — `ScreenshotService` class:
       - Constructor takes `AdbService`, device serial, session ID, and `List<ScreenshotConfig> enabledSizes`.
       - `ScreenshotConfig`: `String sizeId` (SS0-SS4), `double scale` (1.0, 0.5, 0.25, 0.125, 0.0675), `int intervalSeconds`.
       - `Future<ScreenshotResult> capture()`:
         a. Run `adb exec-out screencap -p` → raw PNG bytes on stdout.
         b. Decode PNG using `image` package: `img.decodePng(pngBytes)`.
         c. For each enabled size: resize via Lanczos filter (`img.copyResize(width, height, filter: img.Filter.lanczos)`), encode as JPEG at 50% quality (`img.encodeJpg(resized, quality: 50)`).
         d. Write JPEG to `screenshots/<session_id>/<timestamp>_<sizeId>.jpg` in data directory.
         e. Determine dimensions from resized image.
         f. Insert one row per size into `screenshots` table via ScreenshotDao.
         g. Return list of saved screenshot paths.
       - `Future<void> startAutoCapture()` — starts per-size timers based on configured interval. Each timer independently fires `capture()`.
       - `Future<void> stop()` — cancels all timers.
       - Wireless detection: if session is over WiFi ADB, auto-disable all screenshot capture. Show banner "Screenshots disabled during wireless profiling for stability."
       - 3-second timeout on ADB screencap command.
       - If capture fails: log error, skip this interval, continue (do not stop session).
    
    2. Update `lib/core/database/screenshot_dao.dart` (if placeholder):
       - `batchInsert(List<ScreenshotRow> rows)` — inserts all screenshot rows for a capture event.
       - `queryBySession(String sessionId)` — returns all screenshots for a session ordered by timestamp.
    
    3. Flesh out `lib/features/active_session/screenshots_tab.dart`:
       - Shows a thumbnail grid of captured screenshots.
       - Each thumbnail: JPEG image, timestamp, size label (SS0/SS1/etc.).
       - Click thumbnail → expand to full-size viewer overlay.
       - Auto-scroll to most recent capture.
       - SS1 (50%) is default size shown in thumbnails.
       - Empty state: "No screenshots captured" with info about enabling sizes in Settings.
    
    DO NOT: Use any cloud image processing services. All processing is local (image package).
    DO NOT: Block UI thread during image decode/resize — use `compute()` or Isolate for heavy work.
    DO NOT: Capture screenshots if device is over WiFi (wireless ADB).
  </action>
  <acceptance_criteria>
    - `lib/core/services/screenshot_service.dart` exports `ScreenshotService` with `capture()`, `startAutoCapture()`, `stop()`
    - Capture pipeline: screencap PNG → decode → resize 5 sizes via Lanczos → encode JPEG 50% quality → save to disk
    - Screenshot filenames: `screenshots/<session_id>/<ts>_SS0.jpg` through `_SS4.jpg`
    - One `screenshots` table row per saved size with size_id, width_px, height_px, file_size_bytes
    - Wireless ADB: screenshots auto-disabled, banner displayed
    - Screenshots tab shows thumbnail grid with size labels, click to expand
    - `flutter analyze` — zero errors
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter analyze lib/core/services/screenshot_service.dart lib/features/active_session/screenshots_tab.dart</automated>
  </verify>
  <done>Screenshot pipeline captures 5 sizes (SS0-SS4) via ADB screencap, resizes with Lanczos, saves as JPEG. Auto-disabled over wireless. Thumbnail grid in active session tab.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| ADB screencap output → ScreenshotService | Raw PNG bytes from device. Malformed or truncated image data. |
| Ring buffer → Chart widget | In-memory floating point data consumed by UI rendering. |
| MetricCollector → SQLite | Batch write of metric samples to disk. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-10 | Tampering | screenshot_service.dart — malformed PNG from ADB | mitigate | Wrap PNG decode in try-catch; if decode fails, log error, skip this capture, continue session. Validate PNG magic bytes before decode. |
| T-01-11 | Denial of Service | screenshot_service.dart — excessive screenshot storage | mitigate | Per-size configurable intervals. SS4 at 2s = ~1800 files/hour × 3KB = 5.4MB — acceptable. User controls via Settings. |
| T-01-12 | Denial of Service | metric_chart.dart — rendering performance | mitigate | Max 300 data points per chart. Skip render if stream emits faster than 60fps (unlikely at 1Hz source). setState batching via SchedulerBinding.addPostFrameCallback. |
| T-01-13 | Information Disclosure | screenshot_service.dart — screenshots stored on disk | accept | Screenshots stored in user's private data directory with OS-default permissions. Same risk profile as any local screenshot tool. |
</threat_model>

<verification>
- Run active session against Android emulator → charts render with 1Hz updates, all metric cards visible
- Verify batch writes: after 10s session, metric_samples table has ~10 rows
- Verify ring buffer: after 70s session, buffer holds 60 latest samples
- Screenshot capture: verify SS0-SS4 files created in screenshots/<id>/ directory
</verification>

<success_criteria>
1. All metric charts render in 2-column grid with VS Code Dark+ styling, updating at 1Hz
2. Ring buffer enforces 300-sample cap, oldest evicted on overflow
3. SQLite batch writer flushes accumulated samples every 5 seconds, final flush on stop
4. Screenshot pipeline captures, resizes, saves 5 sizes with correct filenames and DB rows
5. GPU card hidden when gpu_pct = null for entire session
6. Wireless ADB auto-disables screenshots with UI banner
7. Chart null gaps visible as line breaks (no zero-fill)
</success_criteria>

<output>
After completion, create `.planning/phases/01-v1-0-external-profiling-mvp/03-SUMMARY.md`
</output>
