---
phase: "01"
plan: "01"
type: execute
wave: 1
depends_on: []
files_modified:
  - pubspec.yaml
  - lib/main.dart
  - lib/app.dart
  - lib/shared/theme.dart
  - lib/core/database/database.dart
  - lib/core/database/session_dao.dart
  - lib/core/database/metric_dao.dart
  - lib/core/database/marker_dao.dart
  - lib/core/database/session_stats_dao.dart
  - lib/core/database/marker_stats_dao.dart
  - lib/core/database/screenshot_dao.dart
  - lib/core/models/session.dart
  - lib/core/models/device.dart
  - lib/core/models/metric_sample.dart
  - lib/core/models/marker.dart
  - lib/core/models/session_stats.dart
  - lib/core/models/marker_stats.dart
  - lib/core/services/adb_service.dart
  - lib/features/device_list/device_list_screen.dart
  - lib/features/device_list/device_card.dart
  - lib/features/app_picker/app_picker_screen.dart
  - lib/features/app_picker/app_list_item.dart
  - lib/features/active_session/active_session_screen.dart
  - lib/features/active_session/charts_tab.dart
  - lib/features/active_session/screenshots_tab.dart
  - lib/features/active_session/markers_tab.dart
  - lib/features/session_history/history_screen.dart
  - lib/features/session_history/session_list_item.dart
  - lib/features/session_detail/detail_screen.dart
  - lib/features/session_detail/scorecard_tab.dart
  - lib/features/session_detail/replay_charts_tab.dart
  - lib/features/session_detail/fps_analysis_tab.dart
  - lib/features/session_detail/markers_detail_tab.dart
  - lib/features/comparison/comparison_screen.dart
  - lib/features/settings/settings_screen.dart
  - lib/shared/widgets/metric_chart.dart
  - lib/shared/widgets/fps_histogram_chart.dart
  - lib/shared/widgets/scorecard_widget.dart
  - lib/shared/widgets/marker_stats_table.dart
  - lib/shared/widgets/comparison_delta_table.dart
  - lib/shared/widgets/metric_value_badge.dart
  - lib/shared/widgets/gpu_unavailable_badge.dart
  - assets/fonts/JetBrainsMono-Regular.ttf
  - assets/fonts/JetBrainsMono-Bold.ttf
  - test/unit/ring_buffer_test.dart
  - ios_agents/requirements.txt
  - ios_agents/collector.py
  - ios_agents/device_list.py
  - ios_agents/app_list.py
  - .github/workflows/ci.yml
  - .github/workflows/packet-capture-test.yml
autonomous: true
requirements: [MVP-01, MVP-02, MVP-03, MVP-04, MVP-12]

must_haves:
  truths:
    - "Flutter project compiles and runs on Windows with `flutter run -d windows`"
    - "App window appears with VS Code-inspired dark theme, custom title bar, activity bar, collapsible sidebar"
    - "Sidebar shows navigation icons: Devices, History, Compare, Settings"
    - "SQLite database file `performancebench.db` is created on first launch in OS-conventional data dir"
    - "All Appendix C v1.0 tables exist in the database with exact column names, types, and constraints"
    - "ADB subprocess can list connected Android devices and installed apps"
    - "Static device data (manufacturer, model, OS, chipset, GPU) is collected and stored in devices table"
    - "Navigation screen placeholders exist for all screens: DeviceList, AppPicker, ActiveSession, History, SessionDetail, Comparison, Settings"
    - "Privacy guard: no HTTP/HTTPS network code anywhere; only localhost ADB socket"
    - "CI workflow builds on windows-latest, macos-latest, ubuntu-latest"
  artifacts:
    - path: "pubspec.yaml"
      provides: "Flutter project dependencies"
      contains: "sqflite_common_ffi, fl_chart, riverpod, go_router, window_manager, uuid, csv, path_provider, path"
    - path: "lib/app.dart"
      provides: "MaterialApp, GoRouter routes, ThemeData for Dark/Light/HighContrast/System themes"
      exports: ["class App"]
    - path: "lib/core/database/database.dart"
      provides: "SQLite init via sqflite_common_ffi + schema_version migration runner"
      exports: ["Future<Database> initDatabase()", "Future<void> runMigrations(Database)"]
    - path: "lib/core/models/metric_sample.dart"
      provides: "MetricSample model with all 50+ columns matching Appendix C exactly"
      contains: "class MetricSample"
    - path: "lib/core/services/adb_service.dart"
      provides: "ADB subprocess wrapper with device discovery, app listing, static data collection"
      exports: ["class AdbService", "Future<List<Device>> discoverDevices()", "Future<List<AppInfo>> listApps(String serial)"]
    - path: "lib/shared/theme.dart"
      provides: "ThemeData with VS Code Dark+ color palette tokens"
      exports: ["class AppTheme", "ThemeData get darkTheme", "ThemeData get lightTheme", "ThemeData get highContrastTheme"]
  key_links:
    - from: "lib/app.dart"
      to: "lib/shared/theme.dart"
      via: "import for ThemeData"
      pattern: "import.*theme"
    - from: "lib/app.dart"
      to: "lib/core/database/database.dart"
      via: "initDatabase() call on app start"
      pattern: "initDatabase"
    - from: "lib/features/device_list/device_list_screen.dart"
      to: "lib/core/services/adb_service.dart"
      via: "AdbService.discoverDevices() polling"
      pattern: "discoverDevices"
    - from: ".github/workflows/ci.yml"
      to: "pubspec.yaml"
      via: "flutter pub get + flutter build matrix"
      pattern: "flutter build windows"
