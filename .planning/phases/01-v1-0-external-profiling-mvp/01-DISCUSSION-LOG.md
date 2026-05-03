# Phase 1: v1.0 External Profiling MVP - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-04
**Phase:** 1-v1.0 External Profiling MVP
**Areas discussed:** Development flow, iOS strategy on Windows, Testing cadence, Packaging strategy, Design system fidelity, Error resilience vs debuggability, Privacy verification

---

## Development Flow

| Option | Description | Selected |
|--------|-------------|----------|
| Android-first | Build + test Android first, add iOS later | |
| Both in parallel | Write Android and iOS code simultaneously | ✓ |

**User's choice:** Both platforms built in parallel

---

| Option | Description | Selected |
|--------|-------------|----------|
| Skeleton first | Scaffold entire Flutter project with all screens, navigation, services, DB first | ✓ |
| Depth-first | Complete one vertical slice end-to-end before next | |

**User's choice:** Skeleton first — scaffold everything, then fill features

---

| Option | Description | Selected |
|--------|-------------|----------|
| Follow wave order | ROADMAP.md wave order (scaffold → parsers → charts → analytics → iOS → history → polish) | ✓ |
| Prioritize visible UI | Build charts + history screens early for visual feedback | |

**User's choice:** Follow ROADMAP.md wave order exactly

---

## iOS Strategy on Windows

| Option | Description | Selected |
|--------|-------------|----------|
| Build blind, test later | Write iOS code on Windows, test when Mac available | |
| CI-based testing | GitHub Actions macOS runner for iOS tests | ✓ |
| Remote Mac access | Cloud Mac for development + testing | |

**User's choice:** CI-based testing via GitHub Actions macOS runner

---

| Option | Description | Selected |
|--------|-------------|----------|
| Smoke tests | Verify iOS collector starts, connects, produces valid format | |
| Full test suite | Every parser, edge case, integration test on CI | ✓ |

**User's choice:** Full iOS test suite on CI

---

| Option | Description | Selected |
|--------|-------------|----------|
| Bundle Python env | Ship Python 3.10+ embedded, pyidevice auto-installed | ✓ |
| Require user install | Document pyidevice setup steps | |

**User's choice:** Bundle Python 3.10+ embedded — zero user setup

---

## Testing Cadence

| Option | Description | Selected |
|--------|-------------|----------|
| TDD | Red-Green-Refactor per spec §14 | ✓ |
| Test-after | Implement first, tests after feature works | |

**User's choice:** TDD throughout

---

| Option | Description | Selected |
|--------|-------------|----------|
| Critical path only | 100% on parsers, analytics, DB; UI smoke tests | ✓ |
| 80%+ overall | High coverage everywhere | |

**User's choice:** Critical path 100% coverage — parsers, analytics, DB

---

| Option | Description | Selected |
|--------|-------------|----------|
| CI only | Android emulator + macOS runner for iOS | ✓ |
| Manual + CI | CI automated + manual real-device testing | |

**User's choice:** CI-only integration tests

---

## Packaging Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| All platforms from start | CI matrix builds for Win/Mac/Linux immediately | ✓ |
| Windows-first | Build Windows installer first, add others later | |

**User's choice:** All platforms from start — full CI matrix

---

| Option | Description | Selected |
|--------|-------------|----------|
| Full CI matrix | GitHub Actions windows-latest + macos-latest + ubuntu-latest on every push | ✓ |
| Windows CI + manual others | CI for Windows, manual macOS/Linux builds | |

**User's choice:** Full CI matrix on every push

---

## Design System Fidelity

| Option | Description | Selected |
|--------|-------------|----------|
| Close clone | Match VS Code color tokens, spacing, layout exactly | |
| Inspired by, not clone | VS Code reference but adapted for profiling context | ✓ |

**User's choice:** VS Code-inspired, not pixel-cloned — adapted for profiling tool

---

| Option | Description | Selected |
|--------|-------------|----------|
| Dark theme only | Default dark, single theme | |
| Multiple themes | Dark, Light, High Contrast, System — four theme options | ✓ |

**User's choice:** Four theme options — Dark (default), Light, High Contrast, System

---

## Error Resilience vs Debuggability

| Option | Description | Selected |
|--------|-------------|----------|
| Dual mode | Debug mode (full traces, --debug flag) vs Release (graceful null) | ✓ |
| Always verbose | Full logging everywhere | |

**User's choice:** Dual mode with --debug flag toggle

---

| Option | Description | Selected |
|--------|-------------|----------|
| Status bar + log panel | Error count indicator, clickable log panel for details | ✓ |
| Toast notifications | Brief per-error toasts | |
| Silent — log only | Debug log file, no UI indication | |

**User's choice:** Status bar error count + clickable log panel

---

## Privacy Verification

| Option | Description | Selected |
|--------|-------------|----------|
| Guard from start | No network code except localhost, deny-list in CI, automated packet capture test | ✓ |
| Verify at end only | Build normally, run 30-min packet capture at phase end | |

**User's choice:** Privacy guard built from project scaffold — automated from day 1

---

## Claude's Discretion

None — user made all decisions explicitly.

## Deferred Ideas

None — discussion stayed within Phase 1 scope.
