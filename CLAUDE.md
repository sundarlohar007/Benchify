# Benchify

Free, open-source mobile + desktop performance profiler — GameBench alternative at $0. Local-only data, MIT license. Internal codename: PerformanceBench (binaries, package names). GitHub: https://github.com/sundarlohar007/Benchify

## Workflow
- GSD workflow active. Follow `.planning/PROJECT.md` + `.planning/ROADMAP.md`
- YOLO mode — auto-approve, just execute
- Coarse granularity — 6 phases, fewest possible
- Parallel execution — independent tasks run simultaneously
- Verifier enabled — verify work after each phase

## Hard Contracts (from UNIFIED-SPEC.md)
- SQL schema matches Appendix C exactly — no deviations
- Metric parsers match §5 formulas exactly
- Forbidden patterns (§F): no cloud telemetry, no mock data, no paid deps, no unbounded ring buffers, no blocking I/O on UI thread
- Stop-gates (§E): ask user before schema changes, skipping metrics, adding network calls, bumping major deps, adding features outside spec, language changes

## Source of Truth
- `UNIFIED-SPEC.md` — complete behavioral specification (309KB)
- `implementation_plan.md` — phase summary and sprint breakdown
- `.planning/PROJECT.md` — living project context
- `.planning/REQUIREMENTS.md` — 90 requirements across 6 phases
- `.planning/ROADMAP.md` — phase structure, waves, dependencies

## Current State
All 6 phases implemented. Desktop + Mobile + Server + Web + Injector + SDK + Game Engine plugins are functional.
Audit branch `audit/v0.1.x` completed 20/20 slices with 199 findings (84 fixed).
Next: CI stabilization sprint → first tagged release `v0.1.0`.
