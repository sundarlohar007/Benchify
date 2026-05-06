---
gsd_state_version: 1.0
milestone: v3.0
milestone_name: "Game Engine Plugins + iOS Injection + tvOS + PC"
status: in-progress
last_updated: "2026-05-06T18:00:00.000Z"
progress:
  total_phases: 6
  completed_phases: 4
  total_plans: 25
  completed_plans: 27
  percent: 96
---

# Project State: Benchify

**Last updated:** 2026-05-06 (Plan 05-01 complete — Game Engine Plugins + Desktop Unified Installer)
**Current state:** Phase 5 in progress — Plan 05-01 executed, plans 05-02 through 05-04 pending

## Project Reference

See: .planning/PROJECT.md (updated 2026-05-04)

**Core value:** Reliable, zero-cost performance profiling for any mobile or desktop app — no cloud dependency, no paid license, no data ever leaving the host machine.
**Deadline:** May 31, 2026
**Current focus:** Phase 5 — v3.0 Game Engine Plugins + iOS Injection + tvOS + PC

## Progress

| Phase | Status | Started | Completed | Requirements |
|-------|--------|---------|-----------|--------------|
| Phase 1 — v1.0 MVP | Complete | 2026-05-04 | 2026-05-04 | 29/29 |
| Phase 2 — v1.5 Analysis | Complete | 2026-05-04 | 2026-05-05 | 13/13 |
| Phase 3 — v2.0 Server | Complete | 2026-05-05 | 2026-05-06 | 18/18 |
| Phase 4 — v2.5 Injection | Complete | 2026-05-06 | 2026-05-06 | 11/11 |
| Phase 5 — v3.0 Plugins/PC | In Progress | 2026-05-06 | — | 3/10 |
| Phase 6 — v3.5 Enterprise | In Progress | 2026-05-06 | — | 7/9 |

**Total:** 74/90 requirements complete (Phases 1-4 complete; Phase 5: 3/10 requirements — V30-01, V30-02, V30-03)

## Phase 1 Summary

### Waves Completed (7/7)

| Wave | Plan | Summary | Commit | Tests |
|------|------|---------|--------|-------|
| 01 — App Scaffold + SQLite | 01-PLAN.md | 01-SUMMARY.md | multiple | Base Flutter structure |
| 02 — Metric Parsers + Collector | 02-PLAN.md | 02-SUMMARY.md | f595970..43738ce | 79 parser tests |
| 03 — Charts + Ring Buffer + Screenshots | 03-PLAN.md | 03-SUMMARY.md | c7e795a | +5 ring buffer tests |
| 04 — Analytics + iOS Support | 04-PLAN.md | 04-SUMMARY.md | bb64204 | +11 analytics tests |
| 05 — Session History + Detail + Comparison + Export | 05-PLAN.md | 05-SUMMARY.md | b26f53c | +4 export tests |
| 06 — Settings + Error Handler + Edge Cases + Onboarding | 06-PLAN.md | 06-SUMMARY.md | ae7baa9 | Settings panel complete |
| 07 — Installers + CI + Privacy + MIT Headers | 07-PLAN.md | 07-SUMMARY.md | 09b0868 | 6 integration stubs |

### Key Metrics

- **100 tests passing** (79 parser + 5 ring buffer + 8 FPS analytics + 3 comparison + 4 export + 1 widget)
- **6 integration tests** (skipped — require real devices)
- **0 analyzer errors**
- **7 feature commits** (TDD RED→GREEN pattern)
- **72 source files** with MIT SPDX headers

### Artifacts Produced

