---
phase: "01"
plan: "04"
type: execute
wave: 4
depends_on: ["01-02", "01-03"]
files_modified:
  - lib/core/analytics/fps_analytics.dart
  - lib/core/analytics/analytics_service.dart
  - lib/core/analytics/comparison_analytics.dart
  - test/unit/fps_analytics_test.dart
  - test/unit/comparison_analytics_test.dart
  - ios_agents/collector.py
  - ios_agents/device_list.py
  - ios_agents/app_list.py
  - lib/core/services/ios_service.dart
autonomous: true
requirements: [MVP-16, MVP-17]

must_haves:
  truths:
    - "Post-session analytics compute FPS median/min/max/1%low/p95/stability/histogram/variability_index from saved metric_samples"
    - "Power analytics compute mAh consumed, avg mW, total mWh, estimated playtime hours from battery samples"
    - "Per-marker stats auto-computed on session stop for all range markers"
    - "Session stats row exists in session_stats table immediately after session stop"
    - "iOS collector.py streams newline-delimited JSON with all 14 metric keys per §5.10 mapping"
    - "IosService manages Python subprocess lifecycle (start, SIGTERM, SIGKILL), parses stdout JSON lines"
    - "iOS MetricSample population maps collector.py JSON fields to model columns per §5.10 table"
    - "iOS data saves to same SQLite tables as Android data"
  artifacts:
    - path: "lib/core/analytics/fps_analytics.dart"
      provides: "FPS median, min, max, 1% low, p95 frame time, stability %, histogram, variability index, frame ratio jank total"
      exports: ["class FpsAnalytics", "FpsStats compute(List<double> samples)"]
    - path: "lib/core/analytics/analytics_service.dart"
      provides: "Post-session computation of session_stats + marker_stats + power analytics + memory analytics + network analytics"
      exports: ["class AnalyticsService", "Future<void> computeSessionStats(String sessionId)", "Future<void> computeMarkerStats(String sessionId)"]
    - path: "ios_agents/collector.py"
      provides: "Python subprocess streaming iOS metrics as JSON lines to stdout"
    - path: "lib/core/services/ios_service.dart"
      provides: "Python subprocess lifecycle management, stdout JSON parsing, MetricSample mapping"
      exports: ["class IosService", "Stream<MetricSample> start(String udid, String bundleId)"]
  key_links:
    - from: "lib/core/analytics/analytics_service.dart"
      to: "lib/core/database/metric_dao.dart"
      via: "query metric_samples for session time range"
      pattern: "metricDao.*query"
    - from: "lib/core/analytics/analytics_service.dart"
      to: "lib/core/database/session_stats_dao.dart"
      via: "upsert computed session_stats row"
      pattern: "sessionStatsDao.*upsert"
    - from: "lib/core/services/ios_service.dart"
      to: "ios_agents/collector.py"
      via: "Python subprocess launch with udid + bundle_id args"
      pattern: "collector\\.py"
---

<objective>
Build post-session analytics engine computing all §6 metrics (FPS stats, power energy math, memory trends, network totals, per-marker stats) from saved metric_samples. Build full iOS pyidevice support on macOS: collector.py streaming JSON, IosService subprocess manager, MetricSample mapping. D-01: iOS built alongside Android.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@UNIFIED-SPEC.md lines 1167-1430 (§6.1 FPS Analytics, §6.2 Per-Marker Stats, §6.3 Session-Level Stats, §6.4 Session Comparison Delta, §6.5 Launch Complete Marker, §6.6 Power Analytics, §6.7 Memory Analytics, §6.8 Network Analytics)
@UNIFIED-SPEC.md lines 996-1036 (§5.10 iOS Metrics via pyidevice — architecture, JSON field mapping, IosService contract)
@UNIFIED-SPEC.md lines 501-527 (§4.3 iOS metrics table)

