---
phase: 02-v1-5-analysis-platform-expansion
plan: 03
type: execute
wave: 3
depends_on:
  - 02
files_modified:
  - performancebench/lib/core/collector/metric_collector.dart
  - performancebench/lib/core/services/alert_service.dart
  - performancebench/lib/core/database/marker_dao.dart
  - performancebench/lib/features/settings/settings_screen.dart
  - performancebench/lib/features/active_session/status_bar.dart
  - performancebench/lib/core/services/adb_service.dart
  - performancebench/lib/features/app_picker/app_picker_screen.dart
  - performancebench/test/core/services/alert_service_test.dart
  - performancebench/test/core/collector/auto_start_test.dart
autonomous: true
requirements:
  - V15-06
  - V15-07

must_haves:
  truths:
    - "Status bar shows alert count badge (red pill) when threshold breached during profiling session"
    - "Auto-marker created at each breach timestamp with label indicating breached threshold"
    - "Three threshold types configurable in Settings → Profiling: FPS < 30/10s, CPU > 85%/5s, Memory +100MB/30s"
    - "Session auto-starts on ALL connected devices when target app detected via ADB logcat"
    - "User pre-selects 'watch' packages in Settings — auto-start triggers only for those packages"
  artifacts:
    - path: "performancebench/lib/core/services/alert_service.dart"
      provides: "Threshold alert polling integrated into MetricCollector tick loop — checks FPS sliding window, CPU sliding window, memory growth over window"
      exports: ["AlertService", "_checkFpsThreshold", "_checkCpuThreshold", "_checkMemoryThreshold"]
      min_lines: 80
    - path: "performancebench/lib/features/settings/settings_screen.dart"
      provides: "Threshold Alert section under Profiling category — 3 toggle rows + threshold value sliders"
      contains: ["FPS Alert", "CPU Alert", "Memory Alert", "thresholdEnabled", "thresholdFpsMin", "thresholdCpuMax", "thresholdMemoryGrowthMb"]
    - path: "performancebench/lib/core/services/adb_service.dart"
      provides: "logcat polling method for auto session start"
      contains: ["startLogcatMonitor", "ACTIVITY_START regex"]
  key_links:
    - from: "alert_service.dart _checkFpsThreshold()"
      to: "metric_collector.dart _sampleTick()"
      via: "Called each tick; reads ring buffer last 10 samples; checks if all < 30 FPS"
      pattern: "alertService\\.checkThresholds"
    - from: "alert_service.dart onBreach()"
      to: "status_bar.dart alertBadgeCount"
      via: "State update increments badge count"
      pattern: "alertBadgeCount"
    - from: "adb_service.dart startLogcatMonitor()"
      to: "app_picker_screen.dart autoStartConfig"
      via: "Stream of package names matched against user's watch list"
      pattern: "logcatMonitor.*watchPackages"
</objective>

<objective>
Active profiling features: Metric threshold alerts with status bar badge + auto-markers, and auto session start via ADB logcat polling.

Purpose: Proactive monitoring during profiling sessions — users get notified of threshold breaches in real-time without needing to watch charts. Auto-start eliminates manual "start session" action, enabling unattended profiling runs.

Output: AlertService integrated into MetricCollector, threshold config in Settings, auto-start logcat monitor in AdbService, AppPicker watch-list UI.
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
@UNIFIED-SPEC.md Appendix D (ADB logcat command: `adb logcat -s ActivityManager:I`)
@performancebench/lib/core/collector/metric_collector.dart (integrate AlertService into _sampleTick)
@performancebench/lib/core/services/adb_service.dart (add logcat monitoring with ACTIVITY_START regex)
@performancebench/lib/features/settings/settings_screen.dart (add Threshold Alerts subsection)
@performancebench/lib/features/active_session/status_bar.dart (add alert count badge)
@performancebench/lib/features/app_picker/app_picker_screen.dart (add "Watch for auto-start" UI)
</context>

<tasks>

