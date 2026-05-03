# Roadmap: Benchify

**Created:** 2026-05-04
**Deadline:** May 31, 2026
**Phases:** 6 | **Requirements:** 90 | **Coverage:** 100%

## Phase Overview

| # | Phase | Goal | Reqs | Days | Success Criteria |
|---|-------|------|------|------|------------------|
| 1 | v1.0 External Profiling MVP | Ship Flutter desktop profiler with Android+iOS support | 29 | 7 | 3 |
| 2 | v1.5 Analysis + Platform Expansion | Add advanced analysis, video recording, Windows iOS | 13 | 5 | 3 |
| 3 | v2.0 Team Server + Web Dashboard | Multi-user server, web UI, CI/CD REST API | 18 | 5 | 3 |
| 4 | v2.5 Android SDK Injection | Inject SDK into APKs for in-app profiling | 11 | 4 | 3 |
| 5 | v3.0 Game Engine Plugins + iOS Injection + tvOS + PC | Unity/Unreal/Godot plugins, Windows PC profiling | 10 | 4 | 3 |
| 6 | v3.5 Enterprise | SSO, RBAC, audit, on-prem deploy | 9 | 2 | 3 |

**Total:** 27 days across 6 phases

---

## Phase 1: v1.0 — External Profiling MVP

**Goal:** Ship installable Flutter desktop app that profiles Android (all hosts) and iOS (macOS) at GameBench-parity metric depth. No injection, no cloud, no server.

**Duration:** 7 days (May 4–10)
**Requirements:** MVP-01 through MVP-29

**Build order (wave-based parallel):**

Wave 1 (parallel):
- App scaffold + project setup (MVP-01, MVP-02, MVP-03)
- Database schema + migrations (MVP-02)
- ADB service + device discovery (MVP-04, MVP-12)

Wave 2 (parallel):
- All metric parsers (MVP-06, MVP-07, MVP-08, MVP-09, MVP-10, MVP-11)
- MetricCollector engine (MVP-05)

Wave 3 (parallel):
- Charts + ring buffer (MVP-13)
- SQLite batch writer (MVP-14)
- Screenshot pipeline (MVP-15)

Wave 4 (parallel):
- Post-session analytics (MVP-16)
- iOS pyidevice support (MVP-17)

Wave 5 (parallel):
- Session history/replay (MVP-18)
- Session comparison (MVP-19)
- Export JSON/CSV (MVP-20)

Wave 6 (parallel):
- Settings panel + error handling (MVP-21)
- Edge cases + hardening (MVP-23)
- Onboarding + demo session (MVP-24)

Wave 7:
- Windows installer + macOS DMG (MVP-22)
- Auto-update strategy (MVP-25)
- Tests + README + privacy verification + license headers (MVP-26, MVP-27, MVP-28, MVP-29)

**UI hint:** yes — full Flutter desktop UI with 9+ screens

**Success criteria:**
1. App runs on Windows + macOS + Linux, discovers Android devices via ADB, displays real-time FPS/CPU/Memory/Battery charts
2. iOS profiling works on macOS via pyidevice — all 20+ metrics flowing at 1Hz
3. Session saves to SQLite, exports to JSON/CSV, can be replayed, compared, and verified (packet capture shows zero outbound connections)

---

## Phase 2: v1.5 — Analysis + Platform Expansion

**Goal:** Add drag-region analysis, disk I/O, threshold alerts, auto session start, Windows iOS support via tidevice + Mac proxy, Android video recording.

**Duration:** 5 days (May 11–15)
**Requirements:** V15-01 through V15-13

**Build order (wave-based parallel):**

Wave 1 (parallel):
- Drag-region selection + per-region stats (V15-01)
- Disk I/O activation (V15-02)
- Schema migration v2 (V15-13)

Wave 2 (parallel):
- Auto-detected issues (V15-03)
- Session collections (V15-04)
- Session search + filter (V15-05)

Wave 3 (parallel):
- Metric threshold alerts (V15-06)
- Auto session start (V15-07)