---

<objective>
Scaffold the entire Flutter desktop project with all dependencies, navigation shell, VS Code-inspired dark theme system (4 themes per D-14), complete database schema matching Appendix C exactly, ADB service with device discovery, and CI pipeline. Every screen has a placeholder skeleton per D-02 skeleton-first approach. Privacy guard (D-18) enforced from first commit — zero network code.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/phases/01-v1-0-external-profiling-mvp/01-CONTEXT.md
@UNIFIED-SPEC.md §§1-3, §8, Appendix C (lines 3191-3602), §9.1-9.3 (lines 1831-2033), §12, §13
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create Flutter project, install dependencies, scaffold navigation shell</name>
  <files>
    pubspec.yaml
    lib/main.dart
    lib/app.dart
    lib/shared/theme.dart
    assets/fonts/JetBrainsMono-Regular.ttf
    assets/fonts/JetBrainsMono-Bold.ttf
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 1831-2033 (§9.1 Design System — color palette, typography, spacing)
    @UNIFIED-SPEC.md lines 2675-2776 (§12 File Structure)
    @UNIFIED-SPEC.md lines 2837-2853 (§13.6 pubspec.yaml dependencies)
  </read_first>
  <action>
    1. Run `flutter create performancebench --org com.performancebench --platforms=windows,macos,linux` in the repo root.
    2. Edit `pubspec.yaml` to add these exact dependencies:
       - sqflite_common_ffi: ^2.3.0
       - fl_chart: ^0.67.0
       - riverpod: ^2.5.0
       - go_router: ^13.0.0
       - uuid: ^4.0.0
       - path_provider: ^2.1.0
       - path: ^1.9.0
       - csv: ^6.0.0
       - file_picker: ^8.0.0
       - window_manager: ^0.3.8
    3. Register JetBrainsMono font in pubspec.yaml fonts section.
    4. Create `lib/main.dart` — entry point that calls `windowManager.ensureInitialized()`, sets minimum size (800x600), default size (1280x800), then runs `App()` wrapped in `ProviderScope`.
    5. Create `lib/app.dart`:
       - Riverpod `ProviderScope` root
       - `MaterialApp.router` using `GoRouter` with routes: `/` (DeviceList), `/app-picker/:deviceId`, `/session/:sessionId`, `/session/active/:sessionId`, `/history`, `/compare`, `/settings`
       - Theme registration for all 4 themes per D-14/D-15: dark (default), light, high contrast, system
       - Custom title bar logic via `window_manager` — hidden native title bar, set `TitleBarStyle.hidden`
    6. Create `lib/shared/theme.dart`:
       - `AppColors` extension on `ColorScheme` with all design tokens from §9.1.1: bg.base (#1E1E1E), bg.sidebar (#252526), bg.elevated (#2D2D30), bg.hover (#2A2D2E), bg.selected (#094771), bg.input (#3C3C3C), text.primary (#D4D4D4), text.secondary (#858585), text.disabled (#5A5A5A), text.accent (#4FC3F7), border.subtle (#3C3C3C), border.focus (#007ACC), accent.blue (#007ACC), accent.recording (#F44747), accent.success (#4EC9B0), accent.warning (#CE9178), accent.danger (#F44747), accent.gold (#DCDCAA)
       - Per-metric chart colors map: FPS=#569CD6, CPU_App=#4EC9B0, CPU_System=#4EC9B060, Memory=#CE9178, Battery%=#DCDCAA, Battery_mA=#C586C0, Battery_mV=#9CDCFE, Battery_Temp=#F44747, Network_TX=#4FC1FF, Network_RX=#85C1E9, GPU=#C586C0, Thermal dynamic (0→#4EC9B0, 1→#CE9178, 2→#F44747, 3→#FF0000)
       - Four ThemeData factories: `darkTheme` (VS Code Dark+ defaults), `lightTheme` (inversions with light bg #FFFFFF, text #1E1E1E), `highContrastTheme` (black bg #000000, white text, yellow accent), `systemTheme` (delegates to platform brightness).
       - Typography scale from §9.1.2: text.xs=10, text.sm=11, text.base=13, text.md=14, text.lg=20, text.xl=28, mono.value=16, mono.sm=12
       - Monospace font: Cascadia Code on Windows, SF Mono on macOS, JetBrains Mono on Linux (bundled as fallback)
       - Per application spec: Never hardcode hex colors in widgets — use Theme.of(context) extensions.
    DO NOT: Create any business logic in this task — only Flutter project setup, routing, and theme infrastructure.
    Per D-18: No HTTP packages (http, dio, etc.) in pubspec.yaml. No network code anywhere.
  </action>
  <acceptance_criteria>
    - `pubspec.yaml` contains all 11 dependencies listed above with exact version constraints
    - `lib/main.dart` exists and calls `windowManager.ensureInitialized()` + `runApp(ProviderScope(child: App()))`
    - `lib/app.dart` exists with `MaterialApp.router` using `GoRouter` with all 7 routes
    - `lib/shared/theme.dart` exists with `AppColors` extension class and all 32+ color token getters
    - `lib/shared/theme.dart` contains `darkTheme`, `lightTheme`, `highContrastTheme`, `systemTheme` factories
    - `flutter analyze` reports zero errors in lib/
    - Project builds: `flutter build windows --debug` succeeds
    - Grep for 'http' in pubspec.yaml returns no HTTP client packages (only flutter sdk references)
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter analyze lib/main.dart lib/app.dart lib/shared/theme.dart</automated>
  </verify>
  <done>Flutter desktop app window appears with custom title bar and working GoRouter navigation. All 4 themes render with correct VS Code Dark+ color tokens. Project compiles cleanly on Windows.</done>
</task>

<task type="auto">
  <name>Task 2: Implement complete database schema (Appendix C exact) with migration runner, all model classes, and all DAOs</name>
  <files>
    lib/core/database/database.dart
    lib/core/database/session_dao.dart
    lib/core/database/metric_dao.dart
    lib/core/database/marker_dao.dart
    lib/core/database/session_stats_dao.dart
    lib/core/database/marker_stats_dao.dart
    lib/core/database/screenshot_dao.dart
    lib/core/models/session.dart
    lib/core/models/device.dart
    lib/core/models/metric_sample.dart
    lib/core/models/marker.dart
    lib/core/models/session_stats.dart
    lib/core/models/marker_stats.dart
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 3191-3602 (Appendix C SQL DDL — all CREATE TABLE statements)
    @UNIFIED-SPEC.md lines 1671-1829 (§8 Database Schema — key columns summary)
  </read_first>
  <action>
    1. Create `lib/core/database/database.dart`:
       - `Future<Database> initDatabase()` using `databaseFactoryFfi` from `sqflite_common_ffi`
       - Data dir path from `path_provider` → `<data_dir>/performancebench.db`
       - `Future<void> runMigrations(Database db)` — reads `schema_version` table, applies migrations additively
       - Migration v1: Execute ALL Appendix C v1.0 CREATE TABLE statements verbatim
       - Tables to create: `schema_version`, `devices`, `sessions`, `static_device_data`, `static_app_data`, `metric_samples`, `marker_groups`, `markers`, `regions`, `marker_stats`, `session_stats`, `screenshots`, `session_tags`
       - Insert `schema_version(version=1, applied_at=now_ms)`
       - All column names, types, and constraints MUST match Appendix C exactly. No deviations.
    
    2. Create all model classes in `lib/core/models/`:
       - `device.dart` — `class Device` with ALL columns from `devices` table: `id`, `name`, `manufacturer`, `model`, `os_version`, `os_api_level`, `kernel_version`, `chipset`, `chipset_vendor`, `gpu_vendor`, `gpu_model`, `cpu_cores_count`, `cpu_max_freq_khz`, `screen_resolution`, `screen_density_dpi`, `refresh_rate_hz`, `battery_capacity_mah`, `total_ram_kb`, `internal_storage_gb`, `is_rooted`, `is_emulator`, `first_seen_at`. Include `fromMap(Map<String, dynamic>)` and `toMap()` factories.
       - `metric_sample.dart` — `class MetricSample` with ALL columns from `metric_samples` table: `id`, `session_id`, `timestamp`, `fps`, `jank_count`, `jank_small_count`, `jank_big_count`, `jank_ratio_count`, `frametimes_json`, `cpu_system_pct`, `cpu_app_pct`, `cpu_app_pct_freq_norm`, `cpu_cores`, `cpu_core_states_json`, `cpu_core_freqs_json`, `cpu_threads_top_json`, `memory_pss_kb`, `memory_java_kb`, `memory_native_kb`, `memory_graphics_kb`, `memory_stack_kb`, `memory_code_kb`, `memory_system_kb`, `memory_webview_kb`, `battery_pct`, `battery_ma`, `battery_mv`, `battery_temp_c`, `charging`, `charging_source`, `wifi_active`, `net_tx_bytes`, `net_rx_bytes`, `net_wifi_tx_bytes`, `net_wifi_rx_bytes`, `net_cellular_tx_bytes`, `net_cellular_rx_bytes`, `net_other_tx_bytes`, `net_other_rx_bytes`, `thermal_status`, `gpu_pct`, `gpu_freq_mhz`, `gpu_mem_kb`, `disk_read_kb`, `disk_write_kb`, `screen_brightness`, `volume_pct`. Include `fromMap` and `toMap`.
       - `session.dart` — `class Session` with ALL columns from `sessions` table: `id`, `device_id`, `platform`, `target_kind`, `app_package`, `app_name`, `app_version`, `app_version_code`, `started_at`, `ended_at`, `duration_ms`, `title`, `notes`, `tags`, `tags_kv_json`, `target_fps`, `production_mode`, `strict_mode`, `injected`, `collection_id`, `project_id`, `user_id`.
       - `marker.dart` — `class Marker` matching `markers` table.
       - `session_stats.dart` — `class SessionStats` matching `session_stats` table with ALL columns from lines 3409-3485.
       - `marker_stats.dart` — `class MarkerStats` matching `marker_stats` table.
    
    3. Create all DAO classes:
       - `session_dao.dart` — CRUD operations for sessions table. Insert, update, query by id, query all ordered by started_at DESC, query by device_id, delete with confirmation.
       - `metric_dao.dart` — Batch insert (list of MetricSample), query by session_id ordered by timestamp ASC, query by session_id AND timestamp range (for marker stats), delete by session_id.
       - `marker_dao.dart` — insert marker, query by session_id, update ended_at, query launch_complete marker.
       - `session_stats_dao.dart` — upsert (INSERT OR REPLACE) session_stats row, query by session_id.
       - `marker_stats_dao.dart` — insert marker_stats, query by marker_id, query by session_id.
       - `screenshot_dao.dart` — insert screenshot row, query by session_id ordered by timestamp, delete by session_id.
    
    All DAOs accept a `Database` instance in constructor (no global state). Use proper parameterized queries — never string concatenation for SQL (SQL injection prevention).
    DO NOT: Add any v1.5+ tables (collections, detected_issues, videos, lenses, alerts, notification_channels, api_tokens, alert_events, team_*). v1.0 tables only.
  </action>
  <acceptance_criteria>
    - `lib/core/database/database.dart` contains `initDatabase()` returning `Future<Database>` and `runMigrations(Database)` creating all 13 v1.0 tables
    - `lib/core/models/metric_sample.dart` has exactly 53 fields matching `metric_samples` table columns
    - `lib/core/models/session.dart` has exactly 22 fields matching `sessions` table columns
    - `lib/core/models/device.dart` has exactly 23 fields matching `devices` table columns
    - `lib/core/models/session_stats.dart` has exactly 45 fields matching `session_stats` table columns
    - Every DAO uses parameterized queries (`db.insert(table, map)`, `db.query(table, where: 'id = ?', whereArgs: [id])`)
    - Grep for `rawInsert` or `rawQuery` with string interpolation returns zero results (all queries parameterized)
    - `schema_version` table has row with version=1 after initDatabase completes
    - No v1.5+ tables exist (grep for `collections`, `detected_issues`, `videos` CREATE TABLE returns zero)
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter analyze lib/core/ && dart test test/unit/ --concurrency=1</automated>
  </verify>
  <done>Database opens successfully, all 13 v1.0 tables created with exact Appendix C column names/types/constraints, all model classes serializable to/from Map, all DAOs functional with parameterized queries.</done>
</task>

<task type="auto">
  <name>Task 3: Implement ADB service wrapper with device discovery, app listing, static data collection, and wire navigation screens</name>
  <files>
    lib/core/services/adb_service.dart
    lib/features/device_list/device_list_screen.dart
    lib/features/device_list/device_card.dart
    lib/features/app_picker/app_picker_screen.dart
    lib/features/app_picker/app_list_item.dart
    lib/features/active_session/active_session_screen.dart
    lib/features/active_session/charts_tab.dart
    lib/features/active_session/screenshots_tab.dart
    lib/features/active_session/markers_tab.dart
    lib/features/session_history/history_screen.dart
    lib/features/session_history/session_list_item.dart
    lib/features/session_detail/detail_screen.dart
    lib/features/session_detail/scorecard_tab.dart
    lib/features/session_detail/replay_charts_tab.dart
    lib/features/session_detail/fps_analysis_tab.dart
    lib/features/session_detail/markers_detail_tab.dart
    lib/features/comparison/comparison_screen.dart
    lib/features/settings/settings_screen.dart
    lib/shared/widgets/metric_chart.dart
    lib/shared/widgets/fps_histogram_chart.dart
    lib/shared/widgets/scorecard_widget.dart
    lib/shared/widgets/marker_stats_table.dart
    lib/shared/widgets/comparison_delta_table.dart
    lib/shared/widgets/metric_value_badge.dart
    lib/shared/widgets/gpu_unavailable_badge.dart
    .github/workflows/ci.yml
    .github/workflows/packet-capture-test.yml
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 393-501 (§4.1 Android features table, §4.3 Android metrics)
    @UNIFIED-SPEC.md lines 1038-1106 (§5.11 Static Device + App Data)
    @UNIFIED-SPEC.md lines 1945-2033 (§9.2 Application Shell Layout, §9.3 Custom Title Bar)
  </read_first>
  <action>
    1. Create `lib/core/services/adb_service.dart` — ADB service class:
       - Constructor takes no args; finds `adb` on PATH via `which adb` (or `where adb` on Windows).
       - `Future<List<Device>> discoverDevices()` — runs `adb devices -l`, parses output for serial, transport_id, product, model, device state. Returns list of Device objects with `name`, `id` (serial). Filters out unauthorized/offline devices from active list but shows them as disabled rows.
       - `Future<List<AppInfo>> listApps(String serial)` — runs `adb -s <serial> shell pm list packages -3`, parses package names. For each package, runs `dumpsys package <pkg>` to extract app label (labelRes/nonLocalizedLabel), versionName, versionCode. Returns list with `AppInfo(package, name, version, buildNumber)`.
       - `Future<StaticDeviceData> collectStaticData(String serial)` — runs all commands from §5.11 to collect device manufacturer, model, board, OS version, chipset, GPU vendor/model/driver, screen resolution/density, RAM, storage, battery capacity, is_emulator, is_rooted. Stores in `static_device_data` table. Parses `getprop` output fields exactly as listed in §5.11.
       - `Future<StaticAppData> collectAppData(String serial, String package)` — runs `dumpsys package <pkg>` to extract install source, install/update time, targetSdk, minSdk, permissions, ABI list, APK size.
       - All ADB calls use 3-second timeout (`Process.run` with timeout). On timeout or non-zero exit: return null for that field, log the error, continue.
       - Private method `_runAdb(List<String> args, {Duration timeout = const Duration(seconds: 3)})` centralizes all ADB subprocess calls.
       - No blocking on UI thread — all methods return `Future` and use async/await.
    
    2. Create all feature screen skeletons per D-02 (skeleton-first):
       - `lib/features/device_list/device_list_screen.dart` — VS Code-style activity bar (48px left strip with icon-only buttons: Devices/History/Compare/Settings), collapsible sidebar (280px) showing device tree (connected devices with status dot, recent sessions list), main content area with placeholder text "Select a device to start profiling".
       - `lib/features/device_list/device_card.dart` — ListTile-like widget showing platform icon, device name, OS version, connection status (green dot=connected, grey=offline, red=unauthorized), "Start" button.
       - `lib/features/app_picker/app_picker_screen.dart` — Shows list of installed apps on selected device. Each row: app icon (placeholder), app label, package name, version. "Start Profiling" button navigates to active session.
       - `lib/features/app_picker/app_list_item.dart` — ListTile widget showing app label, package name, version.
       - All remaining screen files: Create minimal placeholder widgets that display the screen name in a centered Text widget on `bg.base` background. Each screen must be importable and navigable via GoRouter.
       - Active session screen: shows REC indicator placeholder, stop button, empty chart grid area with 2-column layout framework.
       - History screen: shows table header row (Date, App, Device, Duration, FPS, Tag) with empty state "No sessions recorded yet".
       - Session detail screen: shows tab bar with 5 tabs (Scorecard, Charts, FPS Analysis, Markers, Screenshots), each tab a placeholder.
       - Comparison screen: shows two session selector dropdowns + empty delta table.
       - Settings screen: shows two-column layout (categories left, settings right) with placeholder sections.
       - Shared widget files: create stub classes that render placeholder Text / Container widgets. Each widget must accept appropriate constructor params so later waves can wire real data.
    
    3. Create CI workflow files:
       - `.github/workflows/ci.yml` — GitHub Actions workflow triggered on push to main and PRs. Matrix: `os: [windows-latest, macos-latest, ubuntu-latest]`. Steps: checkout, install Flutter 3.19+, `flutter pub get`, `flutter analyze`, `flutter build windows` (Windows), `flutter build macos` (macOS), `flutter build linux` (Linux). Must pass on all three OS.
       - `.github/workflows/packet-capture-test.yml` — Placeholder workflow with name "Privacy Verification — Packet Capture". Contains a comment documenting the test that will be implemented: "Verifies zero outbound network connections during a 30-min profiling session using tshark/pktmon. To be completed in Wave 7 per D-20."
    
    4. Create iOS agent files (skeleton placeholders per D-01 — iOS built in parallel from start):
       - `ios_agents/requirements.txt` — contains: `py-ios-device>=2.0.0`
       - `ios_agents/collector.py` — placeholder Python script that prints JSON comment header describing the interface contract (§5.10): streams newline-delimited JSON to stdout with keys fps, jank.small, jank.jank, jank.big, cpu, mem_bytes, bat_pct, bat_ma, bat_mv, bat_temp_c, net_tx, net_rx, thermal, gpu_pct. Contains `def main(): pass` with TODO.
       - `ios_agents/device_list.py` — placeholder script. Prints JSON comment describing interface: lists connected iOS devices via pyidevice.
       - `ios_agents/app_list.py` — placeholder script. Prints JSON comment describing interface: lists installed apps on iOS device.
    
    DO NOT: Implement real iOS collection logic in this task (belongs to Wave 4, MVP-17). Only skeleton files with interface contracts.
    DO NOT: Create any network code (HTTP clients, sockets except ADB local). Per D-18, privacy guard from scaffold.
    Per D-17: Include a StatusBar widget area in the app shell (22px bottom bar) showing ready state.
    Per D-16: Include a notion of debug mode (command-line `--debug` flag parsed in main.dart, stored as Riverpod provider).
  </action>
  <acceptance_criteria>
    - `lib/core/services/adb_service.dart` contains `AdbService` class with `discoverDevices()`, `listApps()`, `collectStaticData()`, `collectAppData()` methods
    - All ADB calls use 3-second timeout via `Process.run` with `timeout` parameter
    - `lib/features/device_list/device_list_screen.dart` renders activity bar (4 icons) + sidebar (device tree + recent sessions) + main content
    - All 8 feature screen directories have a main screen file with a named widget class (e.g., `class DeviceListScreen extends ConsumerWidget`)
    - GoRouter in app.dart has working routes for all 7 screens — navigating between them works
    - `flutter analyze` reports zero errors in entire lib/
    - `.github/workflows/ci.yml` exists with matrix build for windows-latest, macos-latest, ubuntu-latest
    - `grep -r 'http\.' lib/` returns zero results (no HTTP network code)
    - `ios_agents/` directory exists with 4 files: requirements.txt, collector.py, device_list.py, app_list.py
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter analyze lib/ && flutter test test/unit/ring_buffer_test.dart</automated>
  </verify>
  <done>App launches with VS Code shell layout, all 7 screens navigable, ADB service discovers connected Android devices and lists installed apps, static device data collected, CI builds on all 3 platforms, privacy guard verified (zero network code).</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| ADB subprocess → App | ADB shell commands execute on connected Android device. Untrusted device output enters app parsing pipeline. |
| File system → App | SQLite database file stored in user-writable data directory. Other processes on same machine could modify it. |
| Python subprocess → App | iOS collector.py stdout JSON stream. Malformed or crafted JSON enters app. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-01 | Tampering | adb_service.dart — ADB output parsing | mitigate | Validate all ADB output before parsing; return null (not crash) on malformed output; numeric fields parsed with int.tryParse/double.tryParse; string fields sanitized with size limits |
| T-01-02 | Information Disclosure | database.dart — SQLite file permissions | mitigate | Create SQLite file with OS-default user permissions (0644 on Unix); document that data directory is user-private in README |
| T-01-03 | Denial of Service | adb_service.dart — ADB subprocess timeout | mitigate | All ADB calls use 3-second timeout; failed calls return null and log error; session never crashes on ADB failure |
| T-01-04 | Elevation of Privilege | adb_service.dart — shell command injection | mitigate | ADB serial strings validated against alphanumeric+dot+dash+colon pattern before passing to shell; package names validated against Android package name regex |
| T-01-05 | Spoofing | device_list_screen.dart — device identity | accept | ADB protocol does not provide cryptographic device identity. Risk accepted — app displays what ADB reports. User is responsible for device trust. |
</threat_model>

<verification>
- `flutter run -d windows` — app window appears with dark theme, activity bar, sidebar, all screens navigable
- `flutter analyze` — zero errors
- Open `performancebench.db` with SQLite CLI, run `.schema` — compare against Appendix C DDL
- ADB device discovery shows connected devices with name, model, OS version
- CI workflow passes on push to GitHub (all 3 OS)
</verification>

<success_criteria>
1. Flutter desktop app compiles and runs on Windows with full VS Code-inspired shell layout (activity bar, sidebar, tab bar, status bar, custom title bar)
2. SQLite database created on first launch with all 13 v1.0 tables matching Appendix C column names, types, and constraints exactly
3. ADB service discovers connected Android devices, lists installed apps, and collects static device+app data
4. All 7 navigation routes work — DeviceList → AppPicker → ActiveSession → History → SessionDetail → Comparison → Settings
5. All 4 themes (Dark, Light, High Contrast, System) render correctly from ThemeData design tokens
6. GitHub Actions CI builds green on windows-latest, macos-latest, ubuntu-latest
7. Zero HTTP network code anywhere in lib/ (verified by grep)
8. iOS agent skeleton files exist with interface contract documentation
</success_criteria>

<output>
After completion, create `.planning/phases/01-v1-0-external-profiling-mvp/01-SUMMARY.md`
</output>
