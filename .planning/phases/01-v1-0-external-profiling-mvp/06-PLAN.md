---
phase: "01"
plan: "06"
type: execute
wave: 6
depends_on: ["01-04", "01-05"]
files_modified:
  - lib/features/settings/settings_screen.dart
  - lib/core/services/error_handler.dart
  - lib/core/services/session_service.dart
  - lib/features/onboarding/onboarding_screen.dart
  - lib/shared/widgets/status_bar.dart
  - assets/demo/demo_session.json
autonomous: true
requirements: [MVP-21, MVP-23, MVP-24]

must_haves:
  truths:
    - "Settings panel has categories: Profiling, Paths, Appearance, Charts, Keyboard Shortcuts, About — with all controls from §9.9"
    - "Debug mode (--debug flag) shows full stack traces and ADB command output; Release mode shows graceful errors"
    - "Status bar shows error count with clickable log panel per D-17"
    - "ANR/crash detection catches Android ANR dialogs and iOS crash logs"
    - "USB unplug mid-session recovers gracefully — session stops, data saved, user sees 'Device disconnected' message"
    - "ADB auto-recovery reconnects after ADB server restart without manual intervention"
    - "Onboarding flow shows 3-step intro (Connect Device → Select App → Profile) with 'skip' option"
    - "Bundled demo session loads from assets/demo/demo_session.json and appears in session history"
  artifacts:
    - path: "lib/features/settings/settings_screen.dart"
      provides: "Full settings UI with Profiling/Paths/Appearance/Charts/Keyboard/About categories"
    - path: "lib/core/services/error_handler.dart"
      provides: "Centralized error handling, debug/release mode switching, error count tracking"
      exports: ["class ErrorHandler", "void logError(String)", "int get errorCount"]
    - path: "lib/features/onboarding/onboarding_screen.dart"
      provides: "3-step onboarding wizard shown on first launch"
    - path: "lib/shared/widgets/status_bar.dart"
      provides: "22px bottom status bar with recording state, error count, SQLite status, clickable log panel"
  key_links:
    - from: "lib/features/settings/settings_screen.dart"
      to: "lib/shared/theme.dart"
      via: "theme provider for Appearance settings"
      pattern: "ThemeProvider"
    - from: "lib/core/services/session_service.dart"
      to: "lib/core/services/adb_service.dart"
      via: "ADB recovery on disconnect"
      pattern: "adbService"
    - from: "lib/features/onboarding/onboarding_screen.dart"
      to: "lib/app.dart"
      via: "GoRouter redirect on first launch"
      pattern: "onboarding"
---

<objective>
Build full settings panel (Profiling/Paths/Appearance/Charts/Keyboard/About), implement error handling with Debug/Release dual mode (D-16), status bar with error count and clickable log panel (D-17), edge case hardening (ANR/crash detection, USB unplug recovery, ADB auto-recovery, foreground/background tracking), and 3-step onboarding flow with bundled demo session.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@UNIFIED-SPEC.md lines 2313-2372 (§9.9 Settings Screen — full settings table, keyboard shortcuts)
@UNIFIED-SPEC.md lines 2004-2031 (§9.2 Status bar spec, §9.3 Title bar)
@UNIFIED-SPEC.md — §E Stop-gates (no automatic schema changes, no new network calls)
@.planning/phases/01-v1-0-external-profiling-mvp/01-CONTEXT.md — D-16 (Debug/Release mode), D-17 (status bar with error count), D-13 through D-15 (themes)

