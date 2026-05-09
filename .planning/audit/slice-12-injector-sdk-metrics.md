# Slice 12 — Injector: SDK metrics (fps, cpu, memory, gpu, network, net_per_process, webview_js)

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-09

## Scope

All metric collection modules in `sdk/src/metrics/`.

| Path                                             | LOC | Read |
|--------------------------------------------------|----:|:----:|
| `sdk/src/metrics/mod.rs`                         |   8 | full |
| `sdk/src/metrics/cpu.rs`                         | 116 | full |
| `sdk/src/metrics/fps.rs`                         | 161 | full |
| `sdk/src/metrics/gpu.rs`                         |  78 | full |
| `sdk/src/metrics/memory.rs`                      |  88 | full |
| `sdk/src/metrics/network.rs`                     | 192 | full |
| `sdk/src/metrics/net_per_process.rs`             | 364 | full |
| `sdk/src/metrics/webview_js.rs`                  | 115 | full |

## User-flow trace

> *The metric collection thread (started by `nativeInit` in S-11) calls `collect_metrics()` every 1s. Each call reads /proc files and sysfs paths, delegates to the metric modules, and produces a `MetricSample`. The formulas must match UNIFIED-SPEC §5 exactly or the dashboard displays wrong data.*

### Critical formula audit results

1. **cpu_app_pct (B-114, HIGH)**: Was `(Δpid_ticks / HZ) × 100` — CPU-seconds per interval, NOT the spec-required `(Δpid_ticks / Δtotal_ticks) × 100`. Coincidentally ~correct at 1Hz on idle single-core, but wildly wrong under load or with lag.
2. **cpu_system_pct (B-115, HIGH)**: Was `(Δtotal / HZ) / 1.0` (division by 1.0 no-op!). Spec requires `((Δtotal - Δidle) / Δtotal) × 100`. Never subtracted idle ticks.
3. **parse_proc_stat_total (B-116, LOW)**: Only summed 7 of 10 fields — missing steal/guest/guest_nice. Affects emulators.
4. **Jank model (B-117+B-118, MED×2)**: SDK uses simplified 2×/4× fixed multipliers against hardcoded 60Hz. Spec uses rolling 3-frame window + absolute thresholds (83.3ms/125ms) + device refresh rate. Behavioral change — deferred to coordinate with Dart side.

### Thread safety audit

5. **net_per_process.rs (B-119, HIGH)**: `static mut` for `TRACKED_PID` and `PREV_SNAPSHOT` — UB under concurrent access. `#[allow(static_mut_refs)]` suppressed the warning but didn't fix the race. Fixed with `Mutex<NetState>`.

### Spec compliance audit

6. **Network classification (B-120, MED)**: Missing `nan*` (WiFi NAN), `ccmni*`, `pdp*`, `ppp*` (cellular) per §5.5. Affects Chinese OEM devices with MediaTek chipsets.

## Findings

| ID    | Sev   | Title                                                                                              | Status              |
|-------|-------|----------------------------------------------------------------------------------------------------|---------------------|
| B-114 | HIGH  | `compute_app_cpu_pct` formula wrong — seconds instead of tick ratio                                | FIXED in this slice |
| B-115 | HIGH  | `compute_system_cpu_pct` formula wrong — ignored idle ticks                                        | FIXED in this slice |
| B-116 | LOW   | `parse_proc_stat_total` only summed 7 of 10 fields                                                | FIXED in this slice |
| B-117 | MED   | Jank classification uses hardcoded 60Hz VSYNC, not device refresh rate                             | DEFERRED-TO-S20     |
| B-118 | MED   | Jank tier algorithm doesn't match spec (simplified vs rolling window)                              | DEFERRED-TO-S20     |
| B-119 | HIGH  | `static mut` in net_per_process.rs — undefined behavior                                           | FIXED in this slice |
| B-120 | MED   | Network interface classification missing spec-required prefixes                                    | FIXED in this slice |
| B-121 | NIT   | `other_pss = VmSize - VmRSS` is semantically misleading                                           | DEFERRED-TO-S20     |
| B-122 | LOW   | `frame_deltas.drain(0..n-60)` may carry over stale frames across cycles                           | DEFERRED-TO-S20     |
| B-123 | NIT   | Duplicate `NetInterface` / `NetDelta` types across two modules                                     | DEFERRED-TO-S20     |

## Local fixes summary

1. **B-114 + B-115 (HIGH×2)** — `cpu.rs` + `transport.rs`: Rewrote `compute_app_cpu_pct` to take `(pid_delta, total_delta)` and compute the spec-correct ratio. Added `parse_idle_ticks()`. Rewrote `compute_system_cpu_pct` to take `(total_delta, idle_delta)`. Transport now tracks `last_cpu_idle` and computes both CPU metrics per §5.2.
2. **B-116 (LOW)** — `cpu.rs`: Changed `parts[1..8]` → `parts[1..]` to sum all /proc/stat fields. Added tests for 10-field and 7-field formats.
3. **B-119 (HIGH)** — `net_per_process.rs`: Replaced `static mut TRACKED_PID` + `static mut PREV_SNAPSHOT` with `Lazy<Mutex<NetState>>`. Removed `unsafe` blocks and `#[allow(static_mut_refs)]`.
4. **B-120 (MED)** — `network.rs` + `net_per_process.rs`: Added `nan*` to WiFi; `ccmni*`, `pdp*`, `ppp*` to Cellular in both modules' `classify_interface()`. Added test cases.

## Verification

```
$ cargo test -- --test-threads=1
205 passed; 0 failed; 0 ignored
```

```
$ cargo check
Finished `dev` profile in 3.65s (8 pre-existing warnings outside S-12 scope)
```

New tests added: 6 (parse_idle_ticks, compute_app_cpu_pct_zero_total, compute_system_cpu_pct, compute_system_cpu_pct_zero_total, parse_proc_stat_total_7_fields, classify_spec_prefixes).