Wave 4 (parallel):
- tidevice on Windows for iOS (V15-08)
- Mac proxy daemon (V15-09)
- Linux first-class smoke test (V15-10)

Wave 5 (parallel):
- Android video recording — screenrecord synced (V15-11)
- Video player UI with chart scrub sync (V15-12)

**UI hint:** yes — new analysis panels, video player, alert configuration

**Success criteria:**
1. User can drag-select a region on any session timeline and see per-region stats matching per-marker stats format
2. Windows user can profile iOS device via tidevice (subset metrics) or Mac proxy (full metrics)
3. Android screen recording saves H.264 MP4 synced with session — scrubbing video moves chart cursor and vice versa

---

## Phase 3: v2.0 — Team Server + Web Dashboard + CI/CD

**Goal:** Separate Rust/Axum server repo with PostgreSQL, React/Vite web dashboard, session upload, REST API for CI/CD automation.

**Duration:** 5 days (May 16–20)
**Requirements:** V20-01 through V20-18

**Build order (wave-based parallel):**

Wave 1 (parallel):
- `performancebench-server` repo setup + Rust/Axum scaffold (V20-01)
- PostgreSQL schema + migrations (V20-02)
- Auth system — email/bcrypt, JWT, API tokens (V20-05)

Wave 2 (parallel):
- Session CRUD API endpoints (V20-15)
- Session upload from desktop (V20-04)
- TLS setup (V20-06)

Wave 3 (parallel):
- React/Vite web dashboard scaffold (V20-03)
- Sessions list + multi-filter (V20-07)
- Session detail view (V20-08)

Wave 4 (parallel):
- Trends Explorer (V20-09)
- Lenses (V20-10)
- Detected Issues tile (V20-11)
- Analysis Reports (V20-12)

Wave 5 (parallel):
- Notifications — Email/Slack/Webhook (V20-13)
- Threshold alert rules (V20-14)
- Webhook callbacks (V20-16)

Wave 6 (parallel):
- Web live overlay via WebSocket (V20-17)
- Mobile profiler app (V20-18)

**UI hint:** yes — React web dashboard, mobile app UI

**Success criteria:**
1. Desktop app uploads session to team server; web dashboard shows session list, detail, and trends from any browser on local network
2. CI script can start/stop profiling via REST API with API token auth and receive webhook on session complete
3. Web live overlay mirrors active desktop session in real-time via WebSocket

---

## Phase 4: v2.5 — Android SDK Injection

**Goal:** Separate injector repo. APK patching via apktool + Frida gadget. In-app FPS overlay. SDK-to-desktop communication over ADB socket.

**Duration:** 4 days (May 21–24)
**Requirements:** V25-01 through V25-11

**Build order (wave-based parallel):**

Wave 1 (parallel):
- `performancebench-injector` repo setup (V25-01)
- APK injection via apktool + Smali (V25-02)
- SDK native .so in Rust (V25-03)

Wave 2 (parallel):
- Re-signing with keystore (V25-04)
- Frida gadget alternative (V25-07)

Wave 3 (parallel):
- In-app FPS overlay widget (V25-05)
- SDK → desktop ADB socket port 8080 (V25-06)

Wave 4 (parallel):
- WebView/JS memory collection (V25-08)
- Per-connection network stats (V25-09)
- ADB broadcast actions (V25-10)

Wave 5:
- iOS video recording — pymobiledevice3 DVT (V25-11)

**UI hint:** yes — injector GUI (Flutter), in-app overlay widget

**Success criteria:**
1. User can inject SDK into any APK, re-sign, install, and see FPS overlay on device during profiling session
2. Frida gadget injection works without re-signing — user drops gadget .so and profiles
3. Per-connection network stats appear in desktop app for injected app

---

## Phase 5: v3.0 — Game Engine Plugins + iOS Injection + tvOS + PC

**Goal:** Unity/Unreal/Godot plugins with auto-markers. iOS IPA injection. tvOS support. Windows PC target profiling with PDH/DXGI/ETW.

**Duration:** 4 days (May 25–28)
**Requirements:** V30-01 through V30-10

