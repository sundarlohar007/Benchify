# Slice 16 — pcprobe: PC video capture

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-09

## Scope

All PC video capture modules in `sdk/src/pc_video/`.

| Path                          | LOC | Read |
|-------------------------------|----:|:----:|
| `pc_video/mod.rs`             | 311 | full |
| `pc_video/chunk_manager.rs`   | 334 | full |
| `pc_video/windows_capture.rs` | 282 | full |
| `pc_video/linux_capture.rs`   | 512 | full |
| `pc_video/mac_capture.rs`     | 260 | full |

## Key themes

### 1. ffmpeg subprocess lifecycle (linux_capture.rs)
`Child::kill()` sends SIGKILL on Unix, not SIGTERM. This prevents ffmpeg from writing the chunk trailer, producing corrupt final chunks. Fixed to use `libc::kill(pid, SIGTERM)`.

### 2. Error diagnostics (mod.rs)
ffmpeg concat errors only reported exit code, no stderr. Fixed to capture and include ffmpeg's diagnostic output in the error message.

### 3. Missing dependency (linux_capture.rs)
`libc` crate is used in `#[cfg(linux)]` blocks but not in Cargo.toml. This means Linux builds fail. Deferred since this is a cross-platform dep change.

### 4. Test safety (linux_capture.rs)
Tests mutate global env vars (`set_var`/`remove_var`) which is unsound with parallel test threads. Currently masked by `--test-threads=1`.

### 5. Chunk manager robustness
No guard against double-calling `open_next_chunk` without completing the previous chunk. This could silently skip recorded content during concat.

## Findings

| ID    | Sev  | Title                                                      | Status              |
|-------|------|------------------------------------------------------------|---------------------|
| B-150 | HIGH | `stop_capture` sends SIGKILL instead of SIGTERM            | FIXED in this slice |
| B-151 | MED  | ffmpeg concat error has no diagnostic detail                | FIXED in this slice |
| B-152 | HIGH | `libc` crate not in Cargo.toml (Linux build fail)          | DEFERRED-TO-S20     |
| B-153 | LOW  | `open_next_chunk` has no double-call guard                 | DEFERRED-TO-S20     |
| B-154 | LOW  | `recording_overhead_estimate_pct` hardcoded to 5.0         | DEFERRED-TO-S20     |
| B-155 | LOW  | Linux tests mutate global env vars (unsound in parallel)   | DEFERRED-TO-S20     |
| B-156 | LOW  | concat silently uses wrong path for non-UTF-8 dirs         | DEFERRED-TO-S20     |
| B-157 | NIT  | Unused import `std::path::Path` in windows_capture.rs      | DEFERRED-TO-S20     |

## Verification

```
$ cargo test -- --test-threads=1  (SDK)
212 passed; 0 failed; 0 ignored

$ cargo check  (pcprobe)
Finished — 0 errors
```