<interfaces>
Already exist:
- MetricDao.queryBySession(String sessionId) → List<MetricSample> (from lib/core/database/metric_dao.dart)
- SessionStatsDao, MarkerStatsDao, MarkerDao (from lib/core/database/)
- MetricSample model (from lib/core/models/metric_sample.dart)
- Session, SessionStats, MarkerStats models (from lib/core/models/)
- AdbService._runAdb() pattern for subprocess management (from lib/core/services/adb_service.dart)
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Build FpsAnalytics + AnalyticsService with full TDD and all §6 algorithms</name>
  <files>
    test/unit/fps_analytics_test.dart
    lib/core/analytics/fps_analytics.dart
    test/unit/comparison_analytics_test.dart
    lib/core/analytics/comparison_analytics.dart
    lib/core/analytics/analytics_service.dart
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 1167-1460 (§6.1-6.8 all analytics algorithms, formulas, acceptance criteria)
  </read_first>
  <behavior>
    FPS Analytics:
    - Test 1: Empty list → all fields return 0.0
    - Test 2: 99 × 60fps + 1 × 5fps → one_percent_low ≈ 5.0 (±0.1)
    - Test 3: 5 × 30fps + 95 × 60fps → p95_frame_time_ms ≈ 33.3ms (±1.0ms)
    - Test 4: 100 × 60fps → stability_pct = 100.0
    - Test 5: [58.0, 59.0, 62.0] → histogram key `55` = 3 (5fps bucket size)
    - Test 6: [20.0, 30.0, 60.0] → min_fps = 20.0, max_fps = 60.0
    - Test 7: All 60fps → variability_index = 0.0
    - Test 8: [60, 30, 60, 30, 60] → variability_index ≈ 30.0

    Comparison Analytics:
    - Test 1: Session A fps_median=60.0, B fps_median=54.0 → is_regression=true, delta_percent ≈ -10%
    - Test 2: Session A cpu_avg=20.0, B cpu_avg=25.0 → is_regression=true (higher CPU is regression)
    - Test 3: Session A stability=90.0, B stability=85.0 → is_regression=true (lower stability is regression)
  </behavior>
  <action>
    RED phase: Create test files. Tests must FAIL first.

    GREEN phase — FPS Analytics (`lib/core/analytics/fps_analytics.dart`):
    1. `FpsAnalytics` class with static `FpsStats compute(List<double> samples)`.
    2. All algorithms per §6.1 exactly:
       a. **Median**: Sort ascending. Odd count → middle. Even count → mean of two middle.
       b. **Min/Max**: `samples.reduce(min)` / `samples.reduce(max)`. Return 0 for empty.
       c. **1% Low**: `count = (len * 0.01).ceil()`, min 1, max len. Sort ascending. `mean(samples[0..count-1])`.
       d. **95th Frame Time**: Sort ascending. `idx = (len * 0.05).floor()`, clamped to [0, len-1]. `fps_5th = sorted[idx]`. `p95_frame_time_ms = 1000.0 / fps_5th` if fps_5th > 0, else 0.
       e. **Stability %**: `lo = median × 0.8`, `hi = median × 1.2`. Count where lo ≤ fps ≤ hi. `(count / len) × 100`.
       f. **Histogram**: `bucket_size = 5`. `bucket_key = (fps / 5).floor() * 5`. Return Map<int, int> → JSON string for DB.
       g. **Variability Index**: `diffs = [abs(samples[i] - samples[i-1]) for i in 1..len-1]`. `mean(diffs)` if len ≥ 2 else 0.0.
       h. **Frame Ratio Jank Total**: Sum of `jank_ratio_count` across all metric_samples (passed in separately — not computed from fps list).
    3. `FpsStats` data class: median, min, max, onePercentLow, p95FrameTimeMs, stabilityPct, histogramJson, variabilityIndex, frameRatioJankTotal.

    GREEN phase — Comparison Analytics (`lib/core/analytics/comparison_analytics.dart`):
    1. `ComparisonAnalytics` class with `List<MetricDelta> compare(SessionStats a, SessionStats b)`.
    2. Per §6.4: compare FPS Median, FPS 1% Low, FPS Stability, Frame Time P95, CPU Avg, Memory Peak, Jank/min, Big Jank Total, GPU Avg.
    3. `MetricDelta`: metric (String), valueA (double), valueB (double), delta (double), deltaPercent (double), isRegression (bool).
    4. Regression rules: FPS lower=regression, CPU/Memory/Jank higher=regression, Stability lower=regression.
    5. Regression indicators: ≥5% = red (🔴), 1-5% = yellow (🟡), improvement = green (🟢), no change = dash (—).

    GREEN phase — Analytics Service (`lib/core/analytics/analytics_service.dart`):
    1. `AnalyticsService` class takes Database reference.
    2. `Future<SessionStats> computeSessionStats(String sessionId)` — called after session stop:
       a. Query all metric_samples for session ordered by timestamp.
       b. Extract fps list (non-null values). Call FpsAnalytics.compute(fpsList) → populate fps_median through fps_histogram.
       c. cpu_avg_pct = mean(cpu_app_pct non-null). cpu_peak_pct = max(cpu_app_pct non-null). Same for freq_norm fields.
       d. Memory: avg/peak for pss_kb and each subsection. growth_kb = last - first. Trend slope via simple linear regression on pss_kb vs timestamp. Flag if slope > 100 KB/min over session > 5 min.
       e. GPU: gpu_avg_pct = mean(non-null), gpu_peak_pct = max(non-null).
       f. Battery/Power per §6.6:
          - Filter out charging samples. If has_charging_period flag any charging sample.
          - mah_consumed: trapezoidal integration of abs(mA) over time.
          - avg_power_mw: mean(V × abs(mA)) for samples where both non-null.
          - total_power_mwh: trapezoidal integration of V × abs(mA) over time.
          - estimated_playtime_h: battery_capacity_mah / avg_current_ma (if both > 0).
          - battery_drain_pct: first_pct - last_pct. battery_drain_per_hour: drain / hours.
          - battery_temp_max_c: max(temp_c non-null).
       g. Jank: sum all jank_count/jank_small_count/jank_big_count. jank_per_min = jank_total / (duration_minutes).
       h. Network per §6.8: net_total_tx_kb = (last_cumulative - first_cumulative) / 1024. Same for wifi/cellular/other. Throughput = total_kb / duration_s.
       i. thermal_peak = max(thermal_status non-null).
       j. duration_ms = last_timestamp - first_timestamp. launch_complete_ms from launch_complete marker.
       k. Upsert into session_stats table.
    3. `Future<void> computeMarkerStats(String sessionId)` — per §6.2:
       a. Query all range markers (ended_at IS NOT NULL) for session.
       b. For each marker: query metric_samples BETWEEN started_at AND ended_at.
       c. If empty → skip (no row inserted).
       d. Compute fps stats, cpu_avg, mem_peak, gpu_avg, battery_drain, jank totals, jank/min, duration_ms.
       e. Insert one marker_stats row per marker.
    4. Integration: Called from session stop flow. Must complete before user sees session detail.

    REFACTOR: Extract trapezoidal integration helper. Extract mean/max on nullable lists.

    DO NOT: Run analytics during active recording (post-session only per §6).
    DO NOT: Use charging samples in power math (§6.6 charging filter).
    DO NOT: Skip markers with 0 samples — just skip insertion per §6.2.
  </action>
  <acceptance_criteria>
    - `test/unit/fps_analytics_test.dart` passes all 8 test cases
    - `test/unit/comparison_analytics_test.dart` passes all 3 test cases
    - `lib/core/analytics/analytics_service.dart` exports AnalyticsService with computeSessionStats and computeMarkerStats
    - Trapezoidal integration used for mAh and mWh computation
    - Charging samples excluded from power analytics (has_charging_period flag set)
    - Line regression for memory trend slope computation
    - session_stats row exists in DB immediately after computeSessionStats completes
    - `flutter test test/unit/fps_analytics_test.dart test/unit/comparison_analytics_test.dart` — all green
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter test test/unit/fps_analytics_test.dart test/unit/comparison_analytics_test.dart && flutter analyze lib/core/analytics/</automated>
  </verify>
  <done>All §6 analytics algorithms implemented with TDD. Post-session computation produces session_stats and marker_stats rows. Comparison delta engine works with regression detection.</done>