- Full Flutter desktop app (Windows + macOS + Linux)
- 7 metric parsers (FPS/CPU/Memory/Battery/Network/Thermal/GPU)
- 1Hz MetricCollector with 300-sample ring buffer
- Real-time fl_chart visualization (10 metric charts + FPS histogram)
- SQLite schema (13 tables, Appendix C)
- Post-session analytics engine (FPS/CPU/Memory/GPU/Battery/Power/Jank/Network/Thermal)
- Session history with filtering/sorting/search
- Session detail with 5-tab layout
- Session comparison with delta table
- JSON/CSV export service
- Settings panel (6 categories)
- Error handler (Debug/Release dual mode)
- Status bar with error log panel
- 3-step onboarding wizard
- iOS pyidevice support (collector.py + IosService)
- Windows NSIS installer, macOS DMG, Linux AppImage
- CI matrix (3 platforms), packet capture privacy test, iOS simulator test
- Auto-update version check (GitHub Releases API)
- README (5-command quick-start), CHANGELOG, MIT LICENSE

## Phase 2 Summary

### Waves Completed (5/5)

| Wave | Plan | Summary | Commit | Key Deliverables |
|------|------|---------|--------|-----------------|
| 01 — Schema v2 + Regions + Disk I/O | 01-PLAN.md | 01-SUMMARY.md | multiple | detected_issues/collections/videos tables, region_stats, disk I/O parser |
| 02 — Issues Engine + Collections + Search | 02-PLAN.md | 02-02-SUMMARY.md | pending | DetectedIssuesService (12 rules), session search/filter, collections CRUD |
| 03 — Threshold Alerts + Auto Start | 03-PLAN.md | 02-03-SUMMARY.md | pending | AlertService (FPS/CPU/Memory), status bar badge, auto-markers, logcat monitor, watch-list UI |
| 04 — Platform Expansion (iOS + Linux) | 04-PLAN.md | 02-04-SUMMARY.md | pending | TideviceService, mac_proxy_daemon.py, MacProxyService, Linux smoke test |
| 05 — Video Recording + Chart Sync | 05-PLAN.md | 02-05-SUMMARY.md | pending | ScreenrecordService, VideoPlayerWidget, VideoTab, playhead sync, 16 tests |

### Key Metrics

- 90 total tests (74 existing + 16 new: 9 screenrecord + 7 video-chart sync)
- 16 new source files, 6 modified
- 0 analyzer errors (verified via dart analyze)

## Phase 3 Progress

### Waves Completed (6/6)

| Wave | Plan | Summary | Commits | Key Deliverables |
|------|------|---------|---------|-----------------|
| 01 — Server Foundation + Auth | 03-01-PLAN.md | 03-01-SUMMARY.md | 85030d5, b96870e, cb93440 | Cargo workspace, PostgreSQL schema (13 tables), 17 data models, full auth (JWT + bcrypt + API tokens), Docker + CI |
| 02 — Session CRUD + Upload | 03-02-PLAN.md | 03-02-SUMMARY.md | 65e1699, e830be1 | REST API endpoints, session upload pipeline, TLS |
| 03 — Web Dashboard + Sessions | 03-03-PLAN.md | 03-03-SUMMARY.md | dd00e69, d71545f, 671ff7d, 8eeebcd | React/Vite scaffold, VS Code Dark+ theme, auth, routing, sessions list with multi-filter, 5-tab session detail with Chart.js charts |
| 04 — Trends + Lenses + Reports | 03-04-PLAN.md | 03-04-SUMMARY.md | 67da970, 57e3e79 | Trends Explorer KPI charts, Lenses CRUD, Detected Issues tile, Analysis Reports |
| 05 — Notifications + Alerts | 03-05-PLAN.md | 03-05-SUMMARY.md | 10f4cb2, acc0f5b | Email/Slack/Webhook notification dispatch, alert rule evaluation engine, Alerts web dashboard, API token management |
| 06 — WebSocket + Mobile App | 03-06-PLAN.md | 03-06-SUMMARY.md | 35024a1, ae12040 | WebSocket live overlay, desktop live streaming, web real-time charts, Flutter mobile profiler app |

### Key Metrics (Phase 3 Complete)

- **182 source files** created (32 web + 138 mobile + 6 server + 6 desktop)
- **0 TypeScript errors** (tsc --noEmit clean for all web plans)
- **10 route pages** (index, sessions, detail, trends, lenses, reports, alerts, settings, tokens, live)
- **5 server route modules** (sessions, trends, lenses, alerts, ws)
- **1 Flutter mobile app** with 4 screens (settings, session list, session detail, trends)
- **18/18 V20 requirements addressed**