**Build order (wave-based parallel):**

Wave 1 (parallel):
- Unity Plugin — UPM package (V30-01)
- Unreal Engine Plugin — C++ + Blueprint (V30-02)

Wave 2 (parallel):
- Godot Plugin — GDScript (V30-03)
- iOS IPA Injection — dylib injection (V30-04)

Wave 3 (parallel):
- tvOS Support — pyidevice tvOS (V30-05)
- `pb-pcprobe` binary scaffold (V30-10)

Wave 4 (parallel):
- Windows PC Profiling — PDH/DXGI/ETW (V30-06, V30-07, V30-08)

Wave 5:
- PC video recording — Windows/Linux/macOS (V30-09)

**UI hint:** yes — game engine Editor windows, pcprobe UI

**Success criteria:**
1. Unity developer can install UPM package, add auto-markers on scene load, and see draw calls + memory in PerformanceBench during editor play mode
2. iOS IPA injected with PerformanceBench.framework profiles on device with free Apple ID (7-day expiry documented)
3. Windows PC game shows FPS/CPU/Memory in PerformanceBench via `pb-pcprobe` with DXGI frame timing

---

## Phase 6: v3.5 — Enterprise

**Goal:** SAML SSO, LDAP, RBAC, JIT provisioning, Jira integration, audit log, on-premises deployment guide.

**Duration:** 2 days (May 29–30)
**Requirements:** V35-01 through V35-09

**Build order (wave-based parallel):**

Wave 1 (parallel):
- SAML 2.0 SSO — Okta, Azure AD, Google Workspace (V35-01)
- LDAP authentication (V35-02)
- JIT user provisioning (V35-03)

Wave 2 (parallel):
- RBAC — Owner/Admin/Member/Viewer (V35-05)
- Audit log (V35-06)
- Multi-org/multi-project hierarchy (V35-09)

Wave 3 (parallel):
- Jira issue creation from session (V35-04)
- Thread-level CPU breakdown (V35-08)
- On-premises deployment guide (V35-07)

**UI hint:** no — backend/configuration heavy

**Success criteria:**
1. User can log into team server with Okta SAML SSO; new user auto-provisioned via JIT
2. Admin can assign roles (Owner/Admin/Member/Viewer) and all actions appear in audit log
3. On-premises deployment guide allows fresh Ubuntu server to host PerformanceBench server behind nginx with TLS in under 10 steps

---

## Dependency Graph

```
Phase 1 (v1.0 MVP) ──────┐
                          ├──→ Phase 2 (v1.5 Analysis) ──┐
                          │                               ├──→ Phase 3 (v2.0 Server) ──┐
                          │                               │                            ├──→ Phase 6 (v3.5 Enterprise)
                          │                               └──→ Phase 4 (v2.5 Inject) ─┘
                          │                                         │
                          └─────────────────────────────────────────┘
                                                                    │
                                                    Phase 5 (v3.0 Plugins/PC)
```

- Phases 2 and 4 both depend on Phase 1
- Phase 3 depends on Phase 2
- Phase 4 depends on Phase 2 (needs session format from v1.5)
- Phase 5 is largely independent after Phase 1 (game engine plugins, iOS injection, tvOS, PC profiling)
- Phase 6 depends on Phase 3 (extends team server)

**Parallelization opportunities:**
- Phase 5 can start in parallel with Phase 3 after Phase 2 completes
- Within each phase, waves run sequentially but tasks within waves run in parallel

---

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| iOS device availability for testing | Blocked testing | Mock metrics subsystem; test with Android first; verify iOS on macOS agent |
| ADB/pyidevice version conflicts | Parser failures | Pin versions; graceful null on parse failure |
| Cross-platform build matrix (Win/Mac/Linux) | Slow CI | Parallel GitHub Actions runners; smoke test Linux only |
| Feature creep beyond spec | Deadline miss | Hard gate — spec is contract; no additions without explicit user approval |
| 27-day timeline compression | Burnout/quality | YOLO auto-advance; parallel where graph allows; verifier catches regressions |

---
*Roadmap created: 2026-05-04*
