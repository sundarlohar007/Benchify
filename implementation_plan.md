# PerformanceBench Implementation Plan (v1.0 to v3.5)

This plan outlines the complete implementation roadmap for PerformanceBench, spanning from the v1.0 MVP to the v3.5 Enterprise edition, as specified in Sections 7 and 11 of `UNIFIED-SPEC.md`.

## User Review Required

> [!IMPORTANT]
> Please review this comprehensive roadmap. It includes the detailed 12-week sprint plan for v1.0 and the feature-level implementation goals for all subsequent versions up to v3.5. Confirm if you want to proceed with executing the v1.0 MVP Week 1–2 tasks first.

## Open Questions

> [!NOTE]
> No open questions at this stage. Proceeding strictly as defined in the spec.

## Proposed Changes

---
### Phase 1: v1.0 — External Profiling MVP (12 weeks)

**Week 1–2: App Skeleton + Android Discovery**
- Scaffold Flutter desktop app (`flutter create performancebench --platforms=windows,macos,linux`)
- Setup SQLite (`sqflite_common_ffi`) and schema migrations
- Navigation structure (DeviceList → AppPicker → ActiveSession → History)
- Wrap ADB subprocess (`AdbService`), enable device discovery polling
- Deliverable: App runs on Windows + macOS, lists connected Android devices.

**Week 3–4: Android Metrics Collection**
- `MetricCollector`: 1Hz loop emitting `Stream<MetricSample>`
- Parsers for FPS (4-tier jank), CPU (app/system/freq-normalized), Memory (PSS/subsections), Battery (mA/mV/temp), Network, Thermal, and GPU
- Deliverable: Android metrics stream correctly with all 3-second timeouts handled gracefully.

**Week 5–6: Charts + Session Storage + Analytics**
- Real-time `fl_chart` integration fed from 300-sample ring buffer
- SQLite batch writer (flush every 5s)
- Screenshot capture pipeline (5 sizes)
- Compute full post-session analytics (Variability Index, total mAh, avg mW, estimated playtime, etc.)
- Deliverable: Active session UI with charts, screenshots, markers, and full DB save on stop.

**Week 7–8: iOS Support + History + Comparison**
- iOS support via `pyidevice` (macOS only) mapped to `MetricSample`
- History screen: sorting, filtering, replay
- Session comparison: Side-by-side syncing with delta table
- Deliverable: iOS profiling working, plus full session history and comparison capabilities.

**Week 9–10: Export + Polish + Installer**
- Export capabilities (JSON + CSV)
- Settings panel and error handling
- Initial Windows installer (NSIS) and macOS DMG
- Deliverable: Packaged application with robust error paths.

**Week 11: Edge Cases + Hardening**
- ANR/Crash detection Android + iOS
- Foreground/background tracking, multi-process aggregation
- USB unplug recovery and ADB auto-recovery
- Deliverable: All edge cases and platform quirks handled smoothly.

**Week 12: Polish + Installer + Distribution**
- Onboarding flow + bundled demo session
- Auto-update strategy implementation
- CI matrix builds (Win, Mac, Linux) and full documentation
- Deliverable: v1.0 — shippable, installable, and documented.

---
### Phase 2: v1.5 — Analysis + Platform Expansion

**Analysis Features:**
- Drag-region selection on timeline → per-region stats
- Disk I/O activated (schema columns from v1.0)
- Auto-detected issues (Section 6.9) — feature flag default-off
- Session collections (group by project)
- Session search + filter by tag / device / app / chipset
- Metric threshold alerts (local notification when FPS < X for Y seconds)
- Auto session start when target app launches (`am monitor` or `/proc/*/cmdline` poll)

**Platform Expansions:**
- tidevice on Windows for iOS (~8 metrics, documented gaps)
- Mac proxy daemon (Windows → Mac → iPhone, all metrics)
- Linux first-class support smoke test

**Video (Android) — Section 32:**
- Synced screen recording via `adb shell screenrecord` (built-in Android 4.4+)
- H.264 MP4, configurable resolution + bitrate
- Auto-chunked at 3-min Android limit, seamless concat
- Embedded chart-sync timestamps
- Player UI: scrub video → scrubs charts and vice versa

**Schema Additions (migration v2):**
- `detected_issues`, `collections`, `videos` tables activated

---
### Phase 3: v2.0 — Team Server + Web Dashboard + CI/CD

**Separate repository: `performancebench-server`**
- Rust + Axum REST API and PostgreSQL shared storage
- React + Vite web dashboard (matches desktop VS-Code-style design system)
- Session upload from desktop app (opt-in, manual trigger)
- Auth: email + bcrypt, JWT (HS256, 1h expiry), API tokens
- Local network only by default — TLS via user-provided cert

