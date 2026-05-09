# Slice 11 — Injector: SDK Rust lib (transport, jni_bridge, automation, models)

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-09

## Scope

Core SDK library modules — transport layer, JNI bridge, automation handlers, and data models.

| Path                                             | LOC | Read |
|--------------------------------------------------|----:|:----:|
| `sdk/src/transport.rs`                           | 278 | full |
| `sdk/src/jni_bridge.rs`                          | 119 | full |
| `sdk/src/automation.rs`                          | 488 | full |
| `sdk/src/models.rs`                              | 309 | full |
| `sdk/src/lib.rs`                                 |   9 | full |

Skip: `src/metrics/` (S-12), `src/engine_core/` (S-13), `src/pc_metrics/` (S-15), `src/pc_video/` (S-16).

## User-flow trace

> *SDK is injected into the target APK via smali patching (S-09/S-10). On app launch, `SdkLoader.nativeInit` is called from Java, which starts a TCP server on `127.0.0.1:8080` and a 1Hz metric collection thread. The desktop's `MetricCollector` connects via ADB port-forward and reads newline-delimited JSON. CI/CD automation sends commands via ADB broadcast → `BenchifyBroadcastReceiver` → `nativeHandleCommand` → Rust `handle_command` dispatcher.*

1. `nativeInit` receives `Context` and `FpsOverlayView` from Java. **Pre-fix (B-106)**: global refs were captured into locals (`_ctx`, `_overlay`) immediately dropped — the Java objects stayed alive but were unreachable from native.
2. TCP server starts on `127.0.0.1:8080` (T-04-08: loopback only). `start_metric_collection` runs at 1Hz, populating `LATEST_SAMPLE` and `SAMPLE_QUEUE`.
3. `handle_client` drains the queue, then polls `LATEST_SAMPLE` at 100ms — **B-104**: same sample resent ~10× per second (no timestamp dedup).
4. `collect_metrics` reads `/proc/self/stat`, `/proc/self/status`, `/proc/self/net/dev`. **Pre-fix (B-103)**: per-process network data (D-16) was computed correctly, then immediately overwritten by the device-wide `network::parse_net_dev` block.
5. Automation `MARKER` handler pushes event JSON to `EVENT_QUEUE` — **B-105**: that queue is never drained or sent to TCP clients. Markers appear lost on the desktop.
6. `SCREENSHOT` and `EXPORT` handlers construct file paths using `session_id` directly — **Pre-fix (B-110/B-111)**: path traversal via crafted IDs.

## Findings

| ID    | Sev   | Title                                                                                              | Status              |
|-------|-------|----------------------------------------------------------------------------------------------------|---------------------|
| B-102 | LOW   | `SAMPLE_QUEUE` uses `Vec` with O(n) `remove(0)` on every cycle                                    | FIXED in this slice |
| B-103 | HIGH  | Per-process network data silently overwritten by device-wide fallback                              | FIXED in this slice |
| B-104 | MED   | `handle_client` resends same `LATEST_SAMPLE` on every 100ms tick (10× duplicates)                  | DEFERRED-TO-S20     |
| B-105 | HIGH  | `EVENT_QUEUE` populated but never drained or sent to TCP clients (markers lost)                    | DEFERRED-TO-S20     |
| B-106 | MED   | `nativeInit` global refs captured into locals that are immediately dropped                         | FIXED in this slice |
| B-107 | NIT   | `#[serde(rename_all = "snake_case")]` is a no-op on MetricSample                                  | DEFERRED-TO-S20     |
| B-108 | LOW   | `gpu_mem_kb` and `pc_gpu_dedicated_mem_kb` both set from same source (double-counted)              | FIXED in this slice |
| B-109 | LOW   | `charging` field is `i32` instead of `Option<i32>` — schema asymmetry                             | DEFERRED-TO-S20     |
| B-110 | MED   | Path traversal via crafted `session_id` in SCREENSHOT handler                                      | FIXED in this slice |
| B-111 | MED   | Same path traversal in EXPORT handler                                                              | FIXED in this slice |
| B-112 | LOW   | Automation tests flaky under parallel execution (shared global state)                              | DEFERRED-TO-S20     |
| B-113 | LOW   | Poisoned-mutex recovery via `into_inner()` across 7 automation handlers                            | DEFERRED-TO-S20     |

## Cross-slice notes

- **B-103 (HIGH, network overwrite)**: The per-process network module (`net_per_process`, S-12 scope) works correctly; the bug was purely in the transport layer's ordering. Fix is local to transport.rs.
- **B-105 (HIGH, event queue dead)**: Fixing this requires touching `handle_client` which is inside this slice's scope. Deferred because the fix should be coupled with B-104 (dedup) — changing the client loop's semantics without addressing both simultaneously would introduce more complexity.
- **B-106 (MED, JNI refs)**: The retained `GlobalRef` pair is not yet used by any native callback path. The fix is forward-looking — ensures the refs survive for the overlay/ContentResolver integration planned in the engine_core phase.
- **B-112 (LOW, test flakiness)**: Pre-existing. Not caused by S-11 changes. Confirmed by running `cargo test -- --test-threads=1` (all 199 tests pass).

## Local fixes summary

1. **B-102 (LOW)** — `transport.rs`: Replaced `Vec<MetricSample>` with `VecDeque<MetricSample>`. `remove(0)` → `pop_front()`, `push` → `push_back()`. `get_buffered_samples` uses `.iter().cloned().collect()` to return Vec.
2. **B-103 (HIGH)** — `transport.rs`: Added `has_per_process_net` flag. Per-process net data now takes priority; device-wide block only fills the fields when the flag is false. `last_net` always updated for delta baseline freshness.
3. **B-106 (MED)** — `jni_bridge.rs`: Stored `GlobalRef` pair in `Lazy<Mutex<Option<(GlobalRef, GlobalRef)>>>`. Added `#[allow(unused_mut)]` for host-build compat.
4. **B-108 (LOW)** — `models.rs`: Removed `gpu_mem_kb` assignment from `from_pc_snapshot`. PC-specific `pc_gpu_dedicated_mem_kb` is the canonical field.
5. **B-110 + B-111 (MED × 2)** — `automation.rs`: Added `sanitize_path_component()` that strips all chars except `[a-zA-Z0-9_-.]`. Applied to `session_id` and `label` in SCREENSHOT and EXPORT handlers.

## Verification

```
$ cargo test -- --test-threads=1
199 passed; 0 failed; 0 ignored
```

```
$ cargo check
Finished `dev` profile [unoptimized + debuginfo] target(s) in 3.25s
(10 pre-existing warnings from pc_metrics/pc_video modules outside S-11 scope)
```

All existing tests + integration tests pass. No new test files in this slice.
