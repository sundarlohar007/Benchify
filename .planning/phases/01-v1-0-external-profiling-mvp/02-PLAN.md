---
phase: "01"
plan: "02"
type: execute
wave: 2
depends_on: ["01-01"]
files_modified:
  - lib/core/parsers/fps_parser.dart
  - lib/core/parsers/cpu_parser.dart
  - lib/core/parsers/memory_parser.dart
  - lib/core/parsers/battery_parser.dart
  - lib/core/parsers/network_parser.dart
  - lib/core/parsers/thermal_parser.dart
  - lib/core/parsers/gpu_parser.dart
  - lib/core/services/metric_collector.dart
  - test/unit/fps_parser_test.dart
  - test/unit/cpu_parser_test.dart
  - test/unit/memory_parser_test.dart
  - test/unit/battery_parser_test.dart
  - test/unit/network_parser_test.dart
  - test/unit/thermal_parser_test.dart
  - test/unit/gpu_parser_test.dart
autonomous: true
requirements: [MVP-05, MVP-06, MVP-07, MVP-08, MVP-09, MVP-10, MVP-11]

must_haves:
  truths:
    - "FPS parser extracts fps=60.0 +/-2% from 10 valid frames at 16.67ms average"
    - "FPS parser correctly classifies 3-tier jank: 130ms frame triggers big_jank, 90ms frame triggers jank, 20ms on 60Hz triggers small_jank"
    - "Frame ratio jank model (gamma=L/R) correctly counts transitions: 1->2->1->2 over 4 frames produces count=3"
    - "CPU parser computes cpu_app_pct=50.0 when delta_pid_ticks=500 and delta_total_ticks=1000"
    - "CPU parser correctly computes normalized CPU: 2 cores online at 500MHz, max=2GHz, cpu_app_pct=50% => cpu_app_pct_freq_norm=6.25%"
    - "Memory parser extracts all 7 PSS subsections (total, java, native, graphics, stack, code, system) from dumpsys meminfo output"
    - "Battery parser extracts pct=87, temp=31.2C, mA=540, mV=3850 from dumpsys battery + sysfs files"
    - "All parsers return null (not throw) when ADB command fails, times out, or returns malformed output"
    - "MetricCollector runs 1Hz loop, calls all parsers, emits Stream<MetricSample> with first-sample CPU returning null (no delta yet)"
  artifacts:
    - path: "lib/core/parsers/fps_parser.dart"
      provides: "FPS + 3-tier jank + frame-ratio jank + frametimes parsing"
      exports: ["class FpsParser", "FpsResult parse(String)", "JankCounts", "FrameTimings"]
    - path: "lib/core/parsers/cpu_parser.dart"
      provides: "CPU app/system parsing with delta tracking and frequency normalization"
      exports: ["class CpuParser", "CpuResult parse(String pidStat, String procStat)", "CpuFreqResult parseCoreFreqs(String)"]
    - path: "lib/core/parsers/memory_parser.dart"
      provides: "Memory PSS subsection parsing from dumpsys meminfo"
      exports: ["class MemoryParser", "MemoryResult parse(String meminfoOutput)"]
    - path: "lib/core/services/metric_collector.dart"
      provides: "1Hz sample loop emitting Stream<MetricSample> with ring buffer"
      exports: ["class MetricCollector", "Stream<MetricSample> start(String deviceId, String package)"]
  key_links:
    - from: "lib/core/services/metric_collector.dart"
      to: "lib/core/parsers/fps_parser.dart"
      via: "FpsParser.parse() called each 1Hz tick"
      pattern: "FpsParser"
    - from: "lib/core/services/metric_collector.dart"
      to: "lib/core/models/metric_sample.dart"
      via: "MetricSample constructed from parsed results"
      pattern: "MetricSample"
    - from: "lib/core/services/metric_collector.dart"
      to: "lib/core/services/adb_service.dart"
      via: "ADB commands executed through AdbService"
      pattern: "adbService"
    - from: "test/unit/fps_parser_test.dart"
      to: "lib/core/parsers/fps_parser.dart"
      via: "import for test subject"
      pattern: "import.*fps_parser"
