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
| S-05  | Flutter mobile — runtime                                    | DONE        |       14 | [slice-05](./slice-05-flutter-mobile-runtime.md) |
| S-06  | Flutter mobile — Android side                               | DONE        |        6 | [slice-06](./slice-06-flutter-mobile-android.md) |
| S-07  | Flutter mobile — iOS side                                   | DONE        |        4 | [slice-07](./slice-07-flutter-mobile-ios.md)    |
| S-08  | Mobile companion — install + first-run UX                   | DONE        |        9 | [slice-08](./slice-08-mobile-companion-ux.md)   |
| S-09  | Injector — Python core (frida, smali, manifest, resigner)   | DONE        |        8 | [slice-09](./slice-09-injector-python-core.md)  |
| S-10  | Injector — CLI + workflows                                  | DONE        |       10 | [slice-10](./slice-10-injector-cli.md)          |
| S-11  | Injector — SDK Rust lib (transport, jni_bridge, automation) | DONE        |       12 | [slice-11](./slice-11-injector-sdk-rust-lib.md) |
| S-12  | Injector — SDK metrics                                      | DONE        |       10 | [slice-12](./slice-12-injector-sdk-metrics.md)  |
| S-13  | Injector — engine_core + game-engine plugins                | DONE        |        8 | [slice-13](./slice-13-injector-engine-core.md)  |
| S-14  | pcprobe — Rust PC profiler binary                           | DONE        |       10 | [slice-14](./slice-14-pcprobe-binary.md)        |
| S-15  | pcprobe — PC metrics modules                                | DONE        |        8 | [slice-15](./slice-15-pcprobe-pc-metrics.md)    |
| S-16  | pcprobe — PC video capture                                  | pending     |        — |                                                 |
| S-17  | Web dashboard — data + state                                | pending     |        — |                                                 |
| S-18  | Web dashboard — UI                                          | pending     |        — |                                                 |
| S-19  | Build, packaging, CI                                        | pending     |        — |                                                 |
| S-20  | Cross-cutting — golden user flows + final regression        | pending     |        — |                                                 |

## Roll-up counters

(Updated at end of each slice.)

| Severity | Open | Fixed | Deferred | Wontfix | Total |
|----------|-----:|------:|---------:|--------:|------:|
| BLOCKER  |    0 |     2 |        2 |       0 |     4 |
| HIGH     |    0 |    22 |        8 |       0 |    30 |
| MED      |    0 |    28 |       30 |       0 |    58 |
| LOW      |    0 |    14 |       28 |       0 |    42 |
| NIT      |    0 |     8 |       12 |       0 |    20 |
| **All**  |    0 |    74 |       80 |       0 |   154 |

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