<interfaces>
Already exist:
- AppTheme and ThemeData providers (from lib/shared/theme.dart)
- AdbService with device discovery (from lib/core/services/adb_service.dart)
- MetricCollector with stream (from lib/core/services/metric_collector.dart)
- SessionDao, MetricDao (from lib/core/database/)
- GoRouter navigation (from lib/app.dart)
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Build Settings panel with all categories and Error Handler with Debug/Release dual mode (D-16)</name>
  <files>
    lib/features/settings/settings_screen.dart
    lib/core/services/error_handler.dart
    lib/shared/widgets/status_bar.dart
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 2313-2372 (§9.9 Settings Screen — full settings table, categories, controls, keyboard shortcuts)
    @UNIFIED-SPEC.md lines 2004-2009 (§9.2 Status bar specification)
  </read_first>
  <action>
    1. Flesh out `lib/features/settings/settings_screen.dart` (replace placeholder):
       - VS Code Settings page aesthetic: two-column layout (categories list left, settings right).
       - Categories: Profiling, Paths, Appearance, Charts, Keyboard Shortcuts, About.
       - All settings per §9.9 table:
         a. **Profiling**: Sample rate (Dropdown: 500ms/1s/2s, default 1s), Screenshot interval (Dropdown: 5s/10s/30s/Off, default 10s), Chart time window (Dropdown: 30s/60s/120s, default 60s), Jank formula (Radio: GameBench 3-tier / Simple threshold, default GameBench), Auto-detect layer name (Toggle, default On).
         b. **Paths**: ADB executable (File picker + text field, default "Auto (PATH)"), Python executable (File picker + text field, default "Auto (PATH)"), Data directory (Directory picker, default "~/PerformanceBench").
         c. **Appearance**: Theme (Dropdown: Dark/Light/High Contrast/System, per D-14), Monospace font (Dropdown: auto/Cascadia Code/SF Mono/JetBrains Mono, default auto).
         d. **Charts**: FPS histogram bucket (Radio: 5fps/10fps, default 5fps), Chart grid columns (Radio: Auto/1/2/3, default Auto), Show null gaps (Toggle, default On), Animate chart scroll (Toggle, default On).
         e. **Keyboard Shortcuts**: Read-only table showing all shortcuts from §9.9 (Start/Stop: Ctrl+Shift+R, Add Marker: Ctrl+Shift+M, Launch Complete: Ctrl+Shift+L, Screenshot: Ctrl+Shift+S, Toggle Sidebar: Ctrl+B, Expand Chart: Double-click, Close Tab: Ctrl+W). Windows and macOS columns.
         f. **About**: Version (from pubspec.yaml), License ("MIT"), GitHub link, credits.
       - All settings persisted to SharedPreferences (or similar local key-value store) via Riverpod StateNotifier providers.
       - Settings take effect immediately (no "Save" button needed).
       - Warning text for screenshot interval if set below 5s: "Frequent screenshots increase storage usage."
       - Theme change applies instantly to entire app via Riverpod theme provider.
    
    2. Create `lib/core/services/error_handler.dart` — `ErrorHandler` class:
       - D-16: Dual mode detection via `bool isDebugMode` flag (set from `--debug` CLI arg in main.dart, stored as Riverpod provider).
       - `void logError(String source, dynamic error, [StackTrace? stack])`:
         - Debug mode: prints full stack trace to console + stores in internal `List<ErrorEntry>` log with timestamp, source, message, stack.
         - Release mode: prints minimal one-line message (no stack trace). Still stored internally but stack is null.
       - `int get errorCount` — total number of errors logged since app start.
       - `List<ErrorEntry> get errors` — returns internal log (for log panel display). Max 1000 entries (ring buffer — drop oldest on overflow).
       - `void clearErrors()` — reset error count to 0.
       - `ErrorEntry`: timestamp (DateTime), source (String), message (String), stackTrace (String?).
       - Never throws — the error handler itself must be infallible.
    
    3. Create `lib/shared/widgets/status_bar.dart` — `StatusBar` widget per D-17 + §9.2:
       - 22px height, `bg.elevated` background normally, `accent.recording` (red) while recording.
       - Left section: "● REC 00:04:21" while recording, "Ready" when idle.
       - Center section: active device name + sample rate ("Pixel 8 Pro | 1 Hz").
       - Right section:
         - Error count badge: red background pill showing count (e.g., "⚠ 3 errors"). Hidden if errorCount = 0.
         - SQLite write status: "SQLite ✓" green when last flush succeeded, "SQLite ⚠" yellow when last flush failed.
       - Error count badge is clickable: opens log panel (bottom sheet or overlay) showing last N errors with timestamp, source, message, and stack trace (debug mode only).
       - Log panel: scrollable list, VS Code-styled dark panel. Each entry: timestamp in mono 10px, source in secondary, message in primary, stack trace in mono 10px (collapsible per entry).
    
    DO NOT: Use platform channels for simple value storage. Use shared_preferences or similar package.
    DO NOT: Persist debug mode as a permanent setting — it's a CLI flag per D-16, reset on app restart.
    DO NOT: Include any network-related settings (no cloud sync, no telemetry toggles).
  </action>
  <acceptance_criteria>
    - Settings screen has 6 categories with all controls from §9.9 table
    - Theme change takes effect immediately across entire app (Dark/Light/High Contrast/System)
    - Sample rate setting reflected in MetricCollector (next session start picks up new value)
    - ErrorHandler.logError() stores errors with Debug/Release mode differentiation
    - Status bar shows error count badge (hidden when 0), SQLite status, recording state
    - Clicking error count badge opens log panel with error entries
    - Debug mode (--debug flag) shows full stack traces; Release mode shows minimal messages
    - Keyboard shortcuts reference table renders correctly with Windows and macOS columns
    - Settings persisted across app restarts (theme, profiling prefs, paths)
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter analyze lib/features/settings/ lib/core/services/error_handler.dart lib/shared/widgets/status_bar.dart</automated>
  </verify>
  <done>Settings panel fully functional with all 6 categories. Error handler supports Debug/Release dual mode. Status bar shows error count with clickable log panel.</done>