</objective>

<objective>
Build all 7 metric parsers with TDD (per D-08) following §5 formulas exactly: FPS (3-tier jank + frame-ratio + frametimes), CPU (app/system/freq-norm/per-core states), Memory (PSS total + 7 subsections), Battery (pct/mA/mV/temp/charging), Network (per-interface WiFi/Cellular/Other), Thermal (0-3), GPU (Adreno/Mali). Then build MetricCollector 1Hz engine that wires all parsers into a Stream<MetricSample>. Critical path 100% test coverage per D-09.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/REQUIREMENTS.md (MVP-05 through MVP-11)
@UNIFIED-SPEC.md §§5.1-5.7 (lines 530-966) — exact parser algorithms, formulas, null contracts, acceptance criteria
@UNIFIED-SPEC.md §14.1 (lines 2859-2886) — unit test cases and coverage targets

<interfaces>
Already exist from Wave 1:
- AdbService._runAdb(List<String> args) → ProcessResult (from lib/core/services/adb_service.dart)
- MetricSample model with all 53 fields (from lib/core/models/metric_sample.dart)
- Database.Database reference available via Riverpod provider
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Build FPS parser + CPU parser with full TDD</name>
  <files>
    test/unit/fps_parser_test.dart
    lib/core/parsers/fps_parser.dart
    test/unit/cpu_parser_test.dart
    lib/core/parsers/cpu_parser.dart
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 534-700 (§5.1 FPS algorithm, 3-tier jank, frame ratio jank, frametimes; §5.2 CPU algorithm + freq normalization)
    @UNIFIED-SPEC.md lines 2859-2879 (§14.1 required test cases for fps_parser, fps_analytics)
  </read_first>
  <behavior>
    FPS Parser:
    - Test 1: Empty string input → fps=0.0, all jank counts=0
    - Test 2: Fewer than 3 lines → fps=0.0
    - Test 3: 10 valid frames averaging 16.67ms → fps within ±2% of 60.0
    - Test 4: Frame delta of 130ms → big_jank_count=1, jank_count=1, jank_small_count=1 (130ms > 125ms AND >83.3ms AND >refresh_period)
    - Test 5: Frame delta of 90ms → jank_count=1 (>83.3ms), jank_small_count=1 (>refresh_period), big_jank_count=0 (not >125ms)
    - Test 6: Frame delta of 20ms on 60Hz display (refresh=16.67ms) → jank_small_count=1, jank_count=0 (unless rolling avg triggers it)
    - Test 7: Frame delta of 150ms → excluded by outlier filter (≥100ms); fps denominator excludes it; no jank counted
    - Test 8: Frame ratio changes 1→2→1→2 over 4 frames → jank_ratio_count=3
    - Test 9: frametimes_json parses as array of double values, count matches fps within ±2

    CPU Parser:
    - Test 1: First sample → null returned for all CPU fields, snapshot stored
    - Test 2: delta_pid_ticks=500, delta_total_ticks=1000 → cpu_app_pct=50.0
    - Test 3: Malformed /proc/stat output → null returned, no exception
    - Test 4: Cores 0,1 online at 500MHz, cores 2,3 offline, max=2GHz/core, cpu_app_pct=50% → cpu_app_pct_freq_norm=6.25% (50% × 1000/8000)
    - Test 5: All cores online at max freq → cpu_app_pct_freq_norm equals cpu_app_pct (no change)
    - Test 6: sysfs glob parse fails → cpu_core_states_json=null, cpu_core_freqs_json=null, cpu_app_pct_freq_norm=null; base cpu_app_pct still works
  </behavior>
  <action>
    RED phase: Create test files first. Each test must FAIL before implementation starts.

    GREEN phase — FPS Parser (`lib/core/parsers/fps_parser.dart`):
    1. Create `FpsParser` class with static method `FpsResult parse(String surfaceFlingerOutput)`.
    2. Algorithm per §5.1 exactly:
       a. Split output on newlines. If < 3 lines → fps=0.0, all jank=0.
       b. Parse line 1 as `refresh_period_ns` (int), compute `refresh_period_ms = refresh_period_ns / 1_000_000`.
       c. For each line after line 1: split on tab, parse field at index 1 as `actual_present_ns` (int). Skip timestamps ≤ 0.
       d. For consecutive pairs: `delta_ms = (t_curr - t_prev) / 1_000_000`. Skip delta ≤ 0 or delta ≥ 100 (outlier filter).
       e. `fps = 1000.0 / mean(valid_deltas)` if len ≥ 1, else 0.0.
       f. Rolling window of last 3 valid frame times. For each new frame:
          - `jank_small`: delta_ms > refresh_period_ms
          - `jank_count`: delta_ms > 2 × mean(last_3) OR delta_ms > 83.3ms
          - `jank_big`: delta_ms > 2 × mean(last_3) OR delta_ms > 125ms
          - All three independent counters (big jank also increments jank and small)
       g. Frame ratio jank (Γ=L/R): L = delta_ms, R = refresh_period_ms. Γ_curr = ceil(L/R). If Γ_curr ≠ Γ_prev and Γ_prev set, increment jank_ratio_count. Store Γ_prev.
       h. Build frametimes_json array from valid delta_ms values.
    3. `FpsResult` contains: fps (double?), jank_small_count (int?), jank_count (int?), jank_big_count (int?), jank_ratio_count (int?), frametimes_json (String?).
    4. ALL fields null if input is null or parse fails entirely (ADB call failure). Return zero-FpsResult (all 0s) if parse succeeds but no valid frames.

    GREEN phase — CPU Parser (`lib/core/parsers/cpu_parser.dart`):
    1. `CpuParser` class with internal state (snapshot from previous call).
    2. `CpuResult parseProcessStat(String pidStat)`:
       a. Split on whitespace, extract utime (field 13), stime (field 14) as ints. `pid_ticks = utime + stime`.
       b. Store snapshot with timestamp. On first call: store only, return null for cpu_app_pct.
       c. On subsequent calls: `cpu_app_pct = (delta_pid_ticks / delta_total_ticks) × 100.0`, clamped to [0, 100].
    3. `CpuResult parseSystemStat(String procStat)`:
       a. Split first line (starts with "cpu ") on whitespace, skip label. Parse fields: user, nice, system, idle, iowait, irq, softirq (7 fields).
       b. `total_ticks = sum(all 7)`, `idle_ticks = idle + iowait`.
       c. First call: store snapshot, return null for cpu_system_pct.
       d. Subsequent: `cpu_system_pct = ((delta_total_ticks - delta_idle_ticks) / delta_total_ticks) × 100.0`.
    4. `CpuFreqResult parseCoreFreqs(String sysfsOutput)` per §5.2.1 algorithm:
       a. Split on `---`, parse per-core blocks: online (1/0), scaling_cur_freq (kHz), cpuinfo_max_freq (kHz).
       b. Cache `total_max_cycles` (first read, constant per boot).
       c. `core_states_json` = JSON array of online states.
       d. `core_freqs_json` = JSON array of cur freq per core (0 if offline).
       e. `cpu_norm_factor = total_avail_cycles / total_max_cycles`.
       f. `cpu_app_pct_freq_norm = cpu_app_pct × cpu_norm_factor`.
       g. ALL fields null if sysfs parse fails; base CPU% continues.

    REFACTOR: Extract common parsing utilities (nullable int/double parsing, JSON array building). Ensure all parse methods handle null/malformed input gracefully.

    DO NOT: Use any external libraries beyond dart:convert (for JSON). No third-party parser packages.
    DO NOT: Block on any I/O — all parsing is pure synchronous math on string input.
    DO NOT: Fabricate values — if a metric cannot be parsed, return null for that specific field.
  </action>
  <acceptance_criteria>
    - `test/unit/fps_parser_test.dart` contains all 9 test cases from behavior block, all passing
    - `test/unit/cpu_parser_test.dart` contains all 6 test cases from behavior block, all passing
    - `lib/core/parsers/fps_parser.dart` exports `FpsParser` and `FpsResult` with all fields (fps, jank_small_count, jank_count, jank_big_count, jank_ratio_count, frametimes_json)
    - `lib/core/parsers/cpu_parser.dart` exports `CpuParser` and `CpuResult` (cpu_app_pct, cpu_system_pct, cpu_app_pct_freq_norm, cpu_cores_json, cpu_core_states_json, cpu_core_freqs_json)
    - `flutter test test/unit/fps_parser_test.dart test/unit/cpu_parser_test.dart` — all tests pass
    - No test uses real ADB output (all synthetic test inputs)
    - All parse methods return null for null/malformed input, never throw
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter test test/unit/fps_parser_test.dart test/unit/cpu_parser_test.dart</automated>
  </verify>
  <done>FPS and CPU parsers implemented with 100% branch coverage. All §14.1 required test cases pass. Parsers handle null input gracefully.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Build Memory parser + Battery parser with full TDD</name>
  <files>
    test/unit/memory_parser_test.dart
    lib/core/parsers/memory_parser.dart
    test/unit/battery_parser_test.dart
    lib/core/parsers/battery_parser.dart
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 724-884 (§5.3 Memory parse algorithm with PSS subsections mapping; §5.4 Battery with dumpsys + sysfs)
  </read_first>
  <behavior>
    Memory Parser:
    - Test 1: TOTAL PSS line "TOTAL PSS: 524288 kB" → memory_pss_kb = 524288
    - Test 2: Native Heap line "45120" → memory_native_kb = 45120
    - Test 3: EGL mtrack "52224" + GL mtrack "24576" → memory_graphics_kb = 76800
    - Test 4: Code subsection = .so mmap (38400) + .jar mmap (0) + .apk mmap (21504) + .dex mmap (18432) + .oat mmap (15360) + .art mmap (4096) → memory_code_kb = 97792
    - Test 5: Package not running / empty output → all fields null
    - Test 6: Android 6 format (Dalvik Heap instead of Java Heap) → memory_java_kb = Dalvik Heap PSS value

    Battery Parser:
    - Test 1: dumpsys battery level: 87 → battery_pct = 87
    - Test 2: temperature: 312 → battery_temp_c = 31.2
    - Test 3: voltage_now = 3850000 → battery_mv = 3850.0
    - Test 4: current_now = -540000 → battery_ma = 540.0 (absolute value stored)
    - Test 5: AC powered: true → charging = true, charging_source = "AC"
    - Test 6: USB powered: true, wireless powered: false → charging_source = "USB"
    - Test 7: Missing current_now file → battery_ma = null, no exception
    - Test 8: Neither connectivity nor wifi parse succeeds → wifi_active = null
    - Test 9: status: 5 (Full) → charging = true
    - Test 10: status: 3 (Discharging), all powered: false → charging = false
  </behavior>
  <action>
    RED phase: Create test files with all test cases. Tests must FAIL first.

    GREEN phase — Memory Parser (`lib/core/parsers/memory_parser.dart`):
    1. `MemoryParser` class with `MemoryResult parse(String meminfoOutput)`.
    2. Algorithm per §5.3 steps 1-5 exactly:
       a. Find header line containing "Pss" and "Private" columns (skip ASCII art row below).
       b. For each line until TOTAL row: parse label (multi-word tokens before first numeric column) and PSS Total (field at index 1 after label) as int KB.
       c. Map labels to schema: "Native Heap"→memory_native_kb, "Dalvik Heap"/"Java Heap"→memory_java_kb, "EGL mtrack"+"GL mtrack"→sum→memory_graphics_kb, "Stack"→memory_stack_kb, ".so mmap"+".jar mmap"+".apk mmap"+".dex mmap"+".oat mmap"+".art mmap"→sum→memory_code_kb, all other labels→sum→memory_system_kb.
       d. TOTAL PSS line → memory_pss_kb.
       e. If individual subsection label missing → that field null, total may still parse.
       f. If entire dump fails → all fields null.

    GREEN phase — Battery Parser (`lib/core/parsers/battery_parser.dart`):
    1. `BatteryParser` class with three separate parse methods:
       a. `BatteryLevelResult parseDumpsysBattery(String output)` — extracts level (battery_pct as int), temperature (÷10 → double °C), voltage (direct mV), AC/USB/Wireless/Dock powered booleans, status (1-5).
       b. `BatteryCurrentResult parseCurrentNow(String sysfsOutput)` — value in µA ÷ 1000 → mA (absolute value). null if file missing.
       c. `BatteryVoltageResult parseVoltageNow(String sysfsOutput)` — value in µV ÷ 1000 → mV. null if file missing. Prefer this over dumpsys voltage.
       d. `WifiResult parseWifiState(String connectivityOutput)` — parse "NetworkInfo: type: WIFI" → bool. Fallback: "Wi-Fi is enabled/disabled". null if both fail.
       e. Composite charging detection: any of AC/USB/Wireless/Dock = true OR status 2/5 → charging=true. charging_source = first true source or "none".
    3. All parse methods return null for null/malformed input, never throw.

    REFACTOR: Extract common parsing for multi-column whitespace-delimited output. Ensure all nullable returns propagate correctly.

    DO NOT: Make any network calls. All parsing is pure synchronous string processing.
    DO NOT: Use hardcoded device-specific offsets — parse by label name, not line position.
  </action>
  <acceptance_criteria>
    - `test/unit/memory_parser_test.dart` contains all 6 test cases, all passing
    - `test/unit/battery_parser_test.dart` contains all 10 test cases, all passing
    - `lib/core/parsers/memory_parser.dart` exports MemoryParser and MemoryResult with all 8 fields (pss_kb, java_kb, native_kb, graphics_kb, stack_kb, code_kb, system_kb, webview_kb)
    - `lib/core/parsers/battery_parser.dart` exports BatteryParser and BatteryResult (pct, ma, mv, temp_c, charging bool, charging_source text, wifi_active bool)
    - `flutter test test/unit/memory_parser_test.dart test/unit/battery_parser_test.dart` — all green
    - Memory graphics = EGL mtrack + GL mtrack sum (not individual)
    - Memory code = sum of all 6 mmap families (so, jar, apk, dex, oat, art)
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter test test/unit/memory_parser_test.dart test/unit/battery_parser_test.dart</automated>
  </verify>
  <done>Memory parser extracts all 7 PSS subsections. Battery parser handles all 5 dumpsys fields + 2 sysfs files + WiFi state. 100% branch coverage.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Build Network + Thermal + GPU parsers, then build MetricCollector engine wiring all parsers</name>
  <files>
    test/unit/network_parser_test.dart
    lib/core/parsers/network_parser.dart
    test/unit/thermal_parser_test.dart
    lib/core/parsers/thermal_parser.dart
    test/unit/gpu_parser_test.dart
    lib/core/parsers/gpu_parser.dart
    lib/core/services/metric_collector.dart
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 887-966 (§5.5 Network per-interface parse algorithm; §5.6 Thermal; §5.7 GPU Adreno/Mali paths)
    @UNIFIED-SPEC.md lines 396-500 (§4.1 MetricCollector concept — 1Hz loop)
  </read_first>
  <behavior>
    Network Parser:
    - Test 1: Two interfaces (wlan0=TX1024 RX2048, rmnet0=TX512 RX128) → net_wifi_tx_bytes=1024, net_wifi_rx_bytes=2048, net_cellular_tx_bytes=512, net_cellular_rx_bytes=128, net_tx_bytes=1536, net_rx_bytes=2176
    - Test 2: Loopback (lo) excluded from all totals
    - Test 3: First sample → all cumulative stored, deltas null
    - Test 4: Device with WiFi off (no wlan*) → net_wifi_* = 0 cumulative, not null

    Thermal Parser:
    - Test 1: "Status: normal" → thermal_status = 0
    - Test 2: "Status: critical" → thermal_status = 3
    - Test 3: Both commands fail → null, no crash

    GPU Parser:
    - Test 1: Adreno output "4823 10000" → gpu_pct = 48.23
    - Test 2: All paths fail → null returned, no crash
    - Test 3: Mali device utilization integer 75 → gpu_pct = 75.0
  </behavior>
  <action>
    RED phase: Create test files. Tests must FAIL first.

    GREEN phase — Network Parser (`lib/core/parsers/network_parser.dart`):
    1. `NetworkParser` class, `NetworkResult parse(String procNetDev)`.
    2. Algorithm per §5.5 exactly: skip first 2 header lines. Split each line on whitespace → interface name + RX bytes (field 0) + TX bytes (field 8). Skip "lo". Classify by name prefix: wlan*/wifi*/nan*→WiFi, rmnet*/ccmni*/pdp*/ppp*→Cellular, everything else→Other. Sum per category. Populate all 10 fields: net_tx_bytes, net_rx_bytes, net_wifi_tx_bytes, net_wifi_rx_bytes, net_cellular_tx_bytes, net_cellular_rx_bytes, net_other_tx_bytes, net_other_rx_bytes.

    GREEN phase — Thermal Parser (`lib/core/parsers/thermal_parser.dart`):
    1. `ThermalParser` class, `ThermalResult parseThermalService(String output)` — parse "Status:" field, map to 0-3. null if unparseable.
    2. `ThermalResult parseGetprop(String output)` — try `sys.thermal.state` as integer 0-3. null if fails.

    GREEN phase — GPU Parser (`lib/core/parsers/gpu_parser.dart`):
    1. `GpuParser` class, `GpuResult parseAdreno(String output)` — "busy total" → (busy / total) × 100.0.
    2. `GpuResult parseMaliUtil(String output)` — integer 0-100 directly.
    3. `GpuResult parseAny(String systemOutput)` — tries both formats, returns first successful. null if all fail. Never fabricate.

    GREEN phase — MetricCollector (`lib/core/services/metric_collector.dart`):
    1. `MetricCollector` class takes `AdbService` and device serial + package name in constructor.
    2. `start()` returns `Stream<MetricSample>` via `StreamController<MetricSample>.broadcast()`.
    3. 1Hz loop using `Stream.periodic(Duration(seconds: 1))`:
       a. FPS: Discover SurfaceFlinger layer name (try package name, scan full output, topmost visible — §5.1 layer discovery). Run `dumpsys SurfaceFlinger --latency <layer>`. Call FpsParser.parse().
       b. CPU: Run combined `cat /proc/<pid>/stat && echo --- && cat /proc/stat`. Also run sysfs glob for core freq/states (§5.2.1). Call CpuParser for both.
       c. Memory: Run `dumpsys meminfo <package>`. Call MemoryParser.parse().
       d. Battery: Run `dumpsys battery`, `cat current_now`, `cat voltage_now`. Call BatteryParser for each. Derive charging + wifi from same dumpsys output.
       e. Network: Run `cat /proc/net/dev`. Call NetworkParser.parse().
       f. Thermal: Run `dumpsys thermalservice`. Fallback to `getprop sys.thermal.state`. Call ThermalParser.
       g. GPU: Run Adreno path, fallback to Mali paths. Call GpuParser.
       h. All ADB calls use 3-second timeout per §F. Failed calls → null for that metric group.
       i. Construct `MetricSample` from all parsed results. Emit to stream.
    4. PID discovery: At session start, run `adb shell pidof <package>` (or `ps -A | grep <package>`). Cache PID. If PID dies, try rediscover once. If still not found, emit samples with null CPU/memory.
    5. Ring buffer: Maintain internal `List<MetricSample>` of max 300 entries (60s at 1Hz). New sample appended, oldest dropped if > 300. Expose via `List<MetricSample> get buffer`.
    6. Stop: Cancel periodic timer. Close StreamController. Return list of all collected samples.

    DO NOT: Block UI thread — all ADB calls are async. Use `Future`/`await` throughout.
    DO NOT: Continue collection if 5 consecutive total failures (ADB dead, device disconnected) — emit error on stream and stop.
    DO NOT: Fabricate any metric. If parser returns null, the MetricSample field is null. Log the failure.
  </action>
  <acceptance_criteria>
    - All 3 parser test files pass (network: 4 cases, thermal: 3 cases, gpu: 3 cases)
    - `lib/core/services/metric_collector.dart` exports `MetricCollector` class with `start()` returning `Stream<MetricSample>`
    - MetricCollector calls all 7 parsers each tick, handles failures independently per parser
    - First CPU sample returns null for cpu_app_pct and cpu_system_pct (no delta yet)
    - 3-second timeout on all ADB calls via AdbService
    - Ring buffer max size 300 (enforced in append logic)
    - `flutter test test/unit/` — all 7 parser test files pass
    - `flutter analyze lib/core/` — zero errors
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter test test/unit/parser/ test/unit/network_parser_test.dart test/unit/thermal_parser_test.dart test/unit/gpu_parser_test.dart && flutter analyze lib/core/parsers/ lib/core/services/metric_collector.dart</automated>
  </verify>
  <done>All 7 parsers implemented with 100% branch coverage per D-09. MetricCollector 1Hz engine emits Stream<MetricSample> with all 53 fields populated from parsers. Ring buffer holds max 300 samples. First-sample CPU null handling correct.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| ADB shell output → Parser functions | String output from Android device enters parsing pipeline. Malicious/crafted output could cause parsing errors. |