</task>

<task type="auto">
  <name>Task 2: Build iOS pyidevice support — collector.py, device_list.py, app_list.py, and IosService</name>
  <files>
    ios_agents/collector.py
    ios_agents/device_list.py
    ios_agents/app_list.py
    ios_agents/requirements.txt
    lib/core/services/ios_service.dart
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 996-1036 (§5.10 iOS Metrics via pyidevice — architecture, field mapping, IosService contract, acceptance criteria)
    @UNIFIED-SPEC.md lines 501-527 (§4.3 iOS metrics table with DTX services)
    @UNIFIED-SPEC.md lines 1076-1097 (§5.11 iOS static device + app data collection)
  </read_first>
  <action>
    1. Finalize `ios_agents/requirements.txt`:
       ```
       py-ios-device>=2.0.0
       ```
    
    2. Implement `ios_agents/collector.py` — fully functional Python 3.10+ script:
       - Usage: `python3 collector.py <udid> <bundle_id>`
       - Uses `py_ios_device` (pyidevice) library.
       - Establishes DTXProtocol connections to the following instruments:
         a. `graphics.opengl` → FPS data. Parse frame timestamps.
         b. `sysmontap` → CPU (`cpuUsage` — NOT normalized per core), memory (`physFootprint`), thread list (top 8 by CPU).
         c. `memdetail` → memory subsections (App/Other/Total breakdown).
         d. Battery instrument → `batteryPct`, `batteryCurrent` (mA, null for iPhone 8+), `batteryVoltage` (mV), `batteryTemp` (°C).
         e. `processInfo` → `batteryState` (unplugged/charging/full), `thermalState` (0-3), `networkInterface`.
         f. `networking` → per-interface TX/RX bytes (cumulative).
         g. `gpu_counters` (Metal) → GPU % time busy.
       - Jank computation in Python:
         a. Maintain rolling window of last 3 frame times.
         b. 3-tier jank classification using same thresholds as Android (refresh_period=16.67ms for 60Hz iOS default unless device reports otherwise).
         c. Frame ratio jank (Γ=L/R) using same formula.
         d. Build frametimes JSON array per 1-second window.
       - Output: writes one JSON object per second to stdout, newline-delimited.
       - JSON format per §5.10 mapping table exactly:
         ```json
         {"ts": 1712345678000, "fps": 58.3, "jank": {"small": 15, "jank": 3, "big": 0, "ratio": 1}, "frametimes": [16.67, 16.91, ...], "cpu": 23.4, "cpu_threads": [{"tid": 123, "name": "UnityMain", "pct": 18.2}, ...], "mem_bytes": 536870912, "mem_subsections": {"app": 200, "other": 300, "total": 500}, "bat_pct": 87, "bat_ma": null, "bat_mv": 3850, "bat_temp_c": 31.2, "charging": false, "charging_source": "none", "wifi": true, "net_tx": 123456, "net_rx": 654321, "thermal": 0, "gpu_pct": 41.0}
         ```
       - Error handling: catch exceptions per instrument, set that metric group to null, continue collection.
       - Graceful shutdown: handle SIGTERM (Flutter sends on stop), write final line `{"status": "stopped"}`, exit 0.
       - If pyidevice import fails: print `{"error": "pyidevice not installed", "help": "pip3 install py-ios-device"}` to stdout, exit 1.
    
    3. Implement `ios_agents/device_list.py`:
       - Usage: `python3 device_list.py`
       - Lists connected iOS devices via pyidevice.
       - Output: JSON array to stdout: `[{"udid": "...", "name": "iPhone 15", "model": "iPhone16,1", "os_version": "17.2.1", "connected": true}]`.
    
    4. Implement `ios_agents/app_list.py`:
       - Usage: `python3 app_list.py <udid>`
       - Lists installed third-party apps via `installation_proxy`.
       - Output: JSON array to stdout: `[{"bundle_id": "com.example.app", "name": "Example App", "version": "1.2.3", "build": "42"}]`.
    
    5. Create `lib/core/services/ios_service.dart` — `IosService` class:
       - Constructor: takes path to python3, path to ios_agents/ directory.
       - `Future<List<IosDevice>> discoverDevices()` — runs `device_list.py`, parses JSON output. Returns list of IosDevice objects.
       - `Future<List<IosAppInfo>> listApps(String udid)` — runs `app_list.py <udid>`, parses JSON output.
       - `Future<Stream<MetricSample>> start(String udid, String bundleId)` — launches `collector.py <udid> <bundleId>` as a Process.
         a. Read stdout line by line via `utf8.decoder` stream transformer.
         b. Parse each line as JSON.
         c. If JSON parse fails → skip line, log, continue (§5.10 acceptance criteria).
         d. If line has `"error"` key → emit error on stream, stop.
         e. If line has `"status": "stopped"` → close stream normally.
         f. Map JSON fields to MetricSample per §5.10 mapping table exactly:
            - `fps` → fps
            - `jank.small` → jank_small_count
            - `jank.jank` → jank_count
            - `jank.big` → jank_big_count
            - `jank.ratio` → jank_ratio_count
            - `frametimes` → frametimes_json
            - `cpu` → cpu_app_pct (iOS: NOT divided by cores)
            - `mem_bytes` / 1024 → memory_pss_kb
            - `mem_subsections.app` → memory_java_kb (repurposed column)
            - `mem_subsections.other` → memory_system_kb (repurposed column)
            - `bat_pct` → battery_pct
            - `bat_ma` → battery_ma
            - `bat_mv` → battery_mv
            - `bat_temp_c` → battery_temp_c
            - `charging` → charging (bool→int 0/1)
            - `charging_source` → charging_source
            - `wifi` → wifi_active (bool→int 0/1)
            - `net_tx` → net_tx_bytes
            - `net_rx` → net_rx_bytes
            - `thermal` → thermal_status
            - `gpu_pct` → gpu_pct
         g. Emit MetricSample on stream.
       - Stop: send SIGTERM to process, wait 3s, SIGKILL if still running.
       - On subprocess exit unexpectedly: log stderr, stop stream, mark session as completed.
       - pyidevice not installed: show modal with install guide: `pip3 install py-ios-device`.
       - All D-05, D-06: iOS code must work on macOS (not tested on Windows). Guard with platform check — if not macOS, show "iOS profiling requires macOS host".
    
    6. Update iOS static data collection: IosService should call `pyidevice info` commands at session start to populate `devices` table with iOS device info per §5.11 iOS section.

    DO NOT: Attempt to run Python on non-macOS hosts for iOS — hard guard with Platform.isMacOS check.
    DO NOT: Normalize iOS CPU% by core count (per §5.2 iOS difference — preserve raw value).
    DO NOT: Use blocking I/O — all Process interaction is async streams.
  </action>
  <acceptance_criteria>
    - `ios_agents/collector.py` produces valid JSON lines matching §5.10 field mapping when run on macOS with iOS device
    - `ios_agents/device_list.py` lists connected iOS devices as JSON array
    - `ios_agents/app_list.py` lists installed apps as JSON array
    - `lib/core/services/ios_service.dart` manages Python subprocess lifecycle (start → stream → SIGTERM → SIGKILL)
    - Malformed JSON line from collector.py → skipped, next line processed normally
    - Subprocess crash after 10 samples → session stops, 10 samples saved
    - pyidevice not installed → install guide shown before any recording attempt
    - Platform.isMacOS guard prevents iOS profiling on Windows/Linux
    - `flutter analyze lib/core/services/ios_service.dart` — zero errors
    - iOS MetricSample has correct field mapping: cpu_app_pct NOT normalized, mem_bytes÷1024→memory_pss_kb
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && python3 -c "import ast; ast.parse(open('ios_agents/collector.py').read()); print('collector.py syntax OK')" && flutter analyze lib/core/services/ios_service.dart</automated>
  </verify>
  <done>iOS pyidevice support complete: collector.py streams JSON metrics, IosService manages subprocess and maps to MetricSample. Works on macOS. Install guide shown when pyidevice missing.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Python subprocess stdout → IosService | Newline-delimited JSON from external Python process. Malformed or crafted JSON. |