</task>

<task type="auto">
  <name>Task 2: Implement edge case hardening — ANR/crash detection, USB recovery, ADB auto-recovery, foreground/background tracking</name>
  <files>
    lib/core/services/session_service.dart
    lib/core/services/adb_service.dart
    lib/core/services/metric_collector.dart
  </files>
  <read_first>
    @UNIFIED-SPEC.md §4.1 Android features (review USB/screenshot wireless behavior)
    @.planning/phases/01-v1-0-external-profiling-mvp/01-CONTEXT.md — D-16 (Debug/Release for error visibility)
  </read_first>
  <action>
    1. Create/update `lib/core/services/session_service.dart` — `SessionService` (manages session lifecycle):
       - `Future<void> stopSession(Session session)` — calls MetricCollector.stop(), flushes remaining samples via batch writer, calls AnalyticsService.computeSessionStats(), updates session ended_at + duration_ms, closes any open resources.
       - Handles 10-second minimum session enforcement (§4.1): if session duration < 10s, show warning "Session too short (minimum 10 seconds). Stats may be unreliable." but still save.
    
    2. Implement ANR/Crash detection (Android):
       - In `AdbService`, add `Future<String?> checkForAnr(String serial, String package)`:
         - Runs `adb shell dumpsys activity processes | grep -A5 <package>`.
         - Looks for "ANR" keyword or "AppWaitingForDebugger" state.
         - If detected: log error via ErrorHandler, create a special "ANR detected" marker in the session.
       - In `MetricCollector`, on each tick, check if app PID is still alive via `adb shell pidof <package>`. If PID died:
         - Try rediscover once (app may have restarted).
         - If still dead: log "App process terminated", stop collection, mark session as completed with `crash_detected = true`.
    
    3. Implement iOS crash detection:
       - In `IosService`, monitor subprocess stderr for crash-related messages.
       - If collector.py reports `"error": "app_terminated"` in JSON stream, treat same as Android process death.
    
    4. Implement USB unplug recovery:
       - In `AdbService`, add device connection monitoring: periodically check if tracked device serial is still in `adb devices` output.
       - If device disappears mid-session:
         - Log "Device disconnected" via ErrorHandler.
         - Set a 30-second reconnection window: poll every 2s for device reappearance.
         - If reconnected within 30s: resume collection from where it left off (session continues).
         - If not reconnected after 30s: stop session gracefully, save all collected data, show "Device disconnected — session saved" toast.
    
    5. Implement ADB auto-recovery:
       - In `AdbService`, if any ADB command fails with "adb: device not found" or "error: device offline":
         - Wait 2s, retry once.
         - If retry also fails: attempt `adb kill-server && adb start-server`. Wait 3s. Retry command.
         - If still failing after server restart: log error, return null (MetricCollector handles null as metric failure for that tick).
         - Maximum 1 server restart per 60 seconds (rate limit to avoid restart loops).
    
    6. Implement foreground/background tracking (Android):
       - In `MetricCollector`, add `Future<bool> isAppInForeground(String serial, String package)`:
         - Runs `adb shell dumpsys activity activities | grep mResumedActivity`.
         - Checks if output contains the target package name.
         - If app is in background: continue collecting metrics (some may still work), but flag sample with `is_background = true` in session metadata.
         - When app returns to foreground: log transition with timestamp in session notes.
    
    7. Implement wireless ADB screenshot auto-disable:
       - In `ScreenshotService`, if device connection mode is "wireless" (detected via `adb devices -l` output containing "product:" but no "usb:" transport), auto-disable all screenshot sizes. Show banner: "Screenshots disabled during wireless profiling for stability."
    
    DO NOT: Use blocking delays for reconnection polling — use Timer.periodic.
    DO NOT: Crash the app on any recovery path. All edge cases handled gracefully with logging.
    DO NOT: Skip data collection during reconnection attempts — collect what's available.
  </action>
  <acceptance_criteria>
    - ANR detection creates "ANR detected" marker in session when Android ANR dialog appears
    - App process death detection: PID check each tick, stop session if PID gone, save data
    - USB unplug: 30s reconnection window, session saves all data if not reconnected
    - ADB auto-recovery: server restart on persistent failure, max 1 restart per 60s
    - Foreground/background transitions logged with timestamps in session notes
    - Wireless ADB: screenshots auto-disabled with banner shown
    - Zero crashes on any edge case path (tested by simulation)
    - `flutter analyze` — zero errors
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter analyze lib/core/services/session_service.dart lib/core/services/adb_service.dart lib/core/services/metric_collector.dart</automated>
  </verify>
  <done>All edge cases hardened: ANR/crash detection, USB recovery with 30s window, ADB auto-recovery with rate-limited server restart, foreground/background tracking.</done>