| Ring buffer → Chart widget | In-memory data structure read by UI layer. Buffer overflow could cause memory pressure. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-06 | Tampering | All parsers — crafted ADB output | mitigate | All numeric parsing uses int.tryParse/double.tryParse. String length limits on all parsed fields (max 10KB per ADB output). Every parser returns null (not throw) on malformed input. |
| T-01-07 | Denial of Service | metric_collector.dart — ring buffer unbounded growth | mitigate | Hard cap at 300 entries (60s × 5 buffer). Evict oldest on append when full. Documented as §F requirement. |
| T-01-08 | Denial of Service | metric_collector.dart — ADB command hangs | mitigate | 3-second timeout on every ADB call. After 5 consecutive total failures, stop collection and emit error. |
| T-01-09 | Information Disclosure | metric_collector.dart — ADB command logging in debug mode | mitigate | Debug mode (D-16) logs ADB commands to internal log only (written to data dir, not transmitted). Release mode omits raw ADB output from logs. |
</threat_model>

<verification>
- `flutter test test/unit/` — all 7 parser test files pass with 100% branch coverage
- Manual: Run MetricCollector against Android emulator → 10s session produces ~10 MetricSample objects in buffer
- All parsers handle garbage input (random bytes) → return null, no crash
</verification>

<success_criteria>
1. All 7 metric parsers pass their §14.1 unit tests with 100% branch coverage
2. FPS parser correctly implements 3-tier jank (small/medium/big) + frame-ratio jank (Γ=L/R) + frametimes JSON
3. CPU parser correctly computes delta-based app/system CPU% and frequency-normalized CPU%
4. Memory parser correctly extracts all 7 PSS subsections from dumpsys meminfo output
5. Battery parser correctly handles all 5 dumpsys fields + 2 sysfs files + charging source detection
6. Network parser correctly splits WiFi/Cellular/Other per-interface bytes
7. MetricCollector runs at 1Hz, calls all parsers, emits Stream<MetricSample>, maintains 300-entry ring buffer
8. First-sample CPU null handling works correctly (no delta available)
9. All parsers handle null/malformed/timed-out input gracefully without throwing
</success_criteria>

<output>
After completion, create `.planning/phases/01-v1-0-external-profiling-mvp/02-SUMMARY.md`
</output>
