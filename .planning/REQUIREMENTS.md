# Requirements: Benchify

**Defined:** 2026-05-04
**Core Value:** Reliable, zero-cost performance profiling for any mobile or desktop app — no cloud dependency, no paid license, no data ever leaving the host machine.
**Deadline:** May 31, 2026 (27 days)

## v1 Requirements

Requirements for v1.0 through v3.5. Each maps to roadmap phases.

### Phase 1: v1.0 — External Profiling MVP

- [ ] **MVP-01**: Flutter desktop app scaffold with Windows + macOS + Linux support
- [ ] **MVP-02**: SQLite schema (Appendix C) with migration tracking
- [ ] **MVP-03**: Navigation structure (DeviceList → AppPicker → ActiveSession → History)
- [ ] **MVP-04**: ADB subprocess wrapper (AdbService) with device discovery polling
- [ ] **MVP-05**: MetricCollector — 1Hz loop emitting Stream<MetricSample>
- [ ] **MVP-06**: FPS parser (SurfaceFlinger) with 4-tier jank classification
- [ ] **MVP-07**: CPU parser — app/system/normalized, core states, core frequencies
- [ ] **MVP-08**: Memory parser — PSS total + subsections (Java, Native, Graphics, Stack, Code, System)
- [ ] **MVP-09**: Battery parser — %, mA, mV, temp, charging state
- [ ] **MVP-10**: Network parser — per-interface TX/RX bytes, WiFi/Cellular split
- [ ] **MVP-11**: Thermal parser + GPU parser (Adreno/Mali)
- [ ] **MVP-12**: Static device + app data collection at session start (Appendix E)
- [ ] **MVP-13**: Real-time fl_chart integration fed from 300-sample ring buffer
- [ ] **MVP-14**: SQLite batch writer (flush every 5s)
- [ ] **MVP-15**: Screenshot capture pipeline (5 sizes via ADB)
- [ ] **MVP-16**: Post-session analytics — Variability Index, mAh consumed, avg mW, total mWh, estimated playtime
- [ ] **MVP-17**: iOS support via pyidevice (macOS only) mapped to MetricSample
- [ ] **MVP-18**: Session history — sorting, filtering, replay
- [ ] **MVP-19**: Session comparison — side-by-side with delta table
- [ ] **MVP-20**: Export JSON + CSV
- [ ] **MVP-21**: Settings panel + error handling
- [ ] **MVP-22**: Windows installer (NSIS) + macOS DMG
- [ ] **MVP-23**: Edge cases — ANR/crash detection, foreground/background tracking, USB unplug recovery, ADB auto-recovery
- [ ] **MVP-24**: Onboarding flow + bundled demo session
- [ ] **MVP-25**: Auto-update strategy (version check only, no binary download)
- [ ] **MVP-26**: All §14 unit + integration tests passing
- [ ] **MVP-27**: README.md quick-start reproducible in ≤5 commands
- [ ] **MVP-28**: Privacy verification — packet capture confirming no data leaves host
- [ ] **MVP-29**: MIT license headers on all source files

### Phase 2: v1.5 — Analysis + Platform Expansion

- [ ] **V15-01**: Drag-region selection on timeline with per-region stats
- [ ] **V15-02**: Disk I/O activated (schema columns from v1.0)
- [ ] **V15-03**: Auto-detected issues (Section 6.9) — feature flag default-off
- [ ] **V15-04**: Session collections (group by project)
- [ ] **V15-05**: Session search + filter by tag / device / app / chipset
- [ ] **V15-06**: Metric threshold alerts (local notification when FPS < X for Y seconds)
- [ ] **V15-07**: Auto session start when target app launches
- [ ] **V15-08**: tidevice on Windows for iOS (~8 metrics, documented gaps)
- [ ] **V15-09**: Mac proxy daemon (Windows → Mac → iPhone, all metrics)
- [ ] **V15-10**: Linux first-class support smoke test
- [ ] **V15-11**: Android video recording — synced screenrecord, H.264 MP4, auto-chunked
- [ ] **V15-12**: Video player UI — scrub video ↔ scrub charts sync
- [ ] **V15-13**: Schema migration v2 — detected_issues, collections, videos tables

### Phase 3: v2.0 — Team Server + Web Dashboard + CI/CD