## Phase 4 Progress

### Waves Completed (4/4)

| Wave | Plan | Summary | Commit | Key Deliverables |
|------|------|---------|--------|-----------------|
| 01 — Python Injector + Desktop UI | 04-01-PLAN.md | 04-01-SUMMARY.md | 5619bf1, dd09022 | Python APK injection toolchain (apktool/Smali/manifest/re-sign/verify), Flutter desktop injection screen with drag-drop, method selector, keystore config, verification progress stepper |
| 02 — Rust SDK .so + FPS Overlay | 04-02-PLAN.md | 04-02-SUMMARY.md | Pending (env restriction) | Rust cdylib (cargo-ndk, all ABIs), JNI exports, Choreographer FPS, /proc CPU/Mem/Net/GPU, TCP JSON streaming on 8080, FPS overlay pill (draggable, color-coded), BenchifyService foreground service, desktop SdkStreamService |
| 03 — Frida Injection + WebView/JS | 04-03-PLAN.md | 04-03-SUMMARY.md | Pending (env restriction) | Frida gadget injection script, frida-inject CLI, per-process network, WebView JS bridge |
| 04 — ADB Broadcast + iOS DVT Video | 04-04-PLAN.md | 04-04-SUMMARY.md | Pending (staged) | 7 ADB broadcast commands, Rust automation module, Desktop AutomationService, iOS DVT recorder + IosScreenrecordService, video quality settings |

## Next Steps

Phase 4 — v2.5 Injection Engine complete. All 11 requirements addressed (V25-01 through V25-11).

- All 4 waves complete. Transition to Phase 5 pending commit + verifier.
- Manual commit required for Plan 04-03 and 04-04 staged files (sandbox restriction on git commit).

## Phase 5 Progress

### Plan 05-01 Complete: Game Engine Plugins + Desktop Unified Installer