</task>

<task type="auto">
  <name>Task 3: Build onboarding flow with 3-step wizard and bundled demo session</name>
  <files>
    lib/features/onboarding/onboarding_screen.dart
    assets/demo/demo_session.json
  </files>
  <read_first>
    @UNIFIED-SPEC.md — review §9.3 Custom Title Bar for visual consistency
  </read_first>
  <action>
    1. Create `lib/features/onboarding/onboarding_screen.dart` — `OnboardingScreen`:
       - Shown on first launch (detected via SharedPreferences flag `onboarding_completed = false`).
       - 3-step wizard with "Next" / "Back" / "Skip" buttons:
         a. **Step 1 — Connect Device**: Illustration of USB cable connecting phone to computer. Text: "Connect your Android or iOS device via USB. Enable USB Debugging (Android) or Developer Mode (iOS)." "Next" enabled when at least one device detected (poll device list). For iOS: "iOS requires macOS host."
         b. **Step 2 — Select App**: Illustration of app picker screen. Text: "Choose the app you want to profile. PerformanceBench will collect real-time FPS, CPU, memory, battery, and more." User selects an app from connected device (or skips with "I'll do this later").
         c. **Step 3 — Start Profiling**: Summary of what to expect. Text: "Your first session. Metrics stream at 1Hz. All data stays on your machine — never transmitted. Press Start to begin." Big "Start Profiling" button → navigates to ActiveSession screen with selected device+app.
         d. "Skip" at top right (all steps) — sets `onboarding_completed = true`, navigates to DeviceList.
       - VS Code-dark styled: `bg.base` background, `text.primary` text, `accent.blue` buttons.
       - Step indicators: 3 dots at bottom, filled for completed steps, `accent.blue` for current.
       - After completing or skipping: set SharedPreferences flag `onboarding_completed = true`. Never shown again unless user resets in Settings > About > "Reset Onboarding".
    
    2. Create `assets/demo/demo_session.json` — bundled demo session:
       - Pre-recorded 2-minute session data in the same JSON format as export service output.
       - Includes: session metadata (app="com.example.demo", device="Demo Device (Snapdragon 8 Gen 2)"), session_stats (FPS median=58.3, min=22, max=63, 1%low=24.1, stability=81%, jank_total=847), 120 metric_samples (1 per second × 120s), 3 markers (Launch Complete at +4.2s, "Main Menu" at +10s, "Gameplay" at +30s).
       - Realistic data: FPS varies 58-63 with occasional dips to 22, CPU 20-40%, memory 400-600MB, battery drains 2% over 2 min, network TX/RX values.
       - On first launch after onboarding: load demo session into SQLite (sessions, metric_samples, session_stats, markers, marker_stats tables). Appears in session history with "Demo" tag.
       - Demo session load is idempotent — checks if demo session already exists before inserting.
    
    3. Update GoRouter in app.dart:
       - Add route for `/onboarding`.
       - On app start: check `onboarding_completed` flag. If false → redirect to `/onboarding`. If true → redirect to `/`.
    
    DO NOT: Show onboarding after first completion unless user resets manually.
    DO NOT: Require device connection to complete onboarding — Skip is always available.
    DO NOT: Use real device data for demo session — it's pre-baked JSON.
  </action>
  <acceptance_criteria>
    - Onboarding screen shows on first app launch with 3 steps and Skip option
    - Step 1 polls for connected devices, enables Next when device found
    - Step 3 "Start Profiling" navigates to ActiveSession with selected device+app
    - Skip sets onboarding_completed=true, navigates to DeviceList
    - After completing onboarding, subsequent launches go directly to DeviceList
    - "Reset Onboarding" option exists in Settings > About
    - Demo session JSON is valid and loads into SQLite with all 5 tables populated
    - Demo session appears in session history with "Demo" tag, 2m duration, 58.3 median FPS
    - Demo session load is idempotent (no duplicate on restart)
    - `flutter analyze` — zero errors
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter analyze lib/features/onboarding/ && dart run tools/validate_demo_session.dart 2>/dev/null || echo "Manual validation: verify assets/demo/demo_session.json is valid JSON"</automated>
  </verify>
  <done>Onboarding wizard guides new users through 3 steps on first launch. Demo session loads from bundled JSON into SQLite and appears in session history.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| User input → Settings persistence | Settings values stored in SharedPreferences. User-controlled key-value store. |
