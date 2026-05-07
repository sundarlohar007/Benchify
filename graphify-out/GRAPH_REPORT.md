# Graph Report - Benchify  (2026-05-06)

## Corpus Check
- 413 files · ~270,825 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 3219 nodes · 4637 edges · 97 communities detected
- Extraction: 79% EXTRACTED · 21% INFERRED · 0% AMBIGUOUS · INFERRED: 968 edges (avg confidence: 0.7)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]
- [[_COMMUNITY_Community 55|Community 55]]
- [[_COMMUNITY_Community 56|Community 56]]
- [[_COMMUNITY_Community 57|Community 57]]
- [[_COMMUNITY_Community 58|Community 58]]
- [[_COMMUNITY_Community 59|Community 59]]
- [[_COMMUNITY_Community 60|Community 60]]
- [[_COMMUNITY_Community 61|Community 61]]
- [[_COMMUNITY_Community 62|Community 62]]
- [[_COMMUNITY_Community 63|Community 63]]
- [[_COMMUNITY_Community 64|Community 64]]
- [[_COMMUNITY_Community 65|Community 65]]
- [[_COMMUNITY_Community 66|Community 66]]
- [[_COMMUNITY_Community 68|Community 68]]
- [[_COMMUNITY_Community 70|Community 70]]
- [[_COMMUNITY_Community 71|Community 71]]
- [[_COMMUNITY_Community 72|Community 72]]
- [[_COMMUNITY_Community 80|Community 80]]
- [[_COMMUNITY_Community 81|Community 81]]
- [[_COMMUNITY_Community 82|Community 82]]
- [[_COMMUNITY_Community 83|Community 83]]
- [[_COMMUNITY_Community 84|Community 84]]
- [[_COMMUNITY_Community 85|Community 85]]
- [[_COMMUNITY_Community 86|Community 86]]
- [[_COMMUNITY_Community 87|Community 87]]
- [[_COMMUNITY_Community 88|Community 88]]
- [[_COMMUNITY_Community 89|Community 89]]
- [[_COMMUNITY_Community 90|Community 90]]
- [[_COMMUNITY_Community 91|Community 91]]
- [[_COMMUNITY_Community 92|Community 92]]
- [[_COMMUNITY_Community 93|Community 93]]
- [[_COMMUNITY_Community 94|Community 94]]
- [[_COMMUNITY_Community 95|Community 95]]
- [[_COMMUNITY_Community 96|Community 96]]
- [[_COMMUNITY_Community 97|Community 97]]
- [[_COMMUNITY_Community 98|Community 98]]
- [[_COMMUNITY_Community 114|Community 114]]
- [[_COMMUNITY_Community 121|Community 121]]
- [[_COMMUNITY_Community 127|Community 127]]
- [[_COMMUNITY_Community 128|Community 128]]
- [[_COMMUNITY_Community 129|Community 129]]
- [[_COMMUNITY_Community 130|Community 130]]
- [[_COMMUNITY_Community 131|Community 131]]
- [[_COMMUNITY_Community 132|Community 132]]
- [[_COMMUNITY_Community 133|Community 133]]
- [[_COMMUNITY_Community 134|Community 134]]
- [[_COMMUNITY_Community 135|Community 135]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 61 edges
2. `SigningMethod` - 57 edges
3. `collect()` - 44 edges
4. `InjectionResult` - 42 edges
5. `CheckResult` - 42 edges
6. `SignResult` - 38 edges
7. `package:flutter_test/flutter_test.dart` - 35 edges
8. `VerificationResult` - 35 edges
9. `FridaInjector` - 34 edges
10. `TvosMetricSample` - 33 edges

## Surprising Connections (you probably didn't know these)
- `Java_dev_benchify_WebViewBridge_nativeReportJsHeap()` --calls--> `report_js_heap()`  [INFERRED]
  performancebench-injector\sdk\src\jni_bridge.rs → performancebench-injector\sdk\src\metrics\webview_js.rs
- `test_cpu_parser_parses_proc_self_stat()` --calls--> `parse_proc_self_stat()`  [INFERRED]
  performancebench-injector\sdk\tests\integration_test.rs → performancebench-injector\sdk\src\metrics\cpu.rs
- `test_network_parser_parses_proc_net_dev()` --calls--> `parse_net_dev()`  [INFERRED]
  performancebench-injector\sdk\tests\integration_test.rs → performancebench-injector\sdk\src\metrics\net_per_process.rs
- `list_projects()` --calls--> `collect()`  [INFERRED]
  performancebench-server\db\src\team_queries.rs → performancebench-injector\sdk\src\metrics\net_per_process.rs
- `list_sessions()` --calls--> `collect()`  [INFERRED]
  performancebench-server\server\src\routes\sessions.rs → performancebench-injector\sdk\src\metrics\net_per_process.rs

## Communities

### Community 0 - "Community 0"
Cohesion: 0.01
Nodes (310): adb_service.dart, alert_service.dart, api_service.dart, ../../core/analytics/analytics_service.dart, ../../core/analytics/detected_issues_service.dart, ../../core/sdk/sdk_state.dart, ../../core/services/api_service.dart, AnalyticsService (+302 more)

### Community 1 - "Community 1"
Cohesion: 0.01
Nodes (249): app.dart, charts_tab.dart, ../../core/models/device.dart, ../../core/models/ipa_signing_config.dart, ../../core/models/keystore_config.dart, ../../core/services/adb_service.dart, ../../core/services/error_handler.dart, ../../core/services/injection_service.dart (+241 more)

### Community 2 - "Community 2"
Cohesion: 0.02
Nodes (165): create_minimal_entitlements(), detect_available_methods(), _find_app_bundle_in_dir(), free_apple_id_sign(), paid_developer_sign(), Create a minimal entitlements.plist for development signing.      Returns:, Write entitlements dict to a temporary plist file.      Returns:         Path to, Find the .app bundle path within an extracted IPA directory.      Args: (+157 more)

### Community 3 - "Community 3"
Cohesion: 0.02
Nodes (110): create_sso_config(), CreateSsoConfigRequest, delete_sso_config(), get_user(), list_sso_configs(), list_users(), ListUsersQuery, update_sso_config() (+102 more)

### Community 4 - "Community 4"
Cohesion: 0.02
Nodes (73): admin_router(), CreateAlertRuleBody, ListAlertEventsQuery, router(), UpdateAlertRuleBody, audit_router(), register(), Args (+65 more)

### Community 5 - "Community 5"
Cohesion: 0.02
Nodes (106): main, _AdbCall, _FakeAdbShell, main, whenCommandContains, colorForFps, main, main (+98 more)

### Community 6 - "Community 6"
Cohesion: 0.02
Nodes (116): app_list_item.dart, ../../core/database/collection_dao.dart, ../../core/database/database.dart, ../../core/database/detected_issue_dao.dart, ../../core/database/marker_dao.dart, ../../core/database/marker_stats_dao.dart, ../../core/database/region_stats_dao.dart, ../../core/database/session_dao.dart (+108 more)

### Community 7 - "Community 7"
Cohesion: 0.03
Nodes (87): list_apps(), AppDelegate, PcCollector, test_pc_collector_close_no_panic(), test_pc_collector_new_returns_result(), test_pc_collector_tick_produces_metric_sample(), get_device_session_count(), list_devices_for_user() (+79 more)

### Community 8 - "Community 8"
Cohesion: 0.02
Nodes (87): AutoMarkerHook, Benchify, BeginMarker, Benchify, GetFrameStatsJson(), IsEngineLibraryLoaded(), BuildStatsPanel(), Construct() (+79 more)

### Community 9 - "Community 9"
Cohesion: 0.03
Nodes (78): AuditExportQuery, AuditListQuery, AuditPurgeQuery, export_audit_events(), get_audit_event(), list_audit_events(), parse_iso_date(), purge_audit_events() (+70 more)

### Community 10 - "Community 10"
Cohesion: 0.02
Nodes (90): ../../core/database/metric_dao.dart, ../../core/models/metric_sample.dart, ../../core/services/ios_service.dart, ../../core/services/pcprobe_service.dart, ActiveSessionChartsTab, build, LayoutBuilder, SizedBox (+82 more)

### Community 11 - "Community 11"
Cohesion: 0.04
Nodes (62): compute_app_cpu_pct(), compute_system_cpu_pct(), parse_proc_self_stat(), parse_proc_stat_total(), test_compute_app_cpu_pct(), test_compute_app_cpu_pct_clamped(), test_parse_proc_self_stat_normal(), test_parse_proc_self_stat_spaces_in_name() (+54 more)

### Community 12 - "Community 12"
Cohesion: 0.03
Nodes (39): AuditEvent, AuditEventCategory, AuditEventResponse, AuditEventType, CreateAuditEvent, String, test_audit_event_category_serde_roundtrip(), test_audit_event_type_serde_roundtrip() (+31 more)

### Community 13 - "Community 13"
Cohesion: 0.03
Nodes (62): _back, build, _buildStep, Center, Container, _finish, _next, OnboardingScreen (+54 more)

### Community 14 - "Community 14"
Cohesion: 0.07
Nodes (53): CheckResult, _find_app_bundle_in_ipa(), Verify PerformanceBench appears in the main executable's load commands.      Use, Result of a single verification check., Verify code signature on the .app bundle.      Args:         app_dir: Path to th, Find the .app bundle name from an IPA zip file.      Args:         ipa_path: Pat, Aggregate result of all verification checks., Run all verification checks on an injected IPA.      Per 05-02-PLAN:       Check (+45 more)

### Community 15 - "Community 15"
Cohesion: 0.05
Nodes (31): Benchify.Editor, BenchifyEditorWindow, BenchifyService, EditorWindow, _add_missing_permissions(), _add_sdk_components(), _get_existing_permissions(), ManifestPatchResult (+23 more)

### Community 16 - "Community 16"
Cohesion: 0.07
Nodes (48): Should return empty list when pyidevice fails., Should flag gen 1/2 Apple TV without USB-C., Tests for tvOS metric fields that should always be NULL/None., Battery fields should be in the NULLABLE list., Cellular network fields should be in the NULLABLE list., FPS, CPU, Memory should NOT be in NULLABLE list., Tests for tvOS available metric channels., FPS channel should be in available channels. (+40 more)

### Community 17 - "Community 17"
Cohesion: 0.05
Nodes (41): _find_smali_dirs(), _get_class_name(), _get_super_class(), parse_mapping(), ProGuard/R8 mapping.txt parser — resolves obfuscated class/method names.  Per D-, Find all smali directories in a decoded APK., Extract the super class from a smali file., Parse a ProGuard mapping.txt file into a class name lookup table.      Format: (+33 more)

### Community 18 - "Community 18"
Cohesion: 0.08
Nodes (48): AutomationState, handle_command(), handle_export(), handle_marker(), handle_pause(), handle_resume(), handle_screenshot(), handle_start_session() (+40 more)

### Community 19 - "Community 19"
Cohesion: 0.07
Nodes (35): chunk_filename(), ChunkManager, ChunkRecord, temp_output_dir(), test_build_concat_list_format(), test_chunk_manager_default_values(), test_chunk_manager_new_creates_directory(), test_get_chunks_json_format() (+27 more)

### Community 20 - "Community 20"
Cohesion: 0.07
Nodes (44): AabConversionError, convert_aab_to_apk(), AAB to APK converter — wraps bundletool for universal APK generation.  Per D-05:, Raised when AAB conversion fails., Convert an Android App Bundle (.aab) to a universal APK using bundletool.      A, ApkValidationError, decompile_apk(), DecompileError (+36 more)

### Community 21 - "Community 21"
Cohesion: 0.1
Nodes (32): on_app_pause(), on_app_resume(), on_app_start(), on_scene_load(), on_user_marker(), test_app_pause_resume_markers(), test_app_start_emits_launch_marker(), test_scene_loaded_triggers_marker_pair() (+24 more)

### Community 22 - "Community 22"
Cohesion: 0.1
Nodes (28): FlutterWindow(), MessageHandler(), OnCreate(), OnDestroy(), RegisterPlugins(), wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments() (+20 more)

### Community 23 - "Community 23"
Cohesion: 0.07
Nodes (27): create_alert_event(), list_active_alert_rules(), update_alert_rule(), compute_fps_stats(), compute_session_stats(), FpsStats, mean(), mean_i64() (+19 more)

### Community 24 - "Community 24"
Cohesion: 0.05
Nodes (37): ../../core/database/video_dao.dart, ../../core/models/video.dart, build, Center, Column, Container, dispose, _formatTime (+29 more)

### Community 25 - "Community 25"
Cohesion: 0.06
Nodes (34): ../../core/services/plugin_install_service.dart, build, _buildActionButton, _buildEngineIcon, _buildStatusBadge, Card, Container, _getStatus (+26 more)

### Community 26 - "Community 26"
Cohesion: 0.06
Nodes (33): build, _buildAboutSection, _buildAppearanceSection, _buildChartsSection, _buildKeyboardShortcuts, _buildPathsSection, _buildProfilingSection, Chip (+25 more)

### Community 27 - "Community 27"
Cohesion: 0.12
Nodes (20): audit_session_event(), build_adf_description(), create_jira_issue(), CreateJiraIssueRequest, CreateJiraIssueResponse, fmt_opt(), fmt_opt_kb(), generate_summary() (+12 more)

### Community 28 - "Community 28"
Cohesion: 0.11
Nodes (23): Run verification steps on an already-injected APK.      Steps: apksigner verify, verify(), Tests for verifier.py — Multi-step APK verification., Tests for ADB port forwarding and SDK connectivity test., Tests for apksigner signature verification., Tests for Smali patch validation., test_confirms_sdk_init_present(), test_detects_scheme_versions() (+15 more)

### Community 29 - "Community 29"
Cohesion: 0.14
Nodes (5): Benchify, BenchifyPlugin, MonoBehaviour, Benchify, NativeBindings

### Community 30 - "Community 30"
Cohesion: 0.15
Nodes (12): collect_metrics(), JankTracker, main(), # TODO: Parse CLI args (--udid), # TODO: Connect to iOS device via pyidevice, # TODO: Initialize metric collection loop (1 Hz), # TODO: Collect and emit metrics as JSON lines, Computes 3-tier jank classification from rolling frame times. (+4 more)

### Community 31 - "Community 31"
Cohesion: 0.24
Nodes (15): create_capture_item(), init_capture(), list_display_targets(), start_capture(), stop_capture(), test_config(), test_create_capture_item(), test_init_capture() (+7 more)

### Community 32 - "Community 32"
Cohesion: 0.29
Nodes (14): test_get_webview_memory_returns_none_when_no_data(), test_report_js_heap_overwrites_previous(), test_report_js_heap_stores_value(), test_webview_memory_in_metricsample(), test_webview_memory_serialization(), get_webview_memory(), report_js_heap(), reset_webview_memory() (+6 more)

### Community 33 - "Community 33"
Cohesion: 0.28
Nodes (10): list_display_targets(), MacCaptureSession, start_capture(), stop_capture(), test_config(), test_list_display_targets(), test_start_capture_invalid_dimensions(), test_start_capture_invalid_fps() (+2 more)

### Community 34 - "Community 34"
Cohesion: 0.24
Nodes (11): _emit(), _encode_chunk(), _get_lockdown_client(), main(), _on_sigterm(), Stream DVT frames to ffmpeg stdin until stopped or chunk_complete.     Returns T, Handle SIGTERM — gracefully stop after current chunk., Write a JSON status line to stdout and flush. (+3 more)

### Community 35 - "Community 35"
Cohesion: 0.17
Nodes (11): obfuscated_apk_dir(), Pytest fixtures for performancebench-injector tests., Create a mock ProGuard mapping.txt file., Create a temporary directory that is cleaned up after test., Create a mock decoded APK with ProGuard-obfuscated Application class., Create a mock decoded APK with no Application subclass (uses default)., Create a mock decoded APK directory structure with smali files., sample_apk_dir() (+3 more)

### Community 36 - "Community 36"
Cohesion: 0.2
Nodes (9): APK re-signing engine — wraps apksigner from Android Build Tools.  Per D-07: Ful, Re-sign an APK using apksigner with the provided keystore.      Per D-07: Full r, resign(), Tests for resigner.py — APK re-signing via apksigner., Tests for APK re-signing with apksigner., Should raise FileNotFoundError if keystore doesn't exist., test_calls_apksigner_with_correct_args(), test_raises_on_apksigner_failure() (+1 more)

### Community 37 - "Community 37"
Cohesion: 0.17
Nodes (8): AttributeMapping, CreateSsoConfig, LdapProviderConfig, OidcProviderConfig, SamlProviderConfig, SsoConfig, SsoProviderType, UpdateSsoConfig

### Community 39 - "Community 39"
Cohesion: 0.25
Nodes (7): BatteryParser, BatteryResult, _extractBool, parseCurrentNow, parseDumpsysBattery, parseVoltageNow, parseWifiState

### Community 40 - "Community 40"
Cohesion: 0.25
Nodes (7): CpuFreqResult, CpuParser, CpuResult, parse, parseCoreFreqs, _storeSnapshots, _SystemTicks

### Community 41 - "Community 41"
Cohesion: 0.29
Nodes (2): JsBridge, WebViewBridge

### Community 42 - "Community 42"
Cohesion: 0.25
Nodes (4): AlertEvent, AlertRule, Lens, WebhookConfig

### Community 43 - "Community 43"
Cohesion: 0.43
Nodes (6): buildTrendParams(), useBatteryTrends(), useCpuTrends(), useFpsTrends(), useMemoryTrends(), useNetworkTrends()

### Community 45 - "Community 45"
Cohesion: 0.29
Nodes (4): Device, DeviceInfo, collect_metrics(), Stream metrics at 1Hz from tidevice.

### Community 47 - "Community 47"
Cohesion: 0.33
Nodes (4): # TODO: Parse CLI args (--udid), # TODO: Connect to iOS device via pyidevice, # TODO: Enumerate installed apps, # TODO: Output JSON array to stdout

### Community 48 - "Community 48"
Cohesion: 0.33
Nodes (5): GpuParser, GpuResult, parseAdreno, parseAny, parseMaliUtil

### Community 49 - "Community 49"
Cohesion: 0.33
Nodes (5): clearErrors, ErrorEntry, ErrorHandler, logError, setDebugMode

### Community 50 - "Community 50"
Cohesion: 0.33
Nodes (2): RunnerTests, XCTestCase

### Community 51 - "Community 51"
Cohesion: 0.33
Nodes (2): ProtectedRoute(), useAuth()

### Community 53 - "Community 53"
Cohesion: 0.4
Nodes (3): Benchify.Editor, BenchifySettings, ScriptableObject

### Community 54 - "Community 54"
Cohesion: 0.4
Nodes (3): Benchify, BenchifyEditor, ModuleRules

### Community 55 - "Community 55"
Cohesion: 0.4
Nodes (3): # TODO: Discover connected iOS devices via pyidevice, # TODO: Collect device properties (name, OS version, model, UDID), # TODO: Output JSON array to stdout

### Community 56 - "Community 56"
Cohesion: 0.4
Nodes (4): IpaInjectionResult, IpaMetadata, IpaSigningConfig, toPythonValue

### Community 57 - "Community 57"
Cohesion: 0.4
Nodes (4): DiskIoParser, DiskIoResult, parse, reset

### Community 58 - "Community 58"
Cohesion: 0.4
Nodes (4): parseGetprop, parseThermalService, ThermalParser, ThermalResult

### Community 59 - "Community 59"
Cohesion: 0.6
Nodes (1): BenchifyBroadcastReceiver

### Community 60 - "Community 60"
Cohesion: 0.4
Nodes (2): GeneratedPluginRegistrant, -registerWithRegistry

### Community 61 - "Community 61"
Cohesion: 0.5
Nodes (2): buildFiltersFromForm(), handleSave()

### Community 62 - "Community 62"
Cohesion: 0.5
Nodes (3): MemoryParser, MemoryResult, parse

### Community 63 - "Community 63"
Cohesion: 0.67
Nodes (2): collectMetrics(), startMetricCollection()

### Community 64 - "Community 64"
Cohesion: 0.5
Nodes (2): handle_new_rx_page(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.

### Community 65 - "Community 65"
Cohesion: 0.5
Nodes (2): Session, SessionStats

### Community 66 - "Community 66"
Cohesion: 0.5
Nodes (3): NewLocalUser, NewSsoUser, User

### Community 68 - "Community 68"
Cohesion: 0.5
Nodes (1): ApiError

### Community 70 - "Community 70"
Cohesion: 0.67
Nodes (2): FlutterSceneDelegate, SceneDelegate

### Community 71 - "Community 71"
Cohesion: 0.67
Nodes (1): Marker

### Community 72 - "Community 72"
Cohesion: 0.67
Nodes (1): AppError

### Community 80 - "Community 80"
Cohesion: 1.0
Nodes (1): Collection

### Community 81 - "Community 81"
Cohesion: 1.0
Nodes (1): DetectedIssue

### Community 82 - "Community 82"
Cohesion: 1.0
Nodes (1): KeystoreConfig

### Community 83 - "Community 83"
Cohesion: 1.0
Nodes (1): Marker

### Community 84 - "Community 84"
Cohesion: 1.0
Nodes (1): MarkerStats

### Community 85 - "Community 85"
Cohesion: 1.0
Nodes (1): MetricSample

### Community 86 - "Community 86"
Cohesion: 1.0
Nodes (1): RegionStats

### Community 87 - "Community 87"
Cohesion: 1.0
Nodes (1): Session

### Community 88 - "Community 88"
Cohesion: 1.0
Nodes (1): SessionStats

### Community 89 - "Community 89"
Cohesion: 1.0
Nodes (1): Video

### Community 90 - "Community 90"
Cohesion: 1.0
Nodes (1): SdkState

### Community 91 - "Community 91"
Cohesion: 1.0
Nodes (1): Frida injection module — gadget injection without APK resigning.  Per D-09: Frid

### Community 92 - "Community 92"
Cohesion: 1.0
Nodes (1): MainActivity

### Community 93 - "Community 93"
Cohesion: 1.0
Nodes (1): Collection

### Community 94 - "Community 94"
Cohesion: 1.0
Nodes (1): DetectedIssue

### Community 95 - "Community 95"
Cohesion: 1.0
Nodes (1): MarkerStats

### Community 96 - "Community 96"
Cohesion: 1.0
Nodes (1): MetricSample

### Community 97 - "Community 97"
Cohesion: 1.0
Nodes (1): RegionStats

### Community 98 - "Community 98"
Cohesion: 1.0
Nodes (1): VideoMetadata

### Community 114 - "Community 114"
Cohesion: 1.0
Nodes (1): Parse a pyidevice device JSON entry.

### Community 121 - "Community 121"
Cohesion: 1.0
Nodes (1): Return help text for Frida-specific CLI arguments.

### Community 127 - "Community 127"
Cohesion: 1.0
Nodes (1): Should invoke apksigner sign with correct keystore and password flags.

### Community 128 - "Community 128"
Cohesion: 1.0
Nodes (1): Should raise RuntimeError when apksigner fails.

### Community 129 - "Community 129"
Cohesion: 1.0
Nodes (1): Should return pass status when apksigner exits 0.

### Community 130 - "Community 130"
Cohesion: 1.0
Nodes (1): Should detect v1, v2, v3 signature schemes from output.

### Community 131 - "Community 131"
Cohesion: 1.0
Nodes (1): Should raise RuntimeError when apksigner exits non-zero.

### Community 132 - "Community 132"
Cohesion: 1.0
Nodes (1): Should return pass when SdkLoader.init is found.

### Community 133 - "Community 133"
Cohesion: 1.0
Nodes (1): Should raise RuntimeError when SdkLoader.init is not found.

### Community 134 - "Community 134"
Cohesion: 1.0
Nodes (1): Should connect to port 8080, read JSON, and verify timestamp field.

### Community 135 - "Community 135"
Cohesion: 1.0
Nodes (1): Should raise RuntimeError on socket timeout.

## Knowledge Gaps
- **1337 isolated node(s):** `Benchify.Editor`, `Benchify.Editor`, `Benchify`, `Benchify`, `Benchify` (+1332 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 41`** (8 nodes): `WebViewBridge.java`, `JsBridge`, `.reportMemory()`, `WebViewBridge`, `.install()`, `.nativeReportJsHeap()`, `.probeJsMemory()`, `.reset()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 50`** (6 nodes): `RunnerTests.swift`, `RunnerTests.swift`, `RunnerTests.swift`, `RunnerTests`, `.testExample()`, `XCTestCase`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 51`** (6 nodes): `ProtectedRoute.tsx`, `useAuth.ts`, `ProtectedRoute()`, `useAuth()`, `useLogin()`, `useLogout()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 59`** (5 nodes): `BenchifyBroadcastReceiver`, `.nativeHandleCommand()`, `.onReceive()`, `.sendErrorResponse()`, `BenchifyBroadcastReceiver.java`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 60`** (5 nodes): `GeneratedPluginRegistrant`, `.registerWith()`, `-registerWithRegistry`, `GeneratedPluginRegistrant.java`, `GeneratedPluginRegistrant.m`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 61`** (5 nodes): `buildFiltersFromForm()`, `handleApply()`, `handleSave()`, `startEdit()`, `lenses.tsx`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 63`** (4 nodes): `collectMetrics()`, `startMetricCollection()`, `stopProfiling()`, `benchify_frida_agent.js`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 64`** (4 nodes): `handle_new_rx_page()`, `__lldb_init_module()`, `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `flutter_lldb_helper.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 65`** (4 nodes): `session.rs`, `default_true()`, `Session`, `SessionStats`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 68`** (4 nodes): `ApiError`, `.constructor()`, `apiFetch()`, `api.ts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 70`** (3 nodes): `FlutterSceneDelegate`, `SceneDelegate.swift`, `SceneDelegate`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 71`** (3 nodes): `default_marker_type()`, `Marker`, `marker.rs`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 72`** (3 nodes): `AppError`, `.into_response()`, `error.rs`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 80`** (2 nodes): `Collection`, `collection.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 81`** (2 nodes): `DetectedIssue`, `detected_issue.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 82`** (2 nodes): `KeystoreConfig`, `keystore_config.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 83`** (2 nodes): `Marker`, `marker.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 84`** (2 nodes): `MarkerStats`, `marker_stats.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 85`** (2 nodes): `MetricSample`, `metric_sample.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 86`** (2 nodes): `RegionStats`, `region_stats.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 87`** (2 nodes): `Session`, `session.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 88`** (2 nodes): `SessionStats`, `session_stats.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 89`** (2 nodes): `Video`, `video.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 90`** (2 nodes): `SdkState`, `sdk_state.dart`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 91`** (2 nodes): `Frida injection module — gadget injection without APK resigning.  Per D-09: Frid`, `__init__.py`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 92`** (2 nodes): `MainActivity`, `MainActivity.kt`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 93`** (2 nodes): `Collection`, `collection.rs`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 94`** (2 nodes): `DetectedIssue`, `detected_issue.rs`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 95`** (2 nodes): `MarkerStats`, `marker_stats.rs`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 96`** (2 nodes): `MetricSample`, `metric_sample.rs`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 97`** (2 nodes): `region_stats.rs`, `RegionStats`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 98`** (2 nodes): `video.rs`, `VideoMetadata`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 114`** (1 nodes): `Parse a pyidevice device JSON entry.`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 121`** (1 nodes): `Return help text for Frida-specific CLI arguments.`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 127`** (1 nodes): `Should invoke apksigner sign with correct keystore and password flags.`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 128`** (1 nodes): `Should raise RuntimeError when apksigner fails.`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 129`** (1 nodes): `Should return pass status when apksigner exits 0.`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 130`** (1 nodes): `Should detect v1, v2, v3 signature schemes from output.`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 131`** (1 nodes): `Should raise RuntimeError when apksigner exits non-zero.`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 132`** (1 nodes): `Should return pass when SdkLoader.init is found.`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 133`** (1 nodes): `Should raise RuntimeError when SdkLoader.init is not found.`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 134`** (1 nodes): `Should connect to port 8080, read JSON, and verify timestamp field.`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 135`** (1 nodes): `Should raise RuntimeError on socket timeout.`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Community 1` to `Community 0`, `Community 5`, `Community 6`, `Community 8`, `Community 10`, `Community 13`, `Community 24`, `Community 25`, `Community 26`?**
  _High betweenness centrality (0.318) - this node is a cross-community bridge._
- **Why does `package:flutter_test/flutter_test.dart` connect `Community 5` to `Community 0`, `Community 1`, `Community 3`?**
  _High betweenness centrality (0.192) - this node is a cross-community bridge._
- **Why does `build` connect `Community 3` to `Community 4`, `Community 9`, `Community 13`, `Community 15`, `Community 27`?**
  _High betweenness centrality (0.179) - this node is a cross-community bridge._
- **Are the 54 inferred relationships involving `SigningMethod` (e.g. with `PerformanceBench APK Injector — inject profiling SDK into Android APKs.` and `Run the full APK injection pipeline.      Two injection paths:      Smali path (`) actually correct?**
  _`SigningMethod` has 54 INFERRED edges - model-reasoned connections that need verification._
- **Are the 39 inferred relationships involving `collect()` (e.g. with `collect_metrics()` and `parse_proc_self_stat()`) actually correct?**
  _`collect()` has 39 INFERRED edges - model-reasoned connections that need verification._
- **Are the 39 inferred relationships involving `InjectionResult` (e.g. with `PerformanceBench APK Injector — inject profiling SDK into Android APKs.` and `Run the full APK injection pipeline.      Two injection paths:      Smali path (`) actually correct?**
  _`InjectionResult` has 39 INFERRED edges - model-reasoned connections that need verification._
- **Are the 35 inferred relationships involving `CheckResult` (e.g. with `TestCheckResult` and `TestVerificationResult`) actually correct?**
  _`CheckResult` has 35 INFERRED edges - model-reasoned connections that need verification._