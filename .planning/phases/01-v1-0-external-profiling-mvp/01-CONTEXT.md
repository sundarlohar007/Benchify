# Phase 1: v1.0 External Profiling MVP - Context

**Gathered:** 2026-05-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Ship installable Flutter desktop app (Windows + macOS + Linux) that profiles Android and iOS devices via ADB/pyidevice at 20+ real-time metrics, with live charts, session storage/playback/comparison, screenshot capture, and JSON/CSV export. 29 requirements (MVP-01 through MVP-29). 7 days.

</domain>

<decisions>
## Implementation Decisions

### Development Flow
- **D-01:** Both Android + iOS built in parallel — iOS code written alongside Android from start
- **D-02:** Skeleton-first approach — scaffold entire Flutter project (all screens, navigation, services, DB) first, then fill features wave by wave
- **D-03:** Follow ROADMAP.md wave order exactly: scaffold/DB/ADB → parsers → charts/ring buffer → analytics → iOS → history/comparison → export → polish/installers
- **D-04:** Android tested locally on Windows; iOS tested via CI (GitHub Actions macOS runner)

### iOS Strategy on Windows
- **D-05:** CI-based testing via GitHub Actions macOS runner for all iOS code
- **D-06:** Full iOS test suite on CI — every parser, edge case, integration test (not just smoke)
- **D-07:** Bundle Python 3.10+ embedded with app — pyidevice installed automatically, zero user setup

### Testing Cadence
- **D-08:** TDD (Red-Green-Refactor) throughout — write failing test first per spec §14
- **D-09:** Critical path 100% coverage — metric parsers, analytics algorithms, database operations. UI smoke tests only
- **D-10:** CI-only integration tests — Android emulator (GitHub Actions) + macOS runner for iOS. No manual device testing required during build

### Packaging Strategy
- **D-11:** All platforms from start — Windows NSIS installer, macOS DMG, Linux AppImage
- **D-12:** Full CI matrix on every push — windows-latest + macos-latest + ubuntu-latest

### Design System
- **D-13:** VS Code-inspired, not pixel-cloned — dark theme default, adapted for profiling tool context
- **D-14:** Four theme options: Dark (default), Light, High Contrast, System (follows OS setting)
- **D-15:** Design tokens as Flutter ThemeData — consistent across all screens

### Error Resilience
- **D-16:** Dual mode — Debug mode (full stack traces, ADB command output, `--debug` flag) vs Release mode (graceful null, minimal logging)
- **D-17:** Status bar with error count indicator + clickable log panel for surfacing non-fatal errors during profiling

### Privacy Verification
- **D-18:** Privacy guard built from project scaffold — no network code except localhost
- **D-19:** Network access deny-list enforced in CI from day 1
- **D-20:** Automated packet capture test in CI verifies zero outbound connections during 30-min session

### Claude's Discretion

None — user made all decisions. Implementation approach, architecture patterns, state management, and code organization are Claude's domain per spec §G conventions.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Spec & Requirements
- `UNIFIED-SPEC.md` — single source of truth. All hard contracts: schema (Appendix C), metric parsers (§5), analytics algorithms (§6), UI screens (§9), testing (§14), forbidden patterns (§F), stop-gates (§E). 309KB — read relevant sections per task.
- `implementation_plan.md` — 12-week sprint breakdown for v1.0, phase-level goals for v1.5–v3.5

### Planning Documents
- `.planning/PROJECT.md` — project context, core value, constraints (May 31 deadline), key decisions
- `.planning/REQUIREMENTS.md` — 29 MVP requirements (MVP-01 through MVP-29) for Phase 1
- `.planning/ROADMAP.md` — phase structure, wave order, dependency graph, risk register
- `.planning/config.json` — YOLO mode, coarse granularity, parallel execution, quality model profile

### Phase-Specific
- `UNIFIED-SPEC.md` §4 (MVP Scope v1.0) — exact v1.0 scope, metrics list, deferred features
- `UNIFIED-SPEC.md` §5 (Metrics Reference) — parser formulas and ADB command contracts
- `UNIFIED-SPEC.md` §8 (Database Schema) + Appendix C (SQL DDL) — hard schema contract
- `UNIFIED-SPEC.md` §9 (UI/UX Specification) — all screens and design system
- `UNIFIED-SPEC.md` §12 (File Structure) — repository layout
- `UNIFIED-SPEC.md` §13 (Prerequisites and Setup) — environment bootstrap checklist
- `UNIFIED-SPEC.md` §14 (Testing Strategy) — test requirements and acceptance criteria

</canonical_refs>

<code_context>
## Existing Code Insights

Greenfield project — no existing codebase. First code written will be Flutter project scaffold.

### Project Conventions (from spec)
- Language: Dart (Flutter 3.19+), Python 3.10+ (iOS via pyidevice)
- Database: SQLite via `sqflite_common_ffi`
- Charts: `fl_chart`
- Package ID: `pb` (short name), binary: `performancebench`
- Data dir: OS-conventional (`%APPDATA%\PerformanceBench\` on Windows, `~/Library/Application Support/PerformanceBench/` on macOS, `~/.local/share/performancebench/` on Linux)
- Encoding: UTF-8 everywhere, JSON without BOM, LF in repo

### Forbidden Patterns (spec §F)
- No cloud telemetry, analytics SDKs, crash reporters
- No mock data masquerading as real metrics — store NULL + log
- No closed-source dependencies for core functionality
- No blocking I/O on UI thread
- No blocking ADB/pyidevice calls > 3 seconds without timeout
- No unbounded ring buffers (max 60s in-memory)
- No deletion of user sessions without explicit confirmation
</code_context>

<specifics>
## Specific Ideas

- User wants the app to feel like a professional dev tool — VS Code-inspired dark theme with multiple theme options
- Zero-setup iOS experience — Python bundled, pyidevice auto-installed
- Privacy is non-negotiable — automated verification from day 1, not afterthought
- CI-first development — full matrix builds on every push, TDD throughout

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. All 29 MVP requirements are in Phase 1.

</deferred>

---

*Phase: 1-v1.0 External Profiling MVP*
*Context gathered: 2026-05-04*