- [ ] **V20-01**: Separate repo `performancebench-server` — Rust + Axum REST API
- [ ] **V20-02**: PostgreSQL schema + migrations
- [ ] **V20-03**: React + Vite web dashboard (VS-Code-style design)
- [ ] **V20-04**: Session upload from desktop app (opt-in, manual trigger)
- [ ] **V20-05**: Auth — email + bcrypt, JWT (HS256, 1h expiry), API tokens
- [ ] **V20-06**: TLS via user-provided cert (local network default)
- [ ] **V20-07**: Sessions list with multi-filter on web dashboard
- [ ] **V20-08**: Session detail view mirroring desktop
- [ ] **V20-09**: Trends Explorer — KPI trends across sessions
- [ ] **V20-10**: Lenses — saved filters/views
- [ ] **V20-11**: Detected Issues dashboard tile
- [ ] **V20-12**: Analysis Reports — multi-session analytical reports
- [ ] **V20-13**: Notifications — Email / Slack / Webhook channels
- [ ] **V20-14**: Threshold alert rules + alert_events table
- [ ] **V20-15**: Full REST API for CI/CD — sessions CRUD, stats, export, trends, lenses, alerts, devices
- [ ] **V20-16**: Webhook callbacks on session-end / alert-fired
- [ ] **V20-17**: Web live overlay — WebSocket push from desktop
- [ ] **V20-18**: Optional mobile profiler app (Flutter, iOS + Android, read-only)

### Phase 4: v2.5 — Android SDK Injection

- [ ] **V25-01**: Separate repo `performancebench-injector`
- [ ] **V25-02**: APK injection via apktool + Smali patching
- [ ] **V25-03**: SDK native library compiled to .so in Rust
- [ ] **V25-04**: Re-signing with user-provided keystore
- [ ] **V25-05**: In-app FPS overlay (floating widget on device screen)
- [ ] **V25-06**: SDK → desktop via local ADB socket on port 8080
- [ ] **V25-07**: Frida gadget injection as alternative (no re-signing needed)
- [ ] **V25-08**: WebView / JS memory collection
- [ ] **V25-09**: Per-connection network stats (socket API interception)
- [ ] **V25-10**: ADB broadcast actions for automation
- [ ] **V25-11**: iOS video recording — synced via pymobiledevice3 DVT screen-mirror, H.264 MP4

### Phase 5: v3.0 — Game Engine Plugins + iOS Injection + tvOS + PC

- [ ] **V30-01**: Unity Plugin (UPM package) — auto-markers, draw calls, memory, BeginMarker API, Editor window
- [ ] **V30-02**: Unreal Engine Plugin (C++ + Blueprint) — auto-markers, BeginMarker node, RHI frame time, GPU stats
- [ ] **V30-03**: Godot Plugin (GDScript) — auto-markers, RenderingServer draw calls, Autoload singleton
- [ ] **V30-04**: iOS IPA Injection — unencrypted IPA only, free Apple ID signing, dylib injection
- [ ] **V30-05**: tvOS Support — pyidevice tvOS connection, same metrics as iOS where exposed
- [ ] **V30-06**: Windows PC Profiling — PDH API, DXGI presentation hooking, ETW frame timing
- [ ] **V30-07**: PC memory metrics — working set, private bytes, GPU committed memory
- [ ] **V30-08**: PC CPU metrics — per-process CPU time, per-thread, freq via WMI
- [ ] **V30-09**: PC video recording — Windows.Graphics.Capture, ffmpeg x11grab, AVScreenCaptureKit
- [ ] **V30-10**: `pb-pcprobe` binary for PC profiling agent

### Phase 6: v3.5 — Enterprise

- [ ] **V35-01**: SAML 2.0 SSO (Okta, Azure AD, Google Workspace)
- [ ] **V35-02**: LDAP authentication
- [ ] **V35-03**: JIT (Just-In-Time) user provisioning
- [ ] **V35-04**: Jira issue creation from session
- [ ] **V35-05**: RBAC — Owner / Admin / Member / Viewer roles
- [ ] **V35-06**: Audit log — all session uploads, deletes, exports, alert configs
- [ ] **V35-07**: On-premises deployment guide (nginx + TLS + PostgreSQL)
- [ ] **V35-08**: Thread-level CPU breakdown (root required, documented)
- [ ] **V35-09**: Multi-org / multi-project hierarchy (team_orgs / team_projects tables)

## v2 Requirements

Deferred to post-v3.5. Tracked but not in current roadmap.

| Feature | Reason |
|---------|--------|
| Real-time chat / collaboration | Not a communication tool |
| Cloud-hosted SaaS version | Privacy-first, local-only by design |
| Console profiling (PS5, Xbox, Switch) | No public profiling APIs |
| WebGL / browser game profiling | Different product category |
| Vision Pro / AR/VR profiling | No standard APIs yet |

## Out of Scope