| Demo session JSON → SQLite import | Bundled JSON file loaded on first launch. Static asset shipped with app. |
| ADB subprocess → App | Device disconnection/reconnection events detected via ADB polling. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-21 | Tampering | settings_screen.dart — file paths manipulated | mitigate | Validate path exists and is executable before storing ADB/Python paths. Reject paths containing shell metacharacters. |
| T-01-22 | Denial of Service | adb_service.dart — ADB server restart loop | mitigate | Rate-limited to max 1 restart per 60 seconds. After 3 consecutive failures, stop attempting restart, emit error, let session continue without ADB. |
| T-01-23 | Information Disclosure | error_handler.dart — debug stack traces in log panel | mitigate | Debug mode only accessible via `--debug` CLI flag (D-16). Release mode hides stack traces. Log panel data never persisted to disk. |
| T-01-24 | Information Disclosure | demo_session.json — pre-baked session data | accept | Demo data is synthetic, contains no real user or device information. Shipped as static asset. |
</threat_model>

<verification>
- First launch: onboarding wizard appears, complete or skip → DeviceList shown
- Settings: change theme → entire app theme updates instantly. Change sample rate → next session uses new rate
- Status bar: trigger an error → error count badge appears → click → log panel shows entry
- Disconnect USB mid-session → "Device disconnected" toast → 30s reconnection attempted → session saves data
- Demo session visible in session history with "Demo" tag, 2m duration, opens in session detail
</verification>

<success_criteria>
1. Settings panel has all 6 categories with persisted preferences that take effect immediately
2. Error handler supports Debug/Release dual mode with appropriate stack trace visibility per D-16
3. Status bar shows error count badge (clickable log panel) and SQLite write status per D-17
4. USB unplug recovery saves session data with 30s reconnection window
5. ADB auto-recovery restarts server on persistent failure, rate-limited to 1/min
6. ANR/crash detection creates markers and stops collection gracefully
7. Onboarding 3-step wizard shown on first launch with Skip option
8. Bundled demo session loads into SQLite and appears in session history
</success_criteria>

<output>
After completion, create `.planning/phases/01-v1-0-external-profiling-mvp/06-SUMMARY.md`
</output>