| iOS device → collector.py | DTXProtocol instrument data from iOS device. |
| SQLite query → AnalyticsService | MetricSample data read from DB for computation. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-14 | Tampering | ios_service.dart — JSON injection via collector.py stdout | mitigate | Each stdout line validated as JSON before parsing. Failed parses silently skipped. Field values use tryParse for numerics. Line length capped at 64KB. |
| T-01-15 | Denial of Service | ios_service.dart — zombie Python subprocess | mitigate | Force kill (SIGKILL) after 3s SIGTERM timeout. Subprocess PID tracked and cleaned up on app exit via WidgetsBindingObserver. |
| T-01-16 | Information Disclosure | analytics_service.dart — analytics computation in memory | accept | Analytics computed in memory from local SQLite data. No data transmission. Same trust domain as the database. |
| T-01-17 | Elevation of Privilege | collector.py — pyidevice device access | accept | Requires user-authorized USB connection with Developer Mode enabled on iPhone. Apple's security model governs device access. |
</threat_model>

<verification>
- Unit tests: all analytics tests pass (FPS, comparison)
- iOS: Run on macOS with connected iPhone → collector.py streams valid JSON lines → IosService parses and emits MetricSample objects
- After session stop: session_stats row exists in DB with populated FPS/power/memory/network fields
- Marker stats computed for all range markers
</verification>

<success_criteria>
1. Post-session analytics compute all §6 stats (FPS, CPU, memory, battery/power, jank, network, thermal, GPU) and upsert into session_stats table
2. Per-marker stats auto-computed for all range markers on session stop
3. Power analytics: mAh consumed via trapezoidal integration, avg mW, total mWh, estimated playtime
4. iOS collector.py streams 14+ metric fields as newline-delimited JSON matching §5.10 field mapping
5. IosService manages Python subprocess lifecycle with clean start/stop/error handling
6. iOS MetricSample data saves to same SQLite tables as Android data
7. All analytics algorithms pass their §14.1 unit tests
</success_criteria>

<output>
After completion, create `.planning/phases/01-v1-0-external-profiling-mvp/04-SUMMARY.md`
</output>
