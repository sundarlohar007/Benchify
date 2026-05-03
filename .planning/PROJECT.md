# PerformanceBench

## What This Is

Free, open-source mobile + desktop performance profiler — GameBench alternative at $0. Cross-platform desktop app (Windows, macOS, Linux) that connects to Android, iOS, tvOS, and Windows PC targets to collect real-time performance metrics (FPS, CPU, memory, battery, network, thermal, GPU). Built in Flutter desktop + SQLite + Python (pyidevice for iOS) + Rust (server v2.0). MIT licensed. All data stays local.

## Core Value

Reliable, zero-cost performance profiling for any mobile or desktop app — no cloud dependency, no paid license, no data ever leaving the host machine.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Phase 1: v1.0 — External Profiling MVP (Flutter desktop + Android/iOS profiling + charts + sessions + export)
- [ ] Phase 2: v1.5 — Analysis + Platform Expansion (drag-region stats, disk I/O, threshold alerts, video recording)
- [ ] Phase 3: v2.0 — Team Server + Web Dashboard + CI/CD (Rust/Axum backend, React dashboard, REST API)
- [ ] Phase 4: v2.5 — Android SDK Injection (APK injection, Frida gadget, in-app overlay)
- [ ] Phase 5: v3.0 — Game Engine Plugins + iOS Injection + tvOS + PC (Unity/Unreal/Godot plugins, Windows PC profiling)
- [ ] Phase 6: v3.5 — Enterprise (SAML SSO, LDAP, RBAC, audit log, on-premises deployment)

### Out of Scope

- Cloud telemetry or analytics — forbidden (privacy contract)
- Paid/proprietary dependencies for core functionality
- Mobile app as primary profiler (read-only viewer only, v2.0 optional)
- Real-time chat or collaboration features
- Auto-updaters that download executables (version check only)

## Context

PerformanceBench replaces GameBench ($400+/yr license) for mobile game and app developers who need production-grade performance profiling. Two comprehensive spec documents define the entire product: `UNIFIED-SPEC.md` (~309KB, full behavioral contracts, schemas, parsers, UI specs) and `implementation_plan.md` (12-week v1.0 sprint breakdown + phase-level goals for v1.5 through v3.5).

The UNIFIED-SPEC.md is the single source of truth — it defines WHAT to build with exact behavioral contracts. All hard contracts (schema §8, Appendix C DDL, Appendix D ADB commands, §5 metric parsers) must match exactly.

Target timeline compresses all 6 phases into 27 days (May 4 → May 31, 2026). Requires aggressive parallelization, coarse phase slicing, and YOLO execution mode.

## Constraints

- **Timeline**: All 6 phases must complete by May 31, 2026 (27 days from init)
- **Tech stack**: Flutter desktop + SQLite + Python (pyidevice) + Rust (v2.0+) — no substitutions per spec §2
- **License**: MIT (desktop + injector + mobile-profiler), Apache-2.0 (server)
- **Privacy**: No data ever leaves host machine — verified via packet capture
- **Cost**: $0 forever — no infra cost, no dev cost, no user cost
- **Compatibility**: Windows + macOS + Linux hosts; Android + iOS + tvOS + Windows PC targets
- **Hard contracts**: Schema must match Appendix C exactly; metric parsers must match §5 formulas; forbidden patterns (§F) enforced

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Flutter desktop for UI | Cross-platform from single codebase, matches spec §2 | — Pending |
| SQLite for local storage | Zero infra cost, embedded, matches privacy constraint | — Pending |
| Python (pyidevice) for iOS | Only reliable open-source iOS device bridge, matches spec §3 | — Pending |
| Rust for server (v2.0) | Performance + safety for multi-user server, matches spec §2 | — Pending |
| Follow UNIFIED-SPEC.md exactly | Hard contracts prevent drift; spec is single source of truth | — Pending |
| Build all 6 phases by May 31 | User deadline — requires parallel execution, 27-day sprint | — Pending |
| GSD workflow: YOLO + Coarse + Parallel | Matches aggressive timeline — auto-approve, fewest phases, max parallelism | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-04 after initialization*