<task type="tdd" tdd="true">
  <name>Task 1: Metric threshold alerts + status bar badge + auto-marker (V15-06)</name>
  <files>
    performancebench/lib/core/services/alert_service.dart
    performancebench/lib/core/collector/metric_collector.dart
    performancebench/lib/core/database/marker_dao.dart
    performancebench/lib/features/settings/settings_screen.dart
    performancebench/lib/features/active_session/status_bar.dart
    performancebench/test/core/services/alert_service_test.dart
  </files>

  <read_first>
  - Read `performancebench/lib/core/collector/metric_collector.dart` (_sampleTick loop structure — integrate AlertService check each tick)
  - Read `performancebench/lib/core/database/marker_dao.dart` (insert marker with auto_screenshot=0, notes with threshold breach info)
  - Read `performancebench/lib/features/settings/settings_screen.dart` (_buildProfilingSection — add Threshold Alerts subsection)
  - Read `performancebench/lib/features/active_session/status_bar.dart` (current error badge pattern — reuse for alert badge)
  - Read Phase 2 CONTEXT.md decisions D-03, D-04, D-05 (alert surface, threshold types, config location)
  </read_first>

  <behavior>
    Alert service test expectations (alert_service_test.dart):
    Test 1: FPS threshold — last 10 samples all fps < 30 → breach triggers, violation count increments
    Test 2: FPS threshold — last 10 samples mixed (<30, >30) → no breach (must be sustained 10s)
    Test 3: FPS threshold — only 5 samples available → no breach (insufficient window)
    Test 4: CPU threshold — last 5 samples all cpuAppPct > 85% → breach triggers
    Test 5: CPU threshold — last 5 samples with one at 80% → no breach (must be sustained 5s)
    Test 6: Memory threshold — memoryGrowth > 100MB over 30-sample window → breach triggers
    Test 7: Memory threshold — memoryGrowth = 50MB over 30 samples → no breach
    Test 8: All thresholds disabled (config off) → no checks performed
    Test 9: Breach counts correctly (1 breach per threshold per sustained period, not per sample)
    Test 10: Auto-marker created with label "Alert: FPS < 30" at breach timestamp
    Test 11: Second breach of same type after gap → creates NEW marker, not overwriting
  </behavior>

  <action>
  **Create `performancebench/lib/core/services/alert_service.dart`** (per D-03, D-04, D-05):

  ```dart
  /// Configuration for a single threshold alert rule (per D-05: all default-off).
  class ThresholdConfig {
    final bool enabled;         // per D-05: all default-off
    final double threshold;     // threshold value
    final int windowSamples;    // sliding window size in samples (at 1Hz = seconds)
    final String label;         // label for auto-marker (e.g., "FPS < 30")
    final String metricField;   // e.g., 'fps', 'cpuAppPct', 'memoryPssKb'

    const ThresholdConfig({
      this.enabled = false,
      required this.threshold,
      required this.windowSamples,
      required this.label,
      required this.metricField,
    });
  }

  class AlertService {
    final MarkerDao _markerDao;
    ThresholdConfig _fpsConfig;
    ThresholdConfig _cpuConfig;
    ThresholdConfig _memoryConfig;

    /// Ring buffer of recent MetricSamples (shared with MetricCollector).
    final List<MetricSample> _recentSamples = [];
    static const int _maxRecent = 30; // Keep 30s history for threshold checks

    /// Current breach state — prevents repeated markers for same sustained breach.
    bool _fpsBreached = false;
    bool _cpuBreached = false;
    bool _memoryBreached = false;

    /// Callback when a threshold is breached. (Alert count → status bar badge)
    void Function(int totalBreaches, String latestBreachLabel)? onBreach;

    int _totalBreachCount = 0;

    AlertService({
      required MarkerDao markerDao,
      ThresholdConfig fpsConfig = const ThresholdConfig(
        threshold: 30.0, windowSamples: 10, label: 'FPS < 30', metricField: 'fps',
      ),
      ThresholdConfig cpuConfig = const ThresholdConfig(
        threshold: 85.0, windowSamples: 5, label: 'CPU > 85%', metricField: 'cpuAppPct',
      ),
      ThresholdConfig memoryConfig = const ThresholdConfig(
        threshold: 102400.0, windowSamples: 30, label: 'Memory +100MB', metricField: 'memoryPssKb',
      ),
    }) : _fpsConfig = fpsConfig, _cpuConfig = cpuConfig, _memoryConfig = memoryConfig;

    /// Called by MetricCollector each tick with the latest sample.
    void checkThresholds(MetricSample sample, {required String sessionId}) {
      _recentSamples.add(sample);
      while (_recentSamples.length > _maxRecent) {
        _recentSamples.removeAt(0);
      }

      if (_fpsConfig.enabled) _checkFps(sessionId);
      if (_cpuConfig.enabled) _checkCpu(sessionId);
      if (_memoryConfig.enabled) _checkMemory(sessionId);
    }

    void _checkFps(String sessionId) {
      final window = _recentSamples
        .where((s) => s.fps != null)
        .toList();
      if (window.length < _fpsConfig.windowSamples) return;

      final recentWindow = window.sublist(window.length - _fpsConfig.windowSamples);
      final allBelow = recentWindow.every((s) => (s.fps ?? 999) < _fpsConfig.threshold);

      if (allBelow && !_fpsBreached) {
        _fpsBreached = true;
        _fireBreach(sessionId, _fpsConfig.label, _fpsConfig.threshold,
          recentWindow.map((s) => s.fps ?? 0).reduce((a, b) => a + b) / recentWindow.length);
      } else if (!allBelow && _fpsBreached) {
        _fpsBreached = false; // Breach ended
      }
    }

    void _checkCpu(String sessionId) {
      final window = _recentSamples
        .where((s) => s.cpuAppPct != null)
        .toList();
      if (window.length < _cpuConfig.windowSamples) return;

      final recentWindow = window.sublist(window.length - _cpuConfig.windowSamples);
      final allAbove = recentWindow.every((s) => (s.cpuAppPct ?? 0) > _cpuConfig.threshold);

      if (allAbove && !_cpuBreached) {
        _cpuBreached = true;
        _fireBreach(sessionId, _cpuConfig.label, _cpuConfig.threshold,
          recentWindow.map((s) => s.cpuAppPct ?? 0).reduce((a, b) => a + b) / recentWindow.length);
      } else if (!allAbove && _cpuBreached) {
        _cpuBreached = false;
      }
    }

    void _checkMemory(String sessionId) {
      if (_recentSamples.length < _memoryConfig.windowSamples) return;

      final recentWindow = _recentSamples.sublist(
        _recentSamples.length - _memoryConfig.windowSamples);
      final firstMem = recentWindow.first.memoryPssKb;
      final lastMem = recentWindow.last.memoryPssKb;

      if (firstMem != null && lastMem != null) {
        final growth = lastMem - firstMem; // KB
        final growthMb = growth / 1024.0;
        final thresholdKb = _memoryConfig.threshold;

        if (growth > thresholdKb && !_memoryBreached) {
          _memoryBreached = true;
          _fireBreach(sessionId, _memoryConfig.label, _memoryConfig.threshold, growthMb);
        } else if (growth <= thresholdKb && _memoryBreached) {
          _memoryBreached = false;
        }
      }
    }

    void _fireBreach(String sessionId, String label, double threshold, double observedValue) {
      _totalBreachCount++;
      onBreach?.call(_totalBreachCount, label);

      // Create auto-marker at breach timestamp (per D-03)
      _markerDao.insert(Marker(
        sessionId: sessionId,
        label: 'Alert: $label',
        startedAt: DateTime.now().millisecondsSinceEpoch,
        endedAt: null, // Point marker (not range)
        autoScreenshot: 0,
        notes: 'Threshold: $threshold, Observed: ${observedValue.toStringAsFixed(1)}',
      ));
    }

    /// Update threshold config from Settings (per D-05).
    void updateConfig({
      bool? fpsEnabled, double? fpsMin, int? fpsWindow,
      bool? cpuEnabled, double? cpuMax, int? cpuWindow,
      bool? memoryEnabled, double? memoryGrowthMb, int? memoryWindow,
    }) {
      _fpsConfig = ThresholdConfig(
        enabled: fpsEnabled ?? _fpsConfig.enabled,
        threshold: fpsMin ?? _fpsConfig.threshold,
        windowSamples: fpsWindow ?? _fpsConfig.windowSamples,
        label: 'FPS < ${fpsMin?.toInt() ?? 30}',
        metricField: 'fps',
      );
      _cpuConfig = ThresholdConfig(
        enabled: cpuEnabled ?? _cpuConfig.enabled,
        threshold: cpuMax ?? _cpuConfig.threshold,
        windowSamples: cpuWindow ?? _cpuConfig.windowSamples,
        label: 'CPU > ${cpuMax?.toInt() ?? 85}%',
        metricField: 'cpuAppPct',
      );
      _memoryConfig = ThresholdConfig(
        enabled: memoryEnabled ?? _memoryConfig.enabled,
        threshold: (memoryGrowthMb ?? 100) * 1024, // MB to KB
        windowSamples: memoryWindow ?? _memoryConfig.windowSamples,
        label: 'Memory +${memoryGrowthMb?.toInt() ?? 100}MB',
        metricField: 'memoryPssKb',
      );
    }

    /// Reset breach state at session start.
    void reset() {
      _recentSamples.clear();
      _fpsBreached = false;
      _cpuBreached = false;
      _memoryBreached = false;
      _totalBreachCount = 0;
    }
  }
  ```

  **Wire into MetricCollector** (`metric_collector.dart`):
  ```dart
  // Add field:
  final AlertService _alertService;

  // In _sampleTick(), after building MetricSample:
  _alertService.checkThresholds(sample, sessionId: _sessionId);
  ```

  **Add Threshold Alerts section to Settings** (`settings_screen.dart`):

  In `_buildProfilingSection()`, add a new section:
  ```dart
  _SectionHeader('Threshold Alerts', colors),
  const SizedBox(height: 8),

  // FPS Alert — default off (D-05)
  _ToggleRow(
    label: 'FPS Alert (< 30 for 10s)',
    value: _fpsAlertEnabled,
    onChanged: (v) => setState(() => _fpsAlertEnabled = v),
    colors: colors,
  ),
  if (_fpsAlertEnabled)
    _SliderRow(
      label: 'FPS Minimum',
      value: _fpsMinThreshold,
      min: 10, max: 55, divisions: 45,
      displayValue: '${_fpsMinThreshold.toInt()}',
      onChanged: (v) => setState(() => _fpsMinThreshold = v),
      colors: colors,
    ),

  const Divider(height: 8),

  // CPU Alert — default off (D-05)
  _ToggleRow(
    label: 'CPU Alert (> 85% for 5s)',
    value: _cpuAlertEnabled,
    onChanged: (v) => setState(() => _cpuAlertEnabled = v),
    colors: colors,
  ),
  if (_cpuAlertEnabled)
    _SliderRow(
      label: 'CPU Maximum %',
      value: _cpuMaxThreshold,
      min: 50, max: 100, divisions: 50,
      displayValue: '${_cpuMaxThreshold.toInt()}%',
      onChanged: (v) => setState(() => _cpuMaxThreshold = v),
      colors: colors,
    ),

  const Divider(height: 8),

  // Memory Alert — default off (D-05)
  _ToggleRow(
    label: 'Memory Alert (> +100MB in 30s)',
    value: _memoryAlertEnabled,
    onChanged: (v) => setState(() => _memoryAlertEnabled = v),
    colors: colors,
  ),
  if (_memoryAlertEnabled)
    _SliderRow(
      label: 'Memory Growth (MB)',
      value: _memoryGrowthMb,
      min: 50, max: 500, divisions: 45,
      displayValue: '${_memoryGrowthMb.toInt()} MB',
      onChanged: (v) => setState(() => _memoryGrowthMb = v),
      colors: colors,
    ),
  ```

  Persist all threshold config to SharedPreferences:
  - Keys: `threshold_fps_enabled`, `threshold_fps_min`, `threshold_cpu_enabled`, `threshold_cpu_max`, `threshold_memory_enabled`, `threshold_memory_growth_mb`
  - Load on Settings screen init, save on change, push to AlertService via `updateConfig()`

  **Add alert badge to StatusBar** (`status_bar.dart`):

  Reuse existing error badge pattern. Add:
  ```dart
  // If alertCount > 0, show red pill badge next to error badge:
  if (alertCount > 0)
    GestureDetector(
      onTap: () => _showAlertLog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.accentDanger,  // Red
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$alertCount⚠', style: TextStyle(color: colors.textOnAccent, fontSize: 10)),
      ),
    ),
  ```

  **Create test** (`test/core/services/alert_service_test.dart`):
  - Test all 11 behavior cases above
  - Mock MarkerDao to verify auto-marker insert calls
  - Test breach state transitions (breached → not-breached → breached again)

  After tests pass, commit: `docs(02-03): add threshold alerts with status bar badge and auto-markers`
  </action>

  <verify>
    <automated>cd D:/OpenCode/Benchify && dart test test/core/services/alert_service_test.dart</automated>
  </verify>

  <done>
  - AlertService checks FPS, CPU, Memory thresholds each MetricCollector tick
  - Status bar shows red alert count badge on breach
  - Auto-marker created at each breach timestamp with threshold label
  - Settings → Profiling has Threshold Alerts section with 3 toggle+slider rows
  - All config persisted to SharedPreferences, all default-off per D-05
  - 11 test cases pass covering all breach scenarios
  </done>
