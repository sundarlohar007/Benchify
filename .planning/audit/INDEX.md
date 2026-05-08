# Audit Index — `audit/v0.1.x`

Top-level tracker for the 20-slice (5%-each) bug-hunt of the Benchify codebase. Updated at the end of each slice.

## Goal

End-user smooth path:
- **Desktop**: download installer → install → run profiler.
- **Mobile**: install profiler → inject APK/IPA → install patched build on device → start session.

Every bug surfaced gets a stable ID in [`FINDINGS.md`](./FINDINGS.md). Cross-slice references use those IDs only — never restate the bug.

## Slice progress

| #     | Area                                                        | Status      | Findings | Slice report                                    |
|-------|-------------------------------------------------------------|-------------|---------:|-------------------------------------------------|
| S-01  | Flutter desktop — main + lifecycle                          | DONE        |        7 | [slice-01](./slice-01-flutter-desktop-main.md)  |
| S-02  | Flutter desktop — services                                  | DONE        |       26 | [slice-02](./slice-02-flutter-desktop-services.md) |
| S-03  | Flutter desktop — parsers / utils                           | DONE        |        8 | [slice-03](./slice-03-flutter-desktop-parsers.md) |
| S-04  | Flutter desktop — UI screens                                | DONE        |        9 | [slice-04](./slice-04-flutter-desktop-ui.md)    |
| S-05  | Flutter mobile — runtime                                    | pending     |        — |                                                 |
| S-06  | Flutter mobile — Android side                               | pending     |        — |                                                 |
| S-07  | Flutter mobile — iOS side                                   | pending     |        — |                                                 |
| S-08  | Mobile companion — install + first-run UX                   | pending     |        — |                                                 |
| S-09  | Injector — Python core (frida, smali, manifest, resigner)   | pending     |        — |                                                 |
| S-10  | Injector — CLI + workflows                                  | pending     |        — |                                                 |
| S-11  | Injector — SDK Rust lib (transport, jni_bridge, automation) | pending     |        — |                                                 |
| S-12  | Injector — SDK metrics                                      | pending     |        — |                                                 |
| S-13  | Injector — engine_core + game-engine plugins                | pending     |        — |                                                 |
| S-14  | pcprobe — Rust PC profiler binary                           | pending     |        — |                                                 |
| S-15  | pcprobe — PC metrics modules                                | pending     |        — |                                                 |
| S-16  | pcprobe — PC video capture                                  | pending     |        — |                                                 |
| S-17  | Web dashboard — data + state                                | pending     |        — |                                                 |
| S-18  | Web dashboard — UI                                          | pending     |        — |                                                 |
| S-19  | Build, packaging, CI                                        | pending     |        — |                                                 |
| S-20  | Cross-cutting — golden user flows + final regression        | pending     |        — |                                                 |

## Roll-up counters

(Updated at end of each slice.)

| Severity | Open | Fixed | Deferred | Wontfix | Total |
|----------|-----:|------:|---------:|--------:|------:|
| BLOCKER  |    0 |     0 |        1 |       0 |     1 |
| HIGH     |    0 |     5 |        3 |       0 |     8 |
| MED      |    0 |     9 |       12 |       0 |    21 |
| LOW      |    0 |     5 |        8 |       0 |    13 |
| NIT      |    0 |     4 |        3 |       0 |     7 |
| **All**  |    0 |    23 |       27 |       0 |    50 |

## Conventions

- **Finding IDs** are sequential (`B-001`, `B-002`, …). Never reused, never reordered.
- **Severity ladder**:
  - BLOCKER — user can't install / can't launch / core feature broken
  - HIGH — crash, data loss, wrong metric, security hole
  - MED — degraded UX, edge-case fail, missing validation
  - LOW — perf nit, cosmetic, dead code
  - NIT — typo, comment, style
- **Status values**: `OPEN`, `FIXED:<commit-sha>`, `DEFERRED-TO-S<NN>`, `WONTFIX (<reason>)`.
- **Fix policy this run**: fix only local + low-risk inside the slice that surfaced it. Cross-slice or risky → mark `DEFERRED-TO-Sxx` and resolve when context is fuller.
- Every commit message references slice + IDs touched: `audit(S-NN): <area> — N findings (B-XXX..B-YYY), M fixed, K deferred`.