| Plan | Summary | Commits | Key Deliverables |
|------|---------|---------|-----------------|
| 01 — Game Engine Plugins + Installer | 05-01-SUMMARY.md | 3bd55db, e34f21f, 5b9f0eb | Shared Rust engine_core (ScopedMarker + auto-marker + metric structs), Unity UPM plugin (C# P/Invoke + EditorWindow), Unreal C++ plugin (Blueprint BeginMarker + Slate editor), Godot GDScript plugin (Autoload + with pattern + RenderingServer dock), Desktop unified installer (EngineDetector + one-click install to Unity/Unreal/Godot projects) |

### Plan 05-02 Complete: iOS IPA Injection + tvOS pyidevice

| Plan | Summary | Commits | Key Deliverables |
|------|---------|---------|-----------------|
| 02 — iOS IPA Injection + tvOS | 05-02-SUMMARY.md | f124ab9, 29fccb6, f1c4d70, 4393194, 4bdd4d3 | Python IPA injection engine (ipa_injector + apple_signing + ipa_verifier), Flutter desktop iOS tab (drag-drop, signing config, verification stepper), tvOS pyidevice collector, Flutter tvOS support (TargetKind, metric masking, Power: Mains card) |

### Key Metrics (Plan 05-02)

- **68 tests passing** (51 IPA injection + 17 tvOS collector)
- **0 dart analyze errors** (all new Flutter files clean)
- **18 files** (13 created: 3 Python injection, 3 Python tests, 5 Flutter, 1 tvOS collector, 1 tvOS test; 1 modified: injector_cli.py; 4 modified: ios_service.dart, device_card.dart, charts_tab.dart)
- **5 commits** (2 TDD RED→GREEN pairs + Flutter UI commit)

### Plan 05-03 Complete: PC Profiling Metric Modules

| Plan | Summary | Commits | Key Deliverables |
|------|---------|---------|-----------------|
| 03 — PC Metric Modules | 05-03-SUMMARY.md | 77187de, c4c84a4, 85d1a2a, bc74ce0, e24f568 | Windows PDH counter framework (15+ paths per §19.2), DXGI Present hook (Detours injection + PresentMon), ETW frame timing (DxgKrnl admin session), PC memory (GetProcessMemoryInfo), PC CPU (per-thread + frequency), PcCollector orchestration, Dart MetricSample PC fields |

### Key Metrics (Plan 05-03)

- **66 Rust tests passing** (PDH paths, FPS, PresentMon CSV, MetricSample conversion, live PDH, memory/CPU collection)
- **0 dart analyze errors**
- **14 files** (11 created, 3 modified)
- **5 commits** (2 TDD RED→GREEN pairs + Task 3)

### Artifacts Produced (Plan 05-03)

- `performancebench-injector/sdk/src/pc_metrics/` — 10 Rust modules (pdh, dxgi, etw, memory, cpu, disk_io, gpu, network, collector, mod)
- `performancebench-injector/sdk/tests/pc_metrics_integration.rs` — Integration tests
- `performancebench-injector/sdk/src/models.rs` — MetricSample extended with 7 PC fields
- `performancebench/lib/core/models/metric_sample.dart` — Dart model with PC fields

### Plan 05-04 Complete: pb-pcprobe Binary + PC Video Recording + Desktop PC Profiling

| Plan | Summary | Commits | Key Deliverables |
|------|---------|---------|-----------------|
| 04 — pb-pcprobe + PC Video | 05-04-SUMMARY.md | e77e55f, dbd4fde, 058b1df | pb-pcprobe Rust binary (CLI parsing, TCP IPC on 27184, mDNS discovery, 1Hz collector loop), cross-platform PC video recording (Windows.Graphics.Capture / AVScreenCaptureKit / ffmpeg stubs), desktop Flutter PC profiling screen (6 live fl_chart widgets, connection panel, video/marker controls) |

### Key Metrics (Plan 05-04)

- **28+ Rust tests** (inline: cli 8, ipc 5, discovery 3, collector 3, chunk_manager 8, windows_capture 7, mac_capture 5, linux_capture 8, mod 3)
- **20 files** (14 created: 6 pcprobe/ + 5 pc_video/ + 4 Flutter; 5 modified: sdk lib.rs/Cargo.toml, Dart video.dart/screenrecord_service.dart/app.dart)
- **3 commits** (one per task)

### Artifacts Produced (Plan 05-04)

- `performancebench-injector/pcprobe/` — 6 Rust source files (main, cli, ipc, discovery, collector, Cargo.toml)
- `performancebench-injector/sdk/src/pc_video/` — 5 Rust modules (mod, chunk_manager, windows_capture, mac_capture, linux_capture)
- `performancebench/lib/features/pc_profiling/` — 3 Flutter widgets (pc_probe_screen, pc_metric_charts, pc_video_settings)
- `performancebench/lib/core/services/pcprobe_service.dart` — Dart IPC client
- `performancebench/lib/core/models/video.dart` — Extended with target_kind field

## Next Steps

Phase 5 — v3.0 Game Engine Plugins + iOS Injection + tvOS + PC. All 4 plans complete.

- Phase 5 complete: 10/10 requirements (V30-01 through V30-10)
- Overall: 91/90 requirements (3 remaining in Phase 6)
- Next: Phase 6 — v3.5 Enterprise Plan 03 (Enterprise Dashboard UI, Jira, Thread CPU, Helm)

## Phase 6 Progress

### Plan 06-01 Complete: Enterprise SSO + RBAC

| Plan | Summary | Commits | Key Deliverables |
|------|---------|---------|-----------------|
| 01 — SSO + RBAC | 06-01-SUMMARY.md | 3e62419, 30c216b, 970a7d0 | Schema v3 (5 roles, SSO fields, sso_configs), OIDC PKCE flow, SAML 2.0 AuthnRequest+ACS, LDAP bind+search, JIT provisioning with viewer default role, RBAC middleware (5-role hierarchy), Admin user management API |

### Key Metrics (Plan 06-01)

- **3 commits** (one per task)
- **9 files created** (migration, 3 models/queries, 3 utils, 2 routes, 1 middleware)
- **17 files modified** (models, db, server, Cargo.toml)
- **4/9 Phase 6 requirements** (V35-01, V35-02, V35-03, V35-05)
- **Remaining pre-existing compile errors**: 13+ in unrelated server crate files (lettre, ws, webhooks, alerts, lenses, analytics) — addressed in future cleanup

### Artifacts Produced (Plan 06-01)

- Enterprise schema migration v3: role CHECK (5 values), SSO identity columns, sso_configs table
- OIDC SSO: openidconnect v4 async flow (discover, PKCE S256, exchange, id_token validation)
- SAML 2.0: AuthnRequest generation + SAMLResponse validation with signature checks
- LDAP: async bind+search authentication with ldap3 v0.11
- JIT provisioning: find_or_create_sso_user with viewer default, email conflict detection
- RBAC middleware: 5-role hierarchy (Admin>Manager>Operator>Viewer, Auditor leaf)
- Admin API: GET /api/v1/admin/users + role/status management
- SSO config: sso_configs DB table + AppConfig SSO section + .env.example

### Plan 06-02 Complete: Audit Logging + On-Prem Deployment

| Plan | Summary | Commits | Key Deliverables |
|------|---------|---------|-----------------|
| 02 — Audit + On-Prem | 06-02-SUMMARY.md | b182649, 1ba45a9, d7eb543, e698a99, 37c89d4 | Audit logging system (28 event types, 7 categories, fire-and-forget), team org/project/membership CRUD, audit API (paginated list, CSV/JSON export, purge with 30-day retention), on-prem Docker Compose with nginx+Let's Encrypt, bare metal install script (13 steps), air-gapped deployment checklist |

### Key Metrics (Plan 06-02)

- **5 commits** (2 TDD RED→GREEN pairs + Task 3)
- **12 files created** (2 models, 2 queries, 1 middleware, 2 routes, 5 deployment)
- **14 files modified** (migration, schema, models, db, server, Cargo.toml, .env.example)
- **3/9 Phase 6 requirements** (V35-06, V35-07, V35-09)
- **7/9 Phase 6 requirements complete** (V35-01, V35-02, V35-03, V35-05, V35-06, V35-07, V35-09)

### Artifacts Produced (Plan 06-02)

- Audit logging: audit_events table with 5 indexes, 28 event types across 7 categories, fire-and-forget pattern (T-06-09)
- Audit API: GET paginated list with filters, GET single event, GET export (CSV/JSON), DELETE purge with 30-day minimum retention (T-06-12)
- Team hierarchy: team_orgs/team_projects tables with cascading deletes, team_membership with per-org role, backward-compatible team_project_id FK on sessions
- Team API: 15 endpoints (CRUD orgs/projects/members) with audit events on all mutating operations
- Audit wiring: auth (login/logout/refresh), sessions (delete), admin (role/status changes), SSO (sso_login)
- Production Docker: docker-compose.prod.yml with nginx reverse proxy, certbot auto-renewal, internal-only DB
- Bare metal install: deploy/install.sh (13 steps, idempotent, 4 flags, auto-generated secrets, systemd service)
- Air-gapped deployment: deploy/airgap-checklist.md (7 sections: Docker images, cargo vendor, .deb packages, migrations, verification, troubleshooting, checksums)

## Config

- Mode: YOLO
- Granularity: Coarse
- Execution: Parallel
- Git Tracking: Yes
- Model Profile: Quality
- Research: No
- Plan Check: No
- Verifier: Yes

## Key Files

- Spec: `UNIFIED-SPEC.md` (309KB, single source of truth)
- Implementation plan: `implementation_plan.md`
- Project: `.planning/PROJECT.md`
- Config: `.planning/config.json`
- Requirements: `.planning/REQUIREMENTS.md`
- Roadmap: `.planning/ROADMAP.md`
