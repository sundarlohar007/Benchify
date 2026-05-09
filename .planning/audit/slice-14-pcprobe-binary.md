# Slice 14 — pcprobe: Rust PC profiler binary

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-09

## Scope

All pcprobe binary source files.

| Path                                       | LOC | Read |
|--------------------------------------------|----:|:----:|
| `pcprobe/Cargo.toml`                       |  34 | full |
| `pcprobe/src/main.rs`                      | 157 | full |
| `pcprobe/src/cli.rs`                       | 172 | full |
| `pcprobe/src/collector.rs`                 | 272 | full |
| `pcprobe/src/discovery.rs`                 | 160 | full |
| `pcprobe/src/ipc.rs`                       | 348 | full |

## Critical finding: pcprobe was **completely uncompilable**

The pcprobe binary had **10 distinct compilation errors** preventing `cargo check` from succeeding. No single file compiled without at least one error. This means the pcprobe has **never been successfully compiled** against its declared dependency versions.

### Root causes (3 categories)

1. **Dependency declaration errors (3 BLOCKERs + 2 HIGHs):**
   - SDK crate name wrong (`sdk` vs `performancebench-sdk`)
   - Non-existent feature flag (`pc_metrics`)
   - Missing `hostname` dependency
   - Missing tokio features (`rt-multi-thread`, `time`)
   - Missing `flume` dependency (needed by mdns-sd 0.10)

2. **API version mismatches (4 HIGHs):**
   - sysinfo 0.31 removed `ProcessExt`/`SystemExt` traits
   - mdns-sd 0.10 uses `flume::RecvTimeoutError` instead of `std::sync::mpsc`
   - mdns-sd 0.10 changed `get_property()` return type to `TxtProperty`
   - `hostname::get()` Result/Option monad mix

3. **Ownership/type errors (2 MEDs):**
   - `hostname` String moved into vec then borrowed
   - `is_elevated()` dead code with missing `libc` dependency

## Findings

| ID    | Sev     | Title                                                                          | Status              |
|-------|---------|--------------------------------------------------------------------------------|---------------------|
| B-132 | BLOCKER | SDK crate name wrong in Cargo.toml                                             | FIXED in this slice |
| B-133 | BLOCKER | Non-existent `pc_metrics` feature referenced                                   | FIXED in this slice |
| B-134 | HIGH    | sysinfo 0.31 removed ProcessExt/SystemExt traits                               | FIXED in this slice |
| B-135 | HIGH    | `hostname` crate missing from dependencies                                     | FIXED in this slice |
| B-136 | HIGH    | `hostname::get().and_then(...)` mixes Result and Option monads                 | FIXED in this slice |
| B-137 | HIGH    | `discovery.rs` uses std::sync::mpsc but mdns-sd 0.10 uses flume               | FIXED in this slice |
| B-138 | HIGH    | `get_property()` API changed in mdns-sd 0.10                                   | FIXED in this slice |
| B-139 | HIGH    | tokio missing `rt-multi-thread` and `time` features                            | FIXED in this slice |
| B-140 | MED     | `is_elevated()` dead code with missing libc                                    | FIXED in this slice |
| B-141 | MED     | `hostname` use-after-move into properties vec                                  | FIXED in this slice |

## Verification

```
$ cargo check  (pcprobe)
Finished `dev` profile in 4.92s — 0 errors, 4 pre-existing warnings

$ cargo test -- --test-threads=1  (SDK regression)
212 passed; 0 failed; 0 ignored
```