**Web Dashboard features (Section 22):**
- Sessions list with multi-filter, session detail mirroring desktop
- Trends Explorer — KPI trends across sessions for an app/device combo
- Lenses — saved filters/views (`lenses` table)
- Detected Issues dashboard tile and Analysis Reports

**Notifications (Section 23):**
- Email / Slack / Webhook channels and Threshold alert rules
- `notification_channels`, `alerts`, `alert_events` tables

**REST API for CI/CD automation:**
- Full CRUD for sessions, stats, export, trends, lenses, alerts, and devices
- Webhook callbacks on session-end / alert-fired
- API token authentication for CI scripts
- Web live overlay (WebSocket push from desktop)

**Mobile Profiler App (optional, Section 26):**
- Lightweight Flutter mobile app (iOS + Android)
- Read-only view of team server sessions for managers
- Push notifications for alerts

---
### Phase 4: v2.5 — Android SDK Injection

**Separate repository: `performancebench-injector`**
- APK injection via apktool + Smali patching
- SDK native library compiled to `.so` in Rust
- Re-signing with user-provided keystore
- In-app FPS overlay (floating widget on device screen)
- SDK → desktop via local ADB socket on port 8080
- Frida gadget injection as alternative (no re-signing needed)
- WebView / JS memory collection
- Per-connection network stats (socket API interception)
- ADB broadcast actions for automation (start/stop/marker commands)

**Video (iOS) — Section 32:** 
- Synced screen recording via `pymobiledevice3` DVT screen-mirror service. H.264 MP4, ~30 FPS. macOS host only at v2.5.

---
### Phase 5: v3.0 — Game Engine Plugins + iOS Injection + tvOS + PC

**Game Engine Plugins:**
- **Unity Plugin (UPM package):** Auto-markers on `sceneLoaded`, draw calls, SetPass calls, memory metrics, `BeginMarker()` API, Editor window.
- **Unreal Engine Plugin (C++ + Blueprint):** Auto-markers on `PostLoadMapWithWorld`, Blueprint node `BeginMarker`, RHI frame time, GPU stats.
- **Godot Plugin (GDScript):** Auto-markers on `scene_changed`, `RenderingServer` draw calls, Autoload singleton.

**iOS IPA Injection:**
- Studio-provided unencrypted IPA only
- Free Apple ID signing (7-day expiry)
- `PerformanceBench.framework` dylib injection

**tvOS Support (Section 25):**
- pyidevice tvOS connection (USB-C only on Apple TV 4K gen 3+)
- Same metrics as iOS where exposed

**Windows PC Target Profiling (Section 19):**
- Win32 PDH (Performance Data Helper) API for per-process counters
- DXGI presentation hooking for FPS / frame time on Windows games
- ETW (Event Tracing for Windows) for low-overhead frame timing
- Memory: working set + private bytes + GPU committed memory
- CPU: per-process CPU time + per-thread + freq via Win32_Processor WMI

**Video (PC) — Section 32:**
- Windows: Windows.Graphics.Capture API (Win10 1903+) — H.264 via Media Foundation
- Linux: `ffmpeg` + x11grab / pipewire
- macOS: AVFoundation `AVScreenCaptureKit` — H.264 via VideoToolbox

---
### Phase 6: v3.5 — Enterprise

- SAML 2.0 SSO (Okta, Azure AD, Google Workspace) — Section 24
- LDAP authentication — Section 24
- JIT (Just-In-Time) user provisioning — Section 24
- Jira issue creation from session (link performance data to ticket)
- RBAC: Owner / Admin / Member / Viewer roles
- Audit log: all session uploads, deletes, exports, alert configurations
- On-premises deployment guide (nginx + TLS + PostgreSQL)
- Thread-level CPU breakdown (root required — explicitly documented)
- Multi-org / multi-project hierarchy (`team_orgs` / `team_projects` tables)

## Verification Plan

### Automated Tests
- Parser unit tests for metrics as defined in §14
- CI matrix tests for successful builds of Win, Mac, and Linux binaries.

### Manual Verification
- **For v1.0:** Execute the listed test gates per-week, verify using a real Android + iPhone on macOS, launch the Windows installer on a clean VM, and run pyidevice scripts locally.
- **For subsequent versions:** Functional verification of the Web Dashboard, REST APIs, SDK injection via app testing, Game Engine integrations, PC target profiling via sample Windows games, and Enterprise SSO flow testing via Okta/LDAP test instances.