| Feature | Reason |
|---------|--------|
| Cloud telemetry / analytics SDKs | Privacy contract — data never leaves host |
| Paid/proprietary dependencies | $0 forever constraint |
| Mock data as real metrics | Integrity — store NULL + log, never fabricate |
| Auto-updaters that download executables | Security — version check only, link to GitHub Releases |
| Apple Developer account requirement | Barrier to entry — free Apple ID signing for injection |
| Root-required profiling (v1.0) | Accessibility — root optional, documented where needed |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| MVP-01 | Phase 1 | Pending |
| MVP-02 | Phase 1 | Pending |
| MVP-03 | Phase 1 | Pending |
| MVP-04 | Phase 1 | Pending |
| MVP-05 | Phase 1 | Pending |
| MVP-06 | Phase 1 | Pending |
| MVP-07 | Phase 1 | Pending |
| MVP-08 | Phase 1 | Pending |
| MVP-09 | Phase 1 | Pending |
| MVP-10 | Phase 1 | Pending |
| MVP-11 | Phase 1 | Pending |
| MVP-12 | Phase 1 | Pending |
| MVP-13 | Phase 1 | Pending |
| MVP-14 | Phase 1 | Pending |
| MVP-15 | Phase 1 | Pending |
| MVP-16 | Phase 1 | Pending |
| MVP-17 | Phase 1 | Pending |
| MVP-18 | Phase 1 | Pending |
| MVP-19 | Phase 1 | Pending |
| MVP-20 | Phase 1 | Pending |
| MVP-21 | Phase 1 | Pending |
| MVP-22 | Phase 1 | Pending |
| MVP-23 | Phase 1 | Pending |
| MVP-24 | Phase 1 | Pending |
| MVP-25 | Phase 1 | Pending |
| MVP-26 | Phase 1 | Pending |
| MVP-27 | Phase 1 | Pending |
| MVP-28 | Phase 1 | Pending |
| MVP-29 | Phase 1 | Pending |
| V15-01 | Phase 2 | Pending |
| V15-02 | Phase 2 | Pending |
| V15-03 | Phase 2 | Pending |
| V15-04 | Phase 2 | Pending |
| V15-05 | Phase 2 | Pending |
| V15-06 | Phase 2 | Pending |
| V15-07 | Phase 2 | Pending |
| V15-08 | Phase 2 | Pending |
| V15-09 | Phase 2 | Pending |
| V15-10 | Phase 2 | Pending |
| V15-11 | Phase 2 | Pending |
| V15-12 | Phase 2 | Pending |
| V15-13 | Phase 2 | Pending |
| V20-01 | Phase 3 | Pending |
| V20-02 | Phase 3 | Pending |
| V20-03 | Phase 3 | Pending |
| V20-04 | Phase 3 | Pending |
| V20-05 | Phase 3 | Pending |
| V20-06 | Phase 3 | Pending |
| V20-07 | Phase 3 | Pending |
| V20-08 | Phase 3 | Pending |
| V20-09 | Phase 3 | Pending |
| V20-10 | Phase 3 | Pending |
| V20-11 | Phase 3 | Pending |
| V20-12 | Phase 3 | Pending |
| V20-13 | Phase 3 | Pending |
| V20-14 | Phase 3 | Pending |
| V20-15 | Phase 3 | Pending |
| V20-16 | Phase 3 | Pending |
| V20-17 | Phase 3 | Pending |
| V20-18 | Phase 3 | Pending |
| V25-01 | Phase 4 | Pending |
| V25-02 | Phase 4 | Pending |
| V25-03 | Phase 4 | Pending |
| V25-04 | Phase 4 | Pending |
| V25-05 | Phase 4 | Pending |
| V25-06 | Phase 4 | Pending |
| V25-07 | Phase 4 | Pending |
| V25-08 | Phase 4 | Pending |
| V25-09 | Phase 4 | Pending |
| V25-10 | Phase 4 | Pending |
| V25-11 | Phase 4 | Pending |
| V30-01 | Phase 5 | Pending |
| V30-02 | Phase 5 | Pending |
| V30-03 | Phase 5 | Pending |
| V30-04 | Phase 5 | Pending |
| V30-05 | Phase 5 | Pending |
| V30-06 | Phase 5 | Pending |
| V30-07 | Phase 5 | Pending |
| V30-08 | Phase 5 | Pending |
| V30-09 | Phase 5 | Pending |
| V30-10 | Phase 5 | Pending |
| V35-01 | Phase 6 | Pending |
| V35-02 | Phase 6 | Pending |
| V35-03 | Phase 6 | Pending |
| V35-04 | Phase 6 | Pending |
| V35-05 | Phase 6 | Pending |
| V35-06 | Phase 6 | Pending |
| V35-07 | Phase 6 | Pending |
| V35-08 | Phase 6 | Pending |
| V35-09 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 90 total
- Mapped to phases: 90
- Unmapped: 0

---
*Requirements defined: 2026-05-04*
*Last updated: 2026-05-04 after initial definition*