</task>

<task type="tdd" tdd="true">
  <name>Task 2: Auto session start via ADB logcat polling (V15-07)</name>
  <files>
    performancebench/lib/core/services/adb_service.dart
    performancebench/lib/features/app_picker/app_picker_screen.dart
    performancebench/lib/features/settings/settings_screen.dart
    performancebench/test/core/collector/auto_start_test.dart
  </files>

  <read_first>
  - Read `performancebench/lib/core/services/adb_service.dart` (full class — add logcat monitoring stream and START regex parser)
  - Read `performancebench/lib/features/app_picker/app_picker_screen.dart` (add "Watch for auto-start" UI and watch-list management)
  - Read `performancebench/lib/features/settings/settings_screen.dart` (add Auto-Start config section under Profiling)
  - Read Phase 2 CONTEXT.md decisions D-10, D-11 (logcat polling, all-devices simultaneous start)
  - Read `UNIFIED-SPEC.md` Appendix D (`adb logcat -s ActivityManager:I` command)
  </read_first>

  <behavior>
    Auto-start test expectations (auto_start_test.dart):
    Test 1: Valid ActivityManager START line with known package → parseStartLine returns non-null package name
    Test 2: ActivityManager line for different action (not START) → returns null
    Test 3: ActivityManager START line for package NOT in watch list → no auto-start triggered
    Test 4: ActivityManager START line for package IN watch list → auto-start signal emitted
    Test 5: Malformed logcat line (garbled) → returns null, no crash
    Test 6: Two devices connected, same app launches on both → both devices get auto-start sessions (D-11: all-devices)
    Test 7: Watch list is empty → no auto-start triggered (nothing to watch)
    Test 8: Polling interval 2s — logcat monitor starts and streams lines at 2s intervals (use fake async timer)
  </behavior>

  <action>
  **Extend `performancebench/lib/core/services/adb_service.dart`** (per D-10, D-11):

  Add logcat monitoring methods:

  ```dart
  /// Result of parsing a logcat ActivityManager START line.
  class LogcatStartEvent {
    final String serial;       // Device serial
    final String timestamp;    // Logcat timestamp
    final String packageName;  // Target package that started
    final String intent;       // Full intent string

    const LogcatStartEvent({
      required this.serial,
      required this.timestamp,
      required this.packageName,
      required this.intent,
    });
  }

  /// Start monitoring ADB logcat for ActivityManager START events.
  ///
  /// Polls `adb -s <serial> logcat -s ActivityManager:I` every 2 seconds (D-10).
  /// Parses lines matching: /START u0 \{.*cmp=([^/]+)\/.*\}/
  ///
  /// Returns a broadcast stream of [LogcatStartEvent] for each detected app launch.
  /// Call [stopLogcatMonitor] to stop.
  Stream<LogcatStartEvent> startLogcatMonitor(String serial) {
    final controller = StreamController<LogcatStartEvent>.broadcast();
    bool stopped = false;

    Future<void> poll() async {
      if (stopped) return;
      try {
        final output = await runShellCommand(serial, 'logcat -d -s ActivityManager:I');
        if (output != null) {
          // Parse each line for START events
          for (final line in output.split('\n')) {
            final event = _parseActivityStart(line, serial);
            if (event != null) controller.add(event);
          }
          // Clear logcat buffer after reading (logcat -c)
          await runShellCommand(serial, 'logcat -c');
        }
      } catch (_) {
        // Logcat errors are non-fatal — retry next poll
      }

      if (!stopped) {
        await Future.delayed(const Duration(seconds: 2));
        // ignore: unawaited_futures
        poll(); // Recursive polling — lightweight, no stack overflow concern
      }
    }

    poll();
    controller.onCancel = () { stopped = true; };
    return controller.stream;
  }

  /// Parse a single logcat line for ActivityManager START intent.
  /// Returns null if line does not contain a recognizable app launch.
  LogcatStartEvent? _parseActivityStart(String line, String serial) {
    // Match pattern: "ActivityManager: Start proc ... for activity .../."
    // or "START u0 {act=... cmp=com.example.app/.MainActivity}"
    final startMatch = RegExp(
      r'START u\d+\s+\{.*?cmp=([a-zA-Z][a-zA-Z0-9_]*(?:\.[a-zA-Z][a-zA-Z0-9_]*)+)/\.',
    ).firstMatch(line);

    if (startMatch == null) return null;

    final packageName = startMatch.group(1);
    if (packageName == null || packageName.isEmpty) return null;

    // Validate package name format
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$').hasMatch(packageName)) {
      return null;
    }

    // Extract timestamp if present (logcat format: MM-DD HH:MM:SS.mmm)
    String? timestamp;
    final tsMatch = RegExp(r'^(\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d{3})').firstMatch(line);
    if (tsMatch != null) timestamp = tsMatch.group(1);

    return LogcatStartEvent(
      serial: serial,
      timestamp: timestamp ?? DateTime.now().toIso8601String(),
      packageName: packageName,
      intent: line.trim(),
    );
  }

  /// Stop logcat monitoring (handled by stream cancellation).
  void stopLogcatMonitor() {
    // Stream subscription cancellation handles cleanup
  }
  ```

  **Add auto-start config to Settings** (`settings_screen.dart`):

  Under Profiling section, after Threshold Alerts:
  ```dart
  _SectionHeader('Auto Session Start', colors),
  _ToggleRow(
    label: 'Watch for app launches',
    value: _autoStartEnabled,
    onChanged: (v) => setState(() => _autoStartEnabled = v),
    subtitle: 'Start profiling automatically when a watched app launches',
    colors: colors,
  ),
  if (_autoStartEnabled) ...[
    // Watch-list management
    Text('Watched Packages', style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.xs)),
    const SizedBox(height: 4),
    Wrap(
      children: _watchPackages.map((pkg) => Chip(
        label: Text(pkg, style: TextStyle(fontSize: 11, fontFamily: monoFontFamily())),
        onDeleted: () => setState(() => _watchPackages.remove(pkg)),
      )).toList(),
    ),
    const SizedBox(height: 4),
    TextButton.icon(
      icon: Icon(Icons.add, size: 14),
      label: Text('Add Package'),
      onPressed: _addWatchPackage,
    ),
  ],
  ```

  Persist watch list to SharedPreferences:
  - Key: `auto_start_watch_packages` (JSON array of package name strings)
  - Key: `auto_start_enabled` (bool)

  **Add "Watch for auto-start" UI to AppPicker** (`app_picker_screen.dart`):

  Next to each app row, add:
  ```dart
  IconButton(
    icon: Icon(
      _watchPackages.contains(app.package) ? Icons.visibility : Icons.visibility_off,
      size: 16,
      color: _watchPackages.contains(app.package)
        ? colors.accentBlue
        : colors.textDisabled,
    ),
    tooltip: _watchPackages.contains(app.package)
      ? 'Watching for auto-start'
      : 'Add to watch list',
    onPressed: () => _toggleWatch(app.package),
  ),
  ```

  **Wire auto-start into session management flow:**

  Create an `AutoStartService` provider that:
  1. On app start / device connect: if `auto_start_enabled` is true, start logcat monitor on each connected Android device
  2. When a `LogcatStartEvent` arrives with a package in the watch list → auto-start profiling session on that device (per D-11: all devices)
  3. Create session with auto-generated title: "Auto: {package} — {timestamp}"
  4. If a session is already running on that device → create a new parallel session (each device gets its own)

  ```dart
  // In auto start provider:
  void _onAppLaunchDetected(LogcatStartEvent event) {
    if (!_watchPackages.contains(event.packageName)) return;
    if (!_autoStartEnabled) return;

    // Check if already profiling this device
    if (_activeSessions.containsKey(event.serial)) return;

    // Auto-start session
    _startProfilingSession(
      deviceSerial: event.serial,
      package: event.packageName,
      title: 'Auto: ${event.packageName} — ${event.timestamp}',
    );
  }
  ```

  **Create test** (`test/core/collector/auto_start_test.dart`):

  Test `_parseActivityStart()` with realistic logcat lines:
  ```
  "05-04 14:32:01.123  1234  5678 I ActivityManager: START u0 {act=android.intent.action.MAIN cat=[android.intent.category.LAUNCHER] flg=0x10200000 cmp=com.example.game/.MainActivity}"
  ```
  Verify extracted package = "com.example.game"

  Also test edge cases: non-START lines, malformed lines, system package starts (com.android.*).

  After tests pass, commit: `docs(02-03): add auto session start via ADB logcat polling`
  </action>

  <verify>
    <automated>cd D:/OpenCode/Benchify && dart test test/core/collector/auto_start_test.dart</automated>
  </verify>

  <done>
  - ADB logcat monitor polls every 2s and parses ActivityManager START events
  - ActivityManager START regex extracts package name from intent lines
  - Watch list managed in Settings → Auto Session Start and on AppPicker
  - Auto-start creates session on ALL connected devices when watched app launches
  - 8 test cases pass covering valid parse, malformed input, and device multiplicity
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| ADB logcat output → Parser | Raw logcat text parsed for ActivityManager START lines |
| User threshold config → SharedPreferences | User-defined threshold values stored locally |
| MetricCollector samples → AlertService | MetricSample ring buffer analyzed for threshold breaches |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-10 | Injection | adb_service.dart _parseActivityStart() | mitigate | Regex extraction with package name validation against Android package name regex; malformed lines return null |
| T-02-11 | Denial of Service | adb_service.dart logcat polling | mitigate | 2-second polling interval with logcat -c clear prevents buffer accumulation; recursive poll has stream cancellation guard |
| T-02-12 | Spoofing | alert_service.dart _checkFps() | accept | Ring buffer data comes from MetricCollector which parses real ADB shell output — no external input for metrics |
| T-02-13 | Information Disclosure | settings_screen.dart threshold config | accept | Threshold values stored in local SharedPreferences only; no network transmission per privacy contract |
</threat_model>

<verification>
1. Run alert service test: `cd D:/OpenCode/Benchify && dart test test/core/services/alert_service_test.dart`
2. Run auto-start test: `cd D:/OpenCode/Benchify && dart test test/core/collector/auto_start_test.dart`
3. Run full test suite: `cd D:/OpenCode/Benchify && dart test`
4. Verify: `cd D:/OpenCode/Benchify && dart analyze` shows 0 errors
</verification>

<success_criteria>
1. Status bar shows red badge incrementing on each unique threshold breach during session
2. Auto-marker created with "Alert: FPS < 30" label at exact breach timestamp
3. Settings → Profiling shows 3 threshold toggles all default-off with adjustable sliders
4. User can add packages to watch list in Settings and AppPicker
5. Logcat monitor detects app launch and auto-starts profiling session
6. All 19 new tests pass, 0 analyzer errors
</success_criteria>

<output>
After completion, create `.planning/phases/02-v1-5-analysis-platform-expansion/02-03-SUMMARY.md`
</output>
