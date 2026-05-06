# Phase 4: v2.5 Android SDK Injection — Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Inject profiling SDK into APKs for in-app performance data collection. Build Rust native .so library for full metric replacement (FPS, CPU, Memory, Network, GPU — no ADB needed). APK patching via apktool+Smali or Frida gadget injection. In-app FPS overlay widget. iOS video recording via DVT screen-mirror. ADB broadcast automation for CI/CD. 11 requirements (V25-01 through V25-11). 4 days.
</domain>

<decisions>
## Implementation Decisions

### APK Injection Strategy

- **D-01:** Desktop UI-first injection workflow — drag-drop APK, configure settings, re-sign with keystore. Desktop app wraps injection logic.
- **D-02:** User selects injection method per APK — apktool+Smali (permanent, requires re-sign) vs Frida gadget (no re-sign, needs frida-server on device).
- **D-03:** Keystore via desktop file picker + password fields. Desktop remembers last-used keystore path in settings.
- **D-04:** Smali injection into `Application.onCreate()`. SDK native library loads at app start for full lifecycle coverage.
- **D-05:** Full APK compatibility — standard APKs + AAB (via bundletool conversion) + ProGuard/R8 obfuscated builds supported.
- **D-06:** Monorepo sibling — `performancebench-injector/` alongside `performancebench/` and `performancebench-server/`.
- **D-07:** Full resign with user keystore. Original signature replaced. User must use same keystore for app updates.
- **D-08:** Multi-step injection verification — apksigner check → Smali patch validation → ADB port 8080 connection test after install. Desktop shows checkmark per step.
- **D-09:** Frida gadget injection via CLI for CI/CD. GUI injection is desktop-only. CI pipelines use Frida path (no re-sign needed).

### Native SDK Architecture

- **D-10:** Full ADB replacement — Rust .so collects FPS (Choreographer hook), Memory (ActivityManager), CPU (/proc/self/stat), Network (/proc/pid/net/dev), GPU (GLSurfaceView hook). No ADB parsers needed for injected apps.
- **D-11:** JSON newline-delimited over TCP on port 8080. Matches iOS collector.py pattern. Desktop AdbService forwards port. Same MetricSample format.
- **D-12:** FPS overlay — small pill widget in top-right corner. Green (>55 FPS), Yellow (30-55), Red (<30). Draggable. Tap to show/hide details. Monospace font.
- **D-13:** Always-on streaming from app start. SDK loads at Application.onCreate(), begins streaming metrics. Desktop connects and reads anytime.
- **D-14:** cargo-ndk cross-compilation for arm64-v8a, armeabi-v7a, x86_64. CI builds all ABIs. Injector selects correct .so per APK architecture.
- **D-15:** WebView JS collection via `WebView.addJavascriptInterface()`. Periodically calls `window.performance.memory`, reports `usedJSHeapSize`.
- **D-16:** Per-process network totals via `/proc/pid/net/dev`. TX/RX bytes per interface. No socket-level interception.

### iOS Video Recording

- **D-17:** Reuse Android ScreenrecordService pattern — start/stop via pymobiledevice3 DVT screen-mirror. H.264 MP4 chunks to `data/videos/`. Same chunk naming, same Video model schema, same VideoTab playback.
- **D-18:** macOS-only feature. Windows/Linux users see disabled button with tooltip: "iOS video requires macOS". Desktop checks `Platform.isMacOS`.
- **D-19:** Start/stop sync — DVT recording started before first MetricSample, stopped after last. Timestamps in video metadata. Same approach as Android.
- **D-20:** Configurable video quality — 480p/720p/1080p, 15/30/60fps. User setting in Settings → Profiling → iOS Video.
- **D-21:** Video-only — no device audio capture. Simpler, smaller files, less privacy concern.

### Automation + CI/CD

- **D-22:** Full command set via ADB broadcast: START_SESSION, STOP_SESSION, PAUSE, RESUME, MARKER(note), SCREENSHOT, EXPORT. 7 actions.
- **D-23:** Intent extras + JSON payload format. Command via `com.benchify.COMMAND`, payload via `com.benchify.PAYLOAD` (JSON string). SDK responds via `com.benchify.RESPONSE` broadcast with status JSON.
- **D-24:** Desktop CLI mode for CI — `pb automark --session <id> --note 'boss fight start'`. Desktop must be running with active session.
- **D-25:** Injection is GUI-only for desktop users. CI pipelines use Frida gadget path (no re-sign needed). Clean separation.

### Claude's Discretion

