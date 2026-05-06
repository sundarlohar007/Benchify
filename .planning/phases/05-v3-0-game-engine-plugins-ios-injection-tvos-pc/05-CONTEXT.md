# Phase 5: v3.0 Game Engine Plugins + iOS Injection + tvOS + PC — Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Game engine plugins (Unity UPM, Unreal C++/Blueprint, Godot GDScript) for in-engine profiling. iOS IPA dylib injection with auto-detect signing. tvOS pyidevice profiling. Windows PC profiling agent (pb-pcprobe binary) with cross-platform video recording. 10 requirements (V30-01 through V30-10). 4 days.
</domain>

<decisions>
## Implementation Decisions

### Game Engine Plugins

- **D-01:** Shared Rust core library + per-engine wrappers. Auto-marker logic and metric collection in Rust .so (reuses Phase 4 SDK modules). Unity: C# P/Invoke wrapper. Unreal: C++ FFI wrapper. Godot: GDScript Foreign Interface wrapper.
- **D-02:** BeginMarker/EndMarker API matching Phase 1 manual marker pattern. Unity: `using(new BeginMarker("name"))`. Unreal: `FScopedMarker("name")`. Godot: `with BeginMarker.new("name")`. Desktop sees markers in session timeline.
- **D-03:** Stats dashboard in editor — FPS, memory, draw calls during Play mode. Read-only. Not full profiling control (profiling still via desktop app).
- **D-04:** Desktop app unified installer — one-click plugin install to all detected engines. Scans for Unity/Unreal/Godot project directories. Installs plugin packages.
- **D-05:** Per-engine standard distribution as fallback — Unity UPM (git URL), Unreal (GitHub clone into Plugins/), Godot (Asset Library or GitHub clone). MIT license.

### iOS IPA Injection + tvOS

- **D-06:** Auto-detect signing method: 1) Free Apple ID via altool ad-hoc, 2) Paid Developer account with provisioning profile, 3) User-provided certificate. Desktop UI offers all three, auto-detects available options, user picks.
- **D-07:** Desktop UI only — drag-drop IPA in Flutter injection screen (extends Phase 4 injection UI with iOS tab). No CLI for iOS injection.
- **D-08:** tvOS full pyidevice parity — FPS, CPU, Memory, Network, Thermal metrics where exposed by tvOS. Mac-only. Document gaps (GPU, battery, cellular unavailable on tvOS).

### PC Profiling Agent

- **D-09:** pb-pcprobe as Rust binary — reuses Phase 4 SDK metric modules (fps, cpu, memory, network, gpu). PDH via windows-rs, DXGI via windows-rs, ETW via tracelogging. Cross-compile Windows/Linux/macOS. Same JSON/TCP protocol on port 8080.
- **D-10:** PC video recording: Windows via Windows.Graphics.Capture (windows-rs), Mac via AVScreenCaptureKit (objc bindings), Linux via ffmpeg x11grab. Rust orchistrates per-platform. Same 5-min H.264 MP4 chunk pattern as Android/iOS.
- **D-11:** PC-appropriate metrics: FPS (DXGI present timing), CPU (per-core PDH), Memory (working set, private bytes, GPU committed VRAM), GPU (DXGI frame time), Disk I/O, Network. Thermal/fan speed where available. Not forced mobile parity.

### Claude's Discretion

- Rust core library crate structure and shared module boundaries
- Unity Editor window UI (UnityEditor.IMGUI vs UI Toolkit)
- Unreal Editor Customization (Slate widget layout)
- Godot EditorPlugin dock/panel design
- BeginMarker/EndMarker implementation details per engine
- Desktop unified installer engine detection logic
- iOS dylib injection — IPA patching steps, dylib placement, Info.plist modification
- altool command-line integration and Apple ID credential storage
- tvOS pyidevice connection and metric parsing
- pb-pcprobe binary structure, CLI flags, and IPC protocol
- Windows.Graphics.Capture + DXGI swapchain capture details
- AVScreenCaptureKit + CMSampleBuffer encoding pipeline
- ETW session management for frame timing
- PDH counter paths and sampling rate

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Spec & Requirements
- `UNIFIED-SPEC.md` — §32-36 (Game engine plugins), §37 (iOS IPA injection), §38 (tvOS), §39-43 (PC profiling)
- `implementation_plan.md` — Phase-level goals for v3.0

### Planning Documents
- `.planning/PROJECT.md` — Core value, May 31 deadline, constraints
- `.planning/REQUIREMENTS.md` — 10 v3.0 requirements (V30-01 through V30-10)
- `.planning/ROADMAP.md` — Phase 5 scope and wave structure
- `.planning/config.json` — YOLO mode, coarse granularity, parallel execution

### Prior Phase Context
- `.planning/phases/04-v2-5-android-sdk-injection/04-CONTEXT.md` — Rust SDK patterns (D-10 through D-16), injection UI (D-01 through D-09), video recording (D-17 through D-21)

### Codebase Integration Points
- `performancebench-injector/sdk/` — Rust .so library (reuse for game engine core + pb-pcprobe)
- `performancebench-injector/sdk/src/metrics/` — Metric modules to adapt for PC (fps.rs → DXGI, cpu.rs → PDH, etc.)
- `performancebench/lib/features/injection/injection_screen.dart` — Extend with iOS IPA tab
- `performancebench/lib/core/services/screenrecord_service.dart` — Extend for PC video recording
- `performancebench/lib/core/models/metric_sample.dart` — Extend with PC-specific fields if needed
- `ios_agents/dvt_recorder.py` — iOS video pattern for PC video recording

</canonical_refs>

<specifics>
## Specific Ideas

- Game developers expect engine-native APIs — Unity C# feels like Unity, Unreal C++ feels like Unreal, Godot GDScript feels like Godot
- BeginMarker must be near-zero overhead — `#if PERFORMANCEBENCH` guards in production builds
- iOS IPA injection is a power-user feature — clear warnings about encrypted IPAs, Apple ID security, sideloading implications
- pb-pcprobe should feel like a lightweight system tool — single binary, no install, starts/stops from desktop CLI
- PC video recording must handle 144+ FPS — DXGI captures 1000+ fps, encoding at target 60fps for file size
- tvOS is niche but important for Apple TV game developers — same workflow as iOS, just limited metrics

</specifics>

<deferred>
## Deferred Ideas

None from this discussion — all suggestions within Phase 5 scope.
</deferred>

---
*Phase: 5-v3.0 Game Engine Plugins + iOS Injection + tvOS + PC*
*Context gathered: 2026-05-06*
