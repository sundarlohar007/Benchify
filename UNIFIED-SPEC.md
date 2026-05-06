# PerformanceBench Unified Specification

> **Version:** 4.0 (Full Parity Edition)
> **Goal:** Free, open-source mobile + desktop performance profiler — GameBench alternative at $0
> **Cost:** $0 forever, no infra cost, no dev cost, no user cost
> **Timeline:** 12 weeks → v1.0 MVP | Full parity at v3.5
> **Stack:** Flutter desktop + SQLite + Python (pyidevice for iOS) + Rust (server v2.0)
> **Targets:** Android + iOS + tvOS + Windows PC (v3.0)
> **Hosts:** Windows + macOS + Linux (Linux for Android profiling only)
> **License:** MIT (desktop + injector + mobile-profiler), Apache-2.0 (server)
> **For the coder:** Spec defines WHAT to build + exact behavioral contracts. No code. Implement in idiomatic Dart/Python/Rust. SQL schema in Section 8 and Appendix C is hard contract — match exactly.

---

## 🤖 AGENTIC CODER ONBOARDING — READ FIRST

**Audience:** This document is the single source of truth for any agentic coder (Claude Code / Claude Opus, Google Antigravity / Gemini, OpenCode, Cursor, Aider, MiniMax, Kimi, Qwen Coder, GPT-5 Codex, DeepSeek-Coder, Cline, Roo Code, etc.) building PerformanceBench from scratch. Model-agnostic. No hidden context. No external links required to start.

### A. How To Consume This Spec

1. **Read in order, top to bottom, once.** Do NOT skip sections. Sections build on each other.
2. **Build order is §7 (Implementation Plan).** Week 1 starts at Week 1. Do not jump ahead.
3. **Hard contracts are non-negotiable.** Look for the word **"Hard contract"** or **"MUST"** — these mean exact match. Examples: §8 (Schema), Appendix C (DDL), Appendix D (ADB commands), §5 metric parsers.
4. **Acceptance criteria are checklists.** Every section ending in `- [ ] ...` lines is a test gate. All boxes must be tickable before that section is "done."
5. **If unclear:** prefer the most literal reading. Do NOT invent features outside spec. Open an issue / ask user only if truly blocked.

### B. Project Identity (Memorize These Constants)

| Key | Value |
|---|---|
| Product name | `PerformanceBench` (one word, capital P + B) |
| Short name / CLI / package id | `pb` |
| Desktop binary | `performancebench` (Windows: `.exe`, macOS: `.app`, Linux: AppImage) |
| Injector binary | `pbinject` |
| PC profiling probe | `pb-pcprobe` |
| Server binary | `performancebench-server` |
| Default IPC port (desktop ↔ injected SDK) | `8080` (mirrors GB SDK convention for tooling compat) |
| Default PC probe port | `27184` (LAN) / named pipe `\\.\pipe\pb-pcprobe` (local) |
| Default injector overlay HTTP port | `27183` |
| Data dir (desktop) | OS-conventional: `%APPDATA%\PerformanceBench\` (Win), `~/Library/Application Support/PerformanceBench/` (Mac), `~/.local/share/performancebench/` (Linux) |
| DB filename | `performancebench.db` (SQLite) |
| Schema migration tracking | `schema_version` table (Appendix C) |
| Repository names | `performancebench` (desktop) / `performancebench-server` (v2.0) / `performancebench-injector` (v2.5) / `performancebench-mobile` (v2.0 optional) |

### C. Repository / Module Layout (top level)

```
performancebench/                 # main desktop app — start here
├── lib/                          # Dart/Flutter source
├── test/                         # Dart tests
├── integration_test/             # Real-device tests
├── docs/                         # SPEC + screenshots
├── assets/
│   └── ios_product_types.json    # Appendix E.3 lookup table
└── tools/
    └── presentmon/               # bundled PresentMon binary (v3.0)

performancebench-server/          # v2.0 — separate repo
├── src/                          # Rust + Axum
├── migrations/                   # Postgres SQL migrations
└── web/                          # React + Vite dashboard

performancebench-injector/        # v2.5 — separate repo
├── gui/                          # Flutter (same stack as main)
├── cli/                          # Rust binary `pbinject`
└── sdk/
    ├── android/                  # AAR + .so
    └── ios/                      # .framework

performancebench-mobile/          # v2.0 optional — separate repo
└── lib/                          # Flutter mobile (read-only viewer)
```

### D. Definition of Done — v1.0 (12 weeks)

- [ ] All §4.3 metrics flowing at 1Hz on real Android + real iPhone (macOS host)
- [ ] All §6 analytics computed post-session and stored in `session_stats` + `marker_stats`
- [ ] Schema matches Appendix C exactly (verify via `sqlite3 .schema` diff)
- [ ] All §9 screens implemented with VS Code design system
- [ ] All §14 unit + integration tests passing
- [ ] Windows installer + macOS DMG + Linux AppImage build green in CI
- [ ] `README.md` quick-start reproducible by fresh user in ≤5 commands
- [ ] No data ever leaves the host machine — verified via packet capture during 30-min session
- [ ] Open-source license headers on every source file (`SPDX-License-Identifier: MIT`)

### E. Hard Stop-Gates (Do Not Cross Without User Approval)

Stop and ask user before proceeding past any of:
1. Modifying schema in any way different from Appendix C
2. Skipping a metric listed in §4.3
3. Adding network calls outside `localhost`/explicit team-server upload (privacy contract)
4. Bumping versions of major deps without testing matrix
5. Adding features not in §11 Roadmap
6. Choosing a different language for a module than §2 specifies

### F. Forbidden Patterns

- ❌ Cloud telemetry, analytics SDKs, crash reporters that phone home
- ❌ Mock data masquerading as real metrics — if a metric fails, store NULL + log; never fabricate
- ❌ Closed-source dependencies for core functionality (paid APIs, proprietary libs)
- ❌ Strings hardcoded as user-facing English — use `intl` ARB files (i18n-ready even if v1 is en-US only)
- ❌ Synchronous file I/O on UI thread
- ❌ Blocking ADB/pyidevice calls > 3 seconds without timeout
- ❌ Unbounded ring buffers (max 60s in-memory, then flush)
- ❌ Deletion of user sessions without explicit confirmation
- ❌ Writing outside the data dir
- ❌ Auto-updaters that download executables (only check version + link to GitHub Releases)

### G. Model-Agnostic Conventions

This spec works for any LLM coder. Do not rely on tool-specific behavior. Specifically:

- **No proprietary tool calls referenced.** All instructions are text-readable.
- **All file paths are POSIX-style** in spec (forward slashes); coder converts on Windows targets.
- **All shell commands are bash-style.** Equivalents documented for PowerShell where relevant (`Bash` vs `PowerShell` tools both work).
- **All code samples are pseudocode unless explicitly tagged with a language.** Coder produces idiomatic implementation.
- **Time formats:** Unix epoch milliseconds for storage (Section 8). ISO 8601 (`YYYY-MM-DDTHH:MM:SSZ`) for human display + JSON exports.
- **Number formats:** Doubles for fractional metrics, INTEGER for counts/bytes/timestamps. No floats unless space-critical.
- **Encoding:** UTF-8 everywhere. JSON without BOM.
- **Line endings:** LF in repo, OS-native at runtime.
- **Concurrency:** isolate-per-device on Dart side; async/await Rust on server; threading.Thread for pyidevice subprocess wrapping.

### H. Decomposition Strategy For Agents

This spec is sized for incremental delivery. Suggested chunks per agent run:

| Run | Scope | Output |
|---|---|---|
| 1 | §0–§3 read + scaffold repo | empty Flutter project + `lib/` skeleton |
| 2 | §8 + Appendix C | `database.dart` + DAOs + migrations + tests |
| 3 | §5.1 + Appendix D FPS rows | `fps_parser.dart` + tests |
| 4 | §5.2 CPU | `cpu_parser.dart` + tests |
| 5 | §5.3 Memory | `memory_parser.dart` + tests |
| 6 | §5.4–§5.7 + §5.11 + §5.12 | remaining parsers + screenshot pipeline |
| 7 | §6 analytics | `analytics_service.dart` + all algorithms |
| 8 | §9.1–§9.4 design system | theme, tokens, base widgets |
| 9 | §9.2–§9.10 screens | all screens, navigation |
| 10 | §13 packaging | installers, CI |
| 11 | §14 testing | full test suite green |
| 12 | §10 + §15 | platform limit handling + privacy verification |

Each run produces working code + passing tests. No run should leave the codebase in a broken state. Use `git commit` per run with conventional commit format: `feat(fps): SurfaceFlinger parser` etc.

### I. Glossary (Disambiguation)

- **Sample / metric_sample:** One row per second per session in `metric_samples` table.
- **Session:** Single recording instance, one row in `sessions` table.
- **Marker:** User-flagged time point or range, see §6.5 for special "Launch Complete" marker.
- **Region:** Drag-selected post-hoc time range (v2.0+), `regions` table.
- **Lens:** Saved filter+columns view in web dashboard (v2.0+), `lenses` table.
- **Jank:** Frame longer than ideal. Four tiers in PB (small/medium/big/ratio). See §5.1.
- **Variability Index:** Mean of consecutive FPS deltas. §6.1.
- **Production mode:** Histogram-only storage, no per-second samples. §21.
- **Strict mode:** Locked test conditions (brightness/volume/battery). §20.
- **Injection:** Patching a binary to embed PB SDK. v2.5 Android, v3.0 iOS. §18.
- **Probe:** PC profiling agent (`pb-pcprobe.exe`). §19.
- **Host:** The desktop machine running PerformanceBench app. (Win/Mac/Linux)
- **Target:** The device being profiled. (Android/iOS/tvOS/Windows PC)

### J. Anti-Drift Rules For Long Sessions

If conversation context fills up:
1. Re-read this Onboarding section before continuing.
2. Re-verify the current task matches a §7 week.
3. Run tests; do not "remember" passing — re-run.
4. Check git status before committing — never amend without explicit approval.
5. If a metric formula is unclear, **prefer Appendix D (ADB Reference) + §5 over your memory.**

### K. Environment Bootstrap Checklist

Before writing first line of code:
- [ ] Flutter ≥ 3.22 installed (`flutter --version`)
- [ ] Dart ≥ 3.4
- [ ] Python ≥ 3.10 (for pyidevice)
- [ ] Rust ≥ 1.75 (for v2.0 server, v2.5 injector — not v1.0)
- [ ] ADB ≥ 35.0.0 in PATH
- [ ] On macOS: pyidevice 4.x via `pip install pymobiledevice3`
- [ ] On Windows: signed driver setup for ADB (Google USB driver)
- [ ] On Linux: `udev` rules for Android (`51-android.rules`)
- [ ] git ≥ 2.40
- [ ] SQLite CLI ≥ 3.44 (for schema diffing)

See §13 for full setup detail.

### L. Quick-Start For Agent (Run This Mental Check Before Each Edit)

> "Am I editing a file the spec tells me to create? Does my change preserve all hard contracts (§8 schema, §5 parsers, §6 algorithms)? Does it pass §14 acceptance criteria? Have I added a test? Does it stay within forbidden-pattern rules (Section F above)?"

If any answer is "no" — stop and re-read relevant section.

---

## Table of Contents

- [🤖 AGENTIC CODER ONBOARDING — READ FIRST](#-agentic-coder-onboarding--read-first)
- [0. Project Overview](#0-project-overview)
- [1. Why This Exists](#1-why-this-exists)
- [2. Tech Stack Decision](#2-tech-stack-decision)
- [3. Architecture](#3-architecture)
- [4. MVP Scope v1.0](#4-mvp-scope-v10)
- [5. Metrics Reference](#5-metrics-reference)
- [6. Advanced Analytics](#6-advanced-analytics)
- [7. Implementation Plan](#7-implementation-plan)
- [8. Database Schema](#8-database-schema)
- [9. UI/UX Specification](#9-uiux-specification)
- [10. Platform Limitations](#10-platform-limitations)
- [11. Full Roadmap](#11-full-roadmap)
- [12. File Structure](#12-file-structure)
- [13. Prerequisites and Setup](#13-prerequisites-and-setup)
- [14. Testing Strategy](#14-testing-strategy)
- [15. Security Model](#15-security-model)
- [16. GameBench Parity Matrix](#16-gamebench-parity-matrix)
- [17. Permanent Feature Gaps](#17-permanent-feature-gaps)
- [18. Injector Tool Specification](#18-injector-tool-specification)
- [19. Windows PC Target Profiling](#19-windows-pc-target-profiling)
- [20. Strict Testing Mode](#20-strict-testing-mode)
- [21. Production vs Non-Production Mode](#21-production-vs-non-production-mode)
- [22. Trends, Lenses, Detected Issues, Analysis Reports](#22-trends-lenses-detected-issues-analysis-reports)
- [23. Notifications & Alerts](#23-notifications--alerts)
- [24. Authentication (LDAP, SAML, JIT)](#24-authentication-ldap-saml-jit)
- [25. tvOS Support](#25-tvos-support)
- [26. Mobile Profiler App (Optional)](#26-mobile-profiler-app-optional)
- [Appendix A: GPU Support Matrix](#appendix-a-gpu-support-matrix)
- [Appendix B: iOS Support Reality](#appendix-b-ios-support-reality)
- [Appendix C: Database SQL Schema](#appendix-c-database-sql-schema)
- [Appendix D: ADB Command Reference](#appendix-d-adb-command-reference)
- [27. Edge Cases & Hardening](#27-edge-cases--hardening)
- [28. Export & Import Formats](#28-export--import-formats)
- [29. Error Taxonomy](#29-error-taxonomy)
- [30. Internationalization & Accessibility](#30-internationalization--accessibility)
- [31. Data Retention & Backup](#31-data-retention--backup)
- [32. Video Recording (Synced)](#32-video-recording-synced)
- [33. Known Limitations & Risk Register](#33-known-limitations--risk-register)
- [34. Multi-Device Parallel Sessions](#34-multi-device-parallel-sessions)
- [35. OEM-Specific Quirks](#35-oem-specific-quirks)
- [36. Legal & Compliance](#36-legal--compliance)
- [37. Code Signing, Notarization & Distribution](#37-code-signing-notarization--distribution)
- [38. Onboarding & First-Run UX](#38-onboarding--first-run-ux)
- [39. Auto-Update Strategy (No Telemetry)](#39-auto-update-strategy-no-telemetry)
- [40. CI/CD Integration Recipes](#40-cicd-integration-recipes)
- [41. Database Encryption at Rest](#41-database-encryption-at-rest)
- [42. Network Security Hardening](#42-network-security-hardening)
- [43. Long-Session Performance Strategy](#43-long-session-performance-strategy)
- [44. Future Targets & Reserved Roadmap Slots](#44-future-targets--reserved-roadmap-slots)
- [Appendix E: Static Device Data Collection](#appendix-e-static-device-data-collection)
- [Appendix F: Spec Self-Audit Checklist](#appendix-f-spec-self-audit-checklist-for-agent-coders)
- [Appendix G: Agent FAQ](#appendix-g-agent-faq-common-questions-answered)
- [Appendix H: Cross-Reference Index](#appendix-h-cross-reference-index)
- [Appendix I: Per-Model Optimization Hints](#appendix-i-per-model-optimization-hints)

---

## 0. Project Overview

PerformanceBench is a free, open-source desktop application for profiling mobile game and app performance in real time. It is a direct alternative to GameBench ($99–$299/month).

| Property | Value |
|---|---|
| **Cost** | $0 forever |
| **Data location** | Local only — never transmitted |
| **Android support** | Windows + macOS + Linux |
| **iOS support** | macOS only (v1.0), Windows in v1.5 |
| **Profiling method** | External ADB / pyidevice (v1.0), SDK injection (v2.5+) |
| **Root required** | No |
| **Apple Developer account** | No |

### Comparison With GameBench

| Feature | GameBench | PerformanceBench |
|---|---|---|
| Cost | $99–299/month | $0 |
| Data storage | Cloud mandatory | Local only |
| Source code | Proprietary | Open source |
| iOS power mA (iPhone ≤7) | Estimated (5+ min lag) | Real-time via pyidevice |
| iOS power mA (iPhone 8+) | Battery % drain rate | Battery % drain rate (same limit) |
| Team sharing | Paid cloud | Local server (v2.0) |
| Root required | No | No |
| Apple Developer account | Required for injection | Not required |
| Offline operation | No | Yes — fully offline |
| Linux control machine | No | Yes (Android profiling) |
| Internet required | Yes | No |
| CI/CD REST API | Yes (paid plans) | v2.0 |
| Game engine plugins | Unity, Unreal | v3.0 |

---

## 1. Why This Exists

GameBench is the industry standard for mobile game performance profiling. It works, but:

1. **$99–299/month per seat** prohibits indie studios, freelance QA, and academia
2. **All data goes to GameBench's cloud** — unacceptable for unreleased or confidential games
3. **No self-hosting** — teams cannot control their own data
4. **No Linux support** — CI build servers cannot run GameBench
5. **Requires internet** — cannot operate in secure or air-gapped facilities

PerformanceBench solves all five problems at $0.

---

## 2. Tech Stack Decision

### 2.1 Desktop Application: Flutter Desktop

**Why not Tauri + Flutter:** Incompatible as a single application. Tauri renders via system webview (HTML/CSS/JS). Flutter renders via Skia/Impeller. They cannot share a process without a separate IPC bridge — two framework boundaries for zero benefit.

**Decision: Flutter desktop only.**

| Option | Pros | Cons | Decision |
|---|---|---|---|
| **Flutter desktop** | Single framework, cross-platform, fl_chart, Dart subprocess | Dart not Rust | **Chosen** |
| Tauri + React | Rust backend, web chart ecosystem | Two language boundaries | Add Rust via dart:ffi later if needed |
| Electron | Huge ecosystem | 200MB+ runtime, slow | Rejected |

ADB invoked via `dart:io Process.run()`. Rust added later via `dart:ffi` only if profiling reveals bottleneck.

### 2.2 Database: SQLite (Desktop) / PostgreSQL (Team Server)

**Why not PostgreSQL for desktop:** Requires a running server process. Unacceptable UX — users would need to configure PostgreSQL just to open the app.

| Storage | Desktop | Team Server (v2.0) |
|---|---|---|
| **SQLite** (`sqflite_common_ffi`) | Zero setup | Not suitable for multi-user |
| **PostgreSQL** | Bad UX | Correct choice |

### 2.3 iOS Profiling: pyidevice on macOS

| Tool | Host | Metrics | Version |
|---|---|---|---|
| **pyidevice (pymobiledevice3)** | macOS only | full v1.0 metric set | v1.0 |
| tidevice | Windows + macOS | ~8 metrics (subset) | v1.5 |
| Mac proxy daemon | Windows (via Mac) | full v1.0 metric set | v1.5 |

### 2.4 Language Summary

| Component | Language | Framework |
|---|---|---|
| Desktop app | Dart | Flutter 3.19+ |
| iOS metric collector | Python 3.10+ | py-ios-device 2.x |
| Team server (v2.0) | Rust | Axum 0.7+ |
| Team dashboard (v2.0) | TypeScript | React 18 + Vite 5 |

---

## 3. Architecture

### 3.1 Component Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                  DESKTOP APP (Flutter)                        │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                   Flutter UI Layer                       │ │
│  │  DeviceList │ AppPicker │ ActiveSession │ History │ Coll │ │
│  └─────────────────────────┬───────────────────────────────┘ │
│                            │                                  │
│  ┌─────────────────────────▼───────────────────────────────┐ │
│  │               Service + Analytics Layer                  │ │
│  │  AdbService │ IosService │ MetricCollector │ Analytics  │ │
│  │  SessionService │ ExportService │ CollectionService      │ │
│  └──────┬───────────────┬──────────────────────────────────┘ │
│         │               │                                     │
│  ┌──────▼──────┐ ┌──────▼──────┐ ┌────────────────────────┐ │
│  │ADB subprocess│ │Python sub-  │ │  SQLite                │ │
│  │(dart:io)    │ │process      │ │  (sqflite_common_ffi)  │ │
│  └──────┬──────┘ └──────┬──────┘ └────────────────────────┘ │
└─────────┼───────────────┼──────────────────────────────────-─┘
          ▼               ▼
    Android phone     iOS phone (USB, macOS only in v1)
```

### 3.2 Data Flow

```
Device raw output (ADB text / pyidevice JSON)
  → Dart parser → typed MetricSample
  → Ring buffer (300 samples in memory)
      ├── Flutter charts (1Hz refresh, zero DB latency)
      └── SQLite batch writer (every 5s)
          └── Session detail / analytics (query on demand)
```

Key design decisions:
- Ring buffer feeds charts — real-time, no DB read during session
- Batch SQLite writes every 5s — avoid per-sample lock contention
- Failed ADB commands return `null` for that metric — session never crashes
- Analytics (percentiles, histogram, per-marker stats) computed post-session from SQLite, not during recording
- Each ADB command has a 3-second timeout; null returned on timeout or non-zero exit

---

## 4. MVP Scope v1.0

### 4.1 What v1.0 Includes