- Exact Smali injection template code and bytecode offsets
- Rust .so crate structure and module organization
- FPS overlay pixel dimensions, colors, font size
- cargo-ndk CI workflow YAML
- APK manifest modifications (permissions for overlay, network, broadcast receivers)
- Frida gadget injection script (JavaScript)
- DVT recording command-line flags and error handling
- Broadcast intent action string constants
- pb CLI command argument parsing and output format
- Desktop UI widget for drag-drop APK injection workflow
- Keystore password field UX (show/hide, validation)
- AAB→APK conversion via bundletool integration
- ProGuard mapping parser for deobfuscated method names
- ADB port forwarding for SDK socket connection

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Spec & Requirements
- `UNIFIED-SPEC.md` — §24-27 (SDK Injection spec), §28 (Native library), §29 (FPS overlay), §30 (Automation), §31 (iOS video)
- `implementation_plan.md` — Phase-level goals for v2.5

### Planning Documents
- `.planning/PROJECT.md` — Project context, core value, constraints (May 31 deadline)
- `.planning/REQUIREMENTS.md` — 11 v2.5 requirements (V25-01 through V25-11)
- `.planning/ROADMAP.md` — Phase 4 scope and wave structure
- `.planning/config.json` — YOLO mode, coarse granularity, parallel execution

### Prior Phase Context
- `.planning/phases/01-v1-0-external-profiling-mvp/01-CONTEXT.md` — D-01 through D-20 (ADB wrapper, MetricSample model, chart system)
- `.planning/phases/02-v1-5-analysis-platform-expansion/02-CONTEXT.md` — D-01 through D-13 (video recording pattern, Mac proxy)
- `.planning/phases/03-v2-0-team-server-web-dashboard/03-CONTEXT.md` — D-01 through D-51 (server auth, upload, WebSocket patterns)

### Codebase Integration Points
- `performancebench/lib/core/services/adb_service.dart` — ADB subprocess wrapper (port forwarding, shell commands)
- `performancebench/lib/core/services/screenrecord_service.dart` — Android video recording pattern to extend
- `performancebench/lib/core/collector/metric_collector.dart` — MetricSample stream pattern (SDK stream follows same)
- `performancebench/lib/core/models/metric_sample.dart` — MetricSample data model (SDK populates same fields)
- `performancebench/lib/shared/widgets/metric_chart.dart` — Charts that render SDK-collected metrics
- `performancebench-server/` — Upload endpoints for injected-app session data
- `ios_agents/collector.py` — iOS collector pattern for DVT video recording integration

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **ScreenrecordService** — `lib/core/services/screenrecord_service.dart` (298 lines). Pattern to extend for iOS DVT recording. Start/stop/chunk lifecycle, AdbShell interface.
- **AdbService** — `lib/core/services/adb_service.dart`. ADB port forwarding (`adb forward tcp:8080`) for SDK socket. ADB broadcast commands. Subprocess lifecycle.
- **MetricCollector** — `lib/core/collector/metric_collector.dart`. Stream<MetricSample> pattern. SDK stream adapter follows same interface.
- **IosService** — `lib/core/services/ios_service.dart`. Python subprocess lifecycle (start → stdout JSON stream → SIGTERM → SIGKILL). DVT recording follows same pattern.
- **Video model + VideoDao** — Already handle chunk paths, codec, container, resolutions. iOS video drops in seamlessly.
- **Desktop settings UI** — `_SliderRow`, `_ToggleRow`, `_DropdownRow` components. Reuse for injection settings and video quality config.

### Established Patterns
- TDD throughout — RED→GREEN→REFACTOR per module
- Subprocess management — Process.start(), stdout stream, SIGTERM/SIGKILL
- MetricSample — all parsers populate same model fields
- DAO pattern with parameterized queries
- 5-min video chunks with auto-chunk timer

### Integration Points
- **Injection UI → Desktop**: New screen in desktop app (drag-drop APK zone, injection method selector, keystore picker, verification progress)
- **SDK → Desktop**: ADB port forward tcp:8080 → local TCP socket → MetricSample JSON stream
- **Desktop → SDK**: ADB broadcast intents for automation commands
- **Frida → Desktop**: Frida gadget .so injected → connects to frida-server → desktop Frida client controls
- **iOS DVT → Desktop**: pymobiledevice3 DVT subprocess → stdout H.264 stream → MP4 chunk writer

</code_context>

<specifics>
## Specific Ideas

- User expects drag-drop APK injection to "just work" — progress bar, clear error messages, multi-step verification
- FPS overlay must be minimal and non-blocking — draggable pill, color-coded, monospace font
- SDK should be invisible to the target app — no crashes, no ANRs, no permission popups beyond what's declared in manifest
- iOS video should feel like Android video — same chunking, same VideoTab, same sync behavior
- CI/CD automation is for game studios — start session on level load, marker on boss fight, screenshot on death, stop on level complete
- Injection is a power-user feature — clear warnings about APK modification, keystore security, and app update implications

</specifics>

<deferred>
## Deferred Ideas

None from this discussion — all suggestions stayed within Phase 4 scope.
</deferred>

---
*Phase: 4-v2.5 Android SDK Injection*
*Context gathered: 2026-05-06*