| Feature | Android | iOS (Mac) |
|---|---|---|
| Device discovery | Windows + Mac + Linux | Mac only |
| Real-time metric collection (20+ metrics) | Yes | Yes |
| Real-time charts (all metrics) | Yes | Yes |
| FPS stability histogram | Yes | Yes |
| 1% Low FPS + 95th pct frame time | Yes | Yes |
| Min FPS + Max FPS | Yes | Yes |
| **Variability Index** (avg variance consecutive readings) | Yes | Yes |
| **Frame ratio jank** (Γ=L/R formula, settings-toggleable alt model) | Yes | Yes |
| 3-tier jank (Small / Jank / Big Jank, time threshold model) | Yes | Yes |
| **Raw frametimes array** stored per session | Yes | Yes |
| **CPU normalized to current frequency** (Android only) | Yes | N/A |
| **CPU core states** (online/offline per core) | Yes | N/A |
| **CPU core frequencies** (current Hz per core) | Yes | N/A |
| **Memory PSS subsections** (Java, Native, Graphics, Stack, Code, System) | Yes | partial |
| **mAh consumed** (integration over time) | Yes | iPhone ≤7 only |
| **Avg power mW + Total mWh** | Yes | iPhone ≤7 only |
| **Estimated Playtime** (hours from drain rate) | Yes | Yes |
| **Charging detection** | Yes | Yes |
| **WiFi state during session** | Yes | Yes |
| **Network WiFi/Cellular split** (per-interface bytes) | Yes | Yes |
| **Static device data** (manufacturer, board, chipset, GPU vendor+renderer, OS, GPU driver, network operator) | Yes | partial |
| **App static data** (build #, build date, version) | Yes | Yes |
| **5 screenshot sizes** (100/50/25/12.5/6.75% configurable) | USB only | v2 |
| Per-marker stats breakdown | Yes | Yes |
| **Marker groups** (group multiple markers) | Yes | Yes |
| Session scorecard | Yes | Yes |
| Launch Complete marker | Yes | Yes |
| **Session title** (test case names, ticket IDs) | Yes | Yes |
| **Session notes** (text annotations) | Yes | Yes |
| **Tags as key=value pairs** (searchable) | Yes | Yes |
| **10-second minimum session enforcement** | Yes | Yes |
| Session save to SQLite | Yes | Yes |
| Session history (sortable, filterable) | Yes | Yes |
| Session detail / replay | Yes | Yes |
| Session comparison (2 sessions side-by-side) | Yes | Yes |
| **Wireless auto-disables screenshots** | Yes | Yes |
| Manual markers | Yes | Yes |
| Export JSON + CSV | Yes | Yes |
| WiFi ADB | Yes (with caveats) | N/A |

### 4.2 Explicitly Deferred

| Feature | Reason | Version |
|---|---|---|
| APK/IPA injection | Separate product, legal complexity | v2.5 (Android) / v3.0 (iOS) |
| Game engine auto-markers | Requires injection or source | v3.0 |
| Team server + cloud dashboard | Solo use first | v2.0 |
| Windows + iOS (tidevice) | tidevice reliability | v1.5 |
| WiFi iOS profiling | USB-only DTXProtocol pairing tunnel | v1.5 |
| Drag-region analysis | Timeline interaction complexity | v1.5 |
| Disk I/O | /proc parsing added complexity | v1.5 |
| Session collections | Organizational feature | v1.5 |
| Auto session start on app launch | Edge cases | v1.5 |
| Auto-detected issues UI dashboard | Algorithm in v1.5; web tile in v2.0 | v1.5 (algo) / v2.0 (UI) |
| REST API / CI/CD | Team feature | v2.0 |
| Webhooks / alerts | Team feature | v2.0 |
| Web live overlay | Separate server needed | v2.0 |
| Per-connection network stats | Requires injection | v2.0 (server-aggregated) / v2.5 (per-app via SDK) |
| In-app FPS overlay on device | Requires injection | v2.5 (Android) / v3.0 (iOS) |
| SSO / Jira / RBAC | Enterprise | v3.5 |
| Video recording | Native tooling per platform | v1.5 (Android) / v2.5 (iOS) / v3.0 (PC) — Section 32 |

### 4.3 Core Metrics — v1.0 (Expanded, No Root Required)

#### Android via ADB External

| # | Metric | ADB Source | Notes |
|---|---|---|---|
| 1 | FPS | `dumpsys SurfaceFlinger --latency` | Real frame timing from framebuffer |
| 2 | Jank (3-tier time threshold) | Calculated from frame timestamps | Small / Jank / Big Jank — Section 5.1 |
| 3 | Jank (frame ratio Γ=L/R model) | Calculated from frame timestamps | Alt formula, settings-toggleable — Section 5.1 |
| 4 | Variability Index | Per-second analytic | Avg variance consecutive FPS readings — Section 6 |
| 5 | Raw frametimes array | Stored per second as JSON | For deep analysis tools |
| 6 | CPU % (system) | `/proc/stat` | Total system utilization |
| 7 | CPU % (per-app, normalized cores) | `/proc/<pid>/stat` | App-specific; combined call with system |
| 8 | CPU % (normalized to current freq) | + `/sys/devices/system/cpu/cpuN/cpufreq/scaling_cur_freq` | Section 5.2 |
| 9 | CPU core states | `/sys/devices/system/cpu/cpuN/online` | JSON array per sample, online=1/offline=0 |
| 10 | CPU core frequencies | `/sys/devices/system/cpu/cpuN/cpufreq/scaling_cur_freq` | JSON array per sample, kHz |
| 11 | Memory PSS Total | `dumpsys meminfo <package>` | Proportional Set Size |
| 12 | Memory subsections (Java, Native, Graphics, Stack, Code, System) | Same dumpsys output | Section 5.3 |
| 13 | Battery % | `dumpsys battery` | Charge level |
| 14 | Battery mA | `/sys/class/power_supply/battery/current_now` | µA ÷ 1000; null if file missing |
| 15 | Battery voltage (mV) | `/sys/class/power_supply/battery/voltage_now` | µV ÷ 1000; null if file missing |
| 16 | Battery temperature | `dumpsys battery` → `temperature:` | tenths °C ÷ 10; null if field missing |
| 17 | Charging state | `dumpsys battery` → `AC powered:`, `USB powered:`, `Wireless powered:`, `status:` | bool per source + composite |
| 18 | Network TX / RX (per interface) | `/proc/net/dev` | wlan0 / rmnet_data0 / etc. — split WiFi vs Cellular vs other |
| 19 | WiFi active state | `dumpsys connectivity` or `dumpsys wifi` | bool: WiFi connected this sample |
| 20 | Thermal status | `dumpsys thermalservice` | 0=normal 1=fair 2=serious 3=critical |
| 21 | GPU % | sysfs (Adreno/Mali) | Section 5.7; never fabricated; null if unavailable |

**Post-session analytics computed from samples (Section 6):**
- mAh consumed (integral of mA over session duration)
- Average power mW (mean of `V × I` per sample)
- Total power mWh (integral of mW over session)
- Estimated playtime hours (battery_capacity_mAh ÷ avg_mA)
- Variability Index (FPS)

**Static data collected once at session start (see Appendix E):**
- Device: manufacturer, model, board, chipset, GPU vendor, GPU renderer name, OS name+version, GPU driver version, network operator (if SIM)
- App: package, label, version, build number (versionCode), build date

**GPU:** Collected where sysfs path accessible without root. Never fabricated. See Appendix A.

#### iOS via pyidevice on macOS

| # | Metric | DTXProtocol Service | Notes |
|---|---|---|---|
| 1 | FPS | `graphics.opengl` instrument | Real display FPS |
| 2 | Jank (3-tier + Γ ratio) | Calculated from frame timestamps | Same models as Android |
| 3 | Variability Index | Post-session analytic | Same as Android |
| 4 | Raw frametimes array | Stored per session | Same as Android |
| 5 | CPU % (per-app) | `sysmontap` | NOT divided by core count (iOS difference — see 5.2) |
| 6 | CPU per-thread | `sysmontap.threads` | Top 8 threads by CPU usage with names |
| 7 | Memory phys_footprint | `sysmontap` | Bytes |
| 8 | Memory App Usage subsections | `memdetail` instrument | App / Other / Total breakdown |
| 9 | Battery mA (iPhone ≤7, iOS 10.3+) | Battery instrument | Real-time |
| 10 | Battery % | Battery instrument | All devices |
| 11 | Battery voltage | Battery instrument | mV |
| 12 | Battery temperature | Battery instrument | °C where available |
| 13 | Charging state | `processInfo.batteryState` | unplugged / charging / full |
| 14 | Network TX / RX | `networking` instrument | Per-connection aggregated |
| 15 | WiFi active state | `processInfo.networkInterface` | bool |
| 16 | Thermal state | `processInfo.thermalState` | 0–3 |
| 17 | GPU utilization | `gpu_counters` (Metal) | % time GPU busy |

**iOS static data (collected via pyidevice info commands):**
- Device: model identifier, name, OS version, chipset (best-effort from model lookup table)
- App: bundle ID, name, version, build number, executable name

---

## 5. Metrics Reference

> **Format for each metric:** ADB/API command → parse target → algorithm (numbered steps) → return type → null contract → acceptance criteria.

### 5.1 FPS — Android (SurfaceFlinger)

**ADB command:**
```
adb shell dumpsys SurfaceFlinger --latency "<layer_name>"
```

**Output format:**
- Line 1: refresh period in nanoseconds (e.g., `16666666` = 60Hz)
- Lines 2+: three tab-separated integers per line: `desired_ns`, `actual_present_ns`, `ready_ns`

**Parse algorithm — FPS:**
1. Split output on newlines. If fewer than 3 lines → return fps=0.0
2. Parse line 1 as integer → `refresh_period_ns`; `refresh_period_ms = refresh_period_ns / 1_000_000`
3. For each line after line 1: split on tab, parse field at index 1 as integer → `actual_present_ns`
4. Skip any timestamp ≤ 0
5. For each consecutive pair `(t_prev, t_curr)`: compute `delta_ms = (t_curr - t_prev) / 1_000_000`
6. Skip any `delta_ms ≤ 0` or `delta_ms ≥ 100` (outlier / freeze filter)
7. `fps = 1000.0 / mean(valid_deltas)` if `len(valid_deltas) ≥ 1`, else `0.0`

**3-Tier Jank Classification (default time-threshold model):**

Maintain a rolling window of the last 3 valid frame times (delta_ms values). For each new frame:

| Tier | Condition | Field |
|---|---|---|
| **Small Jank** | `delta_ms > refresh_period_ms` (any frame slower than display) | `jank_small_count` |
| **Jank** | `delta_ms > 2 × mean(last_3_frames)` OR `delta_ms > 83.3ms` | `jank_count` |
| **Big Jank** | `delta_ms > 2 × mean(last_3_frames)` OR `delta_ms > 125ms` | `jank_big_count` |

- All three are independent (a Big Jank also increments Jank and Small Jank counters)
- Rolling window starts accumulating from the first frame; for frames 1–3, use available frames as the window
- `83.3ms` = 2 frames at 24fps; `125ms` = 3 frames at 24fps

**Frame Ratio Jank Model (Γ=L/R, settings-toggleable alt):**

GameBench-compatible ratio model. For each frame:
1. `L` = frame latency (delta_ms from previous frame)
2. `R` = device refresh period (refresh_period_ms)
3. `Γ_curr = ceil(L / R)` (round up to nearest integer)
4. If `Γ_curr ≠ Γ_prev` AND `Γ_prev` was set → increment `jank_ratio_count`
5. Store `Γ_prev = Γ_curr` for next frame

Stored in `metric_samples.jank_ratio_count`. Settings UI toggle: "Jank detection formula = Time-threshold (default) / Frame ratio Γ". Both models can run simultaneously (no extra ADB cost — pure math from same frame data); UI shows whichever user picks.

**Raw Frametimes Storage:**

For deep analysis (e.g., custom percentiles, ML), the per-second sample stores the full frame time array as JSON in `metric_samples.frametimes_json` (TEXT). Format: `[16.67, 16.91, 16.40, 33.21, ...]` ms values. Typical 60fps second has 60 entries; null if no frames produced that second. Storage cost: ~300 bytes/s avg → 180KB per 10-min session — negligible.

Acceptance criteria addition:
- [ ] Frame ratios change `1→2→1→2` over 4 frames → `jank_ratio_count` = 3
- [ ] `frametimes_json` parses as array of REAL values, count matches fps within ±2

---

#### 5.1.1 FPS Variability Index

**Computed post-session OR per-second** (configurable via settings; default: per-second feeds active card, post-session canonical value in `session_stats`).

**Algorithm:**
1. Collect ordered FPS samples for window (1s = 60 frames; full session = N samples)
2. Compute consecutive differences: `diffs = [|fps[i] - fps[i-1]| for i in 1..N-1]`
3. `variability_index = mean(diffs)` if `len(diffs) ≥ 1`, else `0.0`

**Interpretation:** Independent of median FPS. A 60fps stable game and a 30fps stable game both score ~1–2 fps. Spikey games score >5 fps regardless of average.

**Stored in:**
- `session_stats.variability_index` (REAL, post-session canonical)
- `marker_stats.variability_index` (REAL, per-marker)
- Live displayed in FPS card stat pill

**Acceptance criteria:**
- [ ] Constant 60fps samples → variability_index = 0.0
- [ ] Alternating 30/60 fps → variability_index ≈ 30.0
- [ ] Empty list → 0.0, no crash

**Layer name discovery (try in order, stop at first non-empty result):**
1. Exact package name as SurfaceFlinger layer
2. Run `adb shell dumpsys SurfaceFlinger` full output; scan all layer names for substring containing package name; use first match
3. Topmost visible layer (fallback; less accurate for multi-window)

**Return type:**
- `fps: double` — 0.0 if valid parse with no usable frames; `null` if ADB call fails
- `jank_small_count: int` — 0 if no janks; `null` if ADB call fails
- `jank_count: int` — 0 if no janks; `null` if ADB call fails
- `jank_big_count: int` — 0 if no janks; `null` if ADB call fails

**Null contract:** Return all four as `null` if ADB exits non-zero or times out. Session never crashes.

**Acceptance criteria (unit tests in `fps_parser_test.dart`):**
- [ ] Empty string input → fps=0.0, all jank counts=0
- [ ] Fewer than 3 lines → fps=0.0
- [ ] 10 valid frames averaging 16.67ms → fps within ±2% of 60.0
- [ ] Frame delta of 130ms → `jank_big_count` increments; also increments `jank_count` and `jank_small_count`
- [ ] Frame delta of 90ms → `jank_count` increments (>83.3ms threshold); also increments `jank_small_count`
- [ ] Frame delta of 20ms on 60Hz display (refresh=16.67ms) → `jank_small_count` increments; `jank_count` does NOT (unless also >2× rolling avg)
- [ ] Frame delta of 150ms → excluded by outlier filter (≥100ms); fps denominator excludes it

---

### 5.2 CPU — Android

**ADB command (single atomic call — reduces race condition between /proc reads):**
```
adb shell "cat /proc/<pid>/stat && echo --- && cat /proc/stat"
```

**Parse algorithm:**
1. Split combined output on `---` separator → `[pid_section, global_section]`
2. If either section missing or malformed → return `null` for all CPU fields
3. **Per-app CPU:** split `pid_section` on whitespace → `utime = field[13]`, `stime = field[14]`; `pid_ticks = utime + stime`
4. **System CPU:** `global_section` first line starts with `cpu `; split on whitespace, skip label → `[user, nice, system, idle, iowait, irq, softirq]` (7 fields); `total_ticks = sum(all 7)`
5. Store snapshot `(pid_ticks, total_ticks)` with timestamp
6. On next sample: `cpu_app_pct = (Δpid_ticks / Δtotal_ticks) × 100.0`, clamped to [0, 100]
7. `cpu_system_pct = ((Δtotal_ticks - Δidle_ticks) / Δtotal_ticks) × 100.0`
8. First sample per session: store snapshot only, return `null` (no delta yet)

**iOS CPU difference:** CPU% from `sysmontap.cpuUsage` is NOT divided by core count. 200% means 2 cores fully busy. The UI must display a tooltip: "iOS CPU% is not normalized per core count." Do NOT normalize it — preserve the raw value.

**Return type:** `cpu_app_pct: double?`, `cpu_system_pct: double?` (null on failure or first sample)

**Acceptance criteria:**
- [ ] First sample → null returned, no crash
- [ ] Invalid/missing PID → null returned
- [ ] `Δpid_ticks = 500`, `Δtotal_ticks = 1000` → cpu_app_pct = 50.0

---

#### 5.2.1 CPU Normalized to Current Frequency (Android)

**Rationale:** Bare CPU% reports load relative to current operating point. A CPU at 50% load running at 500MHz on a 2GHz-max chip is doing only 12.5% of max work. GameBench-compatible "normalized usage" accounts for this.

**ADB command (combined call, sysfs glob):**
```
adb shell "for c in /sys/devices/system/cpu/cpu[0-9]*; do
  echo $c
  cat $c/online 2>/dev/null
  cat $c/cpufreq/scaling_cur_freq 2>/dev/null
  cat $c/cpufreq/cpuinfo_max_freq 2>/dev/null
  echo ---
done"
```

**Parse algorithm:**
1. Split on `---` → list of per-core blocks
2. For each block: parse `online` (1=on, 0=off; missing means cpu0 always-on), `scaling_cur_freq` (kHz), `cpuinfo_max_freq` (kHz)
3. `core_states_array = [online_state for each core]` → JSON array stored in `cpu_core_states_json`
4. `core_freqs_array = [scaling_cur_freq_kHz for each core, 0 if offline]` → JSON in `cpu_core_freqs_json`
5. `total_max_cycles = sum(cpuinfo_max_freq across all cores)` (cached after first read — does not change)
6. `total_avail_cycles = sum(scaling_cur_freq for each ONLINE core)`
7. `cpu_norm_factor = total_avail_cycles / total_max_cycles` (in [0, 1])
8. `cpu_app_pct_freq_norm = cpu_app_pct × cpu_norm_factor` (still 0–100 scale)

**Storage:**
- `cpu_app_pct_freq_norm` REAL nullable in `metric_samples`
- `cpu_core_states_json` TEXT nullable
- `cpu_core_freqs_json` TEXT nullable

**Null contract:** If sysfs files unreadable on this device → all three fields null; UI shows "Normalized CPU: N/A"; non-normalized `cpu_app_pct` continues to populate.

**Cache:** `cpuinfo_max_freq` is constant per boot; read once on session start, store in `MetricCollector` state, do not re-read each second.

**Acceptance criteria:**
- [ ] Cores 0,1 online @500MHz, cores 2,3 offline; max=2GHz/core; cpu_app_pct=50% → cpu_app_pct_freq_norm = 50% × (1000/8000) = 6.25%
- [ ] All cores online @max → cpu_app_pct_freq_norm = cpu_app_pct (no change)
- [ ] sysfs glob fails → all 3 fields null, no crash, base CPU% still works

---

#### 5.2.2 CPU Per-Thread Breakdown (Top 8)

**External (Android):** Requires root or Android <Q. On modern Android, third-party apps (including ADB shell) cannot read `/proc/<pid>/task/<tid>/stat` for other apps. Set null.

**SDK injected (v2.5+):** SDK reads its own process's task dirs. For each thread:
1. Read `/proc/<own_pid>/task/<tid>/stat` → `utime + stime` ticks
2. Read `/proc/<own_pid>/task/<tid>/comm` → thread name
3. Compute delta vs previous sample, sort descending, take top 8
4. Store as JSON: `[{"tid":12345,"name":"UnityMain","cpu_pct":18.2}, ...]`

**iOS via pyidevice:** `sysmontap.threads` field already exposes per-thread cpu+name. Take top 8.

**Storage:** `thread_cpu_samples` table (already in v2.5 schema, Section 18.13). Pre-injection: `thread_data` field is null/empty.

**Acceptance criteria:**
- [ ] SDK injected, idle app → top thread is "main" with low %
- [ ] iOS sysmontap returns 12 threads → only top 8 stored
- [ ] External Android (no SDK) → no rows inserted, UI tab shows "Per-thread CPU requires injected mode"

---

### 5.3 Memory — Android

**ADB command:**
```
adb shell dumpsys meminfo <package_name>
```

**Output structure (relevant excerpt — Android 7+):**
```
                       Pss  Private  Private  SwapPss     Heap     Heap
                     Total    Dirty    Clean    Dirty     Size    Alloc
                    ------   ------   ------   ------   ------   ------
  Native Heap        45120    44980        0      120    52224    44321
  Dalvik Heap        12480    12350        0       50    16384    11200
  Dalvik Other        2560     2520        0        0
  Stack               1024     1024        0        0
  Ashmem                 8        0        0        0
  Other dev             64        0        0        0
  .so mmap           38400      512    35200        0
  .jar mmap              0        0        0        0
  .apk mmap          21504        0    20800        0
  .ttf mmap            512        0      256        0
  .dex mmap          18432       64    16400        0
  .oat mmap          15360        0    15040        0
  .art mmap           4096     3000        0        0
  Other mmap           400      400        0        0
  EGL mtrack         52224    52224        0        0
  GL mtrack          24576    24576        0        0
  Unknown             1280      900        0        0
                  ------   ------   ------
            TOTAL  237040   142540    87696      170
```

**Parse algorithm — full subsections:**
1. Find header line containing `Pss` `Private` columns (skip ASCII art row below)
2. For each line until `TOTAL` row:
   - First whitespace-trimmed token through last digit before next column = label (multi-word ok: `"Native Heap"`)
   - Field at index 1 (after label) = PSS Total in KB
3. Map labels to schema columns:
   - `Java Heap` = `Dalvik Heap` PSS (Android pre-7) OR `Java Heap` (Android 7+ Pro mode); col `memory_java_kb`
   - `Native Heap` PSS → `memory_native_kb`
   - `EGL mtrack` + `GL mtrack` summed → `memory_graphics_kb`
   - `Stack` → `memory_stack_kb`
   - `.so mmap` + `.jar mmap` + `.apk mmap` + `.dex mmap` + `.oat mmap` + `.art mmap` summed → `memory_code_kb`
   - All others (`Ashmem`, `Other dev`, `Other mmap`, `Unknown`, etc.) summed → `memory_system_kb`
4. `TOTAL PSS:` line → `memory_pss_kb` (existing column, primary metric)
5. If line missing → that subsection field null; total may still parse

**Return types:**
- `memory_pss_kb: int?` (primary, must be non-null when app running)
- `memory_java_kb: int?`
- `memory_native_kb: int?`
- `memory_graphics_kb: int?`
- `memory_stack_kb: int?`
- `memory_code_kb: int?`
- `memory_system_kb: int?`

**Null contract:** If `dumpsys meminfo` fails or app not running → all fields null. If individual subsection labels missing on older Android → that field null, total still parses.

**iOS subsections (via pyidevice):**
- `memory_pss_kb` ← `phys_footprint` ÷ 1024
- `memory_app_kb` ← `internal` field of memdetail (alias `memory_java_kb`, repurposed for iOS)
- `memory_other_kb` ← `external` field (alias `memory_system_kb`)
- iOS-specific subsections: same column names, semantic differs by platform (documented per-row in Section 9.7 scorecard)

**Acceptance criteria:**
- [ ] `TOTAL PSS:    524288 kB` → memory_pss_kb = 524288
- [ ] Native Heap line `45120` → memory_native_kb = 45120
- [ ] EGL mtrack `52224` + GL mtrack `24576` → memory_graphics_kb = 76800
- [ ] Package not running → all fields null, no crash
- [ ] Android 6 (no Pro categories) → memory_java_kb = Dalvik Heap PSS instead

---

#### 5.3.1 WebView / WebKit Memory (v1.0 — for hybrid apps)

**Android multi-process detection:**
1. Setting `webview_memory: true` in pb_config or app settings
2. Discover WebView child PIDs: parse `dumpsys activity processes` output for processes whose `cmdline` ends in `:sandboxed_process*` AND whose `parent` PID matches target app
3. For each WebView PID, run `dumpsys meminfo <pid>` and sum PSS Total
4. Store in `metric_samples.memory_webview_kb` (REAL, nullable)

**iOS WebKit memory:**
- pyidevice `memdetail` instrument exposes `WebContent` process memory if `WKWebView` instances exist in target app
- Sum across WebContent processes → `memory_webview_kb`

**Note on cross-platform comparison:** Android WebView and iOS WebKit allocate memory differently. Numbers are not directly comparable. Section 9 scorecard adds tooltip: "WebView memory differs by platform — compare same-platform builds, not Android-vs-iOS."

---

### 5.4 Battery — Android

**Three separate ADB reads per sample cycle:**

**1. Level + temperature:**
```
adb shell dumpsys battery
```
- Parse `level:` field → `battery_pct: int` (0–100)
- Parse `temperature:` field → divide by 10 → `battery_temp_c: double` (tenths of °C)
- Parse `voltage:` field → `battery_mv: double` (mV, direct value)

**2. Current draw:**
```
adb shell cat /sys/class/power_supply/battery/current_now
```
- Value in microamps (µA). Divide by 1000 → mA.
- Negative = discharging (normal during use). Store absolute value in `battery_ma`. Separately track discharge direction via sign.
- File may not exist on all hardware → return `null`; no exception.

**3. Voltage (cross-check):**
```
adb shell cat /sys/class/power_supply/battery/voltage_now
```
- Value in microvolts (µV). Divide by 1000 → mV.
- File may not exist → return `null`.
- If both `dumpsys battery` voltage and this file are available, prefer this file (more precise).

**4. Charging detection (parsed from same `dumpsys battery` output):**
- `AC powered: true/false` → `charging_ac: bool`
- `USB powered: true/false` → `charging_usb: bool`
- `Wireless powered: true/false` → `charging_wireless: bool`
- `Dock powered: true/false` → `charging_dock: bool` (Android 12+, may be missing)
- `status: 1|2|3|4|5` → 1=Unknown, 2=Charging, 3=Discharging, 4=Not charging, 5=Full
- Composite: `charging: bool` = (any of ac/usb/wireless/dock = true) OR (status = 2 OR status = 5)

**5. WiFi state (separate command):**
```
adb shell dumpsys connectivity | grep -A2 "Active default network"
```
- Parse `NetworkInfo: type: WIFI` → `wifi_active: bool`
- Fallback: `adb shell dumpsys wifi | grep -i "Wi-Fi is"` → enabled/disabled
- If neither parses → null (do not block session)

**Return type:**
- `battery_pct: int?` — null only if ADB fails entirely
- `battery_ma: double?` — null if file missing or ADB fails
- `battery_mv: double?` — null if file missing or ADB fails
- `battery_temp_c: double?` — null if field missing or ADB fails
- `charging: bool?` — null if dumpsys fails entirely; otherwise bool
- `charging_source: TEXT?` — `"ac"`, `"usb"`, `"wireless"`, `"dock"`, `"none"` (max one — pick first true; null if charging=false or unknown)
- `wifi_active: bool?` — null if both connectivity + wifi parse fail

**iOS battery:**
- `battery_pct`: always available from battery instrument
- `battery_ma`: only iPhone ≤7, iOS 10.3+; null for iPhone 8+ (permanent hardware limit)
- `battery_mv`: from battery instrument
- `battery_temp_c`: from battery instrument where available
- `charging`: from `processInfo.batteryState` (unplugged=false, charging/full=true)
- `charging_source`: `"usb"` or `"wireless"` based on whether `processInfo.batteryState == .charging` AND no other indicator (best-effort; iOS does not distinguish reliably)
- `wifi_active`: from `processInfo.networkInterface` instrument

**Storage warning:** If `charging = true` mid-session, set flag `session.has_charging_period = true`. UI shows warning on session detail: "Battery measurements unreliable — device was charging during X% of session." Power analytics (mAh consumed, drain rate, estimated playtime) excluded for charging samples.

**Acceptance criteria:**
- [ ] `level: 87` → battery_pct = 87
- [ ] `temperature: 312` → battery_temp_c = 31.2
- [ ] Missing `current_now` file → battery_ma = null, no exception thrown
- [ ] `current_now` = `-540000` → battery_ma = 540.0 (absolute value stored)
- [ ] `voltage_now` = `3850000` → battery_mv = 3850.0

---

### 5.5 Network — Android

**ADB command:**
```
adb shell cat /proc/net/dev
```

**Parse algorithm:**
1. Skip header lines (first 2 lines)
2. For each remaining line: split on `|` then whitespace → interface name + byte counters
3. Skip `lo` (loopback) and any interface with both RX and TX bytes = 0
4. **Classify interface by name prefix:**
   - `wlan*` / `wifi*` / `nan*` → category: WiFi
   - `rmnet*` / `ccmni*` / `pdp*` / `ppp*` → category: Cellular (mobile data)
   - `eth*` / `usb*` / `lo*` → category: Other (shown but separated)
   - Anything else → category: Other
5. Per-interface running totals: store named cumulative values
6. Aggregated columns:
   - `net_wifi_tx_bytes` / `net_wifi_rx_bytes` (sum WiFi class)
   - `net_cellular_tx_bytes` / `net_cellular_rx_bytes` (sum Cellular class)
   - `net_other_tx_bytes` / `net_other_rx_bytes` (sum Other class)
   - `net_tx_bytes` / `net_rx_bytes` (sum ALL classes — backwards compat)
7. Delta (bytes/s) computed at analytics time per category

**First sample:** store cumulative only; display as null (no delta available yet).

**Return types:** all cumulative INTEGERs, nullable on ADB fail.

**iOS network split:**
- pyidevice `networking` instrument exposes per-interface separately
- `wifi_*` and `cellular_*` paths in DTX
- Same column names populated; `net_other_*` typically null on iOS

**Acceptance criteria:**
- [ ] Consecutive samples 2s apart: delta_wifi_tx = 2048 → 1024 bytes/s in UI WiFi line
- [ ] First sample → null delta shown, cumulative stored
- [ ] Device with rmnet0 + wlan0 active → both fields populated independently
- [ ] Cellular only (WiFi off) → `net_wifi_*` = 0 cumulative, not null

---

### 5.6 Thermal — Android

**ADB command (try in order):**
```
adb shell dumpsys thermalservice
```
- Parse `Status:` field → map to integer: `normal=0, fair=1, serious=2, critical=3`
- If `thermalservice` unavailable → try `adb shell getprop sys.thermal.state`
- Both fail → `null`

**Return type:** `thermal_status: int?` (0–3)

**Acceptance criteria:**
- [ ] `Status: normal` → 0
- [ ] `Status: critical` → 3
- [ ] Both commands fail → null, no crash

---

### 5.7 GPU — Android

**Try in order, stop at first successful non-empty result:**

1. **Adreno:** `adb shell cat /sys/class/kgsl/kgsl-3d0/gpubusy`
   - Output format: two integers `"busy total"`
   - `gpu_pct = (busy / total) × 100.0`
   - If returns permission denied on Android 13+: first try `adb shell echo 1 > /sys/class/kgsl/kgsl-3d0/perfcounter`, retry once
2. **Mali (Samsung):** `adb shell cat /sys/class/misc/mali0/device/utilization`
   - Integer 0–100 directly → `gpu_pct`
3. **Mali (generic):** `adb shell cat /sys/bus/platform/drivers/mali/*/utilization`
   - Shell expands glob; parse first integer found
4. **Failure:** `gpu_pct = null`. UI shows "GPU: N/A". **Never fabricate a GPU value.**

**Return type:** `gpu_pct: double?`

**Acceptance criteria:**
- [ ] Adreno output `"4823 10000"` → gpu_pct = 48.23
- [ ] All paths fail → null returned; no crash; UI badge shows "GPU: N/A"

---

### 5.8 Disk I/O — Android (v1.5)

**ADB command:**
```
adb shell cat /proc/diskstats
```

**Parse algorithm:**
1. Find line where field[2] is `sda`, `mmcblk0`, or `vda` (first match)
2. `read_sectors = field[5]`, `write_sectors = field[9]` (cumulative sector counts)
3. Sectors × 512 = bytes; compute delta between samples; divide by sample_interval_s → bytes/s → store as KB/s in `disk_read_kb` and `disk_write_kb`

**Return type:** `disk_read_kb: double?`, `disk_write_kb: double?` (null in v1.0; active in v1.5)

---

### 5.9 CPU Per-Core — Android (v1.5)

**ADB command:**
```
adb shell cat /proc/stat
```

Lines after the first (`cpu ` aggregate) are per-core: `cpu0`, `cpu1`, etc. Apply the same delta algorithm as Section 5.2 per core. Store as a JSON array in `cpu_cores` column: `[42.1, 78.3, 15.0, 91.2]`.

---

### 5.10 iOS Metrics via pyidevice

**Architecture:**
- Flutter launches a Python subprocess: `python3 ios_agents/collector.py <udid> <bundle_id>`
- The subprocess streams one newline-delimited JSON object per sample to stdout
- Flutter reads stdout line by line, JSON-decodes each line, and maps fields to `MetricSample`
- Lines that fail JSON parsing are silently skipped (no crash)
- Subprocess stderr is logged internally but not shown to user unless session fails to start

**Metric field mapping (collector.py stdout JSON → MetricSample):**

| JSON key | MetricSample field | Source DTX instrument |
|---|---|---|
| `fps` | `fps` | `graphics.opengl` |
| `jank.small` | `jank_small_count` | computed from frame timestamps |
| `jank.jank` | `jank_count` | computed from frame timestamps |
| `jank.big` | `jank_big_count` | computed from frame timestamps |
| `cpu` | `cpu_app_pct` | `sysmontap.cpuUsage` (NOT per-core normalized) |
| `mem_bytes` | `memory_pss_kb` (÷ 1024) | `sysmontap.physFootprint` |
| `bat_pct` | `battery_pct` | battery instrument |
| `bat_ma` | `battery_ma` | battery instrument (null for iPhone 8+) |
| `bat_mv` | `battery_mv` | battery instrument |
| `bat_temp_c` | `battery_temp_c` | battery instrument |
| `net_tx` | `net_tx_bytes` | networking instrument (cumulative) |
| `net_rx` | `net_rx_bytes` | networking instrument (cumulative) |
| `thermal` | `thermal_status` | `processInfo.thermalState` |
| `gpu_pct` | `gpu_pct` | `gpu_counters` (Metal, % time busy) |

**IosService behavioral contract:**
- On subprocess exit unexpectedly: log stderr, stop collection, mark session as completed (save what was collected)
- On JSON parse failure for a single line: skip line, continue — never crash
- On subprocess failing to start (pyidevice not installed): show a human-readable install guide modal; do not start the session
- Stop is clean: send SIGTERM to subprocess, wait up to 3s, then SIGKILL

**Acceptance criteria:**
- [ ] Valid JSON line with all fields → MetricSample fully populated
- [ ] Malformed JSON line (partial write) → skipped, next line processed normally
- [ ] Subprocess crashes after 10 samples → session stops, 10 samples saved to SQLite
- [ ] pyidevice not installed → install guide shown before any recording attempt

---

### 5.11 Static Device + App Data

Collected ONCE at session start (not per-second). Stored in `devices` and `sessions` tables (denormalized intentionally — device may swap chipset on different boot).

**Android — collected via ADB at session start:**

| Field | ADB Source | Notes |
|---|---|---|
| `manufacturer` | `getprop ro.product.manufacturer` | "Google", "Samsung", "Xiaomi" |
| `model` | `getprop ro.product.model` | "Pixel 8 Pro", "SM-S911B" |
| `board` | `getprop ro.product.board` | Hardware platform name |
| `device` | `getprop ro.product.device` | Internal codename |
| `os_name` | `getprop ro.build.version.release` | "14", "13" |
| `os_version` | `getprop ro.build.id` | Build ID, e.g., "UQ1A.240105.004" |
| `chipset` | `getprop ro.hardware` + `getprop ro.board.platform` | Combined |
| `cpu_abi` | `getprop ro.product.cpu.abi` | "arm64-v8a", "armeabi-v7a" |
| `gpu_vendor` | `dumpsys SurfaceFlinger \| grep -i "GLES:"` line | Parse 1st token: "Qualcomm", "ARM", "Imagination" |
| `gpu_renderer` | Same line | Parse model: "Adreno (TM) 740", "Mali-G715" |
| `gpu_driver_version` | Same line | Parse OpenGL ES version + driver string |
| `network_operator` | `getprop gsm.sim.operator.alpha` | SIM carrier name; null if no SIM |
| `screen_resolution` | `wm size` parse | "1080x2400" |
| `screen_density` | `wm density` parse | "440" |
| `total_ram_kb` | `cat /proc/meminfo \| grep MemTotal` | KB |
| `total_storage_kb` | `df /data \| tail -1` | KB |
| `battery_capacity_mah` | `dumpsys batterystats \| grep -i "capacity:"` (best-effort) OR `cat /sys/class/power_supply/battery/charge_full_design` | mAh; null if missing |

**App (Android):**

| Field | ADB Source |
|---|---|
| `app_package` | known from picker |
| `app_label` | `dumpsys package <pkg> \| grep "labelRes\|nonLocalizedLabel"` |
| `app_version` | `dumpsys package <pkg> \| grep versionName` |
| `app_build_number` | `dumpsys package <pkg> \| grep versionCode` |
| `app_install_time` | `dumpsys package <pkg> \| grep firstInstallTime` |
| `app_update_time` | `dumpsys package <pkg> \| grep lastUpdateTime` |
| `app_target_sdk` | `dumpsys package <pkg> \| grep targetSdk` |
| `app_min_sdk` | `dumpsys package <pkg> \| grep minSdk` |

**iOS via pyidevice:**

| Field | Source |
|---|---|
| `manufacturer` | Always "Apple" |
| `model` | `lockdown.DeviceClass` + `ProductType` lookup table → "iPhone 15 Pro" from "iPhone16,1" |
| `os_name` | `lockdown.ProductName` → "iPhone OS" |
| `os_version` | `lockdown.ProductVersion` → "17.2.1" |
| `chipset` | Lookup table from `ProductType` → "A17 Pro" |
| `gpu_vendor` | "Apple" |
| `gpu_renderer` | Apple chipset GPU name → "Apple A17 Pro GPU" |
| `screen_resolution` | DTX `screenSize` query |
| `total_ram_kb` | DTX `hw.memsize` |
| `battery_capacity_mah` | DTX battery instrument |

**iOS app:**
- `app_package` (Bundle ID) — known from picker
- `app_label` — `installation_proxy` → CFBundleDisplayName
- `app_version` — CFBundleShortVersionString
- `app_build_number` — CFBundleVersion

**Storage:**
- `devices` table: extended with new columns (see Appendix C)
- `sessions` table: extended with `app_label`, `app_build_number`, `app_target_sdk`, `app_min_sdk`, `app_install_time`, `app_update_time`

**Acceptance criteria:**
- [ ] Pixel 8 Pro: manufacturer="Google", model="Pixel 8 Pro", chipset starts with "Tensor"
- [ ] iPhone 15 (model id `iPhone16,1`): chipset="A17 Pro" via lookup table
- [ ] Missing field on rooted custom ROM → that field null, session continues
- [ ] No SIM card → `network_operator` = null, no crash

---

### 5.12 Screenshots — 5 Sizes

GameBench-compatible screenshot sizing. User configures sizes + intervals independently in settings.

**Sizes:**

| ID | Scale | Typical px (1080p source) | Use case |
|---|---|---|---|
| `SS0` | 100% | 1080×2400 | Full-detail QA evidence |
| `SS1` | 50% | 540×1200 | Default — clear thumbnails |
| `SS2` | 25% | 270×600 | High-frequency capture |
| `SS3` | 12.5% | 135×300 | Frequent capture, low storage |
| `SS4` | 6.75% (1/16 by area) | 67×150 | Burst capture |

**Capture pipeline:**
1. ADB: `adb exec-out screencap -p` returns full PNG to stdout
2. Decode PNG in Dart (`image` package or platform-specific)
3. For each enabled size: scale via Lanczos filter, encode as JPEG @ 50% quality
4. Save to `screenshots/<session_id>/<ts>_<size_id>.jpg`
5. Insert one row per saved size into `screenshots` table with `size_id` column

**Settings UI:**

```
Screenshots
  [✓] Full size (SS0):       Every [Off ▾] (Off / 5s / 10s / 30s / 60s)
  [✓] Half size (SS1):       Every [10s ▾]
  [ ] Quarter size (SS2):    Every [Off ▾]
  [ ] 1/8 size (SS3):        Every [Off ▾]
  [ ] 1/16 size (SS4):       Every [Off ▾]

  Wireless mode: screenshots auto-disabled (preserves session stability)
```

**Wireless behavior:** When session uses WiFi ADB or WiFi iOS connection, all screenshot sizes are forced disabled. UI shows banner: "Screenshots disabled during wireless profiling for stability."

**Storage estimate:**
- SS0: ~100KB/screenshot, every 30s, 10min session = 2MB
- SS1: ~25KB/screenshot, every 10s, 10min session = 1.5MB
- SS3: ~5KB/screenshot, every 2s, 10min session = 1.5MB

**Schema changes:**
```sql
ALTER TABLE screenshots ADD COLUMN size_id TEXT NOT NULL DEFAULT 'SS1';
ALTER TABLE screenshots ADD COLUMN width_px INTEGER;
ALTER TABLE screenshots ADD COLUMN height_px INTEGER;
ALTER TABLE screenshots ADD COLUMN file_size_bytes INTEGER;
```

**Acceptance criteria:**
- [ ] SS0=10s + SS3=2s enabled → 60s session produces 6 SS0 + 30 SS3 = 36 rows in screenshots table
- [ ] All sizes disabled → no screenshots taken, session continues
- [ ] WiFi ADB session → screenshots auto-disabled, banner shown
- [ ] Source PNG 1080×2400 → SS3 file dimensions are 135×300 (within ±2px tolerance)

---

## 6. Advanced Analytics

> All analytics are computed **post-session** from `metric_samples` in SQLite. Never during recording. This keeps the ring buffer and recording pipeline simple and low-overhead.

### 6.1 FPS Analytics

**Inputs:** `List<double> samples` — all fps values for a session or marker time range (fetched once from SQLite; all computation in memory)

**Output fields:**

| Field | Description |
|---|---|
| `median` | Middle value of sorted samples |
| `min_fps` | Minimum value in samples (= 1 / longest frame time in window) |
| `max_fps` | Maximum value in samples (= 1 / shortest frame time in window) |
| `one_percent_low` | Average of bottom 1% of samples |
| `p95_frame_time_ms` | 95th percentile frame time = 1000 / 5th-percentile FPS |
| `stability_pct` | % of samples within ±20% of median |
| `variability_index` | Avg absolute difference between consecutive FPS readings (GameBench-compat) |
| `fps_histogram` | Map of bucket_start → sample_count (5fps buckets default) |
| `frame_ratio_jank_total` | Total frames flagged via Γ=L/R model (Section 5.1) |

**Algorithms:**

**Median:**
Sort ascending. If odd count: middle element. If even: mean of two middle elements.

**Min / Max:**
`min_fps = samples.min()`. `max_fps = samples.max()`. Return 0 for empty list.

**1% Low FPS:**
`count = ceil(len(samples) × 0.01)`, minimum 1, maximum len.
Sort ascending. `one_percent_low = mean(samples[0 .. count-1])`.

**95th Percentile Frame Time:**
Sort ascending. `idx = floor(len × 0.05)`, clamped to `[0, len-1]`.
`fps_5th = sorted[idx]`. `p95_frame_time_ms = 1000.0 / fps_5th` if fps_5th > 0, else 0.

**Stability %:**
`lo = median × 0.8`, `hi = median × 1.2`.
`stability_pct = (count where lo ≤ fps ≤ hi) / len × 100`.

**FPS Histogram:**
`bucket_size` = 5fps (configurable in settings; 5 or 10).
`bucket_key = floor(fps / bucket_size) × bucket_size`.
Store as JSON string for DB: `{"0":2,"5":0,"60":450,"65":30}`.

**Variability Index (GameBench-compatible):**
Mean of absolute differences between consecutive FPS samples. Lower = smoother. GameBench reports this on Studio dashboards.
```
diffs = [abs(samples[i] - samples[i-1]) for i in 1..len-1]
variability_index = mean(diffs) if len ≥ 2 else 0.0
```
Acceptance examples:
- All 60fps → variability_index = 0.0
- [60,30,60,30,60] → diffs=[30,30,30,30] → variability_index = 30.0
- [60,59,61,60,59] → variability_index = 1.25

**Frame Ratio Jank Total:**
Sum of jank counts produced by the frame-ratio model (Γ=L/R, see Section 5.1). Stored separately from time-threshold jank so dashboards can show both.

**Acceptance criteria (`fps_analytics_test.dart`):**
- [ ] Empty samples → all fields return 0.0
- [ ] 99 × 60fps + 1 × 5fps → one_percent_low ≈ 5.0 (±0.1)
- [ ] 5 × 30fps + 95 × 60fps → p95_frame_time_ms ≈ 33.3ms (±1.0ms)
- [ ] All 60fps → stability_pct = 100.0, variability_index = 0.0
- [ ] Samples [58.0, 59.0, 62.0] → histogram key `55` = 3
- [ ] Samples [20.0, 20.0, 60.0] → min_fps = 20.0, max_fps = 60.0
- [ ] Samples [60,30,60,30] → variability_index = 30.0

---

### 6.2 Per-Marker Stats

Triggered automatically when a session stops. `AnalyticsService.computeMarkerStats(sessionId)` runs for all markers in that session.

**Algorithm:**
1. Query all markers for the session where `ended_at IS NOT NULL` (skip point markers which have no range)
2. For each marker: query `metric_samples` where `session_id = ? AND timestamp BETWEEN started_at AND ended_at`, ordered by timestamp ASC
3. If samples list is empty: skip — write no `marker_stats` row for this marker
4. Extract fps values list; apply FpsAnalytics (Section 6.1) → `fps_median`, `fps_min`, `fps_max`, `fps_1pct_low`, `fps_stability`, `frame_time_p95`
5. `cpu_avg = mean(cpu_app_pct values, skip nulls)`
6. `mem_peak_kb = max(memory_pss_kb values, skip nulls)`
7. `gpu_avg = mean(gpu_pct values, skip nulls)`
8. `battery_drain_pct = first_sample.battery_pct - last_sample.battery_pct` (both nullable; null if either missing)
9. `jank_total = sum(jank_count)`, `small_jank_total = sum(jank_small_count)`, `big_jank_total = sum(jank_big_count)`
10. `duration_ms = ended_at - started_at`
11. `jank_per_min = jank_total / (duration_ms / 60_000.0)`
12. Write one `marker_stats` row

**Acceptance criteria:**
- [ ] Marker with 0 samples → no `marker_stats` row inserted
- [ ] Point marker (ended_at IS NULL) → skipped entirely
- [ ] 60-second marker, jank_count sum = 30 → jank_per_min = 30.0
- [ ] `marker_stats` rows exist immediately after session stop → session detail loads without re-computing

---

### 6.3 Session-Level Stats

Computed in the same `AnalyticsService` pass after session stops, before returning to idle state. Uses all `metric_samples` for the session (no time filter).

**Fields computed:** `fps_median`, `fps_min`, `fps_max`, `fps_1pct_low`, `fps_stability`, `frame_time_p95`, `fps_histogram` (JSON), `cpu_avg_pct`, `cpu_peak_pct`, `memory_avg_kb`, `memory_peak_kb`, `gpu_avg_pct`, `battery_drain_pct`, `battery_drain_per_hour`, `battery_temp_max_c`, `jank_total`, `jank_small_total`, `jank_big_total`, `jank_per_min`, `net_total_tx_kb`, `net_total_rx_kb`, `thermal_peak`

**battery_drain_per_hour:**
`drain = first_pct - last_pct` (positive = drained).
`hours = session_duration_ms / 3_600_000`.
`battery_drain_per_hour = drain / hours` if hours > 0, else null.
Show warning in UI if session < 5 minutes: "Drain rate estimate less reliable for short sessions."

**net_total_tx_kb / net_total_rx_kb:**
`last_cumulative - first_cumulative` → total bytes exchanged → ÷ 1024 → KB.

**Acceptance criteria:**
- [ ] `session_stats` row exists immediately after session stop
- [ ] 10-minute session, battery drops 5% → battery_drain_per_hour ≈ 30.0 (±1.0)

---

### 6.4 Session Comparison Delta

**Inputs:** Two `SessionStats` objects: A (baseline), B (comparison)

**Output:** List of `MetricDelta` objects, one per metric:
- `metric: String` — human-readable name
- `value_a: double`, `value_b: double`
- `delta = value_b - value_a`
- `delta_percent = (delta / value_a) × 100` if value_a ≠ 0, else 0
- `is_regression: bool`

**Regression rules:**
- FPS fields: lower is regression (delta < 0)
- CPU, memory, jank: higher is regression (delta > 0)
- Stability %: lower is regression (delta < 0)

**Metrics compared:** FPS Median, FPS 1% Low, FPS Stability, Frame Time P95, CPU Avg, Memory Peak, Jank/min, Big Jank Total, GPU Avg.

---

### 6.5 Launch Complete Marker

A **special first-class marker** separate from user-created markers. Records the moment an app finishes loading and is ready for user interaction.

**Behavior:**
- User taps "Mark Launch Complete" button (distinct from "Add Marker") while session is active
- Creates one `markers` row with `label = '__launch_complete__'` and no `ended_at` (point marker)
- UI renders it as a distinct vertical line (rocket icon) on the timeline
- Session Detail shows "Time to Launch: Xs" computed as `launch_complete_ts - session_started_at`
- Per-marker stats do not apply (point marker, no range)

**Acceptance criteria:**
- [ ] Tap button → marker row inserted with label `'__launch_complete__'`
- [ ] Only one launch complete marker per session (button disables after use)
- [ ] "Time to Launch" displayed in session scorecard if marker exists
- [ ] Launch complete marker visually distinct from user markers on timeline

---

### 6.6 Power Analytics (Battery Energy Math)

GameBench reports **mAh consumed**, **avg power (mW)**, **total energy (mWh)**, and **estimated playtime**. PerformanceBench computes these from existing `metric_samples` rows — **zero extra ADB cost**.

**Inputs (per sample):** `timestamp`, `battery_current_ma`, `battery_voltage_v`, `battery_pct`.

**Charging filter:**
Skip samples where `charging = true`. Energy math only valid during discharge. If `has_charging_period = true`, mark analytics as partial.

**6.6.1 Trapezoidal Integration — Helper:**
```
def integrate(samples, value_fn) -> double:
  total = 0.0
  for i in 1..len-1:
    dt_h = (samples[i].ts - samples[i-1].ts) / 3_600_000.0   // ms → hours
    v0 = value_fn(samples[i-1])
    v1 = value_fn(samples[i])
    if v0 == null or v1 == null: continue
    total += (v0 + v1) / 2.0 × dt_h
  return total
```

**6.6.2 mAh Consumed:**
```
mah_consumed = integrate(samples, s => abs(s.battery_current_ma))
```
- Discharge current is negative on Android (`/sys/class/power_supply/battery/current_now` reports negative when discharging). Take absolute value.
- Unit: mA × hours = **mAh**.
- Acceptance: 30-min session at constant 500 mA → mah_consumed ≈ 250.0 mAh (±5%).

**6.6.3 Average Power (mW):**
```
power_samples = [s.battery_voltage_v × abs(s.battery_current_ma) for s in samples if both not null]
avg_power_mw = mean(power_samples)
```
- V × mA = mW. (Voltage in V × current in mA gives mW directly.)
- Skip samples with voltage = 0 (unsupported devices).

**6.6.4 Total Energy (mWh):**
```
total_power_mwh = integrate(samples, s => s.battery_voltage_v × abs(s.battery_current_ma))
```
- Trapezoidal integration of instantaneous power over time.

**6.6.5 Estimated Playtime (hours):**
```
if avg_current_ma > 0 and battery_capacity_mAh > 0:
  estimated_playtime_h = battery_capacity_mAh / avg_current_ma
else:
  estimated_playtime_h = null
```
- `battery_capacity_mAh` from `dumpsys batterystats | grep capacity` or device DB lookup (Section 5.11). Fallback: read `/sys/class/power_supply/battery/charge_full_design` (in µAh, ÷1000).
- Result: hours of continuous playtime predicted at this load.
- Show as "X.Yh predicted playtime" on session detail.

**6.6.6 Output Fields (session_stats):**
| Field | Unit | Notes |
|---|---|---|
| `mah_consumed` | mAh | Energy drawn |
| `avg_power_mw` | mW | Mean instantaneous power |
| `total_power_mwh` | mWh | Integrated total energy |
| `estimated_playtime_h` | hours | At this load |
| `has_charging_period` | bool | If true, analytics flagged "partial" in UI |

**Acceptance criteria (`power_analytics_test.dart`):**
- [ ] Constant 500mA × 30min → mAh ≈ 250 (±5%)
- [ ] Constant 4.0V × 500mA → avg_power_mw = 2000.0
- [ ] Constant 4.0V × 500mA × 1h → total_power_mwh ≈ 2000 (±5%)
- [ ] 3000 mAh battery / 500mA avg → estimated_playtime_h = 6.0
- [ ] Any charging sample → `has_charging_period = true`

---

### 6.7 Memory Analytics (PSS Subsections)

Track per-subsection trends from Section 5.3 splits.

**6.7.1 Subsection Stats:**
For each subsection field (`memory_java_kb`, `memory_native_kb`, `memory_graphics_kb`, `memory_stack_kb`, `memory_code_kb`, `memory_system_kb`, `memory_webview_kb`):
- `avg_kb`, `peak_kb`, `growth_kb` (= last_value - first_value)

**6.7.2 Memory Trend Detection:**
Linear regression on `memory_pss_kb` vs `timestamp`. If slope > 100 KB/min over a session > 5 min → **flag as "Memory Trending Up"** (Section 6.9).

**6.7.3 Graphics-Heavy Detection:**
If `mean(memory_graphics_kb) / mean(memory_pss_kb) > 0.5` → flag "Graphics-heavy app" (informational, not an issue).

**6.7.4 Output Fields (session_stats additions):**
`mem_java_avg_kb`, `mem_java_peak_kb`, `mem_native_avg_kb`, `mem_native_peak_kb`, `mem_graphics_avg_kb`, `mem_graphics_peak_kb`, `mem_stack_avg_kb`, `mem_code_avg_kb`, `mem_system_avg_kb`, `mem_webview_avg_kb`, `mem_growth_kb`, `mem_trend_slope_kb_per_min`.

---

### 6.8 Network Analytics (Per-Interface)

Per Section 5.5, network bytes split into WiFi / Cellular / Other.

**6.8.1 Per-Interface Totals:**
```
net_wifi_total_tx = last(net_wifi_tx_bytes) - first(net_wifi_tx_bytes)
net_wifi_total_rx = last(net_wifi_rx_bytes) - first(net_wifi_rx_bytes)
... same for cellular, other
```

**6.8.2 Per-Interface Throughput (avg KB/s):**
`(total_bytes / duration_s) / 1024`.

**6.8.3 Cellular-Only Sessions:**
If `wifi_active = false` for ≥ 90% of samples and `net_cellular_total_tx + net_cellular_total_rx > 0` → tag as "cellular session" in scorecard.

**6.8.4 Output Fields (session_stats additions):**
`net_wifi_total_tx_kb`, `net_wifi_total_rx_kb`, `net_cellular_total_tx_kb`, `net_cellular_total_rx_kb`, `net_other_total_tx_kb`, `net_other_total_rx_kb`, `net_wifi_avg_kbps`, `net_cellular_avg_kbps`.

---

### 6.9 Auto-Detected Issues (v2.0)

Post-session pass that scans `session_stats` and `metric_samples` and writes flagged issues to `detected_issues` table. Mirrors GameBench Studio "Detected Issues" dashboard tile.

**Issue rules (each runs after session stop):**

| Rule ID | Trigger | Severity |
|---|---|---|
| `LOW_FPS` | `fps_median < 30` AND target ≥ 60 | high |
| `FPS_REGRESSION` | Compared to baseline session for same app, `fps_median` drops > 15% | high |
| `HIGH_VARIABILITY` | `variability_index > 10` | medium |
| `MEMORY_TRENDING_UP` | Section 6.7.2 slope > 100 KB/min, session ≥ 5min | high |
| `MEMORY_LEAK_SUSPECTED` | Section 6.7.2 slope > 500 KB/min, session ≥ 10min | critical |
| `HIGH_CPU` | `cpu_avg_pct > 80` (post-norm-to-freq) | medium |
| `THERMAL_THROTTLING` | `thermal_peak >= LIGHT` (Section 5.6) | high |
| `LAUNCH_TIME_INCREASE` | `launch_complete_ms` > prior baseline + 20% | medium |
| `BATTERY_DRAIN_HIGH` | `battery_drain_per_hour > 30` (%/h) | medium |
| `BIG_JANK_SPIKE` | `jank_big_total / duration_min > 5` | high |
| `LOW_STABILITY` | `stability_pct < 60` | medium |
| `CELLULAR_HEAVY_USE` | Cellular session and total cellular bytes > 50 MB | informational |

**Schema (`detected_issues`):**
```sql
CREATE TABLE detected_issues (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  rule_id TEXT NOT NULL,
  severity TEXT NOT NULL,           -- informational | medium | high | critical
  metric TEXT,                       -- 'fps_median', 'memory_pss_kb' etc
  observed_value REAL,
  threshold_value REAL,
  message TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX idx_issues_session ON detected_issues(session_id);
CREATE INDEX idx_issues_severity ON detected_issues(severity);
```

**Baseline lookup:**
For regression rules, baseline = mean of last 5 sessions for same `app_id` + `device_id` combo. If < 3 prior sessions exist, skip regression rules.

**UI:**
Session detail "Issues" tab shows table with rule_id, severity (color-coded), message. Tap row → highlight on timeline.

**Acceptance criteria:**
- [ ] Session with `fps_median = 25` → `LOW_FPS` issue inserted
- [ ] 10 sessions, last has `fps_median` 20% below baseline → `FPS_REGRESSION` flagged
- [ ] Empty `metric_samples` → no rules fire (no false positives)

---

### 6.10 Trends Across Sessions (v2.0 — Trends Explorer)

Cross-session aggregation. See Section 22.

---

## 7. Implementation Plan

12 weeks → v1.0: Android + iOS (macOS) external profiling with full analytics, power math, memory subsections, screenshots × 5 sizes, edge cases (§27).

### Week 1–2: App Skeleton + Android Discovery

**Tasks:**
- `flutter create performancebench --platforms=windows,macos,linux`
- `AdbService`: wrap subprocess, expose `Stream<List<Device>>`. Parse `adb devices -l` output.
- Device discovery polling every 2 seconds
- Device list UI: icon, status badge, platform indicator
- App/process picker: `pm list packages -3`, resolve PID via `adb shell pidof <package>`
- SQLite init: `sqflite_common_ffi`, schema v1 migration, all DAOs (see Section 8)
- Navigation structure: DeviceList → AppPicker → ActiveSession → History (GoRouter)
- Riverpod providers for device list and selected device

**Deliverable:** App runs on Windows + macOS. Lists connected Android devices. User can select a target app. No metrics yet.

**Acceptance criteria:**
- [ ] Pixel 8 connected via USB → appears in device list within 3s of connection
- [ ] Disconnect device mid-use → graceful error state, no crash
- [ ] Select app → navigate to ActiveSession screen

---

### Week 3–4: Android Metrics Collection

**Tasks:**
- `MetricCollector`: 1Hz `Timer.periodic`, emits `Stream<MetricSample>`
- Implement all v1.0 parsers per §5:
  - **FPS** (4-tier jank: small/medium/big/frame-ratio Γ=L/R) + raw frametimes JSON (§5.1)
  - **CPU** app + system + per-core states/freqs + freq-normalized + top-8 threads (§5.2)
  - **Memory** PSS + 6 subsections + WebView (§5.3)
  - **Battery** pct + mA + mV + temp + charging source (§5.4)
  - **Network** total + per-interface split (WiFi/Cellular/Other) (§5.5)
  - **Thermal** 0..3 (§5.6)
  - **GPU** % + freq + mem (§5.7)
  - **Static device data** + **static app data** captured at session start (§5.11)
  - **Brightness + volume** capture per sample
- All ADB calls: 3-second timeout; return null on timeout or non-zero exit; session never crashes
- Ring buffer: 300-sample circular per metric; feeds charts
- Layer name discovery for SurfaceFlinger (3-step fallback per §5.1)
- GPU: try all known sysfs paths; null on all failures (never fabricate)
- PID monitoring: if app closes mid-session, null out per-app metrics; continue system metrics
- WiFi state sample (`dumpsys wifi`)

**Deliverable:** All v1.0 Android metrics stream as `MetricSample` objects. Logged to debug console.

**Acceptance criteria:**
- [ ] 30-second session on Pixel 8 → ≥ 28 non-null fps samples
- [ ] ADB disconnect mid-session → all metrics go null; session continues with null samples; no crash
- [ ] Parser unit tests pass 100% (see §14)
- [ ] All §5 acceptance criteria checks pass for each parser

---

### Week 5–6: Charts + Session Storage + Analytics

**Tasks:**
- `fl_chart` line charts: one per metric, 60-second auto-scroll window, reading from ring buffer
- Session start/stop: UUID generation, `sessions` row insert/update
- 10s minimum session enforcement (per §4.1)
- SQLite batch writer: flush ring buffer to `metric_samples` every 5 seconds
- Screenshot capture: `adb exec-out screencap -p` → 5-size pipeline (SS0/SS1/SS2/SS3/SS4 per §5.12) → save JPEGs; insert `screenshots` rows
- Screenshot thumbnail strip in session view (size selector)
- Manual marker: label prompt → `markers` row insert; "Mark Launch Complete" button → special marker
- Marker groups (named sets) — `marker_groups` table writes
- Session title / notes / tags (k=v) UI
- Production vs Non-Production mode toggle (§21)
- Strict testing mode pre-flight + restoration (§20)
- `AnalyticsService.computeMarkerStats()` triggered on session stop
- `FpsAnalytics` class: median, min, max, 1% Low, p95 frame time, stability %, histogram, **Variability Index**, frame-ratio jank total (§6.1)
- `PowerAnalytics` class: mAh consumed (∫|mA| dt) + avg mW + total mWh + estimated playtime (§6.6)
- `MemoryAnalytics`: subsection avg/peak/growth + trend slope (§6.7)
- `NetworkAnalytics`: per-interface totals + avg kbps (§6.8)
- `session_stats` + `marker_stats` rows written after each session
- Active session UI: 2-column chart grid (per §9.5), REC indicator, elapsed time, marker timeline

**Deliverable:** Full Android session: live charts, screenshots ×5 sizes, markers, marker groups, full analytics saved.

**Acceptance criteria:**
- [ ] Session stops → `session_stats` row exists within 2 seconds
- [ ] Marker spanning 30s → `marker_stats` row with correct fps_median + variability_index
- [ ] Power analytics produced: mAh ≈ ∫|mA| dt within ±5%
- [ ] Memory subsection sums approximately equal `memory_pss_kb` ±10%
- [ ] Export JSON contains all metric_samples + markers + session_stats
- [ ] Screenshot taken every 10s → appears in thumbnail strip with all 5 sizes
- [ ] 9-second session refused at session-stop with clear UI error
- [ ] Strict mode pre-flight rejects sessions with battery < 70% or > 98%

---

### Week 7–8: iOS Support + History + Comparison

**Tasks:**
- pyidevice environment check at startup: if not installed, show one-time install guide; do not block Android
- `IosService`: launch `collector.py` subprocess, parse stdout JSON stream, map to MetricSample
- iOS device discovery (`python3 ios_agents/device_list.py`), app list
- Same ring buffer → chart → SQLite → analytics pipeline for iOS samples
- Session history screen: sortable by date / device / app / duration / fps_median
- Session detail: replay charts from SQLite + scorecard + markers table + FPS histogram + launch time
- Session comparison: two sessions side-by-side, synced time axis, delta table with regression coloring
- `MarkerStatsTable` widget: marker name + FPS med + 1% Low + CPU avg + jank/min

**Deliverable:** iOS profiling on macOS. History + comparison + full analytics working end-to-end.

**Acceptance criteria:**
- [ ] iPhone 15 connected on macOS → appears in device list
- [ ] 60s iOS session → fps, cpu, mem, battery_pct all have non-null values
- [ ] Session comparison: Session A vs B → delta table shows regression in red
- [ ] Launch Complete marker → "Time to Launch: Xs" shown in scorecard

---

### Week 9–10: Export + Polish + Installer

**Tasks:**
- Export JSON: full `metric_samples` + session + markers + analytics summary. One file per session.
- Export CSV: one row per second; columns for every metric + active marker label
- Error handling: ADB not found, device disconnect mid-session, pyidevice missing
- Settings panel: all fields from Section 9.5
- App icon, about screen, version display
- Windows installer (flutter_distributor + NSIS)
- macOS DMG (flutter_distributor)
- Smoke test: real Android + real iPhone on macOS, verify all v1.0 metrics + export files
- README: quick start in ≤ 5 steps

### Week 11: Edge Cases + Hardening

**Tasks (per §27):**
- ANR detection (logcat `am_anr` watch)
- Crash detection Android + iOS (logcat `am_crash`, pyidevice `crash_logs`)
- Cold/warm/hot launch classification
- Foreground / background time tracking
- USB unplug recovery (60s grace period)
- ADB daemon auto-recovery
- pyidevice subprocess recycling at 30 min
- SQLite WAL + 5 min checkpoint
- Disk-full guard (100 MB threshold)
- Variable refresh rate per-sample (ProMotion / 144Hz)
- Render thread CPU split (Android HWUI)
- Multi-process aggregation
- OEM quirks loader (§35) — `oem_quirks.json`

**Acceptance:**
- [ ] All §27 acceptance tests pass
- [ ] OEM quirks load on Xiaomi / Samsung / Pixel; defaults applied on unknown brand

### Week 12: Polish + Installer + Distribution

**Tasks:**
- Onboarding flow (§38)
- Bundled demo session
- Privacy redaction defaults (§31.5)
- Auto-update check button — pull-only (§39)
- Windows installer (flutter_distributor + NSIS), unsigned fallback documented
- macOS DMG with Apple Developer ID notarization (when secret present)
- Linux AppImage build
- CI matrix: Win + Mac + Linux green builds
- README quick-start ≤ 5 commands
- `LICENSE`, `PRIVACY.md`, `RISKS.md`, `COMPLIANCE.md` at repo root

**Deliverable:** v1.0 — shippable, installable, documented.

**Acceptance criteria:**
- [ ] Exported JSON parses without error; contains `session`, `metric_samples`, `markers`, `session_stats`
- [ ] Exported CSV has header row; columns match field count on all data rows
- [ ] Windows installer runs on clean Windows 11 VM, app launches without errors
- [ ] macOS DMG runs on macOS 14, iOS + Android profiling both work
- [ ] Linux AppImage runs on Ubuntu 22.04, Android profiling works
- [ ] Onboarding completes ≤ 60s; demo session loadable
- [ ] First app launch makes zero network calls (verified via tcpdump)

---

## 8. Database Schema

> **Hard Contract:** The agentic coder MUST implement exactly this schema. Column names, types, and constraints are not flexible. Deviating will break the analytics and export layers. Migrations must be additive (ALTER TABLE ADD COLUMN, CREATE TABLE IF NOT EXISTS — never DROP TABLE without a migration script).

See **Appendix C** for the full SQL DDL.

### Schema Summary

| Table | Purpose | Min version |
|---|---|---|
| `schema_version` | Migration tracking | v1.0 |
| `devices` | Device snapshot at session time (denormalized intentionally) | v1.0 |
| `sessions` | One row per profiling session | v1.0 |
| `metric_samples` | One row per second per session (core data store) | v1.0 |
| `markers` | User-created and launch_complete markers | v1.0 |
| `marker_groups` | Named groups for related markers | v1.0 |
| `marker_stats` | Analytics summary per marker range (computed post-session) | v1.0 |
| `session_stats` | Analytics summary for full session (computed post-session) | v1.0 |
| `session_tags` | Key=value tags (k:v) per session | v1.0 |
| `screenshots` | Filepath index for screenshot images (5 sizes SS0-SS4) | v1.0 |
| `static_device_data` | Full hardware/OS snapshot per session (Section 5.11) | v1.0 |
| `static_app_data` | App version, install info, permissions snapshot per session | v1.0 |
| `collections` | Named groups of sessions | v1.5 |
| `regions` | Drag-selected post-hoc time ranges | v1.5 |
| `detected_issues` | Auto-detected issues from analytics (Section 6.9) | v1.5 (algo + storage) |
| `videos` | Synced screen recordings (Section 32) | v1.5 (Android) / v2.5 (iOS) / v3.0 (PC) |
| `crashes` | App crash records during session (Section 27.2) | v1.0 |
| `lenses` | Saved filters/views (Section 22) | v2.0 |
| `alerts` | Threshold-based alert rules (Section 23) | v2.0 |
| `notification_channels` | Email/Slack/Webhook destinations (Section 23) | v2.0 |
| `api_tokens` | Tokens for REST API access (Section 24) | v2.0 |
| `alert_events` | Alert firing audit log (Section 23) | v2.0 |
| `reports` | Generated PDF/HTML analysis reports (Section 22.5) | v2.0 |
| `audit_log` | Sensitive-action audit trail (Section 24.5) | v2.0 |
| `team_users` | Multi-user team server accounts (Section 24) | v2.0 |
| `team_orgs` | Org/workspace hierarchy | v2.0 |
| `team_projects` | Project-level grouping under org | v2.0 |

### Key `metric_samples` Columns

| Column | Type | Notes |
|---|---|---|
| `fps` | REAL | Nullable |
| `jank_count` | INTEGER | Time-threshold jank (medium tier, 16.6–33.3ms typical) |
| `jank_small_count` | INTEGER | Small jank (any frame > refresh period) |
| `jank_big_count` | INTEGER | Big jank (≥125ms or >2× rolling avg) |
| `jank_ratio_count` | INTEGER | Frame-ratio jank Γ=L/R model (Section 5.1) |
| `frametimes_json` | TEXT | JSON array of raw frame intervals (ms) for this 1s window |
| `cpu_system_pct` | REAL | Nullable |
| `cpu_app_pct` | REAL | Nullable (raw, normalized to max freq baseline) |
| `cpu_app_pct_freq_norm` | REAL | Nullable; CPU normalized to current freq (Section 5.2.1) |
| `cpu_cores` | TEXT | JSON array of per-core % (v1.0) |
| `cpu_core_states_json` | TEXT | JSON `[{"id":0,"online":true,"freq_khz":1804800}, ...]` |
| `cpu_core_freqs_json` | TEXT | JSON array of cur freq per core (KHz) |
| `cpu_threads_top_json` | TEXT | JSON top-8 thread CPU% (Section 5.2.2) |
| `memory_pss_kb` | INTEGER | Nullable; total PSS |
| `memory_java_kb` | INTEGER | PSS subsection: Java heap |
| `memory_native_kb` | INTEGER | PSS subsection: Native heap |
| `memory_graphics_kb` | INTEGER | PSS subsection: EGL+GL mtrack |
| `memory_stack_kb` | INTEGER | PSS subsection: Stack |
| `memory_code_kb` | INTEGER | PSS subsection: mmap files (.so / .dex / .apk) |
| `memory_system_kb` | INTEGER | PSS subsection: System (Other dev / Cursor / .ttf) |
| `memory_webview_kb` | INTEGER | WebView/Chromium proc PSS (Section 5.3.1) |
| `battery_pct` | INTEGER | Nullable |
| `battery_ma` | REAL | Nullable (hardware-dependent) |
| `battery_mv` | REAL | Nullable (hardware-dependent) |
| `battery_temp_c` | REAL | Nullable (hardware-dependent) |
| `charging` | INTEGER | 0/1 — true if charging at sample time |
| `charging_source` | TEXT | NULL / 'AC' / 'USB' / 'WIRELESS' / 'DOCK' |
| `wifi_active` | INTEGER | 0/1 — `dumpsys wifi` state at sample time |
| `net_tx_bytes` | INTEGER | Cumulative total (all interfaces); legacy field |
| `net_rx_bytes` | INTEGER | Cumulative total (all interfaces); legacy field |
| `net_wifi_tx_bytes` | INTEGER | Cumulative WiFi (wlan*/wifi*) |
| `net_wifi_rx_bytes` | INTEGER | Cumulative WiFi |
| `net_cellular_tx_bytes` | INTEGER | Cumulative cellular (rmnet*/ccmni*/pdp*/ppp*) |
| `net_cellular_rx_bytes` | INTEGER | Cumulative cellular |
| `net_other_tx_bytes` | INTEGER | Cumulative other (eth*/usb*) |
| `net_other_rx_bytes` | INTEGER | Cumulative other |
| `thermal_status` | INTEGER | 0–3; nullable |
| `gpu_pct` | REAL | Nullable (device-dependent) |
| `gpu_freq_mhz` | REAL | Nullable (Adreno gpubusy / Mali pp) |
| `gpu_mem_kb` | INTEGER | Nullable |
| `disk_read_kb` | REAL | Delta KB/s; NULL in v1.0; active in v1.5 |
| `disk_write_kb` | REAL | Delta KB/s; NULL in v1.0; active in v1.5 |
| `screen_brightness` | INTEGER | 0–255; from `settings get system screen_brightness` |
| `volume_pct` | INTEGER | Media stream volume %, 0–100 |

### Key `session_stats` Columns

**FPS:** `fps_median`, `fps_min`, `fps_max`, `fps_1pct_low`, `fps_stability`, `frame_time_p95`, `fps_histogram` (JSON TEXT), `variability_index`, `frame_ratio_jank_total`

**CPU:** `cpu_avg_pct`, `cpu_peak_pct`, `cpu_avg_pct_freq_norm`, `cpu_peak_pct_freq_norm`

**Memory:** `memory_avg_kb`, `memory_peak_kb`, `mem_java_avg_kb`, `mem_java_peak_kb`, `mem_native_avg_kb`, `mem_native_peak_kb`, `mem_graphics_avg_kb`, `mem_graphics_peak_kb`, `mem_stack_avg_kb`, `mem_code_avg_kb`, `mem_system_avg_kb`, `mem_webview_avg_kb`, `mem_growth_kb`, `mem_trend_slope_kb_per_min`

**GPU:** `gpu_avg_pct`, `gpu_peak_pct`

**Battery / Power (Section 6.6):** `battery_drain_pct`, `battery_drain_per_hour`, `battery_temp_max_c`, `mah_consumed`, `avg_power_mw`, `total_power_mwh`, `estimated_playtime_h`, `has_charging_period`

**Jank:** `jank_total`, `jank_small_total`, `jank_big_total`, `jank_ratio_total`, `jank_per_min`

**Network:** `net_total_tx_kb`, `net_total_rx_kb`, `net_wifi_total_tx_kb`, `net_wifi_total_rx_kb`, `net_cellular_total_tx_kb`, `net_cellular_total_rx_kb`, `net_other_total_tx_kb`, `net_other_total_rx_kb`, `net_wifi_avg_kbps`, `net_cellular_avg_kbps`

**Thermal:** `thermal_peak`

**Timing:** `launch_complete_ms` (NULL if no launch_complete marker), `duration_ms`

### Key `marker_stats` Columns

Includes: `fps_median`, `fps_min`, `fps_max`, `fps_1pct_low`, `fps_stability`, `frame_time_p95`, `variability_index`, `cpu_avg_pct`, `cpu_avg_pct_freq_norm`, `mem_peak_kb`, `mem_graphics_peak_kb`, `gpu_avg_pct`, `battery_drain_pct`, `mah_consumed`, `jank_total`, `jank_small_total`, `jank_big_total`, `jank_ratio_total`, `jank_per_min`, `duration_ms`

### `sessions` Table — New Columns

| Column | Type | Notes |
|---|---|---|
| `title` | TEXT | User-set session title (default = app + timestamp) |
| `notes` | TEXT | Free-form notes shown on Session Detail |
| `tags_kv_json` | TEXT | JSON object of k=v tags `{"build":"42","level":"boss"}` |
| `target_fps` | INTEGER | 30/60/90/120/144 — used by analytics for "target met" % |
| `production_mode` | INTEGER | 0/1 — Section 21 (1 = histogram-only, no per-second samples) |
| `strict_mode` | INTEGER | 0/1 — Section 20 (brightness/volume/battery locked) |
| `injected` | INTEGER | 0/1 — true if app was injected via PB SDK (Section 18) |
| `app_version_code` | INTEGER | Captured at session start |
| `app_version_name` | TEXT | Captured at session start |
| `target_kind` | TEXT | 'android' / 'ios' / 'tvos' / 'windows_pc' (v3.0) |

### `devices` Table — New Columns

| Column | Type | Notes |
|---|---|---|
| `chipset` | TEXT | e.g. 'snapdragon_8_gen_2', 'apple_a16' |
| `chipset_vendor` | TEXT | 'qualcomm' / 'mediatek' / 'samsung' / 'apple' / 'unisoc' |
| `gpu_vendor` | TEXT | 'adreno' / 'mali' / 'powervr' / 'apple' |
| `gpu_model` | TEXT | e.g. 'Adreno 740', 'Apple A16 GPU' |
| `cpu_cores_count` | INTEGER | Total core count |
| `cpu_max_freq_khz` | INTEGER | Max freq from `cpufreq/cpuinfo_max_freq` |
| `screen_resolution` | TEXT | e.g. '2400x1080' |
| `screen_density_dpi` | INTEGER | |
| `refresh_rate_hz` | INTEGER | Native display refresh |
| `battery_capacity_mah` | INTEGER | For Section 6.6.5 playtime estimate |
| `total_ram_kb` | INTEGER | From `/proc/meminfo` |
| `internal_storage_gb` | INTEGER | |
| `os_version` | TEXT | e.g. 'Android 14', 'iOS 17.4' |
| `os_api_level` | INTEGER | Android SDK level |
| `kernel_version` | TEXT | `uname -r` |
| `is_rooted` | INTEGER | Detected via `which su` |
| `is_emulator` | INTEGER | Detected via `getprop ro.kernel.qemu` |

### `screenshots` Table — New Columns

| Column | Type | Notes |
|---|---|---|
| `size_id` | TEXT | 'SS0' / 'SS1' / 'SS2' / 'SS3' / 'SS4' (Section 5.12) |
| `width_px` | INTEGER | Final pixel width |
| `height_px` | INTEGER | Final pixel height |
| `file_size_bytes` | INTEGER | Compressed JPEG size |
| `marker_id` | INTEGER | Optional FK to markers (auto-screenshot on marker creation) |

---

## 9. UI/UX Specification

> **Design target:** VS Code aesthetic — dark, information-dense, professional. Not a mobile app scaled up. Not a website. A tool that developers and QA engineers feel at home in immediately. Every pixel earns its place.

---

### 9.1 Design System

#### 9.1.1 Color Palette

The primary theme is **Dark+** (matching VS Code's default dark theme). Light theme mirrors these values with appropriate inversions.

**Background layers (darkest to lightest):**

| Token | Hex | Usage |
|---|---|---|
| `bg.base` | `#1E1E1E` | Main editor area, chart panels |
| `bg.sidebar` | `#252526` | Left sidebar, panel backgrounds |
| `bg.elevated` | `#2D2D30` | Tab bar, dropdown menus, modals |
| `bg.hover` | `#2A2D2E` | List item hover state |
| `bg.selected` | `#094771` | Selected list item (VS Code blue tint) |
| `bg.input` | `#3C3C3C` | Text inputs, search fields |

**Text:**

| Token | Hex | Usage |
|---|---|---|
| `text.primary` | `#D4D4D4` | Main text, labels |
| `text.secondary` | `#858585` | Descriptions, timestamps, units |
| `text.disabled` | `#5A5A5A` | Inactive controls |
| `text.accent` | `#4FC3F7` | Links, highlighted values |
| `text.monospace` | same as primary | Metric values (monospace font) |

**Borders:**

| Token | Hex | Usage |
|---|---|---|
| `border.subtle` | `#3C3C3C` | Card edges, panel dividers |
| `border.focus` | `#007ACC` | Focused inputs |

**Accent & State Colors:**

| Token | Hex | Usage |
|---|---|---|
| `accent.blue` | `#007ACC` | Primary action buttons, active tab indicator |
| `accent.recording` | `#F44747` | REC indicator dot, stop button border |
| `accent.success` | `#4EC9B0` | Connected device, pass state |
| `accent.warning` | `#CE9178` | Fair thermal, warning state |
| `accent.danger` | `#F44747` | Serious/critical thermal, regression delta |
| `accent.gold` | `#DCDCAA` | Launch Complete marker, special events |

**Per-Metric Chart Colors (consistent across all screens):**

| Metric | Line Color | Fill Gradient Start | Usage |
|---|---|---|---|
| FPS | `#569CD6` | `#569CD620` | All FPS charts |
| CPU (App) | `#4EC9B0` | `#4EC9B020` | Per-app CPU |
| CPU (System) | `#4EC9B060` | `#4EC9B010` | System CPU (dimmer) |
| Memory | `#CE9178` | `#CE917820` | PSS memory |
| Battery % | `#DCDCAA` | `#DCDCAA20` | Battery level |
| Battery mA | `#C586C0` | `#C586C020` | Current draw |
| Battery mV | `#9CDCFE` | `#9CDCFE20` | Voltage |
| Battery Temp | `#F44747` | `#F4474720` | Temperature |
| Network TX | `#4FC1FF` | `#4FC1FF20` | Upload bytes |
| Network RX | `#85C1E9` | `#85C1E920` | Download bytes |
| GPU | `#C586C0` | `#C586C020` | GPU utilization |
| Thermal | Dynamic | — | Green→Orange→Red by status level |

> **Thermal color mapping:** status 0 → `#4EC9B0`, status 1 → `#CE9178`, status 2 → `#F44747`, status 3 → `#FF0000`

#### 9.1.2 Typography

**Font stack (resolved at runtime by platform):**

| Role | Windows | macOS | Linux | Fallback |
|---|---|---|---|---|
| UI text | Segoe UI | SF Pro Display | Inter | system-ui |
| Metric values | Cascadia Code | SF Mono | JetBrains Mono | monospace |
| Chart labels | Segoe UI | SF Pro Text | Inter | system-ui |

**Size scale:**

| Token | Size | Usage |
|---|---|---|
| `text.xs` | 10px | Status bar text, chart axis labels |
| `text.sm` | 11px | Sidebar items, secondary info |
| `text.base` | 13px | Main UI text, list items |
| `text.md` | 14px | Section headings, tab labels |
| `text.lg` | 20px | Metric value display (current reading) |
| `text.xl` | 28px | Hero metric (FPS readout, large scorecard) |
| `text.mono.value` | 16px monospace | Real-time metric numbers |
| `text.mono.sm` | 12px monospace | Stat pills (Med: 58 \| 1%: 22) |

#### 9.1.3 Spacing & Geometry

- Base unit: **4px**
- Chart card padding: `12px`
- Sidebar item height: `32px`
- Tab bar height: `35px`
- Status bar height: `22px`
- Title bar height (custom): `30px` (Windows) / `28px` (macOS with traffic lights)
- Card border radius: `4px` (VS Code uses nearly-sharp corners)
- Input border radius: `2px`
- Chart grid line spacing: equal vertical divisions; 5–6 horizontal gridlines per chart

#### 9.1.4 Elevation & Shadows

No drop shadows (VS Code doesn't use them). Elevation communicated through background color only:
- Modals: `bg.elevated` over a `#00000066` overlay
- Tooltips: `bg.elevated` with `border.subtle` outline
- Dropdowns: `bg.elevated` with 1px `border.subtle` border

---

### 9.2 Application Shell Layout

The app uses a VS Code-style three-region shell. This shell is **persistent across all screens**.

```
┌─────────────────────────────────────────────────────────────────────┐
│ TITLE BAR (custom, 30px)                          PerformanceBench  │
│ [─] [□] [×]     File  View  Help                   v1.0.0  ●  Win  │
├──┬──────────────────────────────────────────────────────────────────┤
│  │ SIDEBAR (280px fixed, collapsible)                               │
│  │ ┌────────────────────────────────────────────────────────────┐   │
│A │ │ EXPLORER                                          [⊕] [⋮]  │   │
│C │ ├────────────────────────────────────────────────────────────┤   │
│T │ │ ▼ DEVICES                                                  │   │
│I │ │   ● Pixel 8 Pro (Android 14)           [▶ Start]           │   │
│V │ │     └─ com.example.game                                     │   │
│I │ │   ○ iPhone 15 (iOS 17)                 [▶ Start]           │   │
│T │ │     └─ (tap to select app)                                 │   │
│Y │ ├────────────────────────────────────────────────────────────┤   │
│  │ │ ▼ RECENT SESSIONS                                          │   │
│B │ │   com.example.game                                         │   │
│A │ │   Pixel 8 Pro · 4m 21s · FPS 58                           │   │
│R │ │   2h ago                                                   │   │
│  │ │   com.anothergame.app                                      │   │
│  │ │   iPhone 15 · 2m 14s · FPS 60                             │   │
│  │ │   Yesterday                                                │   │
│  │ └────────────────────────────────────────────────────────────┘   │
│  │ MAIN CONTENT AREA (fills remaining width)                        │
│  │ ┌────────────────────────────────────────────────────────────┐   │
│  │ │ TAB BAR                                                    │   │
│  │ │ [● RECORDING: com.example.game] [Session · 2024-01-15] [+]│   │
│  │ ├────────────────────────────────────────────────────────────┤   │
│  │ │                                                            │   │
│  │ │   (active tab content — chart grid, session detail, etc)   │   │
│  │ │                                                            │   │
│  │ └────────────────────────────────────────────────────────────┘   │
├──┴──────────────────────────────────────────────────────────────────┤
│ STATUS BAR (22px)  ● REC 00:04:21  Pixel 8 Pro  |  1 Hz  |  SQLite ✓│
└─────────────────────────────────────────────────────────────────────┘
```

**Activity bar (leftmost strip, 48px wide):**
- Icon-only vertical strip, VS Code style
- Icons: Devices (server icon), History (clock), Compare (diff icon), Settings (gear)
- Active icon: highlighted with `accent.blue` left border
- Hovering: tooltip with section name

**Sidebar (280px, collapsible with Ctrl+B / ⌘+B):**
- When collapsed: main content fills full width
- Sections use VS Code-style collapsible tree headers
- Device items: platform icon + device name + connection status dot
- Session items: app name, device, duration, median FPS, relative timestamp

**Tab bar:**
- Active recording tab: red dot prefix + app name
- Closed session tabs: session date/time label
- Max visible tabs before scroll: dynamic based on window width
- Close button appears on hover (×)

**Status bar:**
- Background: `bg.elevated` normally; `accent.recording` (red) while recording
- Left: recording indicator + elapsed time OR "Ready"
- Center: active device + sample rate
- Right: SQLite write status (✓ = healthy, last flush time)

---

### 9.3 Custom Title Bar

Use `window_manager` package to remove native title bar on both Windows and macOS. Implement a custom 30px title bar widget.

**Windows:**
- Traffic light buttons (minimize/maximize/close) on LEFT (no, right — Windows convention)
- App name centered
- Menu bar items inline: File · View · Help (open as dropdowns)
- Draggable area: full title bar except buttons and menu items

**macOS:**
- Native traffic lights (red/yellow/green) preserved — use `window_manager` to keep them but customize the rest
- Traffic lights left side (macOS convention)
- App name centered
- No menu bar inline (macOS uses system menu bar)
- Title bar height 28px to match macOS compact style

**Both platforms:**
- Title bar background: `bg.sidebar` (slightly different from main content area)
- Text: `text.secondary` at 12px

---

### 9.4 Real-Time Chart Cards

Each metric is a **MetricCard** widget. MetricCard is the core visual unit of the app.

#### MetricCard Anatomy

```
┌─────────────────────────────────────────────────────┐  ← bg.sidebar border
│ FPS                                          58.3   │  ← label (sm) + current value (mono.value)
│                                                     │
│  ████████████████████████████████████████████████  │
│ 120╴                                               │  ← chart area (fl_chart LineChart)
│  90╴  ·················60fps target·············  │  ← dashed guideline at 60fps
│  60╴ ╭──────────────────────────────────────────╮  │
│  30╴ │▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│  │  ← gradient fill
│   0╴─┴──────────────────────────────────── 60s →  │
│                                                     │
│  Med 58.3 · 1% 24.1 · Stab 81% · Min 22 · Max 63  │  ← stat pills (mono.sm)
└─────────────────────────────────────────────────────┘
```

**Spec:**
- Card background: `bg.sidebar`
- Chart area background: `bg.base` (slightly darker inset)
- Label: `text.secondary`, 11px, uppercase letter-spacing 0.8
- Current value: monospace, 16px, `text.primary`; updates at 1Hz (no animation on value change — just sets)
- Chart line: 2px solid, metric color, smooth curve (`isCurved: true, curveSmoothness: 0.3`)
- Fill gradient: metric color at 20% opacity → transparent (vertical gradient, top to bottom)
- Grid lines: horizontal only, `border.subtle` at 30% opacity, no vertical gridlines
- X-axis: last 60 seconds; auto-scrolls; labels every 15s ("–60s", "–45s", "–30s", "–15s", "now")
- Y-axis: auto-range with 10% padding top; clamp at 0 minimum; labels on left side
- 60fps guideline: dashed horizontal line at y=60, color `border.subtle` at 60% opacity (FPS chart only)
- Null gaps: line breaks where metric is null (device disconnect) — no zero fill, visible gap
- Data points: hidden by default; appear as 4px circle on hover/touch
- Tooltip on hover: VS Code dark popup showing timestamp + exact value + unit

**Stat pills row (below chart):**
- Background: none (text only, `bg.base`)
- Format: `Med 58.3 · 1% 24.1 · Stab 81% · Min 22 · Max 63`
- Font: `text.mono.sm` (12px monospace)
- Color: `text.secondary`
- Live update at 1Hz
- For CPU: `Avg 23.4% · Peak 87.2%`
- For Memory: `Avg 512MB · Peak 681MB`
- For Battery: `mA –328 · V 3.89 · °C 31.2`
- For Network: `↑ 1.1 KB/s · ↓ 8.3 KB/s`
- For Thermal: status text + colored dot

**Jank indicator (FPS card only — below stat pills):**
```
  ◎ Small 89/min   ◉ Jank 14/min   ⬤ Big 2/min
```
- `◎` grey for small, `◉` orange for jank, `⬤` red for big jank
- Update at 1Hz from accumulated jank counts in current window

**On click / double-click:** Expand to full-screen overlay showing only that metric. Same chart, larger, with full zoom + pan enabled.

---

### 9.5 Active Session Screen — Chart Grid

**2-column grid layout (default):**

```
┌─────────────────────────────────────────────────────────────────────────┐
│  ● REC  00:04:21   com.example.game on Pixel 8 Pro [Adreno 750]         │
│  [■ Stop Recording]  [◆ Add Marker ⌘M]  [🚀 Launch Complete ⌘L]  [📷 ⌘S]│
│─────────────────────────────────────────────────────────────────────────│
│  MARKER TIMELINE                                                         │
│  ├────────────── ⬇launch_complete ──────────── ◆ Level 1 ──────────────  │
│─────────────────────────────────────────────────────────────────────────│
│                                                                          │
│  ┌──────────────────────────┐  ┌──────────────────────────┐             │
│  │  FPS              58.3  │  │  CPU (App)        23.4%  │             │
│  │  [chart]                │  │  [chart]                  │             │
│  │  Med 58 · 1% 24 · St 81%│  │  Avg 23.4% · Peak 87.2%  │             │
│  │  ◎89/m  ◉14/m  ⬤2/m    │  │                           │             │
│  └──────────────────────────┘  └──────────────────────────┘             │
│                                                                          │
│  ┌──────────────────────────┐  ┌──────────────────────────┐             │
│  │  Memory           512MB │  │  Battery           87%   │             │
│  │  [chart]                │  │  [chart]                  │             │
│  │  Avg 512 · Peak 681MB   │  │  mA –328 · V 3.89 · 31°C │             │
│  └──────────────────────────┘  └──────────────────────────┘             │
│                                                                          │
│  ┌──────────────────────────┐  ┌──────────────────────────┐             │
│  │  Network            ↑↓  │  │  GPU              41%    │             │
│  │  [chart]                │  │  [chart]                  │             │
│  │  ↑1.1 KB/s · ↓8.3 KB/s  │  │  Avg 41% · Peak 87%       │             │
│  └──────────────────────────┘  └──────────────────────────┘             │
│                                                                          │
│  ┌──────────────────────────┐                                            │
│  │  Thermal         Normal │                                            │
│  │  ████████░░░░░░░░░░░░░  │  (color bar: green→orange→red)             │
│  └──────────────────────────┘                                            │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

**Behavior:**
- REC indicator: pulsing red dot (`accent.recording`), 1-second CSS-equivalent animation (Flutter AnimationController)
- Elapsed timer: counts up from 00:00:00 in monospace
- Toolbar row: blends into tab bar area, same `bg.elevated` background
- "Launch Complete" button: gold color (`accent.gold`), rocket icon; disabled + dimmed after first use
- Marker timeline strip: thin 24px horizontal strip between toolbar and charts. Shows marker start events as vertical colored lines with label on hover. Launch complete shown as rocket icon (gold). Color-coded per marker (cycle through 6 distinct colors).
- Grid auto-adapts: 1 column if window width < 900px; 2 columns 900–1400px; 3 columns > 1400px
- GPU card: hidden entirely if `gpu_pct = null` throughout session (not shown as "N/A" — just absent)
- Thermal card: shows color bar instead of line chart (categorical data, not continuous)

**Marker add flow:**
- Ctrl+Shift+M / ⌘+M → inline label input appears in toolbar area (VS Code command-palette style input)
- User types label + Enter → marker created; Escape → cancelled
- Input appears instantly, no modal dialog

---

### 9.6 Session History Screen

```
┌─────────────────────────────────────────────────────────────────────────┐
│  SESSION HISTORY                                                         │
│  [🔍 Filter sessions...]  [Platform ▾] [Device ▾] [App ▾] [Date ▾]      │
│  Sort: [Date ▾]                                          234 sessions   │
│─────────────────────────────────────────────────────────────────────────│
│  DATE          APP                DEVICE          DURATION  FPS  TAG    │
│─────────────────────────────────────────────────────────────────────────│
│  Today 14:32   com.example.game   Pixel 8 Pro      4m 21s  58.3  rel   │
│  Today 11:08   com.example.game   iPhone 15         2m 14s  60.0       │
│  Yesterday     com.anothergame    Pixel 8 Pro      12m 01s  29.8  🐛   │
│─────────────────────────────────────────────────────────────────────────│
│  (hover row → preview card appears with scorecard snapshot)             │
└─────────────────────────────────────────────────────────────────────────┘
```

**Spec:**
- Table style: VS Code file explorer list — no heavy borders, alternating background very subtle (`bg.hover` at 50% every other row)
- Row hover: `bg.hover` background
- Row click: opens Session Detail in new tab
- Platform column: Android robot icon or Apple logo (colored)
- FPS value: colored by quality: ≥55 → `accent.success`, 30–54 → `accent.warning`, <30 → `accent.danger`
- Tag badges: small rounded pill, `bg.input` background, `text.secondary` text
- Filter bar: inline chips that appear when filter active; dismissible with ×
- Sort column headers: clickable, show sort direction arrow
- Hover preview: tooltip-style card (300px wide) showing FPS sparkline + key stats

---

### 9.7 Session Detail Screen

Tab-based detail view. Opens in a new editor tab.

**Tab strip inside session detail:**
```
[Scorecard] [Charts] [FPS Analysis] [Markers] [Screenshots]
```

Same VS Code tab aesthetic — active tab has bottom blue border line.

#### 9.7.1 Scorecard Tab

Two-column stat grid on `bg.base`:

```
┌──────────────────────────────────────────────────────────────────┐
│  com.example.game  ·  Pixel 8 Pro (Adreno 750)  ·  4m 21s       │
│  2024-01-15 14:32  ·  Android 14  ·  Tags: release               │
│  🚀 Launch Time: 4.2s                                             │
├─────────────────────────────┬────────────────────────────────────┤
│  FPS                        │  JANK                              │
│  Median      58.3           │  Small     2,341  /min  89         │
│  Min         22.0           │  Standard    847  /min  14.2       │
│  Max         63.1           │  Big          23  /min   0.4       │
│  1% Low      24.1           │                                    │
│  95th Pct    28.4 ms        │  CPU (App)                         │
│  Stability   81%            │  Average     23.4 %                │
├─────────────────────────────┤  Peak        87.2 %                │
│  MEMORY                     │                                    │
│  Average    512 MB          │  GPU                               │
│  Peak       681 MB          │  Average     41 %                  │
├─────────────────────────────┤  Peak        87 %                  │
│  BATTERY                    │  Vendor      Adreno 750            │
│  Drain      7.9 %/hr        ├────────────────────────────────────┤
│  Avg mA     –328 mA         │  NETWORK                           │
│  Avg mV     3.89 V          │  TX Total    3.2 MB                │
│  Temp Peak  35.1 °C         │  RX Total    11.1 MB               │
├─────────────────────────────┤  TX Avg      1.1 KB/s              │
│  THERMAL                    │  RX Avg      8.3 KB/s              │
│  Peak       Fair (1)        ├────────────────────────────────────┤
│  Normal     94% of session  │  [Export JSON]   [Export CSV]      │
└─────────────────────────────┴────────────────────────────────────┘
```

- All stat labels: `text.secondary` 12px
- All values: `text.primary` 14px monospace
- Section headers: `text.secondary` uppercase 10px letter-spacing 1.2
- Export buttons: VS Code secondary button style — no fill, `border.subtle` outline, `text.primary` label

#### 9.7.2 Charts Tab (Replay)

Identical layout to active session chart grid but static — data loaded from SQLite. All charts display full session, not rolling 60s. Pan/zoom enabled on all charts. Marker events overlaid as vertical lines on all charts simultaneously (clicking a marker line highlights that timespan across all charts).

#### 9.7.3 FPS Analysis Tab

```
┌──────────────────────────────────────────────────────────────────┐
│  PERCENTILE STATS                  FPS STABILITY HISTOGRAM       │
│                                                                  │
│  Median          58.3              60% │          █             │
│  Min             22.0              40% │          █   █         │
│  Max             63.1              20% │ █        █   █         │
│  1% Low          24.1               0% │─┬──┬──┬──┬───┬──→ FPS  │
│  95th Pct        28.4 ms              0  10 20 30  60 90 120    │
│  Stability       81%                                             │
│  Total Janks     847                                             │
│  Small Janks     2,341                                           │
│  Big Janks       23                                              │
│  Jank Rate       14.2 /min                                       │
└──────────────────────────────────────────────────────────────────┘
```

Histogram bar chart (`fl_chart BarChart`):
- Bars: `accent.blue` fill at 80% opacity
- Hover: highlight bar, show exact count + % tooltip
- Empty buckets: still shown as empty space (no bar) — preserves shape
- Y-axis: percentage (% of total samples)
- X-axis: bucket labels at every other bucket

#### 9.7.4 Markers Tab

Per-marker stats table (sortable):

| Marker | Duration | FPS Med | FPS Min | 1% Low | Stability | S.Jank/m | Jank/m | Big/m | CPU | Mem Peak |
|---|---|---|---|---|---|---|---|---|---|---|
| 🚀 Launch | 4.2s | — | — | — | — | — | — | — | — | — |
| Main Menu | 12s | 60.0 | 58.0 | 58.1 | 98% | 12 | 0 | 0 | 8.2% | 480MB |
| Level 1 Load | 4s | 18.3 | 5.0 | 3.1 | 12% | 234 | 86 | 14 | 78.4% | 510MB |
| Boss Fight | 48s | 43.1 | 12.0 | 18.6 | 51% | 145 | 42 | 3 | 38.9% | 681MB |

- Launch Complete row: 🚀 icon, shows "Time to Launch" in Duration column, all stats show `—` (point marker)
- Jank columns colored: small=grey, standard=orange if >0, big=red if >0
- FPS Med colored same as history screen (green/orange/red)
- Click any row → timeline scrolls all Charts tab charts to that marker's time range + highlights span

---

### 9.8 Session Comparison Screen

```
┌──────────────────────────────────────────────────────────────────┐
│  COMPARE SESSIONS                                                │
│  [Session A ▾: com.example 1.4.2 · Jan 15]  vs                  │
│  [Session B ▾: com.example 1.4.3 · Jan 16]                      │
├──────────────────────────────────────────────────────────────────┤
│  FPS — overlaid (A=blue, B=orange, synced t=0)                  │
│  [chart — both sessions on same axes]                           │
├──────────────────────────────────────────────────────────────────┤
│  METRIC DELTA TABLE                                              │
│  Metric          Session A     Session B     Δ                  │
│  FPS Median       58.3          54.1         –7.2% ↓ 🔴          │
│  FPS 1% Low       24.1          18.3        –24.1% ↓ 🔴          │
│  FPS Stability    81%           68%          –16% ↓ 🔴           │
│  CPU Avg          23.4%         29.1%        +24% ↑ 🔴           │
│  Memory Peak      681MB         724MB        +6.3% ↑ 🔴          │
│  Jank/min         14.2          22.8         +61% ↑ 🔴           │
│  Big Jank/min      0.4           2.1        +425% ↑ 🔴           │
│  GPU Avg           41%           47%         +15% ↑ 🟡           │
│  Battery Drain    7.9%/hr       8.1%/hr      +2.5% ↑ 🟡          │
└──────────────────────────────────────────────────────────────────┘
```

- `🔴` = regression beyond 5% threshold; `🟡` = regression 1–5%; `🟢` = improvement; `—` = no change
- Delta column: negative = red text, positive = red text for regressions (higher CPU/jank = worse), positive = green for improvements (higher FPS = better)
- Both chart overlays use 70% opacity so overlap is visible
- Shorter session: null gap on chart from session end to longest session end
- Session selectors: dropdown showing all sessions grouped by date

---

### 9.9 Settings Screen

Matches VS Code Settings page aesthetic — two-column layout (categories list left, settings right):

```
┌────────────────┬────────────────────────────────────────────────┐
│ SETTINGS       │                                                │
│                │  > Profiling                                   │
│ Profiling      │  ─────────────────────────────────────────     │
│ Paths          │  Sample rate                                   │
│ Appearance     │  [1s ▾]  500ms / 1s / 2s                      │
│ Charts         │                                                │
│ Keyboard       │  Screenshot interval                           │
│ About          │  [10s ▾]  5s / 10s / 30s / Off                 │
│                │                                                │
│                │  Chart time window                             │
│                │  [60s ▾]  30s / 60s / 120s                     │
│                │                                                │
│                │  Jank detection formula                        │
│                │  [● GameBench (3-tier) ○ Simple threshold]     │
│                │                                                │
│                │  Auto-detect SurfaceFlinger layer              │
│                │  [Toggle: ON]                                  │
└────────────────┴────────────────────────────────────────────────┘
```

**Full settings list:**

| Category | Setting | Control | Default |
|---|---|---|---|
| Profiling | Sample rate | Dropdown: 500ms/1s/2s | 1s |
| Profiling | Screenshot interval | Dropdown: 5s/10s/30s/Off | 10s |
| Profiling | Chart time window | Dropdown: 30s/60s/120s | 60s |
| Profiling | Jank formula | Radio: GameBench 3-tier / Simple | GameBench |
| Profiling | Auto-detect layer name | Toggle | On |
| Paths | ADB executable | File picker + text field | Auto (PATH) |
| Paths | Python executable | File picker + text field | Auto (PATH) |
| Paths | Data directory | Directory picker | `~/PerformanceBench` |
| Appearance | Theme | Dropdown: Dark / Light / System | System |
| Appearance | Monospace font | Dropdown: auto / custom | Auto |
| Charts | FPS histogram bucket | Radio: 5fps / 10fps | 5fps |
| Charts | Chart grid columns | Radio: Auto / 1 / 2 / 3 | Auto |
| Charts | Show null gaps | Toggle | On |
| Charts | Animate chart scroll | Toggle | On |
| Keyboard | Shortcuts reference | Read-only table | — |
| About | Version, licenses | Info display | — |

**Keyboard shortcuts reference table (read-only in Settings → Keyboard):**

| Action | Windows | macOS |
|---|---|---|
| Start / Stop recording | Ctrl+Shift+R | ⌘+Shift+R |
| Add Marker | Ctrl+Shift+M | ⌘+Shift+M |
| Mark Launch Complete | Ctrl+Shift+L | ⌘+Shift+L |
| Take Screenshot | Ctrl+Shift+S | ⌘+Shift+S |
| Toggle sidebar | Ctrl+B | ⌘+B |
| Expand chart full-screen | Double-click chart | Double-click chart |
| Close tab | Ctrl+W | ⌘+W |

---

### 9.10 Design Implementation Notes (for Flutter)

**Theme provider:** Use Riverpod + `ThemeData` with custom `ColorScheme`. All colors reference the design tokens above. Never hardcode hex values in widget files — always use `Theme.of(context).colorScheme.xxx` or a custom `AppColors` extension.

**fl_chart configuration:**
- `LineChart` for all time-series metrics
- `BarChart` for FPS histogram
- Disable built-in touch overlays; implement custom hover via `MouseRegion` widget
- Gradient fill: `LinearGradient` from metric color at 20% opacity to transparent
- Chart border: none (`FlBorderData(show: false)`)
- Grid: `FlGridData` with horizontal lines only, `drawVerticalLine: false`

**Ring buffer → chart:**
- `MetricCollector` emits `MetricSample` to a `StreamController`
- `MetricChart` widget holds a local `List<FlSpot>` of max 300 points (60s at 1Hz + buffer)
- On new sample: append to list, drop oldest if > 300. Call `setState` to trigger repaint.
- No `StreamBuilder` (too many rebuilds) — use `stream.listen` in `initState`, call `setState` manually

**Window resizing:**
- Use `LayoutBuilder` in chart grid to switch between 1/2/3 column layout
- Minimum window size: 800 × 600 (enforce via `window_manager.setMinimumSize`)
- Default launch size: 1280 × 800 (centered on screen)

**Platform-specific title bar:**
- Windows: `window_manager` + custom Flutter title bar widget; `window_manager.setTitleBarStyle(TitleBarStyle.hidden)`
- macOS: `window_manager.setTitleBarStyle(TitleBarStyle.hidden)` + `window_manager.setWindowButtonVisibility(hidden: false)` to keep traffic lights

**Fonts:**
- Bundle `JetBrains Mono` in `assets/fonts/` as fallback monospace for Linux; load via `pubspec.yaml`
- Detect platform font at runtime; set in `ThemeData.textTheme` using `GoogleFonts` or bundled assets
- Never use `TextStyle(fontFamily: 'monospace')` directly — use a custom `AppTextStyles` class

**Animations:**
- REC dot pulse: `AnimationController` + `ScaleTransition`, 1-second cycle, infinite
- Tab transitions: `PageTransitionsTheme` with no animation (VS Code doesn't animate tab switches)
- Chart scroll: smooth but not bouncy — `LinearCurve` or `Curves.easeInOut`
- Sidebar collapse: `AnimatedContainer` width tween, 150ms duration

**Acceptance criteria:**
- [ ] Dark theme matches VS Code Dark+ color palette within ±5 Lightness points
- [ ] Chart updates at exactly 1Hz during recording — no frame drops > 33ms on M1 Mac or Ryzen 5
- [ ] Sidebar toggles in ≤ 150ms animated transition
- [ ] Full app launch to device-list-visible: ≤ 2 seconds on Windows 11 / macOS 14
- [ ] Window resize from 800px to 1400px wide → chart grid relayouts without jank
- [ ] Custom title bar draggable on both Windows and macOS
- [ ] All text legible at 100% Windows display scaling and macOS Retina (2× pixel density)

---

## 10. Platform Limitations

### 10.1 iOS on Windows — v1.5

tidevice (Windows iOS tool) is a community DTXProtocol reverse-engineering. Apple breaks it with iOS updates; accuracy is lower than pyidevice. The Mac proxy approach requires a daemon on Mac — effectively the same as using the Mac app.

**v1.5 plan:** tidevice on Windows (~8 metrics), Mac proxy daemon for full metrics, explicit gap table per connection method.

### 10.2 GPU on Android — Device Specific

GPU % via ADB without root is device and driver specific. Full matrix in Appendix A.

- Snapdragon (Adreno): `/sys/class/kgsl/kgsl-3d0/gpubusy` — no root on Android ≤12, may need root on 13+
- Mali: OEM-specific sysfs, not standardized
- Apple GPU (iOS): pyidevice Metal counters — % time busy (not % of max compute throughput)
- PowerVR / other: Not available

PerformanceBench tries all known paths. Shows "GPU: N/A" on failure. Never fabricates.

### 10.3 iOS Battery mA — iPhone 8+ Not Available

Apple removed instantaneous current draw at hardware API level for iPhone 8+.

| Hardware | iOS | mA Available |
|---|---|---|
| iPhone 8+ (all) | Any | No — drain rate only |
| iPhone 7 and older | iOS 10.3+ | Yes |
| iPhone 7 and older | iOS 9.3.5–10.2 | No — firmware bug |

Same limitation as GameBench. For iPhone 8+, report drain rate (% per hour) instead.

### 10.4 Screenshots — WiFi ADB Slow

ADB screencap over WiFi: 2–4 seconds per capture. Disabled by default over WiFi. User can enable in Settings with warning displayed.

### 10.5 iOS Requires USB Throughout Session

DTXProtocol requires USB for stable metric streaming. Wireless iOS profiling needs persistent pairing tunnel — v1.5 scope.

### 10.6 Root-Only Features — Not Before v3.5

| Feature | Root Needed |
|---|---|
| Full per-thread CPU breakdown | Yes |
| Adreno hardware counters (Android 13+) | Yes |
| Detailed Mali hardware counters | Usually yes |

### 10.7 App Store IPA Injection Blocked by FairPlay DRM

App Store IPA downloads are FairPlay encrypted. Injection requires decryption first, which requires a jailbroken device. iOS injection (v3.0) only works with **unencrypted IPAs provided by the studio directly from CI**. Document this clearly at v3.0 release.

### 10.8 iOS CPU Not Normalized Per Core

GameBench iOS CPU uses `thread_info()` — not divided by core count. PerformanceBench matches this behavior. Display the raw value as-is; add a tooltip explaining the difference from Android CPU%.

---

## 11. Full Roadmap

### v1.0 — External Profiling MVP (12 weeks)

Android + iOS (macOS) external profiling at GameBench-parity metric depth.

**Metrics (per Section 4.3 + Section 5):**
- FPS + 4-tier jank (small / medium / big / frame-ratio Γ=L/R)
- Raw frametimes JSON per-second window
- FPS Variability Index (Section 6.6)
- CPU app + system + per-core states/freqs (Section 5.2)
- CPU normalized to current frequency (Section 5.2.1)
- Top-8 thread CPU breakdown (Section 5.2.2)
- Memory PSS subsections: Java / Native / Graphics / Stack / Code / System / WebView (Section 5.3)
- Battery: % / mA / mV / temp / charging source / WiFi state
- Network split per-interface: WiFi / Cellular / Other (Section 5.5)
- Thermal status (0..3)
- GPU % + freq + mem (device-dependent)
- Static device + app data captured per session (Section 5.11)

**Analytics (Section 6):**
- FPS histogram, median, min, max, 1% low, p95, stability %, variability index
- Per-marker stats (auto on session stop)
- Power analytics: mAh consumed, avg mW, total mWh, estimated playtime (Section 6.6)
- Memory subsection avg/peak/growth + trend slope (Section 6.7)
- Per-interface network totals + avg kbps (Section 6.8)

**UI:**
- VS Code-styled Flutter desktop (Section 9)
- Real-time chart grid during recording
- Session history + detail + comparison
- 5-size screenshots (SS0–SS4) with size selector in Settings (Section 5.12)
- Session title / notes / tags k=v
- Marker groups
- Launch Complete marker

**Features:**
- Session export JSON/CSV
- Strict testing mode (Section 20)
- Production vs Non-Production mode (Section 21)
- 10s minimum session enforcement
- ADB + pyidevice (macOS only for iOS)

No injection. No team server. No web dashboard.

### v1.5 — Analysis + Platform Expansion

**Analysis:**
- Drag-region selection on timeline → per-region stats (same as per-marker but user-drawn)
- Disk I/O activated (schema columns from v1.0)
- Auto-detected issues (Section 6.9) — feature flag default-off
- Session collections (group by project)
- Session search + filter by tag / device / app / chipset
- Metric threshold alerts (local notification when FPS < X for Y seconds)
- Auto session start when target app launches (`am monitor` or `/proc/*/cmdline` poll)

**Platform:**
- tidevice on Windows for iOS (~8 metrics, documented gaps)
- Mac proxy daemon (Windows → Mac → iPhone, all metrics)
- Linux first-class support smoke test

**Video (Android) — Section 32:**
- Synced screen recording via `adb shell screenrecord` (built-in Android 4.4+)
- H.264 MP4, configurable resolution + bitrate
- Auto-chunked at 3-min Android limit, seamless concat
- Embedded chart-sync timestamps
- Player UI: scrub video → scrubs charts and vice versa

**v1.5 schema additions (migration v2):**
- `detected_issues` table activated
- `collections` table activated
- `videos` table activated (Section 32)

### v2.0 — Team Server + Web Dashboard + CI/CD

**Separate repository: `performancebench-server`**

- Rust + Axum REST API
- PostgreSQL shared storage
- React + Vite web dashboard (matches desktop VS-Code-style design system)
- Session upload from desktop app (opt-in, manual trigger)
- Auth: email + bcrypt, JWT (HS256, 1h expiry), API tokens
- Local network only by default — TLS via user-provided cert

**Web Dashboard features (Section 22):**
- Sessions list with multi-filter
- Session detail mirroring desktop
- Trends Explorer — KPI trends across sessions for an app/device combo
- Lenses — saved filters/views (`lenses` table)
- Detected Issues dashboard tile
- Analysis Reports — multi-session analytical reports

**Notifications (Section 23):**
- Email / Slack / Webhook channels
- Threshold alert rules
- `notification_channels`, `alerts`, `alert_events` tables

**REST API for CI/CD automation:**
```
POST /api/sessions/start         body: {device, app, label}
GET  /api/sessions/:id           returns: session metadata
GET  /api/sessions/:id/stats     returns: full analytics
GET  /api/sessions/:id/samples   returns: paginated metric_samples
GET  /api/sessions/:id/markers
GET  /api/sessions/:id/issues
POST /api/sessions/:id/stop
GET  /api/sessions               list with filters
GET  /api/export/:id/:format     JSON | CSV | PDF report
GET  /api/trends                 cross-session trends (Lens-driven)
POST /api/lenses                 create saved view
POST /api/alerts                 create alert rule
POST /api/notifications/test     dry-run channel
GET  /api/devices                aggregated device list
GET  /api/apps                   tracked apps
```

- Webhook callbacks on session-end / alert-fired
- API token authentication for CI scripts
- Web live overlay: browser tab mirrors active recording in real-time (WebSocket push from desktop)

**Mobile Profiler App (optional, Section 26):**
- Lightweight Flutter mobile app (iOS + Android)
- Read-only view of team server sessions for managers
- Push notifications for alerts

**Security:** Team server for released / non-confidential games only. Unreleased games: standalone desktop app, no sync.

### v2.5 — Android SDK Injection

**Separate repository: `performancebench-injector`** (already specified in Section 18)

- APK injection via apktool + Smali patching
- SDK native library compiled to `.so` in Rust
- Re-signing with user-provided keystore
- In-app FPS overlay (floating widget on device screen)
- SDK → desktop via local ADB socket on port 8080 (mirrors GameBench SDK HTTP server)
- Frida gadget injection as alternative (no re-signing needed)
- WebView / JS memory collection
- Per-connection network stats (socket API interception)
- ADB broadcast actions for automation (start/stop/marker commands)
- **Video (iOS) — Section 32:** Synced screen recording via `pymobiledevice3` DVT screen-mirror service. H.264 MP4, ~30 FPS. macOS host only at v2.5 (Windows host: v3.0 via Mac proxy)

### v3.0 — Game Engine Plugins + iOS Injection + tvOS + Windows PC

**Unity Plugin (UPM package):**
- Auto-markers on `SceneManager.sceneLoaded`
- Draw calls, batches, SetPass calls, Mono memory, GC alloc
- `PerformanceBench.BeginMarker("boss_fight")` API
- Editor window for config + quick session start

**Unreal Engine Plugin (C++ + Blueprint):**
- Auto-markers on `FCoreUObjectDelegates::PostLoadMapWithWorld`
- `UPerformanceBenchBPLibrary::BeginMarker` Blueprint node
- RHI frame time, GPU stats

**Godot Plugin (GDScript):**
- Auto-markers on `SceneTree.scene_changed`
- `RenderingServer` draw call metrics
- Autoload singleton

**iOS IPA Injection:**
- Studio-provided unencrypted IPA only (App Store IPA blocked by FairPlay)
- Free Apple ID signing (7-day expiry — acceptable for QA)
- `PerformanceBench.framework` dylib injection

**tvOS Support (Section 25):**
- pyidevice tvOS connection (USB-C only on Apple TV 4K gen 3+)
- Same metrics as iOS where exposed

**Windows PC Profiling (Section 19):**
- Win32 PDH (Performance Data Helper) API for per-process counters
- DXGI presentation hooking for FPS / frame time on Windows games
- ETW (Event Tracing for Windows) for low-overhead frame timing
- Memory: working set + private bytes + GPU committed memory
- CPU: per-process CPU time + per-thread + freq via Win32_Processor WMI

**Video (PC) — Section 32:**
- Windows: Windows.Graphics.Capture API (Win10 1903+) — H.264 via Media Foundation
- Linux: `ffmpeg` + x11grab / pipewire (free, GPL ok as subprocess)
- macOS: AVFoundation `AVScreenCaptureKit` — H.264 via VideoToolbox

### v3.5 — Enterprise

- SAML 2.0 SSO (Okta, Azure AD, Google Workspace) — Section 24
- LDAP authentication — Section 24
- JIT (Just-In-Time) user provisioning — Section 24
- Jira issue creation from session (link performance data to ticket)
- RBAC: Owner / Admin / Member / Viewer roles
- Audit log: all session uploads, deletes, exports, alert configurations
- On-premises deployment guide (nginx + TLS + PostgreSQL)
- Thread-level CPU breakdown (root required — explicitly documented)
- Multi-org / multi-project hierarchy (`team_orgs` / `team_projects` tables)

---

## 12. File Structure

v1.0 repository. No server, injector, or plugin directories yet.

```
performancebench/
├── lib/
│   ├── main.dart
│   ├── app.dart                          # MaterialApp, GoRouter, theme
│   ├── core/
│   │   ├── database/
│   │   │   ├── database.dart             # sqflite_common_ffi init + migrations
│   │   │   ├── session_dao.dart
│   │   │   ├── metric_dao.dart
│   │   │   ├── marker_dao.dart
│   │   │   ├── session_stats_dao.dart
│   │   │   ├── marker_stats_dao.dart
│   │   │   └── screenshot_dao.dart
│   │   ├── models/
│   │   │   ├── session.dart
│   │   │   ├── device.dart
│   │   │   ├── metric_sample.dart        # all metric_samples columns (50+ nullable fields, see Appendix C)
│   │   │   ├── marker.dart
│   │   │   ├── session_stats.dart        # fps_min, fps_max, jank tiers, battery_temp_max_c
│   │   │   └── marker_stats.dart         # fps_min, fps_max, jank tiers
│   │   ├── parsers/
│   │   │   ├── fps_parser.dart           # parses SurfaceFlinger output → fps + 3-tier jank
│   │   │   ├── cpu_parser.dart           # parses /proc/stat combined → snapshot + delta
│   │   │   ├── memory_parser.dart        # parses dumpsys meminfo → PSS KB
│   │   │   ├── battery_parser.dart       # parses dumpsys battery + sysfs → pct/mA/mV/temp
│   │   │   ├── network_parser.dart       # parses /proc/net/dev → cumulative bytes
│   │   │   ├── thermal_parser.dart       # parses thermalservice → 0-3
│   │   │   └── gpu_parser.dart           # tries Adreno→Mali→null
│   │   ├── analytics/
│   │   │   ├── fps_analytics.dart        # median, min, max, 1% low, p95, stability, histogram
│   │   │   ├── analytics_service.dart    # compute + store session_stats + marker_stats
│   │   │   └── comparison_analytics.dart # MetricDelta list, regression detection
│   │   └── services/
│   │       ├── adb_service.dart
│   │       ├── ios_service.dart
│   │       ├── metric_collector.dart     # 1Hz loop + ring buffer
│   │       ├── session_service.dart
│   │       └── export_service.dart       # JSON + CSV
│   ├── features/
│   │   ├── device_list/
│   │   │   ├── device_list_screen.dart
│   │   │   └── device_card.dart
│   │   ├── app_picker/
│   │   │   ├── app_picker_screen.dart
│   │   │   └── app_list_item.dart
│   │   ├── active_session/
│   │   │   ├── active_session_screen.dart
│   │   │   ├── charts_tab.dart
│   │   │   ├── screenshots_tab.dart
│   │   │   └── markers_tab.dart
│   │   ├── session_history/
│   │   │   ├── history_screen.dart
│   │   │   └── session_list_item.dart
│   │   ├── session_detail/
│   │   │   ├── detail_screen.dart
│   │   │   ├── scorecard_tab.dart
│   │   │   ├── replay_charts_tab.dart
│   │   │   ├── fps_analysis_tab.dart     # histogram + all percentile stats + min/max
│   │   │   └── markers_detail_tab.dart   # per-marker stats table with 3-tier jank cols
│   │   ├── comparison/
│   │   │   └── comparison_screen.dart
│   │   └── settings/
│   │       └── settings_screen.dart
│   └── shared/
│       ├── widgets/
│       │   ├── metric_chart.dart         # fl_chart line chart wrapper
│       │   ├── fps_histogram_chart.dart  # fl_chart bar chart
│       │   ├── scorecard_widget.dart
│       │   ├── marker_stats_table.dart   # includes jank_small, jank_big columns
│       │   ├── comparison_delta_table.dart
│       │   ├── metric_value_badge.dart
│       │   └── gpu_unavailable_badge.dart
│       └── theme.dart
├── ios_agents/
│   ├── requirements.txt                  # py-ios-device==2.x
│   ├── collector.py                      # streams JSON to stdout; see Section 5.10 field mapping
│   ├── device_list.py
│   └── app_list.py
├── test/
│   ├── unit/
│   │   ├── fps_parser_test.dart          # all acceptance criteria from Section 5.1
│   │   ├── cpu_parser_test.dart
│   │   ├── fps_analytics_test.dart       # all acceptance criteria from Section 6.1
│   │   ├── comparison_analytics_test.dart
│   │   ├── ring_buffer_test.dart
│   │   └── export_service_test.dart
│   └── integration/
│       ├── adb_integration_test.dart
│       └── ios_integration_test.dart
├── pubspec.yaml
├── README.md
└── CHANGELOG.md
```

---

## 13. Prerequisites and Setup

### 13.1 Development Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Flutter SDK | 3.19+ | Desktop app |
| Dart | 3.3+ (bundled) | App language |
| ADB | Latest | Android device comms |
| Python | 3.10+ | iOS metric collection |
| py-ios-device | 2.x | iOS instruments protocol |
| Xcode | 15+ | iOS device support (macOS) |

### 13.2 End User Requirements

**Android (Windows / macOS / Linux):**
1. Download PerformanceBench installer
2. Install ADB (Platform Tools) — bundled in installer where possible
3. Enable USB debugging on Android device

**iOS (macOS only in v1):**
1. Download PerformanceBench installer
2. `brew install python@3.11 && pip3 install py-ios-device`
3. Enable Developer Mode on iPhone: Settings → Privacy & Security → Developer Mode

Apple Developer account: **not required.**

### 13.3 ADB Setup

```bash
# macOS
brew install android-platform-tools

# Windows (Chocolatey)
choco install adb -y

# Verify
adb version
```

### 13.4 pyidevice Setup (macOS)

```bash
brew install python@3.11
pip3 install py-ios-device

# Verify
python3 -c "import ios_device; print('OK')"
python3 -m ios_device list  # list connected iOS devices
```

### 13.5 Flutter Dev Setup

```bash
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
git clone https://github.com/performancebench/performancebench
cd performancebench && flutter pub get
flutter run -d macos   # or windows / linux
```

### 13.6 Key Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite_common_ffi: ^2.3.0    # SQLite desktop
  fl_chart: ^0.67.0              # Charts
  riverpod: ^2.5.0               # State management
  go_router: ^13.0.0             # Navigation
  uuid: ^4.0.0                   # Session UUIDs
  path_provider: ^2.1.0          # Platform data dirs
  path: ^1.9.0
  csv: ^6.0.0                    # CSV export
  file_picker: ^8.0.0            # Export file chooser
  window_manager: ^0.3.8         # Desktop window control
```

---

## 14. Testing Strategy

### 14.1 Unit Tests — No Device Required

All parsers must have 100% branch coverage. Tests must match acceptance criteria in Section 5 and Section 6.

**fps_parser_test.dart — required test cases:**
- Empty string → fps=0, all jank=0
- 1-line input → fps=0
- 10 valid frames at 16.67ms average → fps within ±2% of 60.0
- Frame delta 130ms → big_jank_count increments; jank_count increments; jank_small_count increments
- Frame delta 90ms → jank_count increments (>83.3ms); big_jank_count does NOT (< 125ms unless rolling avg exceeded)
- Frame delta 150ms → excluded by outlier filter; not counted as any jank; fps denominator ignores it

**fps_analytics_test.dart — required test cases:**
- Empty list → all fields return 0.0
- [99 × 60fps, 1 × 5fps] → one_percent_low ≈ 5.0 (±0.1)
- [5 × 30fps, 95 × 60fps] → p95_frame_time_ms ≈ 33.3ms (±1.0ms)
- [100 × 60fps] → stability_pct = 100.0
- [58.0, 59.0, 62.0] → histogram key `55` = 3 (5fps bucket size)
- [20.0, 30.0, 60.0] → min_fps = 20.0, max_fps = 60.0
- Comparison: Session A fps_median=60.0, B fps_median=54.0 → is_regression=true, delta_percent≈-10%

**Coverage targets:**
- All parsers: 100% branch coverage
- `FpsAnalytics`: 100% (all stat functions)
- `AnalyticsService`: full per-marker and session stat computation
- Ring buffer: empty / full / wrap-around edge cases
- Export service: JSON structure valid, CSV column count + header matches

### 14.2 Integration Tests — Device Required

**adb_integration_test.dart:**
- 30s Android session on `emulator-5554` → ≥ 28 non-null fps samples
- All samples: fps non-null and > 0 for ≥ 20 samples in 30s
- battery_pct: non-null in all samples
- cpu_app_pct: non-null in all samples after first (first is null — no delta)

**ios_integration_test.dart:**
- 60s iOS session → fps, cpu, mem, battery_pct all have non-null values
- battery_ma: null for iPhone 8+ (assert null, not assert value)

### 14.3 Platform Test Matrix

| Host OS | Android | iOS |
|---|---|---|
| Windows 10 / 11 | Required | v2 |
| macOS 13 Ventura | Required | Required |
| macOS 14 Sonoma | Required | Required |
| Ubuntu 22.04 | Required | Not planned |

### 14.4 Device Test Matrix

| Device | Priority | Reason |
|---|---|---|
| Google Pixel 8 (Snapdragon, Android 14) | P0 | Stock Android, Adreno GPU path |
| Samsung Galaxy S23 (Snapdragon, Android 13) | P0 | GPU access restriction test |
| Samsung Galaxy S22 (Exynos) | P1 | Mali GPU path |
| Google Pixel 6a (Tensor, Android 13) | P1 | Tensor GPU (no sysfs path expected → GPU N/A) |
| iPhone 15 (iOS 17) | P0 | Latest iOS + Metal GPU counters; battery_ma = null (8+) |
| iPhone 12 (iOS 16) | P1 | iOS 16 instrument protocol |
| Xiaomi / MediaTek | P2 | Different GPU vendor |

---

## 15. Security Model

### 15.1 Local Only — Zero Transmission

| Action | Status |
|---|---|
| Metric data to external server | Never |
| Telemetry / analytics | None |
| Auto-update network check | None |
| Cloud sync | None |
| Team server (v2.0) | Local network, opt-in, manual sync only |

### 15.2 Storage

- SQLite: `<data_dir>/data.db` (user-configurable; default `~/PerformanceBench/data.db`)
- Screenshots: `<data_dir>/screenshots/<session_id>/<ts>.jpg`
- No data written outside these paths

### 15.3 Export

Manual only. User initiates → file picker → write to chosen path. No background upload, no automatic behaviour.

### 15.4 Team Server Security (v2.0)

- Local network only by default — not designed for internet exposure without a reverse proxy
- TLS 1.3 when configured with a certificate (user's responsibility)
- JWT (HS256, 1hr expiry) + bcrypt passwords
- Rate limiting: 100 req/min per IP
- For unreleased / confidential games: **use desktop app standalone mode with no server sync**

---

## 16. GameBench Parity Matrix

### 16.1 Metrics & Analytics

| Metric | GB | v1.0 | v1.5 | v2.0 | v2.5 | v3.0 | v3.5 |
|---|---|---|---|---|---|---|---|
| FPS (real-time) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Min FPS | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Max FPS | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Small Jank count | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Jank count (medium) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Big Jank count | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Frame-ratio jank Γ=L/R | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Raw frametimes | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 1% Low FPS | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 95th pct frame time | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| FPS stability % | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| FPS histogram | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| FPS Variability Index | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CPU % (app + system) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CPU normalized to current freq | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CPU per-core | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| CPU per-core frequency | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Top-8 thread CPU breakdown | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| GPU % | ✅ | ⚠️ | ⚠️ | ⚠️ | ✅ | ✅ | ✅ |
| GPU frequency | ✅ | ⚠️ | ⚠️ | ⚠️ | ✅ | ✅ | ✅ |
| GPU memory | ✅ | ⚠️ | ⚠️ | ⚠️ | ✅ | ✅ | ✅ |
| Memory PSS (total) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Memory subsections (Java/Native/Graphics/Stack/Code/System) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| WebView / JS memory | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Memory growth + trend slope | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Battery % | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Battery mA (Android) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Battery mA (iOS ≤7) | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Battery mA (iOS 8+) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Battery voltage | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Battery temperature | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Charging detection (AC/USB/Wireless/Dock) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| mAh consumed (∫mA dt) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Avg power mW | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Total energy mWh | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Estimated playtime (h) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| WiFi state | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Network TX/RX (total) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Network split WiFi/Cellular/Other | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Network per-connection | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Thermal status (0..3) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Disk I/O | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Thread count | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Static device data snapshot | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Static app data snapshot | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Brightness + volume capture | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Auto-detected issues | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |

### 16.2 Workflow Features

| Feature | GB | v1.0 | v1.5 | v2.0 | v2.5 | v3.0 | v3.5 |
|---|---|---|---|---|---|---|---|
| Screenshots (5 sizes SS0-SS4) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Manual markers | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Marker groups | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Launch Complete marker | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Per-marker stats | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Drag-region selection | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Session title / notes | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Tags (k=v) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Session comparison | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Session history | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Session search + filter | ✅ | ⚠️ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Collections | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Lenses (saved filters) | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Trends Explorer | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Analysis Reports | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Detected Issues dashboard | ✅ | ❌ | ⚠️ | ✅ | ✅ | ✅ | ✅ |
| Production mode (histogram-only) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Strict testing mode | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 10s minimum session enforcement | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Auto session start | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Export JSON / CSV | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| PDF analysis report | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Video recording (Android) | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Video recording (iOS) | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |
| Video recording (PC) | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Video synced to charts | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Keyboard shortcuts | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### 16.3 Platform Coverage

| Platform | GB | v1.0 | v1.5 | v2.0 | v2.5 | v3.0 | v3.5 |
|---|---|---|---|---|---|---|---|
| Android USB | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Android WiFi | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| iOS USB (Mac) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| iOS WiFi | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| iOS on Windows | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Linux control machine | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| tvOS | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Windows PC profiling target | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |

### 16.4 SDK / Injection / Engine Plugins

| Feature | GB | v1.0 | v1.5 | v2.0 | v2.5 | v3.0 | v3.5 |
|---|---|---|---|---|---|---|---|
| APK injection | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |
| IPA injection (unencrypted) | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Unity plugin | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Unreal plugin | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Godot plugin | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| In-app FPS overlay (Android) | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |
| In-app FPS overlay (iOS) | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| SDK HTTP server (port 8080) | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |
| ADB broadcast actions | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |

### 16.5 Team / Cloud / Enterprise

| Feature | GB | v1.0 | v1.5 | v2.0 | v2.5 | v3.0 | v3.5 |
|---|---|---|---|---|---|---|---|
| Team server | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Web dashboard | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Web live overlay | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| REST API (CI/CD) | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Email alerts | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Slack alerts | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Webhooks | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Mobile profiler app | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| API tokens | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| LDAP auth | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| SSO (SAML 2.0) | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| JIT user provisioning | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Jira integration | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| RBAC (4 roles) | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Audit log | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Multi-org / multi-project | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

### 16.6 PerformanceBench Differentiators (always ✅)

| Differentiator | GB | PB (all versions) |
|---|---|---|
| **Cost $0** | ❌ | ✅ |
| **Local-only data** | ❌ | ✅ |
| **Open source (MIT/Apache-2.0)** | ❌ | ✅ |
| **Fully offline operation** | ❌ | ✅ |
| **No account required** | ❌ | ✅ |
| **Linux control machine** | ❌ | ✅ |
| **Source code modifiable** | ❌ | ✅ |
| **Self-hosted team server (LAN)** | ❌ | ✅ (v2.0+) |
| **No vendor lock-in** | ❌ | ✅ |

**Legend:** ✅ = full support | ⚠️ = partial / device-dependent | ❌ = not available

**Parity score by version:**
- **v1.0: ~75% feature parity** (full metrics depth + power analytics + 5 screenshot sizes + Variability Index + memory subsections — major leap from prior estimate)
- **v1.5: ~82%** (auto-detected issues + collections + drag-region)
- **v2.0: ~91%** (web dashboard + REST API + alerts + Trends/Lenses)
- **v2.5: ~94%** (Android SDK injection + overlay)
- **v3.0: ~98%** (engine plugins + iOS injection + tvOS + Windows PC)
- **v3.5: ~100%** (enterprise SSO + RBAC + Jira; video recording shipped per Section 32 — no remaining gaps)

PB **leads GameBench** on: cost, source openness, local-data privacy, Linux host support, mAh/mWh power math precision, frame-ratio Γ jank model exposed, screenshot size flexibility (5 tiers vs GB's static), zero infrastructure required, video recording feature parity at $0 (Section 32).

---

## 17. Permanent Feature Gaps

These features are explicitly NOT planned. Honest about why.

| Feature | Why Not Planned |
|---|---|
| ~~Video recording~~ | **MOVED TO ROADMAP** — see Section 32. Android v1.5 via `adb shell screenrecord`, iOS v2.5 via pymobiledevice3 DVT screen-mirror, PC v3.0 via Windows.Graphics.Capture API. All free. |
| **CPU core frequency** | iOS does not expose clock speeds at all. Android exposes via `/sys/devices/system/cpu/cpuN/cpufreq/scaling_cur_freq` (no root needed on most devices) — may add in v1.5 if demand exists. |
| **Battery mA on iPhone 8+** | Apple hardware limitation. No workaround exists regardless of tooling. Same limitation as GameBench. |
| **App Store IPA injection without jailbreak** | FairPlay DRM encrypted. Decryption requires jailbroken device — outside project scope. Studio must provide unencrypted IPA from CI. |
| **Full cloud infrastructure** | Would require servers, cost, and violates local-only principle. Team server (v2.0) is LAN-only. |
| **ML anomaly detection** | Requires large corpus of session data to train. Possible at v4 once user base is established. |
| **Windows iOS (tidevice) at full metric depth** | Apple's DTXProtocol on Windows is partially reverse-engineered. Some metrics physically cannot be replicated without macOS usbmuxd. Gap documented per connection method (~8 metrics on Windows tidevice vs full set on macOS pyidevice). |
| **Network content interception** | Privacy violation. Only byte counts, no packet inspection. GameBench also only records byte counts. |

---

## Appendix A: GPU Support Matrix (Android)

| GPU | Sysfs Path | No-Root | Notes |
|---|---|---|---|
| Qualcomm Adreno (Android ≤12) | `/sys/class/kgsl/kgsl-3d0/gpubusy` | ✅ | `"busy total"` → `busy/total × 100` |
| Qualcomm Adreno (Android 13+) | Same | ⚠️ | SELinux may block; try `echo 1 > perfcounter` first |
| ARM Mali (Samsung Exynos) | `/sys/class/misc/mali0/device/utilization` | ⚠️ | OEM kernel specific |
| ARM Mali (generic) | `/sys/bus/platform/drivers/mali/*/utilization` | ⚠️ | Glob path; varies per kernel |
| Apple GPU (iOS) | pyidevice `gpu_counters` (Metal) | ✅ | % time busy — NOT % of max compute throughput |
| PowerVR | No standard path | ❌ | Show "Unavailable" |
| Other | Unknown | ❌ | Show "Unavailable" |

**Adreno Android 13+ unlock attempt:**
```bash
adb shell "echo 1 > /sys/class/kgsl/kgsl-3d0/perfcounter"
```
PerformanceBench tries this automatically and logs result. Falls back to "GPU: N/A" if denied. Never fabricates.

**Parse Adreno `gpubusy`:**
File contains two space-separated integers: `"busy total"`.
Example: `"4823 10000"` → `(4823 / 10000) × 100 = 48.23%`

---

## Appendix B: iOS Support Reality

### DTXProtocol Requirements

- Physical device + USB (no WiFi in v1)
- Developer Mode enabled (iOS 16+): Settings → Privacy & Security → Developer Mode
- macOS host with usbmuxd
- Apple Developer account: **not required** for metric collection

### iOS Metric Availability

| Metric | All iOS | Notes |
|---|---|---|
| FPS | ✅ | `graphics.opengl` instrument |
| Jank (3-tier) | ✅ | Derived from frame timestamps |
| CPU % (per-app) | ✅ | `sysmontap` — NOT normalized per core |
| Memory (phys_footprint) | ✅ | `sysmontap` |
| Network TX / RX | ✅ | `networking` instrument (cumulative) |
| Thermal (0–3) | ✅ | `processInfo.thermalState` |
| GPU utilization | ✅ | `gpu_counters`, Metal — % time busy |
| Battery mA (iPhone ≤7, iOS 10.3+) | ✅ | Real instantaneous current |
| Battery mA (iPhone 8+) | ❌ | Apple hardware limit — no workaround |
| Battery voltage | ✅ | Battery instrument |
| Battery temperature | ⚠️ | Available from battery instrument on most devices |
| CPU core frequency | ❌ | iOS does not expose |
| Disk I/O | ⚠️ | Available but complex; v1.5 |
| Thread count | ⚠️ | Via sysmontap; v1.5 |

### iOS Wireless Profiling (v1.5)

Requires: persistent wireless pairing record + TCP tunnel replicating USB transport. Planned for v1.5. Not trivial — Apple's wireless developer transport has changed between iOS versions.

---

## Appendix C: Database SQL Schema

> **Hard contract. Implement exactly as written. All column names, types, and constraints are fixed.**

```sql
-- =========================================================================
-- v1.0 Core Tables
-- =========================================================================

-- Schema version tracking
CREATE TABLE IF NOT EXISTS schema_version (
    version    INTEGER NOT NULL,
    applied_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Devices (snapshot at session time, denormalized intentionally)
CREATE TABLE IF NOT EXISTS devices (
    id                    TEXT PRIMARY KEY,  -- ADB serial or iOS UDID
    name                  TEXT NOT NULL,
    manufacturer          TEXT,
    model                 TEXT,
    os_version            TEXT,
    os_api_level          INTEGER,
    kernel_version        TEXT,
    chipset               TEXT,                  -- e.g. 'snapdragon_8_gen_2'
    chipset_vendor        TEXT,                  -- 'qualcomm'|'mediatek'|'samsung'|'apple'|'unisoc'
    gpu_vendor            TEXT,                  -- 'adreno'|'mali'|'powervr'|'apple'|'unknown'
    gpu_model             TEXT,                  -- e.g. 'Adreno 740'
    cpu_cores_count       INTEGER,
    cpu_max_freq_khz      INTEGER,
    screen_resolution     TEXT,                  -- '2400x1080'
    screen_density_dpi    INTEGER,
    refresh_rate_hz       INTEGER,
    battery_capacity_mah  INTEGER,
    total_ram_kb          INTEGER,
    internal_storage_gb   INTEGER,
    is_rooted             INTEGER DEFAULT 0,     -- 0/1
    is_emulator           INTEGER DEFAULT 0,
    first_seen_at         INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Sessions
CREATE TABLE IF NOT EXISTS sessions (
    id                TEXT    PRIMARY KEY,             -- UUID v4
    device_id         TEXT    NOT NULL REFERENCES devices(id),
    platform          TEXT    NOT NULL,                -- 'android'|'ios'|'tvos'|'windows_pc'
    target_kind       TEXT    NOT NULL DEFAULT 'mobile',
    app_package       TEXT    NOT NULL,
    app_name          TEXT,
    app_version       TEXT,
    app_version_code  INTEGER,
    started_at        INTEGER NOT NULL,                -- Unix ms
    ended_at          INTEGER,                         -- NULL while recording
    duration_ms       INTEGER,                         -- denormalized for fast list views
    title             TEXT,                            -- user-set title (default = app + ts)
    notes             TEXT,
    tags              TEXT,                            -- JSON array ['release','pixel8']
    tags_kv_json      TEXT,                            -- JSON object {"build":"42","level":"boss"}
    target_fps        INTEGER DEFAULT 60,
    production_mode   INTEGER DEFAULT 0,               -- 0/1 — Section 21
    strict_mode       INTEGER DEFAULT 0,               -- 0/1 — Section 20
    injected          INTEGER DEFAULT 0,               -- 0/1 — true if PB SDK injected
    collection_id     TEXT,                            -- NULL until v1.5 collections
    project_id        TEXT,                            -- NULL until v2.0 team server
    user_id           TEXT                             -- NULL until v2.0 team server
);

-- Static device data — full hardware snapshot per session (Section 5.11)
CREATE TABLE IF NOT EXISTS static_device_data (
    session_id        TEXT PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,
    raw_getprop_json  TEXT,           -- full Android getprop dump as JSON (or iOS plist)
    sensors_json      TEXT,           -- accelerometer/gyro/etc presence
    cameras_json      TEXT,
    sim_carriers_json TEXT,
    locale            TEXT,
    timezone          TEXT,
    captured_at       INTEGER NOT NULL
);

-- Static app data — app-level snapshot per session
CREATE TABLE IF NOT EXISTS static_app_data (
    session_id          TEXT PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,
    install_source      TEXT,            -- com.android.vending / sideload / unknown
    install_time_ms     INTEGER,
    update_time_ms      INTEGER,
    target_sdk          INTEGER,
    min_sdk             INTEGER,
    permissions_json    TEXT,            -- granted/requested
    abi_list            TEXT,            -- 'arm64-v8a,armeabi-v7a'
    apk_size_bytes      INTEGER,
    captured_at         INTEGER NOT NULL
);

-- Metric samples — one row per second per session
CREATE TABLE IF NOT EXISTS metric_samples (
    id                       INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id               TEXT    NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    timestamp                INTEGER NOT NULL,   -- Unix ms

    -- FPS / Jank
    fps                      REAL,
    jank_count               INTEGER,            -- time-threshold (medium tier)
    jank_small_count         INTEGER,            -- small jank
    jank_big_count           INTEGER,            -- big jank (≥125ms or >2× rolling avg)
    jank_ratio_count         INTEGER,            -- frame-ratio Γ=L/R model
    frametimes_json          TEXT,               -- JSON array of raw frame intervals (ms)

    -- CPU
    cpu_system_pct           REAL,
    cpu_app_pct              REAL,               -- raw (max-freq baseline)
    cpu_app_pct_freq_norm    REAL,               -- normalized to current freq (Section 5.2.1)
    cpu_cores                TEXT,               -- JSON array of per-core % (v1.0 active)
    cpu_core_states_json     TEXT,               -- JSON [{"id":0,"online":true,"freq_khz":N}, ...]
    cpu_core_freqs_json      TEXT,               -- JSON [freq_khz, freq_khz, ...]
    cpu_threads_top_json     TEXT,               -- JSON top-8 threads (Section 5.2.2)

    -- Memory (PSS subsections — Section 5.3)
    memory_pss_kb            INTEGER,
    memory_java_kb           INTEGER,
    memory_native_kb         INTEGER,
    memory_graphics_kb       INTEGER,
    memory_stack_kb          INTEGER,
    memory_code_kb           INTEGER,
    memory_system_kb         INTEGER,
    memory_webview_kb        INTEGER,            -- WebView/Chromium proc PSS

    -- Battery
    battery_pct              INTEGER,
    battery_ma               REAL,
    battery_mv               REAL,
    battery_temp_c           REAL,
    charging                 INTEGER DEFAULT 0,  -- 0/1
    charging_source          TEXT,               -- NULL|'AC'|'USB'|'WIRELESS'|'DOCK'

    -- Connectivity
    wifi_active              INTEGER,            -- 0/1

    -- Network (cumulative bytes; deltas computed at analytics time)
    net_tx_bytes             INTEGER,            -- legacy: total all interfaces
    net_rx_bytes             INTEGER,
    net_wifi_tx_bytes        INTEGER,
    net_wifi_rx_bytes        INTEGER,
    net_cellular_tx_bytes    INTEGER,
    net_cellular_rx_bytes    INTEGER,
    net_other_tx_bytes       INTEGER,
    net_other_rx_bytes       INTEGER,

    -- Thermal / GPU / Disk
    thermal_status           INTEGER,            -- 0..3
    gpu_pct                  REAL,
    gpu_freq_mhz             REAL,
    gpu_mem_kb               INTEGER,
    disk_read_kb             REAL,               -- delta KB/s (v1.5)
    disk_write_kb            REAL,

    -- Environment (used by Strict mode validation, Section 20)
    screen_brightness        INTEGER,            -- 0..255
    volume_pct               INTEGER             -- 0..100 media stream
);

-- Marker groups — named sets of related markers
CREATE TABLE IF NOT EXISTS marker_groups (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT    NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    name       TEXT    NOT NULL,
    color      TEXT,                            -- hex, defaults to palette
    created_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Markers
CREATE TABLE IF NOT EXISTS markers (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id      TEXT    NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    group_id        INTEGER REFERENCES marker_groups(id) ON DELETE SET NULL,
    label           TEXT    NOT NULL,        -- '__launch_complete__' for special
    started_at      INTEGER NOT NULL,
    ended_at        INTEGER,                  -- NULL = point marker
    auto_screenshot INTEGER DEFAULT 0,       -- 0/1
    notes           TEXT
);

-- Sub-marker time regions (v2.0)
CREATE TABLE IF NOT EXISTS regions (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id  TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    label       TEXT NOT NULL,
    started_at  INTEGER NOT NULL,
    ended_at    INTEGER NOT NULL,
    color       TEXT
);

-- Per-marker analytics (computed post-session)
CREATE TABLE IF NOT EXISTS marker_stats (
    id                       INTEGER PRIMARY KEY AUTOINCREMENT,
    marker_id                INTEGER NOT NULL REFERENCES markers(id) ON DELETE CASCADE,
    session_id               TEXT    NOT NULL,
    duration_ms              INTEGER,
    fps_median               REAL,
    fps_min                  REAL,
    fps_max                  REAL,
    fps_1pct_low             REAL,
    fps_stability            REAL,
    frame_time_p95           REAL,
    variability_index        REAL,
    cpu_avg_pct              REAL,
    cpu_avg_pct_freq_norm    REAL,
    memory_peak_kb           INTEGER,
    mem_graphics_peak_kb     INTEGER,
    gpu_avg_pct              REAL,
    battery_drain_pct        REAL,
    mah_consumed             REAL,
    jank_total               INTEGER,
    jank_small_total         INTEGER,
    jank_big_total           INTEGER,
    jank_ratio_total         INTEGER,
    jank_per_min             REAL
);

-- Session-level analytics summary (computed post-session)
CREATE TABLE IF NOT EXISTS session_stats (
    session_id                  TEXT    PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,

    -- FPS
    fps_median                  REAL,
    fps_min                     REAL,
    fps_max                     REAL,
    fps_1pct_low                REAL,
    fps_stability               REAL,
    frame_time_p95              REAL,
    fps_histogram               TEXT,    -- JSON
    variability_index           REAL,
    frame_ratio_jank_total      INTEGER,

    -- CPU
    cpu_avg_pct                 REAL,
    cpu_peak_pct                REAL,
    cpu_avg_pct_freq_norm       REAL,
    cpu_peak_pct_freq_norm      REAL,

    -- Memory
    memory_avg_kb               INTEGER,
    memory_peak_kb              INTEGER,
    mem_java_avg_kb             INTEGER,
    mem_java_peak_kb            INTEGER,
    mem_native_avg_kb           INTEGER,
    mem_native_peak_kb          INTEGER,
    mem_graphics_avg_kb         INTEGER,
    mem_graphics_peak_kb        INTEGER,
    mem_stack_avg_kb            INTEGER,
    mem_code_avg_kb             INTEGER,
    mem_system_avg_kb           INTEGER,
    mem_webview_avg_kb          INTEGER,
    mem_growth_kb               INTEGER,
    mem_trend_slope_kb_per_min  REAL,

    -- GPU
    gpu_avg_pct                 REAL,
    gpu_peak_pct                REAL,

    -- Battery + Power
    battery_drain_pct           REAL,
    battery_drain_per_hour      REAL,
    battery_temp_max_c          REAL,
    mah_consumed                REAL,
    avg_power_mw                REAL,
    total_power_mwh             REAL,
    estimated_playtime_h        REAL,
    has_charging_period         INTEGER DEFAULT 0,

    -- Jank
    jank_total                  INTEGER,
    jank_small_total            INTEGER,
    jank_big_total              INTEGER,
    jank_ratio_total            INTEGER,
    jank_per_min                REAL,

    -- Network per-interface
    net_total_tx_kb             REAL,
    net_total_rx_kb             REAL,
    net_wifi_total_tx_kb        REAL,
    net_wifi_total_rx_kb        REAL,
    net_cellular_total_tx_kb    REAL,
    net_cellular_total_rx_kb    REAL,
    net_other_total_tx_kb       REAL,
    net_other_total_rx_kb       REAL,
    net_wifi_avg_kbps           REAL,
    net_cellular_avg_kbps       REAL,

    -- Thermal
    thermal_peak                INTEGER,

    -- Timing
    launch_complete_ms          INTEGER,
    duration_ms                 INTEGER
);

-- Screenshots (5 sizes — Section 5.12)
CREATE TABLE IF NOT EXISTS screenshots (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id      TEXT    NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    marker_id       INTEGER REFERENCES markers(id) ON DELETE SET NULL,
    timestamp       INTEGER NOT NULL,
    filepath        TEXT    NOT NULL,         -- screenshots/<session_id>/<ts>_<size>.jpg
    size_id         TEXT    NOT NULL,         -- 'SS0'|'SS1'|'SS2'|'SS3'|'SS4'
    width_px        INTEGER,
    height_px       INTEGER,
    file_size_bytes INTEGER
);

-- =========================================================================
-- v1.5 Tables
-- =========================================================================

-- Collections — named groups of sessions
CREATE TABLE IF NOT EXISTS collections (
    id          TEXT    PRIMARY KEY,           -- UUID
    name        TEXT    NOT NULL,
    description TEXT,
    color       TEXT,
    created_at  INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- =========================================================================
-- v2.0 Tables (Team server / Web dashboard / Detected Issues)
-- =========================================================================

-- Auto-detected issues (Section 6.9)
CREATE TABLE IF NOT EXISTS detected_issues (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id      TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    rule_id         TEXT NOT NULL,
    severity        TEXT NOT NULL,             -- informational|medium|high|critical
    metric          TEXT,
    observed_value  REAL,
    threshold_value REAL,
    message         TEXT NOT NULL,
    created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- Saved filters / views (Lenses — Section 22)
CREATE TABLE IF NOT EXISTS lenses (
    id          TEXT PRIMARY KEY,              -- UUID
    name        TEXT NOT NULL,
    owner_id    TEXT,                          -- user_id, NULL = global
    filters_json TEXT NOT NULL,                -- {"app":"com.foo","device_chipset":"sd8gen2",...}
    columns_json TEXT,                         -- which session_stats columns to display
    sort_by     TEXT,
    is_shared   INTEGER DEFAULT 0,
    created_at  INTEGER NOT NULL,
    updated_at  INTEGER NOT NULL
);

-- Notification channels (Email/Slack/Webhook — Section 23)
CREATE TABLE IF NOT EXISTS notification_channels (
    id            TEXT PRIMARY KEY,
    name          TEXT NOT NULL,
    kind          TEXT NOT NULL,               -- 'email'|'slack'|'webhook'|'jira'
    config_json   TEXT NOT NULL,               -- recipient list, webhook URL, slack webhook etc
    is_enabled    INTEGER DEFAULT 1,
    created_at    INTEGER NOT NULL
);

-- Alert rules (threshold-based — Section 23)
CREATE TABLE IF NOT EXISTS alerts (
    id                 TEXT PRIMARY KEY,
    name               TEXT NOT NULL,
    metric             TEXT NOT NULL,          -- 'fps_median'|'memory_peak_kb'|...
    operator           TEXT NOT NULL,          -- '<'|'>'|'<='|'>='|'=='
    threshold          REAL NOT NULL,
    scope_filter_json  TEXT,                   -- restrict to certain apps/devices
    channel_ids        TEXT NOT NULL,          -- JSON array of notification_channels.id
    is_enabled         INTEGER DEFAULT 1,
    created_at         INTEGER NOT NULL,
    updated_at         INTEGER NOT NULL
);

-- Alert firings (audit log of alerts that triggered)
CREATE TABLE IF NOT EXISTS alert_events (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    alert_id    TEXT NOT NULL REFERENCES alerts(id) ON DELETE CASCADE,
    session_id  TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    fired_at    INTEGER NOT NULL,
    value       REAL NOT NULL,
    delivered   INTEGER DEFAULT 0
);

-- API tokens (REST API access — Section 24)
CREATE TABLE IF NOT EXISTS api_tokens (
    id            TEXT PRIMARY KEY,
    user_id       TEXT,
    token_hash    TEXT NOT NULL UNIQUE,        -- sha256(token), never store plaintext
    label         TEXT,
    scopes        TEXT,                        -- JSON array ['read:sessions','write:sessions']
    expires_at    INTEGER,                     -- NULL = no expiry
    last_used_at  INTEGER,
    created_at    INTEGER NOT NULL
);

-- Team server: orgs / projects / users (v2.0)
CREATE TABLE IF NOT EXISTS team_orgs (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    created_at  INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS team_projects (
    id          TEXT PRIMARY KEY,
    org_id      TEXT NOT NULL REFERENCES team_orgs(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    created_at  INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS team_users (
    id              TEXT PRIMARY KEY,
    org_id          TEXT REFERENCES team_orgs(id) ON DELETE CASCADE,
    email           TEXT NOT NULL UNIQUE,
    display_name    TEXT,
    password_hash   TEXT,                      -- bcrypt; NULL if SSO-only
    role            TEXT NOT NULL,             -- 'owner'|'admin'|'member'|'viewer'
    sso_subject     TEXT,                      -- SAML subject, NULL if password-only
    is_active       INTEGER DEFAULT 1,
    created_at      INTEGER NOT NULL
);

-- =========================================================================
-- Indexes
-- =========================================================================

CREATE INDEX IF NOT EXISTS idx_samples_session_time   ON metric_samples(session_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_markers_session        ON markers(session_id);
CREATE INDEX IF NOT EXISTS idx_marker_stats_marker    ON marker_stats(marker_id);
CREATE INDEX IF NOT EXISTS idx_screenshots_session    ON screenshots(session_id);
CREATE INDEX IF NOT EXISTS idx_screenshots_size       ON screenshots(size_id);
CREATE INDEX IF NOT EXISTS idx_sessions_started       ON sessions(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_collection    ON sessions(collection_id);
CREATE INDEX IF NOT EXISTS idx_sessions_app_device    ON sessions(app_package, device_id);
CREATE INDEX IF NOT EXISTS idx_sessions_target_kind   ON sessions(target_kind);
CREATE INDEX IF NOT EXISTS idx_regions_session        ON regions(session_id);
CREATE INDEX IF NOT EXISTS idx_issues_session         ON detected_issues(session_id);
CREATE INDEX IF NOT EXISTS idx_issues_severity        ON detected_issues(severity);
CREATE INDEX IF NOT EXISTS idx_alerts_metric          ON alerts(metric);
CREATE INDEX IF NOT EXISTS idx_alert_events_alert     ON alert_events(alert_id);
CREATE INDEX IF NOT EXISTS idx_marker_groups_session  ON marker_groups(session_id);
CREATE INDEX IF NOT EXISTS idx_api_tokens_hash        ON api_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_team_users_email       ON team_users(email);

-- =========================================================================
-- Additional canonical tables (DDL defined in their respective sections)
-- =========================================================================
-- crashes        — see §27.2 (App crash records during session)
-- videos         — see §32.8 (Synced screen recordings)
-- reports        — see §22.5 (Generated PDF/HTML analysis reports)
-- audit_log      — see §24.5 (Sensitive-action audit trail)
-- All four are part of the canonical schema. Implementations MUST create them
-- per their section DDL. Indexes for these tables also defined inline.
```

**Migration strategy:** Version-based migration function. Each case applies one version. All migrations additive. `ALTER TABLE ADD COLUMN` for new columns. `CREATE TABLE IF NOT EXISTS` for new tables.

```
v1  → initial v1.0 full schema (all sample columns including cpu_cores, marker_groups, static_device_data, static_app_data, screenshots×5, crashes, videos placeholders)
v2  → v1.5: activate disk_io columns, collections, regions, detected_issues, parallel_group_id, videos
v3  → v2.0: lenses, alerts, alert_events, notification_channels, api_tokens, team_orgs/projects/users, audit_log, reports
v4  → v2.5: injector schema (Section 18.13), per-connection network stats columns
v5  → v3.0: tvOS + Windows PC target_kind extensions, PC-specific metric_samples columns (pc_handle_count, pc_thread_count, pc_page_faults_per_s, pc_gpu_dedicated_mem_kb, pc_gpu_shared_mem_kb)
v6  → v3.5: enterprise (SAML, Jira config, RBAC roles)
```

**Storage estimate:** ~50 columns × 1 sample/s × 10 min = ~30KB per session (most NULL columns compress well in SQLite). 1,000 sessions ≈ 30MB. Still negligible.

**Production mode (Section 21) reduces this to ~2KB/session** by storing only histograms, no per-second samples.

---

## Appendix D: ADB Command Reference

All commands invoked via `Process.run('adb', [...args])` with 3-second timeout. Null returned on timeout or non-zero exit. Session never crashes on individual metric failure.

| Metric | ADB Command | Parse Target |
|---|---|---|
| Device list | `adb devices -l` | Lines after header; parse serial + model |
| Installed apps | `adb shell pm list packages -3` | Strip `package:` prefix |
| Running PID | `adb shell pidof <package>` | First integer token |
| FPS + jank | `adb shell dumpsys SurfaceFlinger --latency "<layer>"` | Tab-separated timestamps; see Section 5.1 |
| CPU (combined) | `adb shell "cat /proc/<pid>/stat && echo --- && cat /proc/stat"` | Split on `---`; see Section 5.2 |
| CPU per-core (v1.0) | `adb shell cat /proc/stat` | Lines `cpu0`, `cpu1`, … |
| Memory PSS | `adb shell dumpsys meminfo <package>` | `TOTAL PSS:` line → KB |
| Battery | `adb shell dumpsys battery` | `level:`, `temperature:`, `voltage:` fields |
| Battery mA | `adb shell cat /sys/class/power_supply/battery/current_now` | µA integer ÷ 1000 |
| Battery voltage (precise) | `adb shell cat /sys/class/power_supply/battery/voltage_now` | µV integer ÷ 1000 |
| Network | `adb shell cat /proc/net/dev` | Per-interface TX/RX cumulative bytes |
| Thermal | `adb shell dumpsys thermalservice` | `Status` field 0–3 |
| GPU (Adreno) | `adb shell cat /sys/class/kgsl/kgsl-3d0/gpubusy` | `"busy total"` → % |
| GPU (Mali) | `adb shell cat /sys/class/misc/mali0/device/utilization` | Integer 0–100 |
| Disk I/O (v1.5) | `adb shell cat /proc/diskstats` | sda or mmcblk0 sector counts |
| Screenshot | `adb exec-out screencap -p` | PNG binary on stdout → save as JPEG |

**Battery mA sign convention:** `current_now` negative = discharging. Store absolute value. UI shows discharge icon.

**Network delta calculation:**
Store cumulative bytes in `metric_samples`. Compute delta at analytics time to avoid first-sample edge case:
`delta_kb_per_s = (current_cumulative - previous_cumulative) / 1024.0 / sample_interval_s`

**Layer name discovery strategy:**
1. Try exact package name as SurfaceFlinger layer
2. If no match: `dumpsys SurfaceFlinger` full output → find layer containing package name substring
3. Fallback: topmost visible layer (less accurate for multi-window)

---

## 18. Injector Tool Specification

> **Scope:** v2.5 (Android APK injection + overlay) and v3.0 (iOS IPA injection + overlay).
> **Separate repository:** `performancebench-injector` — standalone tool, NOT part of the main desktop app repo.
> **Host platforms:** Windows + macOS for Android injection. macOS only for iOS injection.
> **Philosophy:** Zero source code required. Works on any pre-built APK or IPA. Studio provides the binary; injector patches it.

---

### 18.1 Architecture Overview

```
performancebench-injector/
├── GUI app (Flutter desktop — same stack as main app)
│   ├── Drag-drop zone for APK / IPA / AAB
│   ├── Configuration panels (server URL, signing, overlay options)
│   ├── Progress console (live log output)
│   └── Inject button → triggers CLI pipeline
│
├── CLI tool (Dart, compiled to native binary: pbinject)
│   ├── pbinject android [OPTIONS] <input.apk> -o <output.apk>
│   └── pbinject ios     [OPTIONS] <input.ipa> -o <output.ipa>
│
├── android/
│   ├── sdk/           # PerformanceBenchSDK.aar (Kotlin/Java)
│   ├── overlay/       # FloatingOverlayService + OverlayView
│   └── patcher/       # apktool wrapper + smali patcher (Dart)
│
├── ios/
│   ├── sdk/           # PerformanceBench.framework (Swift/ObjC)
│   ├── overlay/       # MetalOverlayView + UIWindowOverlay
│   └── patcher/       # insert_dylib wrapper + codesign (Dart)
│
└── shared/
    ├── bridge/        # SDK ↔ desktop TCP bridge protocol
    └── signing/       # keystore + Apple ID signing logic
```

**Data flow after injection:**

```
Injected app running on device
  → SDK collects metrics (same v1.0 metric set as external, but higher fidelity + per-app network + WebView)
  → SDK sends newline-delimited JSON over local TCP socket (ADB port forward)
  → Main desktop app receives on localhost:27182
  → Same MetricSample pipeline → ring buffer → charts → SQLite
```

The main desktop app treats injected sessions identically to external ADB sessions — same UI, same storage, same analytics. The only difference: `session.profiling_mode = 'injected'` column distinguishes them.

---

### 18.2 Android SDK — What Gets Injected

**`PerformanceBenchSDK.aar`** — Kotlin library, ~1.5MB ARM64.

**Metrics the SDK collects that ADB external cannot:**
- FPS via `Choreographer.FrameCallback` — exact per-frame timestamps from rendering thread (more accurate than SurfaceFlinger dump)
- GPU % via `EGL_ANDROID_blob_cache` + hardware counters where available (Adreno, Mali)
- Per-thread CPU breakdown (`/proc/<pid>/task/<tid>/stat`)
- WebView / JS heap via `WebView.getMemoryInfo()` + JS bridge
- Per-connection network TX/RX + time-to-first-byte via `OkHttp` / `HttpUrlConnection` interceptors
- Draw calls (via `Canvas` and OpenGL ES intercept where available)
- GC pause times via `VMRuntime.getRuntime().gcCount()` delta
- Custom user markers: `PerformanceBench.beginMarker("boss_fight")` / `endMarker("boss_fight")`
- Auto-markers: `Activity.onResume` / `onPause` transitions

**Metrics that remain the same as external (ADB):**
- Battery %, mA, mV, temperature (still via `/sys` paths — SDK reads same files)
- Thermal status
- Network total TX/RX (cross-check with per-connection stats)

**SDK initialization (automatic after injection):**
- Uses `ContentProvider` with `android:initOrder="1000"` for zero-code init
- No `Application.onCreate()` override needed
- Reads config from `assets/pb_config.json` baked in at injection time

**`pb_config.json` fields baked into APK at injection time:**

| Field | Type | Description |
|---|---|---|
| `server_host` | string | Desktop app IP (default: `127.0.0.1` via ADB port forward) |
| `server_port` | int | TCP port (default: `27182`) |
| `sample_rate_ms` | int | Sampling interval (default: `1000`) |
| `overlay_enabled` | bool | Show FPS overlay on device |
| `overlay_position` | string | `"top_left"` / `"top_right"` / `"bottom_left"` / `"bottom_right"` |
| `overlay_style` | string | `"minimal"` / `"standard"` / `"detailed"` |
| `auto_session` | bool | Start session automatically when app foregrounds |
| `auto_markers` | bool | Insert Activity lifecycle markers automatically |
| `webview_memory` | bool | Enable WebView JS heap tracking |
| `screenshot_interval_s` | int | 0 = disabled (screenshots taken by desktop via ADB even in injected mode) |

---

### 18.3 Android APK Injection Pipeline

**Input:** Any `.apk` or `.aab` file.
**Output:** Re-signed `.apk` ready to install.

**Pipeline steps (in order — each step is a discrete, logged stage):**

#### Step 1: Validate Input

- Verify file is valid ZIP (APK is a ZIP)
- Extract `AndroidManifest.xml` via `apktool d --no-res` (decode resources lightly)
- Read: `package`, `versionCode`, `versionName`, `minSdkVersion`, `targetSdkVersion`
- Check `minSdkVersion ≥ 21` (SDK requires Android 5+)
- Check for split APK (`.aab` or split APK set) — handle bundled vs standalone
- **Fail fast:** if file is not a valid APK, report clearly and stop

#### Step 2: Decompile

```
apktool d -f -o <work_dir> <input.apk>
```

- `work_dir` = temp directory, cleaned up on success or failure
- Decodes: Smali bytecode, AndroidManifest.xml, resources (partially)
- Progress: log `[1/8] Decompiling APK...`

#### Step 3: Inject SDK Library

- Copy `PerformanceBenchSDK.aar` contents into `<work_dir>/lib/arm64-v8a/` and `lib/armeabi-v7a/` (if original APK has armeabi)
- Copy Java/Kotlin classes as pre-dexed `.dex` file into `<work_dir>/smali_classes3/` (new dex partition)
- Copy `pb_config.json` (pre-filled from GUI config) into `<work_dir>/assets/`
- Do NOT modify any existing Smali files — ContentProvider auto-init means no code changes needed
- Progress: log `[2/8] Injecting SDK libraries...`

#### Step 4: Patch AndroidManifest.xml

Add the following to `<application>` block in `AndroidManifest.xml`:

```xml
<!-- PerformanceBench SDK ContentProvider (auto-init) -->
<provider
    android:name="net.performancebench.sdk.PbInitProvider"
    android:authorities="${packageName}.pb_init"
    android:exported="false"
    android:initOrder="1000" />

<!-- PerformanceBench Overlay Service (if overlay_enabled) -->
<service
    android:name="net.performancebench.overlay.OverlayService"
    android:exported="false" />
```

Add permissions if not already present:
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />  <!-- overlay -->
<uses-permission android:name="android.permission.INTERNET" />
```

- `SYSTEM_ALERT_WINDOW`: required for floating overlay. App must request at runtime on Android 6+. SDK handles the runtime request dialog automatically.
- Progress: log `[3/8] Patching AndroidManifest.xml...`

#### Step 5: Overlay Injection (if `overlay_enabled`)

- Copy overlay assets: `<work_dir>/assets/pb_overlay/` containing fonts, config
- No additional Smali patching needed — `OverlayService` starts from `PbInitProvider`
- Progress: log `[4/8] Injecting overlay assets...`

#### Step 6: Rebuild APK

```
apktool b <work_dir> -o <unsigned.apk>
```

- `--use-aapt2` flag if original used aapt2 (detect from apktool.yml)
- Progress: log `[5/8] Rebuilding APK...`

#### Step 7: Align

```
zipalign -v 4 <unsigned.apk> <aligned.apk>
```

- Required before signing. Always run even if input was already aligned.
- Progress: log `[6/8] Aligning...`

#### Step 8: Sign

**Option A — Auto-generated debug keystore (default, easiest):**
```
keytool -genkey -v -keystore pb_debug.keystore -alias pb -keyalg RSA -keysize 2048 -validity 10000 -storepass pbdebug -keypass pbdebug -dname "CN=PerformanceBench"
apksigner sign --ks pb_debug.keystore --ks-key-alias pb --ks-pass pass:pbdebug --key-pass pass:pbdebug --out <output.apk> <aligned.apk>
```

**Option B — User-provided keystore (for cert-pinned apps):**
- User provides `.jks` or `.keystore` + alias + passwords
- `apksigner sign --ks <user.keystore> --ks-key-alias <alias> --ks-pass pass:<pw> --key-pass pass:<kpw> --out <output.apk> <aligned.apk>`

**Option C — v1 signature only (for Android 5–6 compatibility):**
- `jarsigner -keystore <ks> -storepass <pw> -keypass <kpw> <aligned.apk> <alias>`

- Progress: log `[7/8] Signing APK...`

#### Step 9: Verify + Install

```
apksigner verify --verbose <output.apk>
adb install -r -d <output.apk>
```

- `-r` = replace existing app
- `-d` = allow version downgrade (for re-injection after version bump)
- **Cert pinning warning:** if original app uses certificate pinning and user chose auto-generated keystore, show warning: "This app may reject network connections due to certificate pinning. Use original keystore."
- Progress: log `[8/8] Installing on device...`

**Failure handling:**
- Any step failure: log full error + suggestion, clean up temp dir, do not install
- Common errors and plain-language messages:

| Error | User message |
|---|---|
| `apktool` not found | "apktool not installed. Download from apktool.ibotpeaches.com and add to PATH." |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | "Uninstall the app first, then retry. (Different signature from installed version)" |
| `SYSTEM_ALERT_WINDOW` denied | "Overlay needs permission. Grant via Settings → Apps → [app] → Display over other apps." |
| Split APK input | "Split APKs detected. Merge with 'bundletool build-apks' first, then inject." |
| minSdk < 21 | "App targets Android < 5.0. SDK requires Android 5+. Cannot inject." |

---

### 18.4 Android Overlay Widget

The floating overlay widget appears on top of the app. It is a system window overlay (`WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY`).

#### Overlay Styles

**Minimal (default):**
```
┌────────┐
│ 58 fps │   ← monospace, white text on semi-transparent black pill
└────────┘
```
- Size: 80×28dp
- Font: monospace 14sp bold
- Background: `#CC000000` (80% black)
- Border radius: 14dp (fully rounded pill)
- No border

**Standard:**
```
┌───────────────┐
│ FPS  58  ◉14 │   ← fps value + jank dot indicator
│ CPU  23%      │
└───────────────┘
```
- Size: 120×52dp
- Two rows: FPS + jank tier badge, CPU%
- Jank badge: grey (◎ small), orange (◉ standard), red (⬤ big) — shows highest active tier
- Font: monospace 12sp

**Detailed:**
```
┌──────────────────────┐
│  FPS   58  ◉ 14/min  │
│  CPU   23%  MEM 512M │
│  GPU   41%  BAT  87% │
│  ↑1.1  ↓8.3  🌡 31°  │
└──────────────────────┘
```
- Size: 180×88dp
- Four rows of metrics
- All values update at 1Hz

#### Overlay Behavior

- **Draggable:** User can drag overlay to any screen position. Position saved to SharedPreferences per-app.
- **Tap to toggle:** Single tap cycles through: Minimal → Standard → Detailed → Hidden → Minimal
- **Long press:** Opens overlay settings mini-panel (change position preference, disable)
- **Rotation:** Overlay repositions correctly on device rotation
- **App foreground detection:** Overlay hidden automatically when PerformanceBench app is foregrounded; re-appears when game returns
- **ADB toggle:** `adb shell am broadcast -a net.performancebench.ACTION_OVERLAY_TOGGLE` — enables/disables overlay without tapping screen (useful for automated tests)
- **Color coding:** FPS text color changes by value: ≥55fps → green (`#4EC9B0`), 30–54 → orange (`#CE9178`), <30 → red (`#F44747`)
- **Transparency:** Overlay background transparency configurable in `pb_config.json` (`overlay_alpha`: 0.5–1.0)

#### Overlay Permission Flow (Android 6+)

On first launch after injection:
1. SDK detects `SYSTEM_ALERT_WINDOW` not granted
2. Shows one-time dialog: "PerformanceBench overlay needs permission to display over other apps."
3. Tapping "Grant" opens system settings page for this permission
4. User grants → overlay starts immediately
5. If denied: overlay disabled silently; SDK continues metric collection without overlay

---

### 18.5 iOS Framework Injection Pipeline

**Input:** Unencrypted `.ipa` file (from studio CI pipeline — NOT App Store download).
**Output:** Re-signed `.ipa` ready to install via `ios-deploy` or Xcode.
**Host:** macOS only.

**Hard requirement:** IPA must be a **development build or ad-hoc build** from Xcode. App Store IPAs are FairPlay encrypted — injection fails at Step 2 with a clear error.

**Pipeline steps:**

#### Step 1: Validate Input

- Verify `.ipa` is valid ZIP
- Extract `Payload/*.app/Info.plist`
- Read: `CFBundleIdentifier`, `CFBundleVersion`, `CFBundleExecutable`
- Check `CFBundleExecutable` binary is a Mach-O fat binary or ARM64 slice
- Check for FairPlay encryption: inspect `__LINKEDIT` segment for `cryptid != 0` → fail with message: "This IPA is encrypted by FairPlay (App Store download). Injection requires a development build from your Xcode project or CI pipeline."
- Progress: log `[1/7] Validating IPA...`

#### Step 2: Extract IPA

```
unzip -q <input.ipa> -d <work_dir>
```

- Working path: `<work_dir>/Payload/<AppName>.app/`
- Progress: log `[2/7] Extracting IPA...`

#### Step 3: Copy Framework

- Copy `PerformanceBench.framework/` into `<work_dir>/Payload/<AppName>.app/Frameworks/`
- Copy `pb_config.json` into `<work_dir>/Payload/<AppName>.app/`
- Progress: log `[3/7] Copying PerformanceBench.framework...`

#### Step 4: Inject Dylib Load Command

Uses `insert_dylib` tool (or equivalent Mach-O binary patching in Dart):

```
insert_dylib --strip-codesig --inplace '@rpath/PerformanceBench.framework/PerformanceBench' <work_dir>/Payload/<AppName>.app/<Executable>
```

- Adds `LC_LOAD_DYLIB` load command pointing to the framework
- `--strip-codesig`: removes existing code signature (will be replaced in Step 6)
- Alternative for Swift apps: patch `__DATA.__objc_classlist` to register `PbBootstrap` class if `insert_dylib` unavailable
- Progress: log `[4/7] Patching binary load commands...`

#### Step 5: Patch Info.plist

Add required keys if not present:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>PerformanceBench streams metrics to the desktop app over local network.</string>
<key>NSBonjourServices</key>
<array>
    <string>_pb-metrics._tcp</string>
</array>
```

- Progress: log `[5/7] Patching Info.plist...`

#### Step 6: Sign

**Option A — Apple ID (recommended, free, 7-day expiry):**
```
xcrun xcodebuild -exportArchive ... (via ios-deploy signing flow)
```
1. User provides Apple ID email + password (stored in macOS Keychain, not on disk)
2. Tool calls Apple's provisioning API to create ad-hoc provisioning profile for connected device UDID
3. Signs app + framework with resulting certificate
4. **7-day expiry** — must re-inject after 7 days. Show expiry date prominently in GUI.

**Option B — Local code signing assets (.p12 + .mobileprovision):**
- User provides `.p12` certificate + password + `.mobileprovision` file
- `openssl pkcs12 -in <cert.p12> -nocerts -nodes -out private.key`
- `security import private.key -k ~/Library/Keychains/login.keychain`
- `codesign -f -s "<identity>" --entitlements <entitlements.plist> <App.app>/Frameworks/PerformanceBench.framework`
- `codesign -f -s "<identity>" --entitlements <entitlements.plist> <App.app>`

**Entitlements required:**
```xml
<key>application-identifier</key>  <string><TEAM_ID>.<bundle_id></string>
<key>com.apple.developer.team-identifier</key>  <string><TEAM_ID></string>
<key>get-task-allow</key>  <true/>   ← required for debugging/profiling attachment
```

- Progress: log `[6/7] Signing application...`

#### Step 7: Package + Install

```
cd <work_dir> && zip -qr <output.ipa> Payload/
ios-deploy --bundle <work_dir>/Payload/<AppName>.app --no-wifi
```

- `ios-deploy` installs directly to connected device via USB
- Alternative: `cfgutil install-app <output.ipa>` if ios-deploy unavailable
- Progress: log `[7/7] Installing on device...`

**Failure handling:**

| Error | User message |
|---|---|
| FairPlay encryption detected | "App Store IPA detected. Provide a development/ad-hoc build from Xcode or your CI pipeline." |
| Apple ID 2FA required | "Two-factor authentication required. Enter the 6-digit code sent to your Apple device." |
| `get-task-allow` entitlement missing | "Provisioning profile does not allow profiling. Use a development profile with 'get-task-allow' enabled." |
| Device UDID not in provisioning profile | "Your device UDID is not registered in this provisioning profile. Re-inject with Apple ID to auto-register." |
| ios-deploy not found | "ios-deploy not installed. Run: brew install ios-deploy" |
| `.p12` algorithm incompatible | "Certificate uses unsupported algorithm. Export from Keychain with 'Legacy PKCS#12' option." |

---

### 18.6 iOS Framework — What Gets Injected

**`PerformanceBench.framework`** — Swift/ObjC framework, ~2MB ARM64.

**Auto-initialization:** Uses `+load` method on `PbBootstrap` Objective-C class. No app code changes needed. Runs before `main()`.

**Metrics collected (higher fidelity than pyidevice external):**
- FPS via `CADisplayLink` callback — exact per-frame timestamps from main render loop
- GPU via `MTLCommandBuffer.gpuStartTime` / `gpuEndTime` — % time GPU busy per command buffer
- CPU via `thread_info(THREAD_BASIC_INFO)` — per-thread breakdown, total app CPU
- Memory via `task_info(TASK_VM_INFO)` → `phys_footprint` (same as pyidevice, but lower overhead)
- Network per-connection: TX/RX bytes + time-to-first-byte via `NSURLProtocol` swizzle (intercepts `NSURLSession` + `NSURLConnection`)
- OpenGL ES / Metal draw calls via `MTLCommandBuffer` inspection
- Custom markers: `[PerformanceBench beginMarker:@"boss_fight"]` / `endMarker:`
- Auto-markers: `UIViewController viewDidAppear` transitions via method swizzle
- WebKit JS heap: `[WKWebView evaluateJavaScript:@"performance.memory.usedJSHeapSize" ...]`

**Data bridge:** Framework opens TCP socket to `127.0.0.1:27182` via usbmuxd USB tunnel. Desktop app sets up tunnel before session start:
```
iproxy 27182 27182 <udid>    (pymobiledevice3 or libimobiledevice)
```

---

### 18.7 iOS Overlay Widget

Implemented as a `UIWindow` at `UIWindowLevelAlert + 1` (above all app content, including navigation bars).

#### Overlay Styles (same 3 tiers as Android)

**Minimal:**
```
┌────────┐
│ 58 fps │
└────────┘
```

**Standard:**
```
┌─────────────┐
│ FPS  58 ◉14 │
│ CPU  23%    │
└─────────────┘
```

**Detailed:**
```
┌──────────────────┐
│ FPS  58  ◉14/min │
│ CPU  23%  MEM 128M│
│ GPU  41%  BAT  87%│
│ ↑1.2 ↓8.1  31°   │
└──────────────────┘
```

#### iOS-Specific Behavior

- **Gesture recognizer:** `UIPanGestureRecognizer` for drag, `UITapGestureRecognizer` for style cycle
- **Safe area:** respects `safeAreaInsets` — never overlaps notch or Dynamic Island
- **Rotation:** `UIDevice.orientationDidChangeNotification` → reposition to current corner preference
- **Screen recording detection:** `UIScreen.main.isCaptured` → optionally hide overlay during system screen recording
- **App switcher:** overlay hidden when app enters background (`UIApplication.willResignActiveNotification`)
- **SwiftUI apps:** UIWindow overlay approach works regardless of whether app uses UIKit or SwiftUI
- **ADB toggle not available on iOS:** use HTTP endpoint instead: `POST http://localhost:27183/overlay/toggle` (framework runs mini HTTP server on port 27183 for test automation)
- **Permission:** No special iOS permission required for UIWindow overlay at `UIWindowLevelAlert` — works without entitlements

---

### 18.8 Data Bridge Protocol (SDK ↔ Desktop)

Both Android and iOS SDKs stream metric data to the desktop app over a local TCP socket via ADB port forward (Android) or usbmuxd tunnel (iOS).

**Port:** `27182` (default, configurable in `pb_config.json`)

**Protocol:** Newline-delimited JSON (same format as `collector.py` stdout — allows shared parsing code in desktop app)

**Message types:**

```
{"type":"hello","sdk_version":"1.0","platform":"android","package":"com.example.game","session_id":"<uuid>"}
{"type":"metrics","ts":1705123456789,"fps":58.3,"jank_small":2,"jank":0,"jank_big":0,"cpu":23.4,"mem_bytes":536870912,"bat_pct":87,"bat_ma":-328.4,"bat_mv":3890.0,"bat_temp_c":31.2,"net_tx":10240,"net_rx":81920,"thermal":0,"gpu_pct":41.2}
{"type":"marker_start","ts":1705123460000,"label":"boss_fight","group":"gameplay"}
{"type":"marker_stop","ts":1705123508000,"label":"boss_fight"}
{"type":"launch_complete","ts":1705123461200}
{"type":"draw_calls","ts":1705123456789,"draw_calls":142,"set_pass_calls":18,"triangles":89402}
{"type":"thread_cpu","ts":1705123456789,"threads":[{"tid":12345,"name":"UnityMain","cpu_pct":18.2},{"tid":12346,"name":"UnityGfx","cpu_pct":12.1}]}
{"type":"network_connection","ts":1705123456789,"remote_ip":"52.86.12.3","tx_bytes":2048,"rx_bytes":16384,"ttfb_ms":142}
{"type":"gc","ts":1705123456789,"gc_count_delta":2,"gc_pause_ms":8}
{"type":"bye","reason":"app_backgrounded"}
```

**Desktop app behavior on each message type:**
- `hello`: log connection, store session_id, set `session.profiling_mode = 'injected'`
- `metrics`: same as external MetricSample; feeds ring buffer + charts
- `marker_start` / `marker_stop`: insert `markers` rows; trigger marker_stats computation on stop
- `launch_complete`: insert special `__launch_complete__` marker
- `draw_calls`: store in separate `draw_call_samples` table (v2.5 schema addition)
- `thread_cpu`: store in `thread_cpu_samples` table (v2.5 schema addition)
- `network_connection`: store in `network_connections` table (v2.5 schema addition)
- `gc`: store in `metric_samples.gc_count` and `gc_pause_ms` columns (v2.5 schema addition)
- `bye`: mark session end; trigger full analytics computation

**Reconnect behavior:**
- Desktop app retries TCP connect every 2 seconds if connection drops
- SDK retries TCP connect every 5 seconds if desktop not listening
- Sessions survive brief disconnects (≤30s) — samples during disconnect stored by SDK, flushed on reconnect as a batch
- `bye` message always sent before SDK shuts down cleanly

**ADB port forward setup (Android):**
```
adb -s <serial> forward tcp:27182 tcp:27182
```
Desktop app runs this automatically when starting an injected session. Tears down on session stop.

**iOS tunnel setup:**
```
python3 -m pymobiledevice3 usbmux forward 27182 27182
```
Desktop app spawns this as a subprocess. Requires `pymobiledevice3` installed (`pip3 install pymobiledevice3`).

---

### 18.9 Injector GUI Specification

**Separate Flutter desktop app** — same design system as main app (Section 9 colors, fonts, layout). Ships as part of the `performancebench-injector` repository.

```
┌──────────────────────────────────────────────────────────────────────┐
│ PerformanceBench Injector                              v1.0  [─][□][×]│
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│   ┌─────────────────────────────────────────────────────────────┐    │
│   │                                                             │    │
│   │          Drop APK / IPA / AAB here                          │    │
│   │                                                             │    │
│   │              or  [Browse File]                              │    │
│   │                                                             │    │
│   └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
│   ┌─ LOADED: com.example.game v1.4.2 (APK, ARM64+ARM32, 87MB) ─────┐ │
│   │  Min SDK: 26 (Android 8)   Target SDK: 34 (Android 14)         │ │
│   └────────────────────────────────────────────────────────────────┘ │
│                                                                       │
│   ┌─ CONFIGURATION ───────────────────────────────────────────────┐  │
│   │  Desktop app address:  [127.0.0.1]  Port: [27182]             │  │
│   │  ─────────────────────────────────────────────────────────    │  │
│   │  Overlay:    [● On]   Style: [Standard ▾]                     │  │
│   │  Position:   [Top Right ▾]   Alpha: [80% ─────●──── ]        │  │
│   │  ─────────────────────────────────────────────────────────    │  │
│   │  Auto session:   [● On]    Auto markers:   [● On]             │  │
│   │  WebView memory: [○ Off]   Sample rate:    [1s ▾]             │  │
│   └────────────────────────────────────────────────────────────────┘  │
│                                                                       │
│   ┌─ SIGNING ─────────────────────────────────────────────────────┐  │
│   │  [● Auto (debug keystore)]  [○ Custom keystore]               │  │
│   │                                                               │  │
│   │  Custom keystore:  [Browse .jks file]  _____________________  │  │
│   │  Alias:            [_______________]   Password: [•••••••••]  │  │
│   └────────────────────────────────────────────────────────────────┘  │
│                                                                       │
│   ┌─ OUTPUT ──────────────────────────────────────────────────────┐  │
│   │  [● Install directly on connected device]                     │  │
│   │  [○ Save to file: /Users/me/Desktop/game_pb.apk  [Browse]]   │  │
│   └────────────────────────────────────────────────────────────────┘  │
│                                                                       │
│   [■■■■■■■■■■■■■■■■░░░░░░░░░░░░░░░░]  Step 3/8: Injecting SDK...    │
│                                                                       │
│   ┌─ LOG ──────────────────────────────────────────────────────────┐  │
│   │  [1/8] Validating APK...                          ✓ 0.1s      │  │
│   │  [2/8] Decompiling APK...                         ✓ 4.2s      │  │
│   │  [3/8] Injecting SDK libraries...                 ⟳           │  │
│   └────────────────────────────────────────────────────────────────┘  │
│                                                                       │
│                                    [Cancel]  [▶ Inject & Install]     │
└──────────────────────────────────────────────────────────────────────┘
```

**Behavior:**
- Drag-drop zone: accepts `.apk`, `.ipa`, `.aab`. Rejects anything else with clear message.
- On file load: immediately parse and display app info (package, version, SDK range, size, ABI list)
- Configuration panels: collapsed by default, expand with chevron
- Signing section: switches form fields based on radio selection
- Progress bar: animates through steps; each step logs completion time
- Log area: monospace font, auto-scrolls to bottom, copyable
- "Inject & Install" button: disabled until valid file loaded; shows spinner during injection
- Cancel: kills current pipeline step cleanly, cleans up temp files
- On success: green banner "✓ Installed on Pixel 8 Pro. Session auto-starts when app launches." + "Open in PerformanceBench" button

**iOS-specific additional panel (shown when IPA detected):**

```
┌─ iOS SIGNING ───────────────────────────────────────────────────────┐
│  [● Apple ID (free, 7-day expiry)]  [○ Code signing assets]         │
│                                                                      │
│  Apple ID:   [user@example.com  ]                                   │
│  Password:   [••••••••••••••••• ]  (stored in macOS Keychain)       │
│  Team:       [Personal Team (ABC123DE) ▾]   (auto-detected)         │
│                                                                      │
│  Connected device:  iPhone 15 (UDID: abc123...)  [Refresh]          │
│                                                                      │
│  ⚠ Certificate expires in 7 days. Re-inject on 2024-01-22.          │
└──────────────────────────────────────────────────────────────────────┘
```

---

### 18.10 Injector CLI (`pbinject`)

Compiled Dart native binary. Ships alongside GUI. Used for CI/CD pipelines.

**Usage:**

```
pbinject android [OPTIONS] <input.apk> -o <output.apk>
pbinject ios     [OPTIONS] <input.ipa> -o <output.ipa>
pbinject android --install [OPTIONS] <input.apk>      # inject + adb install directly
pbinject ios     --install [OPTIONS] <input.ipa>      # inject + ios-deploy directly
```

**Android options:**

| Flag | Default | Description |
|---|---|---|
| `--server-host` | `127.0.0.1` | Desktop app host |
| `--server-port` | `27182` | Desktop app port |
| `--overlay` | `true` | Enable FPS overlay |
| `--overlay-style` | `minimal` | `minimal` / `standard` / `detailed` |
| `--overlay-position` | `top_right` | `top_left` / `top_right` / `bottom_left` / `bottom_right` |
| `--auto-session` | `true` | Auto start session on foreground |
| `--auto-markers` | `true` | Auto Activity lifecycle markers |
| `--webview-memory` | `false` | WebView JS heap tracking |
| `--sample-rate` | `1000` | Sampling interval ms |
| `--keystore` | — | Path to `.jks` keystore (omit = auto debug) |
| `--keystore-alias` | — | Keystore alias |
| `--keystore-pass` | — | Keystore password |
| `--key-pass` | — | Key password |
| `--device` | first connected | ADB device serial for `--install` |
| `--verbose` | `false` | Full pipeline logging |

**iOS options:**

| Flag | Default | Description |
|---|---|---|
| `--server-host` | `127.0.0.1` | Desktop app host |
| `--server-port` | `27182` | Desktop app port |
| `--overlay` | `true` | Enable FPS overlay |
| `--overlay-style` | `minimal` | `minimal` / `standard` / `detailed` |
| `--apple-id` | — | Apple ID email |
| `--apple-password` | — | Apple ID password (use `@keychain:name` for Keychain reference) |
| `--team-id` | auto | Apple Team ID |
| `--p12` | — | Path to `.p12` certificate (alternative to Apple ID) |
| `--p12-password` | — | `.p12` password |
| `--mobileprovision` | — | Path to `.mobileprovision` |
| `--udid` | first connected | iOS device UDID for `--install` |
| `--verbose` | `false` | Full pipeline logging |

**CI/CD example (Android):**

```bash
# In CI after APK build:
pbinject android \
  --server-host 192.168.1.100 \
  --overlay-style minimal \
  --keystore /secrets/release.jks \
  --keystore-alias release \
  --keystore-pass "$KEYSTORE_PASS" \
  --key-pass "$KEY_PASS" \
  --install \
  build/app-release.apk

# Desktop app then starts a session automatically when the injected app launches.
# REST API (v2.0) can trigger session start/stop programmatically from CI.
```

**Exit codes:**

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Input file invalid / not found |
| 2 | FairPlay encryption detected (iOS) |
| 3 | Decompile failed (apktool error) |
| 4 | Signing failed |
| 5 | Install failed (ADB / ios-deploy error) |
| 6 | Missing dependency (apktool / zipalign / ios-deploy not found) |

---

### 18.11 Required External Tools (Injector Dependencies)

**Android:**

| Tool | Install | Purpose |
|---|---|---|
| `apktool` | `brew install apktool` / download JAR | APK decompile + rebuild |
| `zipalign` | Part of Android SDK build-tools | APK alignment |
| `apksigner` | Part of Android SDK build-tools | APK signing |
| `keytool` | Part of JDK | Debug keystore generation |
| `adb` | Android SDK Platform-tools | Device installation |

**iOS (macOS only):**

| Tool | Install | Purpose |
|---|---|---|
| `insert_dylib` | `brew install insert_dylib` | Mach-O load command injection |
| `ios-deploy` | `brew install ios-deploy` | IPA installation to device |
| `pymobiledevice3` | `pip3 install pymobiledevice3` | USB tunnel for data bridge |
| Xcode CLI tools | `xcode-select --install` | codesign, plist tools |

**At injector startup:** Check all required tools for current injection type. If any missing: show install instructions before allowing injection attempt (not after a failed pipeline run).

---

### 18.12 Injector File Structure

```
performancebench-injector/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── pipeline/
│   │   │   ├── android_pipeline.dart      # Steps 1-9 for APK
│   │   │   ├── ios_pipeline.dart          # Steps 1-7 for IPA
│   │   │   ├── pipeline_step.dart         # Step interface + result type
│   │   │   └── dependency_checker.dart    # Tool availability check
│   │   ├── signing/
│   │   │   ├── android_signer.dart        # apksigner wrapper
│   │   │   ├── ios_signer.dart            # codesign + Apple ID flow
│   │   │   └── keystore_manager.dart      # .jks create/load/validate
│   │   ├── patching/
│   │   │   ├── apktool_wrapper.dart       # apktool subprocess wrapper
│   │   │   ├── manifest_patcher.dart      # XML patching
│   │   │   ├── insert_dylib_wrapper.dart  # Mach-O patching
│   │   │   └── plist_patcher.dart         # Info.plist patching
│   │   └── bridge/
│   │       ├── adb_forwarder.dart         # ADB port forward setup
│   │       └── ios_tunnel.dart            # pymobiledevice3 tunnel
│   └── features/
│       ├── injector_screen.dart           # Main GUI
│       ├── config_panel.dart              # Configuration form
│       ├── signing_panel.dart             # Signing options
│       ├── progress_console.dart          # Log + progress bar
│       └── app_info_card.dart             # Loaded APK/IPA info
├── bin/
│   └── pbinject.dart                      # CLI entry point
├── sdk/
│   ├── android/
│   │   └── PerformanceBenchSDK.aar        # Pre-built (built from sdk-android repo)
│   └── ios/
│       └── PerformanceBench.framework/    # Pre-built (built from sdk-ios repo)
├── test/
│   ├── pipeline_test.dart
│   ├── manifest_patcher_test.dart
│   └── plist_patcher_test.dart
└── pubspec.yaml
```

---

### 18.13 Additional Schema Tables (v2.5)

These tables are added to the **main desktop app SQLite DB** (migration v3) when the desktop app processes injected session data.

```sql
-- Per-connection network stats (from SDK bridge 'network_connection' messages)
CREATE TABLE IF NOT EXISTS network_connections (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id   TEXT    NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    timestamp    INTEGER NOT NULL,
    remote_ip    TEXT    NOT NULL,
    tx_bytes     INTEGER NOT NULL DEFAULT 0,
    rx_bytes     INTEGER NOT NULL DEFAULT 0,
    ttfb_ms      REAL,               -- time to first byte, nullable
    protocol     TEXT                -- 'https', 'http', 'tcp', 'udp'
);

-- Draw calls per sample (from SDK 'draw_calls' messages)
CREATE TABLE IF NOT EXISTS draw_call_samples (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id   TEXT    NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    timestamp    INTEGER NOT NULL,
    draw_calls   INTEGER,
    set_pass_calls INTEGER,
    triangles    INTEGER,
    batches      INTEGER
);

-- Thread CPU breakdown (from SDK 'thread_cpu' messages)
CREATE TABLE IF NOT EXISTS thread_cpu_samples (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id   TEXT    NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    timestamp    INTEGER NOT NULL,
    thread_data  TEXT    NOT NULL    -- JSON array: [{"tid":123,"name":"UnityMain","cpu_pct":18.2}]
);

-- GC events (from SDK 'gc' messages)
-- Stored in metric_samples via two new columns (migration v3):
-- ALTER TABLE metric_samples ADD COLUMN gc_count_delta INTEGER;
-- ALTER TABLE metric_samples ADD COLUMN gc_pause_ms REAL;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_netconn_session ON network_connections(session_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_drawcall_session ON draw_call_samples(session_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_thread_cpu_session ON thread_cpu_samples(session_id, timestamp);
```

---

### 18.14 Acceptance Criteria — Injector

**Android APK injection:**
- [ ] Valid APK in → injected APK installs successfully on Pixel 8 (Android 14)
- [ ] Injected app launches → desktop app receives `hello` message within 3 seconds
- [ ] Metrics stream at 1Hz → 60 samples in 60 seconds (±2)
- [ ] FPS overlay appears on device within 2 seconds of app foreground
- [ ] Overlay drag + position saved → survives app restart
- [ ] Overlay tap cycles: minimal → standard → detailed → hidden → minimal
- [ ] `marker_start` message received → marker row inserted in desktop DB
- [ ] App backgrounds → `bye` message received → session stats computed
- [ ] FairPlay IPA dropped on GUI → error shown in <1 second, no pipeline started
- [ ] Missing `apktool` → clear install instructions shown, inject button disabled
- [ ] CLI `pbinject android --install app.apk` → exits 0, app installed, overlay visible

**iOS IPA injection (macOS):**
- [ ] Valid development IPA + Apple ID → installs on iPhone 15 (iOS 17)
- [ ] 7-day expiry warning shown on GUI and in `pbinject --verbose` output
- [ ] USB tunnel established → metrics stream at 1Hz
- [ ] FPS overlay respects safe area (no overlap with Dynamic Island on iPhone 15)
- [ ] HTTP toggle endpoint works: `POST localhost:27183/overlay/toggle` → overlay hides/shows
- [ ] App Store IPA → error "FairPlay encrypted" at Step 1 before any processing

---

## 19. Windows PC Target Profiling (v3.0)

> **Scope:** PB profiles Windows PC games as a **target** (Win/Mac/Linux still hosts). GameBench has Studio Pro Desktop. PB matches via Win32 PDH + ETW. Zero $ — all native APIs.

### 19.1 Architecture

```
PB Desktop (host) ──[local IPC]──► pb-pcprobe.exe (target)
                                    ├─ PDH counters (CPU, mem, disk, net, GPU)
                                    ├─ ETW session (frame timing low-overhead)
                                    └─ DXGI hooking (FPS via Present() interception)
```

`pb-pcprobe.exe` = small Rust agent installed on target PC. Connects to PB host via TCP `127.0.0.1:27184` (or LAN). Streams 1Hz samples + raw frametimes.

Same-machine mode: probe + host on one PC; uses named pipe `\\.\pipe\pb-pcprobe`.

### 19.2 PDH Counters

| Metric | PDH Path |
|---|---|
| CPU process % | `\Process(<exe>)\% Processor Time` ÷ logical core count |
| CPU per-core | `\Processor(0..N)\% Processor Time` |
| Working set | `\Process(<exe>)\Working Set` |
| Private bytes | `\Process(<exe>)\Private Bytes` |
| Page faults/s | `\Process(<exe>)\Page Faults/sec` |
| Disk read/s | `\Process(<exe>)\IO Read Bytes/sec` |
| Disk write/s | `\Process(<exe>)\IO Write Bytes/sec` |
| Network rx/tx | `\Network Interface(*)\Bytes Received/sec` + `\Bytes Sent/sec` |
| Thread count | `\Process(<exe>)\Thread Count` |
| Handle count | `\Process(<exe>)\Handle Count` |
| GPU usage | `\GPU Engine(*engtype_3D)\Utilization Percentage` |
| GPU dedicated mem | `\GPU Process Memory(*)\Dedicated Usage` |
| GPU shared mem | `\GPU Process Memory(*)\Shared Usage` |

PDH access via `windows-rs` crate (`Windows::Win32::System::Performance`). Counters opened once per session, queried at 1Hz.

### 19.3 FPS via DXGI Present Hook

For DX11/12 games: hook `IDXGISwapChain::Present` to log timestamp on every frame. Two methods:

**Method A — In-game DLL injection (preferred):**
- `pb-pcprobe-dx.dll` injected via `CreateRemoteThread` + `LoadLibrary`.
- Hooks `Present` via Microsoft Detours (free, MIT).
- Per-frame `QueryPerformanceCounter()` → write to shared memory ring buffer.
- Probe agent reads ring buffer 60×/s → emits frametimes_json each second.

**Method B — PresentMon (fallback, no injection):**
- Microsoft's PresentMon uses ETW provider `Microsoft-Windows-DxgKrnl`.
- No injection, no game modification.
- Slightly higher overhead; usable for closed games.
- PB ships PresentMon binary (MIT license) in `tools/presentmon/`.

User chooses in Settings: "Hook injection (low overhead)" or "ETW only (no injection)".

### 19.4 Frame Timing via ETW

Low-overhead alternative for **non-DX games** (Vulkan/OpenGL):
- ETW provider `Microsoft-Windows-D3D9` for DX9
- ETW provider `Microsoft-Windows-DxgKrnl` for DXGI events (fired regardless of API)
- Emit one `metric_samples` row/s with `fps`, `frametimes_json`, `frame_ratio_jank_count`

### 19.5 GPU Vendor Counters (Optional v3.5)

| Vendor | API | Notes |
|---|---|---|
| NVIDIA | NVAPI / NVML | GPU clock, mem clock, temp, power draw — free SDK |
| AMD | ADL / AGS | Similar |
| Intel | Intel GPA frame analyzer SDK | Free |

Wire as plugins; ship with NVAPI by default.

### 19.6 Schema Mapping

Re-use existing `metric_samples` columns. `target_kind = 'windows_pc'` on session row. iOS-only fields stay NULL.

PC-specific fields added to `metric_samples`:
| Column | Type | Notes |
|---|---|---|
| `pc_handle_count` | INTEGER | Win32 handle count |
| `pc_thread_count` | INTEGER | Active thread count |
| `pc_page_faults_per_s` | REAL | |
| `pc_gpu_dedicated_mem_kb` | INTEGER | |
| `pc_gpu_shared_mem_kb` | INTEGER | |

### 19.7 Probe Agent Spec

`pb-pcprobe.exe`:
- Rust binary, ≤ 5 MB compiled
- Runs as user process (no admin) — PDH user counters require it; admin only for ETW kernel session
- Self-elevates if user opts into ETW frame timing
- Auto-discovers PB host via mDNS / Bonjour (Bonjour Services for Windows)
- Falls back to manual `--host 192.168.1.10:27184`

### 19.8 Acceptance Criteria

- [ ] Notepad.exe → CPU/mem/disk samples flowing within 2s of probe attach
- [ ] DX12 sample game → FPS + frametimes match in-game frame counter ±2%
- [ ] PresentMon mode → no game modification, FPS captured for any DXGI app
- [ ] GPU% from PDH within 5% of MSI Afterburner reference reading
- [ ] Probe runs without admin → PDH metrics work, ETW frame timing requires admin (clear UI message)

---

## 20. Strict Testing Mode (v1.0)

GameBench feature: enforce reproducible test conditions. PB matches.

### 20.1 What Strict Mode Locks

| Setting | Value | ADB Command |
|---|---|---|
| Screen brightness | 50% (configurable 25/50/75/100) | `settings put system screen_brightness 127` |
| Auto-brightness | Off | `settings put system screen_brightness_mode 0` |
| Media volume | 50% (configurable) | `media volume --set 7` (out of 15 typically) |
| Battery range | 70%–98% | refuse session start outside |
| Charging | Disconnected | refuse if `charging = true` at start |
| Do Not Disturb | On | `cmd notification set_dnd on` |
| Airplane mode | Optional toggle | `settings put global airplane_mode_on 1` + broadcast |
| Display timeout | Max (30 min) | `settings put system screen_off_timeout 1800000` |

### 20.2 Pre-Session Validation

```
Before session start, in strict mode:
  current_pct = battery_pct
  if current_pct < 70 or current_pct > 98:
    abort with message "Battery must be 70-98% (current: X%). Charge or discharge first."
  if charging:
    abort "Disconnect charger before starting strict session."
  if thermal_status >= 1:
    warn "Device thermal: <STATUS>. Recommend cooling before session."
```

### 20.3 Restoration on Session End

Original values captured before lock → restored on session stop or app crash. Stored in `sessions.strict_restore_json`:
```json
{"brightness":89,"auto_brightness":1,"volume":11,"dnd":0,"timeout":60000}
```

### 20.4 Strict Mode Schema

`sessions.strict_mode INTEGER DEFAULT 0`
`sessions.strict_config_json TEXT` — locked values used
`sessions.strict_restore_json TEXT` — pre-lock state
`sessions.strict_violations_json TEXT` — any drift detected mid-session (battery <70%, etc.)

### 20.5 UI

Settings → "Strict Testing":
- ☑ Enable Strict Mode by default
- Brightness lock: [25%][50%][75%][100%]
- Volume lock: [0%][25%][50%][75%][100%]
- Battery range: [60-99%] [70-98%] (recommended) [80-95%]
- ☑ Toggle Airplane mode
- ☑ Disable notifications (DND)

Active session badge: `[STRICT]` red badge in title bar when active.

### 20.6 Acceptance Criteria

- [ ] Strict on, battery 50% → session refuses to start, clear error
- [ ] Strict on, brightness=89 pre-session → set to 127 at start, restored to 89 at stop
- [ ] Strict on, app crash mid-session → restoration still runs (atexit handler)
- [ ] Strict on, charger plugged mid-session → flagged in `strict_violations_json`, session continues with warning

---

## 21. Production vs Non-Production Mode

GameBench SDK distinguishes Production (low overhead, prod builds) vs Non-Production (full data, dev builds). PB mirrors.

### 21.1 Production Mode

**Storage:** Only histograms + final session_stats. **No** per-second `metric_samples` rows.

**What gets stored:**
- `session_stats` (full row)
- FPS histogram (already JSON)
- Memory histogram (5KB buckets)
- CPU histogram (5% buckets)
- 1 screenshot per minute max (SS3 size — 12.5%)
- `markers` rows (still full fidelity)
- `marker_stats` (computed from in-memory ring before discard)
- `static_device_data` + `static_app_data`
- `detected_issues`

**What does NOT get stored:**
- `metric_samples` rows
- `frametimes_json`
- `cpu_threads_top_json`
- Raw screenshots > 1/min

**Storage:** ~2 KB/session vs ~30 KB/session. Acceptable for production telemetry at scale.

**Use case:** App in user's hands; PB SDK injected; opt-in user telemetry.

### 21.2 Non-Production Mode (Default)

Full per-second sampling, all columns, all screenshots. v1.0 default. Use case: dev/QA testing.

### 21.3 Mode Selection

`sessions.production_mode INTEGER 0/1`. Set at session start. Cannot toggle mid-session.

GUI: Settings → "Recording Mode" radio:
- ◉ Non-Production (full detail, dev/QA)
- ◯ Production (histogram-only, low overhead)

Injector tool: `pbinject android --mode production app.apk` writes `production_mode=1` constant into SDK config.

### 21.4 Histogram Compute Path

In-memory ring buffer (last 60s of samples) → on each sample arrival, increment histogram bucket counter; do NOT write row to SQLite. On session end: write final histograms only.

### 21.5 Acceptance Criteria

- [ ] Production mode 1h session → `metric_samples` count = 0
- [ ] Production mode 1h session → `session_stats` populated, `fps_histogram` non-empty
- [ ] Non-prod 1h session → ~3600 `metric_samples` rows
- [ ] Switching mode mid-session refused — UI shows "Stop session first"

---

## 22. Trends, Lenses, Detected Issues, Analysis Reports (v2.0)

GameBench Studio web dashboard headline features. PB matches in self-hosted web dashboard.

### 22.1 Trends Explorer

**Purpose:** Multi-session line charts of any metric over time, grouped by app/device/build.

**UI:**
- X-axis: session timeline (chronological) or build version
- Y-axis: chosen KPI (fps_median, mem_peak_kb, mah_consumed, jank_per_min, etc.)
- Series: grouped by `app_package` or `device_id` or `tags_kv_json` key
- Filter chips: device chipset, OS version, target FPS, has marker X
- Annotation: red dot when `detected_issues` row exists for that session

**Backend:**
```sql
SELECT s.id, s.started_at, ss.<metric>
FROM sessions s
JOIN session_stats ss ON ss.session_id = s.id
WHERE <filters>
ORDER BY s.started_at;
```

**Export:** Trend CSV + PNG chart.

### 22.2 Lenses (Saved Views)

**Purpose:** Saved filter+columns combos. Reusable. Shareable across team.

**Schema:** `lenses` table (Section 8).

**Lens definition:**
```json
{
  "name": "Pixel 8 Boss Fights — Last 30 days",
  "filters": {
    "device_model": "Pixel 8",
    "tags_kv": {"level": "boss"},
    "started_after": "2026-03-29T00:00:00Z"
  },
  "columns": ["fps_median","fps_1pct_low","mem_peak_kb","mah_consumed"],
  "sort_by": "started_at DESC"
}
```

**UI:**
- Web dashboard "Lenses" sidebar
- Click → loads sessions list filtered + columns customized
- Owner can ☑ "Share with team" → visible to all org members
- Org admin can pin Lenses to top of nav

### 22.3 Detected Issues Dashboard

**Purpose:** Top-level tile showing currently flagged issues across all sessions.

**Implementation:** Reads `detected_issues` table (Section 6.9). Groups by `rule_id`. Severity color-coded.

**UI:**
```
┌─ Detected Issues ──────────────────┐
│ 🔴 14 LOW_FPS                      │
│ 🟠 9 FPS_REGRESSION                │
│ 🟠 6 MEMORY_LEAK_SUSPECTED         │
│ 🟡 22 HIGH_VARIABILITY             │
│ ─────────────────────────────────── │
│ Click any to filter sessions list  │
└────────────────────────────────────┘
```

### 22.4 Analysis Reports

**Purpose:** Multi-session PDF/HTML report. GameBench calls this "Analysis".

**Generation:**
- Pick 2+ sessions OR a Lens
- Pick template: "Build comparison" / "Device matrix" / "Regression analysis" / "Custom"
- Output: PDF via `wkhtmltopdf` (free, GPL) or HTML page

**PDF sections:**
1. Cover (app + date range + device list)
2. Executive summary (KPI deltas vs baseline)
3. Per-metric trend charts
4. Detected issues summary
5. Per-session detail pages
6. Static device/app data appendix

**REST endpoint:** `POST /api/reports body: {lens_id, template_id, format: 'pdf'|'html'}` → returns 202 + report ID; `GET /api/reports/:id` polls; `GET /api/reports/:id/download` streams.

### 22.5 Schema

`reports` table (v2.0):
```sql
CREATE TABLE reports (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    template_id     TEXT NOT NULL,
    lens_id         TEXT REFERENCES lenses(id) ON DELETE SET NULL,
    session_ids     TEXT,                  -- JSON array
    status          TEXT NOT NULL,         -- 'queued'|'rendering'|'done'|'failed'
    output_path     TEXT,
    created_by      TEXT,
    created_at      INTEGER NOT NULL,
    completed_at    INTEGER
);
```

### 22.6 Acceptance Criteria

- [ ] Trends Explorer renders chart for `fps_median` across 50 sessions in <2s
- [ ] Save Lens → reload → filters + columns persist exactly
- [ ] Shared Lens visible to org members; private Lens not
- [ ] PDF report renders with charts in <30s for 10-session input
- [ ] Detected Issues tile counts match `detected_issues` GROUP BY rule_id

---

## 23. Notifications & Alerts (v2.0)

GameBench: email + Slack + webhook + Jira on threshold breach. PB matches free via SMTP/webhooks.

### 23.1 Notification Channels

| Kind | Config keys |
|---|---|
| `email` | `smtp_host`, `smtp_port`, `smtp_user`, `smtp_pass`, `from_addr`, `recipients[]`, `tls` |
| `slack` | `webhook_url` (Slack Incoming Webhook URL) |
| `webhook` | `url`, `method` (POST default), `headers`, `auth_token` |
| `jira` | (v3.5 only) `base_url`, `email`, `api_token`, `project_key`, `issue_type` |

Stored in `notification_channels` table. `config_json` encrypted at rest with key from `~/.performancebench/key`.

### 23.2 Alert Rules

`alerts` table (Section 8). Rule examples:

```
fps_median < 30        → channels: ['email-team','slack-perf']
mem_peak_kb > 500000   → channels: ['email-leads']
jank_per_min > 20      → channels: ['slack-perf']
mah_consumed > 100     → channels: ['email-team']
detected_issues.severity = 'critical' → channels: ['email-leads','slack-perf']
```

Rule operators: `<`, `>`, `<=`, `>=`, `==`, `!=`. Evaluated against `session_stats` columns post-session.

### 23.3 Evaluation

Worker job runs after `session_stats` insert:
```python
for alert in alerts where is_enabled = 1:
  value = session_stats[alert.metric]
  if matches_filter(session, alert.scope_filter_json):
    if compare(value, alert.operator, alert.threshold):
      fire(alert, session, value)

def fire(alert, session, value):
  for channel_id in alert.channel_ids:
    channel = notification_channels[channel_id]
    deliver(channel, format_message(alert, session, value))
  insert into alert_events (alert_id, session_id, fired_at, value, delivered)
```

### 23.4 Message Templates

Email subject: `[PerformanceBench] Alert: <alert.name> on <app> @ <device>`
Body:
```
Alert: <alert.name>
App: <app>
Device: <device>
Session: https://pb.example.com/sessions/<id>

Metric: <metric>
Threshold: <op> <threshold>
Observed: <value>

Detected Issues:
- LOW_FPS (high)
- HIGH_VARIABILITY (medium)
```

Slack: rich blocks with session link button.
Webhook: JSON `{"alert_id","alert_name","metric","threshold","value","session":{...}}`.

### 23.5 Rate Limiting

Same alert + same session → fire once. Same alert across different sessions → max 10/hour per channel (configurable).

### 23.6 GUI

Web dashboard "Alerts" page:
- List of rules + enabled toggle
- "New Rule" wizard: pick metric → operator → threshold → scope (apps/devices) → channels
- Test button → sends sample notification to channel
- Recent firings (last 100) from `alert_events`

### 23.7 Acceptance Criteria

- [ ] Email sent within 30s of session end when threshold breached
- [ ] Slack webhook delivers formatted blocks with session link
- [ ] Webhook receives valid JSON; signature header `X-PB-Signature: hmac-sha256=...`
- [ ] Rate limit: 11 sessions in 1h breach same rule → 10 firings, 1 suppressed log entry

---

## 24. Authentication (v2.0 + v3.5 Enterprise)

### 24.1 v2.0 Auth (Free Tier)

- Email + bcrypt password
- JWT (HS256, 1h expiry, refresh token 7d)
- API tokens (`api_tokens` table, sha256-hashed)
- 2FA optional (TOTP, free libs `pyotp` / `otplib`)

### 24.2 v3.5 LDAP

- Bind via `ldap3` (Python) or `ldap-rs` (Rust)
- Map LDAP `mail` attribute → `team_users.email`
- Map LDAP groups → PB roles (configurable mapping table)
- JIT user creation on first successful bind

### 24.3 v3.5 SAML 2.0 SSO

- Library: `python3-saml` (free) or `samael` (Rust)
- SP-initiated and IdP-initiated flows
- Tested with Okta, Azure AD, Google Workspace, Auth0
- JIT provisioning: SAML attributes → user fields:
  - `nameid` → `sso_subject`
  - `email` → `email`
  - `displayName` → `display_name`
  - `groups` → role mapping
- Multi-IdP support: multiple `idp_metadata.xml` files registered

### 24.4 RBAC

| Role | Permissions |
|---|---|
| Owner | All + billing + delete org |
| Admin | Manage users, alerts, lenses, projects |
| Member | Upload sessions, create markers, view all sessions in projects |
| Viewer | Read-only on assigned projects |

Permission check via decorator/middleware: `@requires('admin')` on routes.

### 24.5 Audit Log

`audit_log` table:
```sql
CREATE TABLE audit_log (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id     TEXT,
    action      TEXT NOT NULL,        -- 'session.upload'|'session.delete'|'alert.create'|'user.login'|...
    target_kind TEXT,
    target_id   TEXT,
    metadata    TEXT,                  -- JSON
    ip_address  TEXT,
    user_agent  TEXT,
    created_at  INTEGER NOT NULL
);
CREATE INDEX idx_audit_user ON audit_log(user_id);
CREATE INDEX idx_audit_action ON audit_log(action);
CREATE INDEX idx_audit_time ON audit_log(created_at DESC);
```

Captured: login/logout, session upload/delete, alert create/edit/delete, user invite/role change, export, API token issue/revoke.

### 24.6 Acceptance Criteria

- [ ] LDAP bind with Active Directory test setup → user logs in
- [ ] Okta SAML SP-initiated flow → user lands on dashboard logged in
- [ ] JIT: new SAML user → `team_users` row created with mapped role
- [ ] Viewer role → cannot access alert management endpoints (403)
- [ ] Audit log records all sensitive actions; queryable last-30-days in <1s

---

## 25. tvOS Support (v3.0)

### 25.1 Connection

Apple TV 4K (gen 3+) supports USB-C developer mode. Earlier models: WiFi-only via Xcode.

Connect via pyidevice `tcpforward` over USB-C. Same DTX protocol as iOS.

### 25.2 Available Metrics

Mostly identical to iOS (same DTXProtocol):
- FPS via Metal counters
- CPU via sysmontap
- Memory phys_footprint
- Network bytes
- Thermal state
- GPU % (Metal counters)

Not available:
- Battery % (mains-powered) — store NULL
- Battery mA / mV / temp — NULL
- Cellular network — N/A

### 25.3 UI

`target_kind = 'tvos'`. Battery card hidden. "Power: Mains" label shown instead. Otherwise identical to iOS.

### 25.4 Acceptance Criteria

- [ ] Apple TV 4K (gen 3) USB-C → device discovery shows `tvOS 17.4`
- [ ] FPS samples flow at 1Hz during tvOS app session
- [ ] Battery card hidden in UI when target_kind='tvos'
- [ ] Network samples include WiFi only (no cellular)

---

## 26. Mobile Profiler App (Optional, v2.0+)

Lightweight read-only app for managers/leads to monitor team sessions on phone.

### 26.1 Stack

Flutter mobile (iOS + Android) — same codebase as desktop with mobile-tailored UI.

### 26.2 Features

- Login → JWT (same auth as web dashboard)
- Sessions list (last 100, paginated)
- Session detail (read-only):
  - Scorecard
  - Charts (replay only, no live recording)
  - Markers list
  - Detected issues
- Push notifications for alerts (FCM Android, APNs iOS)
- Lenses list
- Trends Explorer (simplified, single-metric chart)

### 26.3 What It Does NOT Do

- No recording (use desktop)
- No injection
- No alert configuration (read-only triggers)
- No team admin

### 26.4 Distribution

- Android: APK via GitHub Releases + F-Droid (no Play Store cost)
- iOS: TestFlight free tier (allows 10K external testers per app)

### 26.5 Acceptance Criteria

- [ ] iOS app login → sessions list loads in <2s on LTE
- [ ] FCM push alert delivered on Android within 5s of alert fire
- [ ] Charts render frametimes_json without lag on iPhone SE 3rd gen
- [ ] No write endpoints accessible — all mutations return 403

---

## Appendix E: Static Device Data Collection

> **Hard contract:** What gets captured per session for `static_device_data` + `static_app_data`. Section 5.11 references this.

### E.1 Android getprop Sources

```bash
# Identity
adb shell getprop ro.product.manufacturer       # 'Google'
adb shell getprop ro.product.model              # 'Pixel 8'
adb shell getprop ro.product.brand              # 'google'
adb shell getprop ro.product.device             # 'shiba'
adb shell getprop ro.product.name               # 'shiba'
adb shell getprop ro.product.cpu.abi            # 'arm64-v8a'
adb shell getprop ro.product.cpu.abilist        # full ABI list
adb shell getprop ro.serialno                   # serial number

# OS
adb shell getprop ro.build.version.release      # '14'
adb shell getprop ro.build.version.sdk          # '34'
adb shell getprop ro.build.version.security_patch
adb shell getprop ro.build.fingerprint
adb shell getprop ro.build.id
adb shell getprop ro.build.type                 # 'user'|'eng'

# Hardware
adb shell getprop ro.hardware                   # SoC family
adb shell getprop ro.board.platform             # 'shiba' or 'sm8550'
adb shell getprop ro.soc.manufacturer           # 'Google'|'QTI'|'Samsung'
adb shell getprop ro.soc.model                  # 'Tensor G3'

# Display
adb shell wm size                               # '1080x2400'
adb shell wm density                            # '420'
adb shell dumpsys display | grep "real" | head -1

# Storage
adb shell df /data | tail -n 1                  # parse to MB
adb shell df /sdcard | tail -n 1

# RAM
adb shell cat /proc/meminfo | grep MemTotal     # 'MemTotal:        7777216 kB'

# Locale + timezone
adb shell getprop persist.sys.locale            # 'en-US'
adb shell getprop persist.sys.timezone          # 'America/Los_Angeles'

# Root + emulator detection
adb shell which su                              # path or empty
adb shell getprop ro.kernel.qemu                # '1' on emu

# Sensors
adb shell dumpsys sensorservice | head -100     # parse list

# Cameras
adb shell dumpsys media.camera | head -50

# SIM + Carrier
adb shell getprop gsm.operator.alpha            # carrier name
adb shell getprop gsm.sim.operator.alpha
adb shell dumpsys telephony.registry | head -30
```

### E.2 iOS pyidevice Sources

```python
import pymobiledevice3

with usbmux.create_using_usbmux(udid) as lockdown:
    info = lockdown.all_values
    # info contains:
    # 'ProductType' → 'iPhone15,2' (lookup table maps to 'iPhone 14 Pro')
    # 'ProductVersion' → '17.4.1'
    # 'BuildVersion'   → '21E236'
    # 'CPUArchitecture'→ 'arm64e'
    # 'DeviceClass'    → 'iPhone'|'iPad'|'AppleTV'|'Watch'
    # 'HardwareModel'  → 'D74AP'
    # 'UniqueDeviceID' → UDID
    # 'SerialNumber'
    # 'TimeZone'
    # 'BasebandVersion'
    # 'DeviceColor'
    # 'TotalDiskCapacity'
    # 'AvailableDiskCapacity'
```

### E.3 ProductType Lookup Table

Bundled JSON `assets/ios_product_types.json` maps `ProductType` → human name + chipset + GPU.

```json
{
  "iPhone15,2": {"name":"iPhone 14 Pro","chipset":"apple_a16","gpu":"Apple A16 GPU"},
  "iPhone15,3": {"name":"iPhone 14 Pro Max","chipset":"apple_a16","gpu":"Apple A16 GPU"},
  "iPhone16,1": {"name":"iPhone 15 Pro","chipset":"apple_a17_pro","gpu":"Apple A17 Pro GPU"},
  "iPhone16,2": {"name":"iPhone 15 Pro Max","chipset":"apple_a17_pro","gpu":"Apple A17 Pro GPU"},
  "iPad13,1":   {"name":"iPad Air 4","chipset":"apple_a14","gpu":"Apple A14 GPU"},
  "AppleTV14,1":{"name":"Apple TV 4K (3rd gen)","chipset":"apple_a15","gpu":"Apple A15 GPU"}
}
```

Updated annually with new device releases. Community PR-able in repo.

### E.4 App Static Data (Android)

```bash
# Package info
adb shell dumpsys package <pkg> | grep -E "versionName|versionCode|firstInstallTime|lastUpdateTime|targetSdk|minSdk|installerPackageName"

# Permissions
adb shell dumpsys package <pkg> | grep -E "permission|granted=true"

# APK path + size
adb shell pm path <pkg>                         # e.g. /data/app/.../base.apk
adb shell stat -c %s /data/app/.../base.apk

# Native libs (ABI hint)
adb shell pm dump <pkg> | grep primaryCpuAbi
```

### E.5 App Static Data (iOS)

```python
from pymobiledevice3.services.installation_proxy import InstallationProxyService

with InstallationProxyService(lockdown) as ips:
    apps = ips.get_apps(application_type='User')
    app = apps[bundle_id]
    # app contains:
    # 'CFBundleVersion'       → build number
    # 'CFBundleShortVersionString' → version name
    # 'CFBundleIdentifier'    → bundle ID
    # 'Path'                  → install path
    # 'ApplicationType'       → 'User'|'System'
    # 'SignerIdentity'        → 'Apple iPhone OS Application Signing'
    # 'Entitlements'          → dict
```

### E.6 Capture Timing

Static data captured **once at session start**, before metric_samples loop begins. Inserts into `static_device_data` and `static_app_data` tables (Section 8). NEVER updated mid-session.

If capture fails (timeout, permission), session still proceeds; `raw_getprop_json = NULL` with note in `sessions.notes`.

### E.7 Privacy Note

Serial numbers, UDIDs, IMEIs are captured **locally only**. Never transmitted unless user explicitly uploads session to team server. Local export (JSON/CSV) includes them; redaction option in Settings: "Redact device identifiers on export" → replaces with SHA256 hash.

---

## 27. Edge Cases & Hardening

> **Purpose:** Catch issues GameBench has battled for years. Every edge case below must be handled in v1.0 unless tagged otherwise.

### 27.1 ANR Detection (Android)

App Not Responding events break user experience. Capture via:
- Listen to `am_anr` log: `adb shell logcat -b events am_anr`
- Match PID = target app PID
- Insert as `markers` row with `label = '__anr__'` and `notes` containing the offending component
- Fire `ANR_DETECTED` issue rule (severity: critical)

`metric_samples.had_anr INTEGER 0/1` — sticky for 5s after detection so chart shows red marker.

### 27.2 Crash Detection (Android + iOS)

**Android:**
- Watch logcat `am_crash` event
- Or detect when target PID disappears mid-session (`pidof <pkg>` returns empty)
- Try to fetch tombstone: `adb shell run-as <pkg> ls /data/data/<pkg>/cache/` (debuggable apps only)
- Logcat slice ±10s around crash saved as `crashes/<session_id>.log`

**iOS:**
- pyidevice `crash_logs` service polls for new crash reports every 10s
- New crash log → save to `crashes/<session_id>/<bundle_id>-<ts>.ips`
- Mark session with `__crash__` marker

**Schema:**
```sql
CREATE TABLE crashes (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id  TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    timestamp   INTEGER NOT NULL,
    log_path    TEXT,                 -- relative to data dir
    short_name  TEXT,                 -- 'SIGSEGV' | 'NSException' | 'OOM'
    component   TEXT
);
```

### 27.3 Cold / Warm / Hot Launch Detection

Three launch types differ in what user perceives. Detection at session start:

| Type | Detection |
|---|---|
| **Cold** | App PID not present before session start; `am start` triggered fresh |
| **Warm** | App was in foreground recently (Android: `dumpsys activity recents` shows entry < 60s); process exists, activity recreated |
| **Hot** | App in foreground; just `moveTaskToFront` |

Stored as `sessions.launch_kind TEXT`. Affects baseline comparison in §6.9 — only compare cold-to-cold launches for `LAUNCH_TIME_INCREASE`.

### 27.4 Foreground / Background Time

Per-sample boolean `app_in_foreground INTEGER 0/1` from:
- Android: `dumpsys activity activities | grep mResumedActivity` checks if pkg matches
- iOS: pyidevice `applicationStateChanged` notifications

`session_stats`:
- `time_foreground_s` / `time_background_s`
- Analytics ignore background samples for FPS but include them for memory/network/battery (legit drain).

### 27.5 Multi-Process Apps

Apps split into multiple processes (browsers, game engines with separate render proc):
- `pidof <pkg>` returns multiple PIDs → primary = main, others = children
- Memory aggregated: sum of all child PIDs' PSS + main's PSS
- Per-process breakdown stored as `metric_samples.processes_json` = `[{"name":"main","pid":1234,"pss_kb":123456,"cpu_pct":12.3},...]`

### 27.6 Variable Refresh Rate

Modern phones (120Hz/144Hz, ProMotion). Refresh rate may change mid-session:
- Sample `dumpsys display | grep mRefreshRate` per second
- Store `metric_samples.refresh_rate_hz REAL` (variable, not from `devices` table snapshot)
- Frame jank thresholds adapt: `frame_period_ms = 1000 / current_refresh_rate`

### 27.7 Render Thread Split (Android HWUI)

Modern Android renders on separate `RenderThread`. Need both:
- `cpu_app_main_thread_pct` REAL — UI thread CPU%
- `cpu_app_render_thread_pct` REAL — RenderThread CPU%
- Sourced from `/proc/<pid>/task/<tid>/stat` for each — discover threads via `/proc/<pid>/task/`

### 27.8 Frame Pacing / Vsync Misses

Beyond jank count, track:
- `vsync_misses_count` INTEGER per sample — frames that missed vsync deadline
- Source: SurfaceFlinger latency parse (Section 5.1) — count entries where `vsync_ts > present_ts`

### 27.9 Battery Health

Beyond live mA/mV:
- `battery_capacity_actual_mah` from `dumpsys batterystats | grep "Estimated battery capacity"` — actual usable
- `battery_capacity_design_mah` from `/sys/class/power_supply/battery/charge_full_design`
- `battery_health_pct = capacity_actual / capacity_design × 100`
- Stored once per session in `static_device_data`

### 27.10 Network Latency

Per-second ICMP ping to gateway (when WiFi active):
- `adb shell ping -c 1 -W 1 8.8.8.8 | tail -n 2` → parse `time=X.X ms`
- `metric_samples.net_latency_ms REAL` — nullable
- Disabled by default (test config); user-enables in Settings

### 27.11 I/O Wait CPU

`/proc/stat` "iowait" column captured per sample:
- `metric_samples.cpu_iowait_pct REAL`
- High iowait → storage bottleneck flag

### 27.12 Doze / App Standby (Android)

Android battery-saving may suspend app:
- `adb shell dumpsys deviceidle get deep` → `IDLE`/`ACTIVE`/`IDLE_PENDING`/etc.
- `metric_samples.doze_state TEXT` — sample-level
- Affects analytics: drain rate during doze ≠ active drain rate

### 27.13 Composition Layer Count

`adb shell dumpsys SurfaceFlinger | grep "Layer "` count → `metric_samples.layer_count INTEGER`
High layer count → GPU bottleneck candidate.

### 27.14 Build Variant Detection

Capture in `static_app_data`:
- `build_type` TEXT — `debug` / `release` / `profile`
  - Android: `dumpsys package <pkg> | grep "flags="` — `DEBUGGABLE` flag
  - iOS: `Entitlements` from app proxy — `get-task-allow` indicates debug

### 27.15 Multi-Window / Split-Screen

Android `dumpsys window | grep "mIsInMultiWindowMode"` per sample → `metric_samples.multi_window INTEGER 0/1`. FPS analytics annotated in chart when active.

### 27.16 Device Disconnect Mid-Session

Hard requirement: never lose data on USB unplug or WiFi drop.

Handling:
1. Collector loop catches IOError → flushes ring buffer to SQLite immediately
2. Session status changes from `recording` → `disconnected`
3. UI shows banner "Device disconnected. Session paused. Reconnect to resume or stop."
4. Reconnect within 60s → resume seamlessly
5. After 60s → auto-stop, mark `ended_at = last_sample_ts`, compute analytics on partial data

### 27.17 Clock Skew

Device clock may differ from host clock. All `metric_samples.timestamp` use **host clock** for consistency. Log device clock at session start in `static_device_data.device_clock_offset_ms`.

### 27.18 ADB Daemon Crash

`adb` daemon may die. Wrap with retry:
1. Detect non-zero exit + "no devices/emulators" → restart daemon: `adb kill-server && adb start-server`
2. Re-detect device
3. Resume session
4. Log incident in `sessions.notes`

### 27.19 pyidevice Process Leak

Long sessions can leak file handles. Recycle pyidevice subprocess every 30 min:
- Snapshot last counters
- SIGTERM subprocess
- Spawn new
- Resume from snapshot
- No data loss (counters are cumulative)

### 27.20 SQLite WAL Mode + Concurrency

Enable WAL: `PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;`
- Writer (collector) + reader (UI) won't block each other
- Checkpoint every 5 min: `PRAGMA wal_checkpoint(TRUNCATE);`
- WAL file capped at 64 MB

### 27.21 Disk Full Protection

Before each batch insert, check available disk:
- < 100 MB free → halt session, show user error "Insufficient disk space"
- Pre-session check enforces 500 MB free

### 27.22 Time Zone Drift

Sessions across regions / DST transitions:
- Store all timestamps as UTC milliseconds
- UI renders in user's local zone
- Export JSON/CSV includes both `timestamp_ms` (UTC) and `timestamp_iso` (local TZ)

### 27.23 HDR / ProMotion / Notch Areas

Screenshot capture at SS0 (full-res):
- HDR images: stored as standard sRGB JPEG (display preserved as captured)
- Notch / Dynamic Island areas not stripped — preserved in image
- Aspect-correct on all sizes (no cropping)

### 27.24 Acceptance Criteria

- [ ] ANR injected via test app (slow main thread) → marker inserted with label `__anr__`, severity critical issue fired
- [ ] App killed mid-session → crash row inserted, logcat slice saved
- [ ] Cold launch: `am force-stop pkg && am start pkg/.MainActivity` → `launch_kind = 'cold'`
- [ ] Phone foregrounds another app for 10s mid-session → `time_background_s` ≈ 10
- [ ] Browser app with multi-process → process count > 1 in `processes_json`
- [ ] Pixel 8 ProMotion 60↔120Hz transitions captured per-sample
- [ ] USB unplug → reconnect within 60s → session resumes
- [ ] 24-hour session does not crash collector or leak handles

---

## 28. Export & Import Formats

### 28.1 JSON Export (Full Session)

```json
{
  "performancebench_export_version": "1.0",
  "exported_at": "2026-04-30T14:00:00Z",
  "session": {
    "id": "uuid-here",
    "title": "Boss Fight v42 — Pixel 8",
    "platform": "android",
    "target_kind": "mobile",
    "app_package": "com.foo.game",
    "app_version": "1.0.42",
    "started_at": 1735689600000,
    "ended_at": 1735690200000,
    "duration_ms": 600000,
    "tags_kv": {"build":"42","level":"boss"},
    "production_mode": false,
    "strict_mode": true,
    "launch_kind": "cold"
  },
  "device": { ...all static_device_data... },
  "app_static": { ...all static_app_data... },
  "samples": [
    {"timestamp": 1735689601000, "fps": 59.2, "jank_count": 0, ...},
    ...
  ],
  "markers": [
    {"label":"boss_phase_2","started_at":...,"ended_at":...,"group":"phases"}
  ],
  "regions": [...],
  "session_stats": { ...all session_stats columns... },
  "marker_stats": [...],
  "detected_issues": [...],
  "crashes": [...],
  "screenshots": [
    {"timestamp":...,"size_id":"SS0","filepath":"screenshots/<id>/<ts>_SS0.jpg"}
  ]
}
```

Screenshots referenced as relative paths. JSON file `<session_id>.json` + `screenshots/` folder zipped → `<session_id>.pbsession.zip`.

### 28.2 CSV Export

Two CSVs per session:
- `<session_id>_samples.csv` — one row per metric_sample, all columns
- `<session_id>_summary.csv` — flat session_stats row

CSV header documented in `docs/csv-schema.md`. Values null → empty string. Timestamps in ISO 8601 + epoch ms columns.

### 28.3 PDF Report

Wkhtmltopdf-rendered HTML template (assets/report-template.html). Sections:
1. Cover (app, device, dates)
2. Scorecard (key KPIs)
3. Per-metric charts
4. Detected issues
5. Markers timeline
6. Static data appendix

### 28.4 Import

`File → Import` accepts:
- `.pbsession.zip` (PB native)
- `.json` (PB JSON without zip — screenshots resolved relative to JSON file)

Import validates `performancebench_export_version`. Creates new `sessions` row with imported data. Marks `sessions.imported = 1`.

`sessions.imported INTEGER 0/1` column added.

### 28.5 GameBench Import (v3.5)

`Import → GameBench Session JSON` — best-effort parser for GB Studio export.
Maps GB fields → PB fields where possible. Unmapped data → `sessions.notes`.

### 28.6 Acceptance Criteria

- [ ] Export → import round-trip preserves all data byte-for-byte (sample count, stats, markers, screenshots)
- [ ] Importing zip without screenshots → session loads, screenshot tab shows "missing"
- [ ] CSV schema documented; column count matches across all sessions of same schema version
- [ ] PDF report renders in <30s for 1h session

---

## 29. Error Taxonomy

Every error surfaced to user has a code. Aids triage + i18n.

### 29.1 Error Code Format

`PB-<DOMAIN>-<NUMBER>` — three uppercase letters or numbers + 3-digit code.

### 29.2 Domains

| Domain | Code prefix | Examples |
|---|---|---|
| ADB | `ADB` | `PB-ADB-001` adb not found, `PB-ADB-002` device unauthorized |
| iOS | `IOS` | `PB-IOS-001` pyidevice missing, `PB-IOS-010` Developer Mode off |
| Database | `DB` | `PB-DB-001` migration failed, `PB-DB-005` disk full |
| Parser | `PRS` | `PB-PRS-001` SurfaceFlinger output unparseable |
| Network | `NET` | `PB-NET-001` team server unreachable |
| Auth | `AUT` | `PB-AUT-001` invalid credentials |
| Injector | `INJ` | `PB-INJ-001` apktool not in PATH, `PB-INJ-010` FairPlay encrypted |
| PC Probe | `PCB` | `PB-PCB-001` PDH counter not found |
| UI | `UI` | `PB-UI-001` chart render failure |
| Generic | `GEN` | `PB-GEN-001` unknown error |

### 29.3 Error Display

Error dialog shows:
- Title: human-readable summary
- Code: `PB-XXX-NNN` (copyable)
- Detail: technical message
- Action: "Open documentation" (deep-links to `docs/errors.md#pb-xxx-nnn`) + "Copy details"

### 29.4 Error Logging

All errors logged to `logs/error.log` (rotated daily, 30-day retention). Format:
```
2026-04-30T14:00:00Z PB-ADB-002 ERROR session=uuid device=R3CN... message="Device unauthorized"
```

### 29.5 Acceptance Criteria

- [ ] Every user-facing error has a code
- [ ] `docs/errors.md` documents every code
- [ ] Error dialog contains "Copy details" button → clipboard contains code + detail + stack trace
- [ ] No raw stack traces shown to user without an error code wrapper

---

## 30. Internationalization & Accessibility

### 30.1 i18n

- All user-facing strings in `lib/l10n/app_en.arb`
- v1.0 ships en-US only
- Architecture supports any locale — community PRs accepted
- Date/time/number formats locale-aware via `intl` package
- Right-to-left (RTL) layout supported (Flutter default)
- Roadmap: en, es, ja, zh-CN, ko by v2.0 if community contributes

### 30.2 Accessibility (WCAG 2.1 AA target)

- All interactive widgets have semantic labels
- Color contrast ≥ 4.5:1 for text, ≥ 3:1 for UI components
- Keyboard navigation: every action reachable without mouse (Tab order, shortcuts in §9.4)
- Screen reader compatible (Flutter `Semantics` widgets on charts + lists)
- Charts have textual data table fallback (toggle button)
- No flashing animations > 3 Hz (epilepsy safety)
- High-contrast theme option (Settings → Accessibility)
- Font size scaling 0.8x – 1.5x via Settings

### 30.3 Acceptance Criteria

- [ ] NVDA / VoiceOver reads device list + session detail correctly
- [ ] Tab key cycles through all interactive elements in logical order
- [ ] High-contrast theme passes 7:1 contrast ratio (AAA)
- [ ] All errors in §29 have ARB string keys
- [ ] Bidi tests with Hebrew sample strings render correctly

---

## 31. Data Retention & Backup

### 31.1 Retention Policy

Default: **never auto-delete**. User controls all data.

User-configurable in Settings → Storage:
- ☑ Auto-delete sessions older than [30/60/90/180/365] days
- ☑ Auto-delete after disk usage exceeds [1/5/10/50] GB
- Action: "View and delete sessions older than..."

Deletion cascades via FK `ON DELETE CASCADE` (Appendix C). Screenshots also deleted.

### 31.2 Backup

`File → Backup` → exports entire `performancebench/` data dir to a single `.pbbackup` archive (zip with custom extension).

Includes:
- `performancebench.db` (with WAL checkpointed first)
- All `screenshots/` contents
- All `crashes/` contents
- `settings.json`

`File → Restore` → unpacks `.pbbackup` over current data dir (with confirmation dialog warning of overwrite).

### 31.3 Auto-Backup (Optional)

Settings → Backup → ☑ Auto-backup weekly to `<chosen_path>`. Last 4 backups retained. Off by default.

### 31.4 Database Vacuum

Weekly `VACUUM;` runs on app start if last vacuum > 7 days ago. Reclaims space after deletes.

### 31.5 Privacy Defaults

Per §15 + Appendix E.7:
- Settings → Privacy:
  - ☑ Redact device identifiers on export (default ON for §28 exports)
  - ☑ Skip serial numbers in screenshots metadata
  - ☑ Strip GPS / cellular identifiers from static_device_data
- Privacy mode applies to JSON/CSV/PDF/PBSession exports + team server uploads

### 31.6 Acceptance Criteria

- [ ] 30-day retention rule deletes session 31 days old → row + screenshot files gone
- [ ] Backup → restore on a different machine → all sessions visible
- [ ] Vacuum reduces DB file size after 1000 sessions deleted
- [ ] Privacy "redact identifiers" replaces UDID with SHA256 in exported JSON

---

## 32. Video Recording (Synced)

> **Scope:** Synced screen video alongside metric timeline. Android v1.5, iOS v2.5, Windows/macOS/Linux PC v3.0. All native tools, all $0.

### 32.1 Why Synced Video

Watching what user saw at the moment FPS dropped → root-cause obvious. PB lacks this v1.0 (only screenshots). Video closes the gap GameBench has owned.

### 32.2 Per-Platform Capture Stack

| Target | Tool | Notes |
|---|---|---|
| Android | `adb shell screenrecord --output-format=h264` | Built-in API ≥ 19 (KitKat). Streams H.264 NALs over stdout. Max 3 min per call (Android limit) — chain seamlessly. No re-encode. |
| iOS | `pymobiledevice3 developer dvt screen` | DVT screen-mirror service. ~30 FPS H.264 via DTXProtocol. macOS host required at v2.5; Windows host via Mac proxy at v3.0. |
| tvOS | Same as iOS (DVT screen-mirror) | Apple TV 4K (gen 3+) USB-C only. |
| Windows PC | Windows.Graphics.Capture API + Media Foundation H.264 encoder | Win10 1903+. Hardware-accelerated when available. |
| macOS PC | `AVScreenCaptureKit` + VideoToolbox | macOS 12.3+. Hardware-accelerated. |
| Linux PC | `ffmpeg -f x11grab` (X11) or `ffmpeg -f kmsgrab` (Wayland) + `libx264` | LGPL/GPL-compatible. ffmpeg invoked as subprocess. |

### 32.3 Recording Pipeline (Android Reference)

```
1. Session start
   ├─ Spawn: adb shell screenrecord --bit-rate 8000000 --output-format h264 -
   ├─ Stream stdout → host file 'video/<session_id>/chunk_000.h264'
   ├─ Watch elapsed time
   └─ At 175s (Android max ~180s): SIGTERM, finalize chunk
2. Chunk rotation
   ├─ chunk_000.h264 finalized → spawn chunk_001.h264 within ~50ms
   ├─ Continuity preserved: collector logs gap_ms in 'videos.gaps_json'
3. Session stop
   ├─ Last chunk finalized
   ├─ Concat via 'ffmpeg -f concat -safe 0 -i list.txt -c copy <session_id>.mp4' (no re-encode)
   ├─ Container = MP4 (faststart for streaming playback)
   └─ Update 'videos' row with final filepath + duration
```

### 32.4 Sync Model

**Goal:** scrubbing chart at time T → video frame at T (and vice versa). ±50 ms tolerance.

Approach:
1. At session start, capture host clock `T0_host` and emit a visible frame marker on device (flash white screen, briefly, hidden by overlay) — provides absolute anchor.
2. Each chunk's start time stored: `videos.chunks_json = [{"file":"chunk_000.h264","start_ms":T0,"duration_ms":175000}, ...]`
3. Player computes `(target_ts - T0_host)` → looks up chunk + offset → seeks.

Fallback if anchor flash undesirable: rely on `screenrecord --time-limit` start time + per-second chart timestamps; tolerance ±200 ms.

### 32.5 Settings

Settings → Recording → Video:
- ☐ Enable video recording (default OFF — opt-in due to disk + perf overhead)
- Resolution: ☐ Native ◉ 1080p ☐ 720p ☐ 480p
- Bitrate: 4 / 8 / 12 / 20 Mbps (default 8)
- Frame rate cap: 30 / 60 (target — actual capped by `screenrecord` ≈ 30)
- ☐ Record audio (Android only, requires `--mic` flag — opt-in)
- ☐ Show capture indicator on device (only Android Q+ — system status)

### 32.6 Storage & Costs

| Setting | Approx | 1h session |
|---|---|---|
| 1080p 8 Mbps | 1 MB/s | ~3.6 GB |
| 720p 4 Mbps | 0.5 MB/s | ~1.8 GB |
| 480p 2 Mbps | 0.25 MB/s | ~900 MB |

User warned in dialog "Video will use ~3.6 GB for 1h session at 1080p 8 Mbps. Continue?" before first session.

Disk-full guard (§27.21) applies — recording auto-stops at 100 MB free, metric collection continues.

### 32.7 Performance Overhead

| Target | Capture overhead |
|---|---|
| Android `screenrecord` | ~3-5% CPU on flagship; ~7-10% on midrange. GPU encode hardware. Negligible on FPS. |
| iOS DVT screen-mirror | ~5-8% CPU. May reduce target FPS by ~3-5 (Apple's pipeline). |
| Windows.Graphics.Capture | ~2-4% CPU when GPU encode available. |

Documented in tooltip + `videos.recording_overhead_estimate_pct`. Strict mode (§20) auto-disables video recording (would invalidate test conditions).

### 32.8 Schema

```sql
-- Video recordings (one per session max)
CREATE TABLE IF NOT EXISTS videos (
    session_id          TEXT    PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,
    filepath            TEXT    NOT NULL,         -- video/<session_id>/<session_id>.mp4
    codec               TEXT    NOT NULL DEFAULT 'h264',
    container           TEXT    NOT NULL DEFAULT 'mp4',
    width_px            INTEGER NOT NULL,
    height_px           INTEGER NOT NULL,
    target_fps          INTEGER,                  -- requested fps
    actual_avg_fps      REAL,                     -- measured from frame count / duration
    bitrate_kbps        INTEGER,
    duration_ms         INTEGER NOT NULL,
    file_size_bytes     INTEGER NOT NULL,
    chunks_json         TEXT,                     -- per-chunk start/duration map for sync
    gaps_json           TEXT,                     -- inter-chunk gaps in ms
    has_audio           INTEGER DEFAULT 0,
    recording_overhead_estimate_pct REAL,
    started_at          INTEGER NOT NULL,
    ended_at            INTEGER NOT NULL,
    created_at          INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

-- sessions table addition
ALTER TABLE sessions ADD COLUMN has_video INTEGER DEFAULT 0;
```

### 32.9 Player UI (Session Detail)

New tab: **Video** alongside Charts / Markers / Screenshots / Issues.

Layout:
```
┌─ Video ──────────────────────────────────────────────────┐
│ [▶] [⏸] [<<] [>>] [↺] 02:47 / 10:00   [1080p 8Mbps] [⚙] │
│                                                            │
│           [video frame rendered here]                      │
│                                                            │
│ [─────●─────────────────────────────────────────────────] │
│ FPS:   ▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│ CPU:   ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│ Mem:   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│ Markers: │ launch   │boss_phase_2 │                        │
└────────────────────────────────────────────────────────────┘
```

- Video pane uses `media_kit` Flutter package (libmpv backend, MIT — free)
- Scrubbing video → highlights matching chart timestamp via shared `playhead_ts` Riverpod provider
- Scrubbing chart → seeks video via `Player.seek(Duration)`
- Marker labels overlaid on timeline → click → seek
- Frame-step (J/K/L keys: ← / pause / →)
- Speed: 0.25x / 0.5x / 1x / 2x / 4x

### 32.10 Export Inclusion

Per §28: `.pbsession.zip` includes `<session_id>.mp4` if present.

Optional: `Export → Video Annotated MP4` — burns charts + markers as video overlay (uses ffmpeg subtitle/overlay filters). Output single MP4 ready to share.

### 32.11 Privacy

Per §31.5 redaction: video may show device-identifying UI (lock screen, notifications). Settings → Privacy → ☑ "Blur status bar in exported video" → ffmpeg crop+blur filter applied during export only (original retained locally).

Team server upload: video transmitted only with session if explicitly toggled per upload. Default OFF.

### 32.12 v3.0 PC Variant Notes

**Windows:** Windows.Graphics.Capture targets full screen or specific window. Capture uses `IDirect3DSurface` → Media Foundation `IMFSinkWriter` → MP4 H.264. Process: `pb-pcprobe` runs capture loop; streams chunks to host via existing TCP channel.

**macOS:** `SCStream` from ScreenCaptureKit → `AVAssetWriter` → MP4. Permission granted at first run via system prompt.

**Linux:** ffmpeg subprocess, configurable display source (DISPLAY env or wlroots socket).

### 32.13 Acceptance Criteria

- [ ] Android session 10 min @ 1080p 8 Mbps → single MP4 ≈ 600 MB, plays in VLC, no audio drift
- [ ] Scrubbing video at 5:00 → charts highlight 5:00 ± 50 ms
- [ ] Scrubbing chart at 7:23 → video seeks to 7:23 ± 50 ms
- [ ] Strict mode ON → video recording auto-disabled with UI message
- [ ] Disk full mid-recording → recording stops, session continues, error logged with code `PB-DB-005`
- [ ] iOS 10-min session via pymobiledevice3 → MP4 ≈ 30 FPS, ~400 MB at default settings
- [ ] PC capture on Windows 11 → no game frame drop > 5%
- [ ] Linux capture via ffmpeg + x11grab → MP4 valid, syncs with charts
- [ ] Marker created during recording → label appears on video timeline
- [ ] Annotated export MP4 contains burnt-in chart strips + marker labels

---

## 33. Known Limitations & Risk Register

> **Honest accounting.** Every project has limits. Documenting them prevents user surprise and gives agentic coders a ready answer when blocked.

### 33.1 Hard Technical Limits (Cannot Be Engineered Around)

| Limit | Why | Workaround |
|---|---|---|
| iPhone 8+ instantaneous mA | Apple removed hardware API | Drain rate (%/h) only |
| App Store IPA injection | FairPlay DRM | Studio supplies unencrypted IPA |
| iOS CPU per-core normalization | iOS doesn't expose | Match GB convention, document |
| PowerVR GPU counters | No public sysfs | Show "N/A" |
| Adreno HW counters Android 13+ | SELinux blocks | Try unlock, fall back |
| Network packet contents | Privacy + complexity | Byte counts only |
| Battery mA Android non-Snapdragon | Some chipsets don't expose `current_now` | Show "N/A" with chipset name |
| iOS cellular per-app bytes | DTXProtocol returns aggregate only | Total interface bytes only |

### 33.2 Soft Limits (Engineered Around — Risks Remain)

| Limit | Risk | Mitigation |
|---|---|---|
| `screenrecord` 3-min Android cap | Chunk seam may drop frames | Chunked w/ ffmpeg concat (§32.3); ±50ms gap logged |
| pymobiledevice3 iOS update lag | Each iOS major release breaks DVT | Pin known-working version per iOS major; document compat matrix |
| Apple silicon vs Intel host | Some pyidevice services behave differently | Test matrix in CI |
| Long sessions (> 6h) | UI charts slow with 21,600+ points | Downsample for display (§43); raw stays in DB |
| SQLite WAL on 100k+ samples | Checkpoint pause | Auto-checkpoint at session boundaries |
| ADB daemon crash | Lost samples during restart | Auto-recovery (§27.18); session marked `disconnected` if > 60s |
| Wireless ADB throughput | Slow over busy WiFi | Disable screencap by default; auto-detect bandwidth and warn |
| Foldable phone screen state | Layer paths change | Manufacturer-specific quirks (§35) |
| Variable refresh rate | Jank thresholds shift mid-session | Per-sample refresh rate column (§27.6) |
| Multi-process apps | PSS sum overcounts shared pages | Document `+sharedPss` column separately |

### 33.3 Distribution & Trust Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Windows SmartScreen warns on unsigned exe | User clicks "Don't run" | Optional EV cert ($200-400/yr donation-funded) OR clear "How to allow" docs |
| macOS Gatekeeper blocks unnotarized | First-run friction | Apple Developer ID ($99/yr donation-funded) OR users right-click → Open |
| Linux distro fragmentation | AppImage/Flatpak/Snap/AUR debate | Ship AppImage primary, community PRs for rest |
| Antivirus flags injector tools | Frida/apktool false-positive | VirusTotal pre-scan; documented allowlist instructions |
| GitHub Releases bandwidth | Limit on free tier | Mirror to Cloudflare R2 free tier or fallback to release-please rotation |
| Auto-update telemetry conflict | Privacy claim vs update notif | Pull-based check on user click only (§39) |

### 33.4 Ecosystem Risks (Out of Our Control)

| Risk | Impact | Watch / Action |
|---|---|---|
| Apple revokes Free Apple ID signing | iOS injection (v3.0) breaks | Document; require Apple Developer Program as fallback |
| Google deprecates `screenrecord` | Android video breaks | Watch Android dev preview; provide MediaProjection fallback via SDK injection |
| Android removes ADB shell access | `pidof`, `getprop`, etc. break | Watch dev preview; pivot to ADBD root or SDK injection |
| iOS removes DTXProtocol | All iOS metrics break | Watch beta releases; ML community usually finds replacement |
| `pymobiledevice3` upstream goes dormant | iOS support stalls | PB forks if needed; community has shown they will |
| `apktool` upstream goes dormant | Android injection stalls | PB forks; alternative: Quark engine, jadx |
| Flutter desktop deprecation | Major rewrite cost | Risk small (Google active); fallback Tauri/Wails |

### 33.5 Patent / IP Risk

PB does not implement any GameBench-patented technique known. **Audit recommended** before public release:
- Search USPTO for "GameBench" patents
- Search EU patents
- If patent identified: avoid technique OR implement via prior-art alternative OR file invalidity research
- Algorithms in §5/§6 use only published-research formulas (frame-ratio Γ=L/R from Industrial Light & Magic 2010 paper; trapezoidal integration is mathematics; PSS subsections are publicly documented Android API)

### 33.6 Trademark Risk

Search "PerformanceBench" trademark availability before public launch:
- USPTO TESS database
- EUIPO eSearch
- WIPO Global Brand Database
- Confirm no conflict in software classification (Class 9 + Class 42)
- Defensive registration optional, ~$350 USPTO

### 33.7 Risk Acceptance Tracking

Each risk above tagged in `RISKS.md` repo file with:
- Risk ID
- Severity (low/med/high)
- Likelihood (rare/possible/likely)
- Owner
- Mitigation status
- Last reviewed date

Reviewed quarterly. Outdated items pruned.

### 33.8 Acceptance Criteria

- [ ] `RISKS.md` exists with all rows above
- [ ] Patent search performed and notes recorded before v1.0 public release
- [ ] Trademark search performed before public launch
- [ ] Each risk has owner + mitigation linked in tracking file

---

## 34. Multi-Device Parallel Sessions

> **Use case:** QA team profiles same build across 5 devices simultaneously. Fleet QA. Requires by v2.0.

### 34.1 Concurrency Model

- One `MetricCollector` isolate per device (Dart isolate)
- Independent ring buffers, independent SQLite write batch
- Shared SQLite via `sqflite_common_ffi` connection pool (writer + readers)
- WAL mode enabled (Section 27.20)

### 34.2 UI

- Device list shows multi-select (Shift+click, Cmd/Ctrl+click)
- "Start Session on N Devices" → opens multi-app picker
- Active sessions tab grid: one tile per device, all charts visible at once
- Synchronized markers — adding a marker fires on all active sessions

### 34.3 Storage

- One `sessions` row per device
- All linked via `sessions.parallel_group_id TEXT` (UUID)
- Comparison view auto-loads all sessions in same parallel_group_id

### 34.4 Schema Addition

```sql
ALTER TABLE sessions ADD COLUMN parallel_group_id TEXT;
ALTER TABLE sessions ADD COLUMN parallel_group_label TEXT;
CREATE INDEX idx_sessions_parallel ON sessions(parallel_group_id);
```

### 34.5 Limits

- Max parallel: bounded by host CPU + USB bandwidth. Default cap 8; configurable.
- ADB bandwidth: each device consumes ~200 KB/s. 8 devices ≈ 1.6 MB/s — well within USB 3.0.
- Disk: 8 × 30 KB/session/min × 60 min = 14.4 MB/h — trivial.

### 34.6 Acceptance Criteria

- [ ] 4 Pixel devices simultaneous → all 4 sessions record at 1Hz, no dropped samples
- [ ] Marker added in UI → row appears in all 4 sessions within 100ms
- [ ] One device disconnects → other 3 continue cleanly
- [ ] Compare view loads parallel_group at once

---

## 35. OEM-Specific Quirks

> **Reality:** Android OEMs differ. Not all devices behave the same. Document workarounds.

### 35.1 Quirks Database

`assets/oem_quirks.json` — versioned, community-PR-able:

```json
{
  "xiaomi": {
    "miui_battery_optimization": "MIUI kills profiling apps; user must disable battery saver per app",
    "miui_developer_settings": "USB debugging (Security settings) toggle in addition to standard ADB",
    "miui_screenshot_permission": "Cross-app screenshots blocked; PB uses standard adb screencap which works"
  },
  "samsung": {
    "knox_warranty": "Knox void warning on Smali patching of preloaded apps; document",
    "one_ui_battery_path": "/sys/class/power_supply/battery/voltage_now path standard but values × 1000",
    "secure_folder_inaccessible": "Secure folder pkg list hidden — document"
  },
  "vivo_oppo_realme": {
    "color_funtouch_battery_path": "Different sysfs name on some chipsets; fallback list documented",
    "background_app_kill": "Aggressive — disable battery optimization per app"
  },
  "huawei": {
    "harmony_os_compat": "HarmonyOS 4+ on flagship — Android-compat partial; some getprop missing",
    "no_google_services": "Document; static_app_data.install_source = 'AppGallery' or sideload"
  },
  "google_pixel": {
    "no_quirks": "Reference baseline"
  },
  "fold_devices": {
    "samsung_fold": "Layer name changes when folded/unfolded; SurfaceFlinger query refresh on state change",
    "google_pixel_fold": "Same",
    "device_state_intent": "android.app.action.DEVICE_STATE_CHANGED — listen for fold transitions"
  }
}
```

### 35.2 Detection Logic

```
chipset_vendor = getprop('ro.soc.manufacturer').lower()
brand = getprop('ro.product.brand').lower()
quirks = load('oem_quirks.json')[brand] or {}
apply_quirks(quirks)
```

### 35.3 Specific Workarounds

**Xiaomi MIUI:**
- USB debugging requires *Developer options* AND *Security → USB debugging* both enabled — show specific dialog if `adb` returns "device unauthorized" on Xiaomi
- ADB authorization may revoke after MIUI updates — auto-retry with reauth flow

**Samsung One UI:**
- Battery `voltage_now` returns mV directly on some — detect by magnitude and skip ÷1000
- Knox container apps invisible to `pm list packages` — show "Cannot profile Knox apps" warning

**Vivo / Oppo / Realme (BBK family):**
- Aggressive background killing — recommend "Don't optimize" per app pre-session
- Some chipsets use `/sys/class/power_supply/usb` instead of `battery` — fallback list

**OnePlus:**
- HyperOS / OxygenOS — generally Pixel-like; few quirks

**Foldables:**
- SurfaceFlinger layer changes on fold transition — re-discover layer post-transition
- Refresh rate may switch based on cover screen vs main screen

**Tablets / Chromebooks running Android:**
- Multi-window default; `multi_window` column always 1
- Different display density — verify screenshot scale

**Emulators (BlueStacks / NoxPlayer / Android Studio AVD):**
- Detect via `ro.kernel.qemu` or `ro.product.cpu.abi` patterns
- Battery values fake — mark `is_emulator = 1` and disable battery analytics

### 35.4 Acceptance Criteria

- [ ] Xiaomi Redmi 12 detected → quirks loaded, USB debugging dialog shown if unauthorized
- [ ] Samsung Fold → fold transition mid-session → layer rediscovered, FPS continues
- [ ] BlueStacks → `is_emulator = 1`, battery analytics disabled
- [ ] Unknown OEM → fallback to defaults; no crashes

---

## 36. Legal & Compliance

### 36.1 Reverse Engineering Position

**DTXProtocol use:** pyidevice / pymobiledevice3 are widely used in security research, automation testing, and education. PB uses them in compliance with:
- US: 17 USC §1201(f) — interoperability exemption for reverse engineering
- EU: Directive 2009/24/EC Article 6 — reverse engineering for interoperability
- Apple Developer Agreement — does NOT prohibit reading device telemetry on devices owned by user

**APK injection (v2.5):** apktool / Smali patching is legal for:
- Apps owned by user / studio
- QA testing of own builds
- Security research
- Within ToS of Google Play (developer-side)

NOT supported / NOT legal:
- Bypassing FairPlay (we refuse explicitly)
- Patching closed-source apps without permission
- Distributing patched apps publicly

User-facing message in injector GUI:
> "Only inject apps you own or have explicit permission to test. PerformanceBench does not endorse unauthorized modification of third-party apps."

### 36.2 Privacy / Data Protection

**GDPR (EU):**
- Local-only mode — no data controller, GDPR not triggered
- Team server mode — controller = self-host operator (not PB project)
- Provide DPIA template in `docs/compliance/gdpr-dpia-template.md`
- Data subject rights endpoints in v2.0 REST API: `GET /api/users/me/data` / `DELETE /api/users/me`

**CCPA (California):**
- Same — local-only avoids; team server requires operator compliance
- Provide template

**PIPEDA (Canada), DPDP Act (India), LGPD (Brazil), POPIA (South Africa):**
- Acknowledge in compliance doc; same local-only-out-of-scope reasoning

**COPPA (US, ages < 13):**
- If profiling kids' apps, screenshots may capture child PII
- Document warning + auto-blur for kids-tagged apps (settings)
- `sessions.contains_minors_content INTEGER 0/1` — user-flagged

**Apple ATT / iOS privacy labels:**
- Not applicable — PB doesn't track users; only device telemetry user opted in

### 36.3 China-Specific

For PB use in China:
- ICP filing required for self-hosted team server with public domain (LAN-only avoids)
- Apple App Store China — ICP licence in app metadata required
- Cybersecurity Law data localization — local-only by default satisfies
- Document in `docs/compliance/china.md`

### 36.4 Open Source Compliance

- Every dependency license vetted (Appendix F.8)
- License compatibility matrix in `docs/licenses.md`
- SPDX identifiers in every source file
- NOTICE file lists all third-party deps + licenses
- `licensee` audit run in CI

### 36.5 Telemetry Statement

> **PerformanceBench does not collect, transmit, or aggregate any usage data, crash reports, analytics, or user identifiers from the desktop application. Local data stays local. Team server data stays on the operator's network. This is enforced by code, verifiable via packet capture (Appendix F.5), and required for the project's $0-cost / open-source identity.**

Pinned as `PRIVACY.md` repo root.

### 36.6 Acceptance Criteria

- [ ] `LICENSES.md` lists every dep license; CI checks no GPL contamination
- [ ] `PRIVACY.md` + `RISKS.md` + `COMPLIANCE.md` present at repo root
- [ ] Injector GUI shows reverse-engineering disclaimer at first run
- [ ] DPIA template in `docs/compliance/`

---

## 37. Code Signing, Notarization & Distribution

### 37.1 Funding Model

PB is $0 for users. Code-signing certs cost money. Resolution:
- **Optional GitHub Sponsors / Open Collective** for cert renewals
- Alternative: GitHub-funded certs via `signpath.io` (free for OSS)
- Fallback: ship unsigned + clear instructions for users

### 37.2 Windows Code Signing

| Path | Cost | Trust UX |
|---|---|---|
| Unsigned | $0 | SmartScreen "Don't run" warning, user clicks "More info" → "Run anyway" |
| Standard cert | ~$200/yr donation-funded | SmartScreen warns until reputation built (~weeks) |
| EV cert | ~$400/yr | Immediate trust, no SmartScreen warning |
| **SignPath Foundation (free for OSS)** | $0 | EV-equivalent trust |

Plan: apply to SignPath Foundation; fallback to unsigned with clear docs.

### 37.3 macOS Notarization

- Apple Developer Program: **$99/yr** required for notarization outside Mac App Store
- Funded via OpenCollective / GitHub Sponsors
- If unfunded: ship unsigned `.app`; document "right-click → Open" workaround

CI workflow `.github/workflows/macos.yml` includes `xcrun notarytool` step gated on secret `APPLE_API_KEY`.

### 37.4 Linux Distribution

- AppImage (primary) — no signing infrastructure required
- Flatpak — Flathub free for OSS
- Snap — Snapcraft free for OSS
- AUR (Arch) — community-maintained
- DEB / RPM — community-maintained

`pkg/linux/` directory holds packaging recipes.

### 37.5 Mobile App Distribution (PB Mobile, v2.0)

- iOS: TestFlight free (10K external testers); App Store distribution requires Apple Developer Program
- Android: GitHub Releases APK + F-Droid (free); Play Store distribution $25 one-time

### 37.6 Update Channel

- GitHub Releases primary
- Mirror via Cloudflare R2 free tier or `release-please`
- Release notes auto-generated from conventional commits
- SHA256 checksums published with each release

### 37.7 Antivirus False-Positive Handling

- Pre-submit binaries to VirusTotal monthly
- If FP: file vendor whitelisting requests (free)
- Document known-flag pattern in `docs/antivirus.md`

### 37.8 Acceptance Criteria

- [ ] CI builds Win exe + macOS dmg + Linux AppImage signed when secrets present
- [ ] Unsigned fallback works on all 3 OSes with clear user instructions
- [ ] SHA256 checksums published with every release
- [ ] `docs/install/{windows,macos,linux}.md` exist with security-warning walkthrough

---

## 38. Onboarding & First-Run UX

### 38.1 First-Run Flow

```
1. Welcome screen
   ├─ Logo + "Profile your apps with zero data leaks"
   ├─ "Let's set up — takes 60 seconds"
   └─ [Continue]

2. Privacy promise screen
   ├─ "Everything stays on this machine."
   ├─ Bullet list: no cloud, no account, no telemetry
   └─ [I understand]

3. Platform setup wizard
   ├─ Detect OS
   ├─ Show: "✓ ADB found at /usr/bin/adb" or "✗ ADB missing — Install"
   ├─ macOS: "✓ pyidevice ready" / "✗ Run: pip install pymobiledevice3"
   └─ [Re-check] / [Continue]

4. Sample session (optional)
   ├─ "Want to see how it works? Connect any Android device or load demo data."
   ├─ [Load demo session] / [Connect device] / [Skip]

5. Done
   ├─ "All set. Tip: press F1 anytime for keyboard shortcuts."
   └─ [Start]
```

### 38.2 Demo Session

Bundled `assets/demo_session.pbsession.zip` — 5-min recording of a public sample app on a Pixel 8. Loaded into local DB on first run if user opts in. Lets user explore charts/markers/comparison without a device.

### 38.3 Tooltips & Discoverability

- `?` icon next to each chart → explains the metric in 1 sentence + link to `§5.X`
- Empty states ("No sessions yet") show CTA + link to docs
- F1 → keyboard shortcut overlay
- Settings → "Reset onboarding" re-runs flow

### 38.4 Acceptance Criteria

- [ ] First run completes in ≤60s on Win/Mac/Linux
- [ ] User without ADB sees actionable install link
- [ ] Demo session loads and explores fully without device
- [ ] User can reset onboarding from settings

---

## 39. Auto-Update Strategy (No Telemetry)

### 39.1 Pull Model Only

PB never phones home. Updates use pull check:
- Settings → About → "Check for updates" button (manual)
- Sends one HTTPS GET to `https://api.github.com/repos/<org>/performancebench/releases/latest` only when user clicks
- Compares published `tag_name` to local version
- Result: "Up to date" or "Update available — open release page"
- **No download in-app.** User clicks → browser opens to GitHub Releases page → user downloads installer.

### 39.2 No Background Checks

No timer, no cron, no on-launch network calls. Privacy-preserving by construction.

### 39.3 Optional: Manual RSS

Users wanting notifications can subscribe to GitHub Releases RSS feed externally. PB does not provide a "watch" feature.

### 39.4 Acceptance Criteria

- [ ] App startup makes zero network calls (verified via tcpdump)
- [ ] "Check for updates" only fires on click
- [ ] Update result includes release notes preview from GitHub API
- [ ] Failure (no network / rate limited) shows graceful error with `PB-NET-002`

---

## 40. CI/CD Integration Recipes

> **Goal:** Studios can wire PerformanceBench into existing pipelines. Free, scriptable.

### 40.1 GitHub Actions

`.github/workflows/perf-benchmark.yml` (provided as template in repo):
```yaml
name: PerformanceBench Smoke
on: [pull_request]
jobs:
  perf:
    runs-on: [self-hosted, android]
    steps:
      - uses: actions/checkout@v4
      - name: Install PerformanceBench
        run: curl -L <release-url> -o pb && chmod +x pb
      - name: Run benchmark
        run: |
          ./pb --headless --device $DEVICE --app com.foo.game \
               --duration 600 --strict --tag build=${{ github.sha }} \
               --output results.json
      - name: Upload to team server
        run: |
          curl -X POST $PB_SERVER/api/sessions/upload \
               -H "Authorization: Bearer ${{ secrets.PB_TOKEN }}" \
               --data-binary @results.json
      - name: Fail on regression
        run: ./pb --check results.json --baseline main --threshold fps_median:-15%
```

### 40.2 GitLab CI

`gitlab-ci.yml` template provided.

### 40.3 Jenkins

Declarative pipeline template provided.

### 40.4 Headless Mode

Desktop app `--headless` flag:
- No window opens
- Logs to stdout/stderr
- Exits 0 on success, non-zero per `§29` error codes
- Same DB writes; results readable post-run via `pb --query "SELECT * FROM session_stats WHERE session_id='$ID'"`

### 40.5 SDK Clients (v2.0)

REST API client libs:
- Python: `pip install performancebench-client` (auto-generated from OpenAPI spec)
- JavaScript / TypeScript: npm package
- Go: `go get`-able module
- All OSS, MIT-licensed, in `clients/` repo dir

### 40.6 Acceptance Criteria

- [ ] `--headless` runs 10-min session, exits 0, writes session_stats row
- [ ] CI template `.github/workflows/perf-benchmark.yml` runs on PR (self-hosted runner with device)
- [ ] Python client `pb_client.list_sessions()` returns paginated list
- [ ] Regression check exits non-zero when threshold breached

---

## 41. Database Encryption at Rest

### 41.1 Default: OS-Level Disk Encryption

PB v1.0 relies on OS-level FDE:
- Windows: BitLocker
- macOS: FileVault
- Linux: LUKS / dm-crypt

Documentation strongly recommends enabling. PB does not encrypt DB itself by default — performance + complexity trade-off.

### 41.2 Optional: SQLCipher (v2.0)

Settings → Security → ☐ "Encrypt database with passphrase":
- Uses SQLCipher (BSD-licensed, free) — `sqflite_sqlcipher` for Flutter
- Passphrase prompted on app start
- Argon2id KDF
- Database file unreadable without passphrase
- Re-encryption migration for existing DBs

### 41.3 Caveats

- Forgotten passphrase = data loss (no recovery — by design)
- Performance hit: ~5-10% on writes
- Backup `.pbbackup` retains encryption — restore prompts for passphrase

### 41.4 Acceptance Criteria

- [ ] SQLCipher mode enabled → DB unreadable via raw `sqlite3` CLI
- [ ] Wrong passphrase → app refuses launch with `PB-DB-010`
- [ ] Backup → restore on different machine with same passphrase succeeds
- [ ] Forgot passphrase → "Reset (will erase data)" option present

---

## 42. Network Security Hardening

### 42.1 Web Dashboard (v2.0)

Headers via Axum middleware:
- `Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:`
- `Strict-Transport-Security: max-age=63072000; includeSubDomains`
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Referrer-Policy: same-origin`
- `Permissions-Policy: camera=(), microphone=(), geolocation=()`

### 42.2 API Authentication

- Bearer tokens (Section 24)
- Token format: random 32-byte URL-safe → SHA256-hashed in DB
- Rate limit: 100 req/min per token, 1000/min per IP
- Replay protection: optional HMAC signing for webhook callbacks

### 42.3 Webhook Signing

When PB server posts to user webhook:
```
X-PB-Signature: t=<unix_ts>,v1=<hmac_sha256(secret, t + body)>
```
Receiver verifies HMAC. Stripe-style. Documented in `docs/webhooks.md`.

### 42.4 TLS

- TLS 1.3 minimum
- Cert: user-provided (ACME/Let's Encrypt recommended; self-signed permitted for LAN)
- HSTS preload only opt-in
- Cipher suite: rust-tls defaults

### 42.5 Brute-Force Protection

- 5 failed logins per IP per 15 min → temporary lockout
- 10 failed total → admin notified via configured channel
- TOTP / 2FA optional from v2.0

### 42.6 Input Sanitization

- All user-generated content (notes, tags, marker labels) escaped before render
- React `dangerouslySetInnerHTML` forbidden in dashboard
- SQL: parameterized queries only (verified by SQL fluent library types)

### 42.7 File Upload Validation

- `.pbsession.zip` import: validate as zip first, max size 5 GB, decompression bomb check (cap ratio 100:1)
- IPA / APK in injector: validate magic bytes
- Path traversal: reject `..` in any imported zip path

### 42.8 Acceptance Criteria

- [ ] Mozilla Observatory grade ≥ A on web dashboard
- [ ] API rate limit returns 429 after threshold
- [ ] Webhook receiver rejects mismatched signature
- [ ] Zip bomb (1KB → 1GB) rejected with `PB-NET-005`
- [ ] XSS payload in session notes rendered safely (escaped, not executed)

---

## 43. Long-Session Performance Strategy

### 43.1 Problem

Sessions of 6h+ produce 21,600+ samples. Naive chart rendering = sluggish UI.

### 43.2 Display-Time Downsampling

When session > 1h, charts render with **Largest Triangle Three Buckets** (LTTB) downsampling:
- Target points: chart width pixels × 2 (typical 1500–3000 points)
- LTTB preserves visual peaks/valleys (better than mean/min/max)
- Implemented in `analytics/downsample.dart`
- Toggle: Settings → Charts → Sample resolution (Auto / Full / 1k / 5k / 30k points)

### 43.3 Database Performance

- Session > 100k samples → analytics queries use `WITH RECURSIVE` time-bucket SQL
- Indexes (Appendix C) cover `(session_id, timestamp)` for range scans
- WAL mode prevents reader/writer contention

### 43.4 Memory Ceiling

Flutter desktop process:
- Cap in-memory chart points at 30k per metric (auto-LTTB above)
- Image cache for screenshots: LRU, 200 MB max
- DB connection: single writer + 4-reader pool

### 43.5 Acceptance Criteria

- [ ] 6h session loads chart in < 2s on M1 Mac / Ryzen 5
- [ ] LTTB downsample preserves all jank spikes visible at full resolution
- [ ] Memory stays under 1 GB during 8h session viewing
- [ ] Switching between 1h / 6h / 24h sessions in UI < 500ms

---

## 44. Future Targets & Reserved Roadmap Slots

### 44.1 visionOS (Apple Vision Pro) — v4.0 candidate

When Apple opens DTXProtocol on visionOS (or through a different channel):
- Add `target_kind = 'visionos'`
- New metric: gaze-tracking latency, render-thread time per eye
- Foveation rendering quality

### 44.2 Smart TV Platforms — v4.0 candidate

- Android TV (already covered via Android target)
- Roku — likely no profiling API, document
- Samsung Tizen — TV SDK exposes some metrics
- LG webOS — limited

### 44.3 WearOS / watchOS — v4.0 candidate

- Lower priority, smaller market
- Battery life primary metric

### 44.4 Cloud Gaming Targets — v4.5 candidate

- GeForce NOW / Xbox Cloud / Stadia-style — profile client app, network is the metric
- Latency emphasis over compute

### 44.5 ML-Based Detection — v4.0 candidate

- Anomaly detection trained on user's own historical sessions (local model)
- Auto-tagging "this looks like a typical loading screen jank pattern"
- All training local (Rust + tract / candle)

### 44.6 Reserved Schema Slots

`metric_samples.reserved_1` through `reserved_8` — added v3.5 for forward-compat without migration thrash.

### 44.7 Acceptance Criteria (when each ships)

Per-target acceptance defined when each enters active development. Section reserved as placeholder for now.

---

## Appendix F: Spec Self-Audit Checklist (For Agent Coders)

Run this checklist after each major feature implementation. Any failure → fix before moving on.

### F.1 Schema Integrity

- [ ] `sqlite3 performancebench.db .schema` matches Appendix C exactly (column names, types, NOT NULL, FK)
- [ ] `schema_version` row matches the migration just applied
- [ ] All FK constraints emit `ON DELETE CASCADE` where spec requires (look for `REFERENCES ... ON DELETE CASCADE`)
- [ ] Indexes from Appendix C all present: `idx_samples_session_time`, `idx_markers_session`, etc.

### F.2 Metric Pipeline

- [ ] Each metric in §4.3 has a parser file named per §12 File Structure
- [ ] Each parser returns `null` on failure; **never** throws into the collector loop
- [ ] Each parser has a unit test in `test/parsers/` with at least 3 cases: happy path, malformed input, empty input
- [ ] Collector loop runs at 1Hz ±50ms drift over 10-min session (verified via timestamp diffs)
- [ ] All ADB calls wrapped with 3s timeout; all pyidevice calls wrapped similarly
- [ ] Network bytes stored cumulative; deltas computed at analytics time only

### F.3 Analytics Correctness

- [ ] FPS analytics tests in §6.1 acceptance criteria pass
- [ ] Power analytics (§6.6) tests pass: 30-min × 500mA → mAh ≈ 250 (±5%)
- [ ] Memory subsection sums approximately equal `memory_pss_kb` (±10%)
- [ ] Variability Index = 0 for all-equal samples
- [ ] Frame-ratio jank Γ=L/R model produces non-zero count on a deliberately janky test trace

### F.4 UI Compliance

- [ ] Dark theme matches VS Code Dark+ within ±5 Lightness points (§9.1)
- [ ] Charts update at 1Hz visually during recording; no dropped frames > 33ms on M1 / Ryzen 5
- [ ] Custom title bar is draggable on Win + Mac (§9.3)
- [ ] All 9 screens (§9.2–§9.10) present and reachable via navigation
- [ ] Active session screen renders all metric cards from §4.3 with charts

### F.5 Privacy Verification

- [ ] tcpdump or wireshark on host machine during 30-min session → zero outbound packets to non-`localhost` / non-LAN (with team server off)
- [ ] No analytics SDK in `pubspec.yaml` or `Cargo.toml`
- [ ] No crash reporter that uploads (Sentry/Firebase Crashlytics/etc.)
- [ ] Export feature requires manual user click; no auto-export
- [ ] Team server upload requires explicit opt-in per session (default off)

### F.6 Build / Distribution

- [ ] `flutter build windows --release` produces signed or unsigned `.exe` that launches on clean Win11 VM
- [ ] `flutter build macos --release` produces `.app`; notarized if Developer ID present, else opens with Gatekeeper override
- [ ] `flutter build linux --release` produces AppImage that runs on Ubuntu 22.04 LTS
- [ ] CI green: GitHub Actions free tier covers all 3 OS builds + tests
- [ ] Release artifacts attached to GitHub Releases tag

### F.7 Cross-Platform Sanity

- [ ] Same DB created on Win/Mac/Linux opens cross-platform (SQLite is portable; verify schema_version reads)
- [ ] Path handling uses `path` package, not raw string concat
- [ ] No hardcoded `\` or `/` separators
- [ ] OS detection via `Platform.isWindows`/`isMacOS`/`isLinux` for OS-specific code paths

### F.8 Dependency Audit

- [ ] Every dependency in `pubspec.yaml` / `Cargo.toml` has a permissive license (MIT/Apache-2.0/BSD/MPL-2.0). No GPL except optional/separable tools (e.g. `wkhtmltopdf` for PDF reports — invoked as subprocess, not linked)
- [ ] No paid SaaS API keys required for build or test
- [ ] No pinned-to-private-registry deps

### F.9 Documentation

- [ ] `README.md` exists at repo root with quick-start in ≤5 commands
- [ ] `CONTRIBUTING.md` references this UNIFIED-SPEC.md as source of truth
- [ ] `LICENSE` file present (MIT for desktop/injector/mobile, Apache-2.0 for server)
- [ ] `CHANGELOG.md` updated per release tag
- [ ] Inline comments minimal and only for non-obvious WHY (per project policy)

### F.10 Final Gate Before Release

- [ ] All §16 Parity Matrix entries for current version marked ✅ are actually working on real device
- [ ] At least one full session recorded on each supported OS host × supported target combination
- [ ] Smoke test: 30-min Genshin Impact session on Pixel 8 + iPhone 15 produces sensible numbers
- [ ] Bug bash with at least 3 testers, zero critical issues open

---

## Appendix G: Agent FAQ (Common Questions Answered)

**Q: I cannot find an obvious entry point. Where do I start?**
A: §7 Week 1. Scaffold via `flutter create performancebench --platforms=windows,macos,linux`. Then implement §8 schema. Then §5.1 FPS parser.

**Q: The user asked for feature X. Spec doesn't mention it. What do I do?**
A: Stop. Ask user. Do not invent. If they confirm, propose adding a new section to spec first, then implement.

**Q: ADB command in Appendix D returns different output on my test device. What do I do?**
A: Output format varies by Android version. §5 parsers must tolerate variation. Add a parser branch + a test case. Do not mutate the ADB command.

**Q: Should I use `ChangeNotifier`, `Riverpod`, `BLoC`, `Provider`, etc.?**
A: §13.6 lists key dependencies. Default to `Riverpod` per §7 Week 1. Do not introduce alternatives without user approval.

**Q: pyidevice fails on iOS 18. What do I do?**
A: Update `pymobiledevice3` to latest. If still fails, document in §10 (Platform Limitations) and store NULL for affected metrics. Never fabricate.

**Q: Can I add a metric not in §4.3 because GameBench has it?**
A: Only if §16 lists it as v1.0 ✅ and §5 has a sub-section for it. Otherwise it goes in v1.5+ roadmap (§11).

**Q: I think the spec is wrong about X. Can I deviate?**
A: No. Open a discussion / issue. User decides. Spec evolves through edits, not silent code drift.

**Q: How do I handle a crash mid-session?**
A: §3 Architecture + §15 Security: ring buffer flush on `atexit` / `FlutterError.onError`. Session marked `ended_at = now()` with note "crashed". Strict mode restoration (§20.3) MUST run.

**Q: What about i18n / translations?**
A: All user-facing strings go in `lib/l10n/app_en.arb`. v1.0 ships en-US only. Other locales via community PRs in v1.5+.

**Q: Do I need to support 32-bit OSes?**
A: No. 64-bit only. Windows 10+, macOS 12+, Linux glibc 2.31+.

**Q: A test is flaky. Can I disable it?**
A: No. Investigate root cause (timing, device state, network). If genuine flake, mark `@Tags(['flaky'])` in Dart and exclude from CI by default — but keep in repo for manual run. Document in test file.

**Q: I see two ways to implement §5.X. Which is canonical?**
A: The one matching the **acceptance criteria** at end of section. If both pass, prefer the one closer to the §6 algorithm pseudocode style.

**Q: How do I structure git commits?**
A: Conventional Commits: `<type>(<scope>): <subject>`. Types: `feat`, `fix`, `chore`, `docs`, `test`, `refactor`, `build`, `ci`, `perf`. Scope optional but encouraged: `feat(fps): SurfaceFlinger parser`.

**Q: Should I push to GitHub immediately?**
A: Only commit locally unless user explicitly says push. Public push is a hard stop-gate (§E.5 of Onboarding).

**Q: GameBench has feature Z that doesn't seem to fit any section. Where does it belong?**
A: Re-read §16 Parity Matrix sub-tables (§16.1–§16.6). If not listed, check §17 Permanent Gaps. If neither, ask user — it may be a missing entry.

---

## Appendix H: Cross-Reference Index

Quick-lookup table for agentic coders. When implementing a feature, find the spec sections you must read.

| Implementing... | Read sections |
|---|---|
| FPS parser | §5.1, §5.1.1, Appendix D (FPS row), §6.1 |
| CPU parser | §5.2, §5.2.1, §5.2.2, Appendix D |
| Memory parser | §5.3, §5.3.1, §6.7 |
| Battery / Power | §5.4, §6.6, Appendix D battery rows |
| Network parser | §5.5, §6.8 |
| Thermal parser | §5.6 |
| GPU parser | §5.7, Appendix A |
| Disk I/O parser | §5.8 |
| iOS metrics | §5.10, Appendix B, Appendix E.2 |
| Static device data | §5.11, Appendix E |
| Screenshots (5 sizes) | §5.12 |
| FPS analytics | §6.1 |
| Per-marker stats | §6.2 |
| Session stats | §6.3 |
| Comparison delta | §6.4 |
| Launch Complete | §6.5 |
| Power analytics | §6.6 |
| Memory analytics | §6.7 |
| Network analytics | §6.8 |
| Auto-detected issues | §6.9 |
| Schema | §8, Appendix C |
| Design system | §9.1 |
| App shell | §9.2, §9.3 |
| Charts | §9.4, §9.5 |
| Session screens | §9.5–§9.8 |
| Settings | §9.9 |
| Flutter notes | §9.10 |
| iOS-on-Win limits | §10.1 |
| GPU support matrix | §10.2, Appendix A |
| Roadmap | §11 |
| File structure | §12 |
| Setup | §13 |
| Tests | §14 |
| Privacy | §15 |
| Parity tracking | §16 |
| Permanent gaps | §17 |
| Injector — Android | §18.1–§18.4, §18.8–§18.14 |
| Injector — iOS | §18.5–§18.7, §18.8–§18.14 |
| PC profiling | §19 |
| Strict mode | §20 |
| Production mode | §21 |
| Web dashboard analytics | §22 |
| Alerts / notifications | §23 |
| Auth | §24 |
| tvOS | §25 |
| Mobile profiler | §26 |
| Self-audit | Appendix F |
| FAQ | Appendix G |

---

## Appendix I: Per-Model Optimization Hints

Different LLM coders behave differently. Hints to help each get best output. Do not let hints override spec — spec wins.

### I.1 Claude Code (Claude Opus / Sonnet)

- Strong at long-context reading. Read full spec once at session start.
- Prefer Skill tool / TaskCreate for structured work.
- Use Edit tool over Write for existing files.
- Excellent at acceptance-test-driven implementation.

### I.2 Google Antigravity (Gemini 2.5 Pro / Gemini 3)

- 1M+ token context — load entire spec + repo for cross-reference work.
- Strong at multi-file refactors. Implement parser + test + DAO together.
- Use built-in browser for design references when implementing §9 UI.

### I.3 OpenCode (model-agnostic CLI)

- Behaves per chosen backend. Use Claude Sonnet 4.6 / Opus 4.7 for best result.
- Long-running sessions: re-read Onboarding section between major tasks.

### I.4 GPT-5 Codex / GPT-4.1

- Prefer smaller, focused prompts: one section at a time.
- Use the §H Cross-Reference Index to scope reads narrowly.
- Strong at SQL — start at §8/Appendix C migrations.

### I.5 MiniMax M2 / abab-7

- Code at par with frontier; prefer Chinese-language reasoning if natural — output English code/comments.
- Decompose §5 metric parsers into one per turn.

### I.6 Kimi K2

- 256k context — load full §5 + Appendix D in single read.
- Strong tool use. Wire ADB commands with subprocess wrapping early.

### I.7 Qwen Coder / DeepSeek-Coder

- Excellent for Rust (server v2.0) + low-level (injector .so).
- Generate idiomatic Cargo.toml; verify dependency licenses (Appendix F.8).

### I.8 Smaller models (≤32B)

- Limit per-turn scope to one parser or one screen.
- Always re-read the section being edited; do not rely on memory.
- Run tests after every change.

### I.9 Universal advice (any model)

- Begin every new conversation by re-reading the **Agentic Coder Onboarding** section at top of spec.
- Never trust memory of prior conversation — verify against current spec text.
- Append to `CHANGELOG.md` after each session.
- Commit per finished section.

---
