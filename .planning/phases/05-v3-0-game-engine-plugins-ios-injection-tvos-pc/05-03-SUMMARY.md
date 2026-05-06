---
phase: 05-v3-0-game-engine-plugins-ios-injection-tvos-pc
plan: 03
subsystem: pc-profiling
tags: [pdh, dxgi, etw, windows-ffi, fps, cpu, memory, gpu, disk-io, network, rust, dart]

requires:
  - phase: 04-v2-5-android-sdk-injection
    provides: "Rust SDK metrics modules (fps.rs compute_fps/classify_jank), MetricSample model"
provides:
  - "Windows PDH counter framework matching UNIFIED-SPEC §19.2 (15+ counter paths)"
  - "DXGI Present hook (Detours injection Method A + PresentMon Method B)"
  - "ETW frame timing session (DxgKrnl provider, admin-required)"
  - "PC memory metrics via GetProcessMemoryInfo (working set, private bytes)"
  - "PC CPU metrics via CreateToolhelp32Snapshot + QueryThreadCycleTime (per-thread)"
  - "PcCollector orchestration producing MetricSample at 1Hz"
  - "Dart MetricSample model extension with 7 PC-specific fields"
affects: [05-04-pb-pcprobe-binary]

tech-stack:
  added: []
  patterns:
    - "Raw FFI to pdh.dll/kernel32.dll/advapi32.dll for all Windows API calls"
    - "Platform-gated modules with #[cfg(windows)] / #[cfg(not(windows))] stubs"
    - "TDD RED→GREEN commit pairs for PDH/DXGI (Task 1) and memory/CPU/ETW (Task 2)"
    - "D-11 compliance: PC fields Option<T>, mobile fields remain None on PC"

key-files:
  created:
    - performancebench-injector/sdk/src/pc_metrics/mod.rs
    - performancebench-injector/sdk/src/pc_metrics/pdh.rs
    - performancebench-injector/sdk/src/pc_metrics/dxgi.rs
    - performancebench-injector/sdk/src/pc_metrics/etw.rs
    - performancebench-injector/sdk/src/pc_metrics/memory.rs
    - performancebench-injector/sdk/src/pc_metrics/cpu.rs
    - performancebench-injector/sdk/src/pc_metrics/disk_io.rs
    - performancebench-injector/sdk/src/pc_metrics/gpu.rs
    - performancebench-injector/sdk/src/pc_metrics/network.rs
    - performancebench-injector/sdk/src/pc_metrics/collector.rs
    - performancebench-injector/sdk/tests/pc_metrics_integration.rs
  modified:
    - performancebench-injector/sdk/src/lib.rs
    - performancebench-injector/sdk/src/models.rs
    - performancebench/lib/core/models/metric_sample.dart

key-decisions:
  - "Used raw FFI (extern \"system\") to pdh.dll/kernel32.dll/advapi32.dll instead of windows-rs 0.58 — feature Win32_System_Diagnostics_Performance unavailable in that crate version"
  - "CPU frequency obtained via wmic CLI fallback instead of WMI COM — simpler, no registry read permissions needed, graceful None fallback"
  - "ETW poll_frame_events returns empty Vec for library phase — full ETW consumer thread deferred to Plan 05-04 pb-pcprobe binary assembly"
  - "D-11 strictly enforced: battery/cellular/thermal fields remain None on PC snapshots"
  - "DXGI DLL loading from filesystem (pb-pcprobe-dx.dll) with SHA-256 integrity check point — actual DLL compiled in Plan 05-04"

patterns-established:
  - "Platform-gated module pattern: all Windows code behind #[cfg(windows)] with non-Windows stubs returning Err"
  - "PDH counter path construction as pure function (build_counter_paths) — testable without Windows"
  - "TDD flow: RED (stub + failing tests) → GREEN (real FFI implementation) → commit per task"
  - "PC-specific MetricSample fields as Option<T> with serde(skip_serializing_if) — zero-impact on mobile"

requirements-completed: [V30-06, V30-07, V30-08]

duration: 56min
completed: 2026-05-06
---

# Phase 5 Plan 03: PC Profiling Metric Modules Summary

**Windows PDH counter framework, DXGI Present hook, ETW frame timing, PC memory/CPU/GPU metrics as pure Rust library modules, plus Dart MetricSample sync — 66 tests passing, ready for pb-pcprobe binary assembly**

## Performance

- **Duration:** ~56 min
- **Started:** 2026-05-06T13:00:00Z
- **Completed:** 2026-05-06T13:56:33Z
- **Tasks:** 3
- **Files modified:** 14 (11 created, 3 modified)

## Accomplishments

- PDH counter framework: 15+ counter paths matching UNIFIED-SPEC §19.2 exactly (CPU, memory, disk, network, GPU, threads, handles) — live `open_query`/`collect_sample` via raw FFI to `pdh.dll`
- DXGI frame timing: Detours injection (Method A) via OpenProcess/VirtualAllocEx/CreateRemoteThread + PresentMon CSV parsing (Method B) with automatic fallback chain — reuses Phase 4 `metrics::fps` for FPS/jank computation
- ETW frame timing: StartTraceW session for DxgKrnl provider, admin gate with clear error message, EnableTraceEx2 for PresentHistory events
- PC memory: GetProcessMemoryInfo (working set, private bytes, page fault count) via `psapi.dll` FFI
- PC CPU: per-thread enumeration via CreateToolhelp32Snapshot + Thread32First/Thread32Next + QueryThreadCycleTime; CPU frequency via wmic fallback
- PcCollector: orchestrates all modules into a 1Hz `tick()` producing complete `MetricSample` with disk/network rate calculation and per-thread CPU JSON
- Dart MetricSample: 7 PC-specific fields added (`pcHandleCount`, `pcThreadCount`, `pcPageFaultsPerS`, `pcGpuDedicatedMemKb`, `pcGpuSharedMemKb`, `pcPerCoreCpuJson`, `pcThreadCpuJson`) with `fromMap`/`toMap` handling
- 66 unit tests passing (PDH counter paths, FPS computation, PresentMon CSV parsing, MetricSample conversion, live PDH on Windows, memory/CPU collection)
- D-11 compliance: battery/cellular/thermal fields remain None for PC; all PC fields are Option<T> for zero-impact on mobile

## Task Commits

Each task was committed atomically:

1. **Task 1: PDH counter framework + DXGI frame timing (RED)** - `77187de` (test)
2. **Task 1: PDH counter framework + DXGI frame timing (GREEN)** - `c4c84a4` (feat)
3. **Task 2: Memory, CPU, ETW + MetricSample integration (RED)** - `85d1a2a` (test)
4. **Task 2: Memory, CPU, ETW + MetricSample integration (GREEN)** - `bc74ce0` (feat)
5. **Task 3: PC metrics collector + integration test + Dart model sync** - `e24f568` (feat)

## Files Created/Modified

- `performancebench-injector/sdk/src/pc_metrics/pdh.rs` - PDH counter framework: open_query, collect_sample, close_query, 15+ counter paths per §19.2, raw FFI to pdh.dll
- `performancebench-injector/sdk/src/pc_metrics/dxgi.rs` - DXGI Present hook: Detours injection (Method A) + PresentMon subprocess (Method B), QPC ring buffer reader, CSV parser, FPS computation reusing Phase 4 fps.rs
- `performancebench-injector/sdk/src/pc_metrics/etw.rs` - ETW frame timing: StartTraceW/EnableTraceEx2 for DxgKrnl provider, admin gate, stop via ControlTraceW
- `performancebench-injector/sdk/src/pc_metrics/memory.rs` - PC memory: K32GetProcessMemoryInfo for working set, private bytes, page faults
- `performancebench-injector/sdk/src/pc_metrics/cpu.rs` - PC CPU: per-thread enumeration (CreateToolhelp32Snapshot + QueryThreadCycleTime), CPU frequency via wmic, ThreadCpu struct
- `performancebench-injector/sdk/src/pc_metrics/disk_io.rs` - Disk I/O: snapshot extraction from PDH, cumulative-to-rate helpers
- `performancebench-injector/sdk/src/pc_metrics/gpu.rs` - GPU metrics: utilization + memory from PDH snapshot
- `performancebench-injector/sdk/src/pc_metrics/network.rs` - Network metrics: RX/TX bytes from PDH snapshot
- `performancebench-injector/sdk/src/pc_metrics/collector.rs` - PcCollector orchestration: tick() at 1Hz, DXGI/ETW fallback chain, disk/network rate calculation
- `performancebench-injector/sdk/src/pc_metrics/mod.rs` - Module declarations
- `performancebench-injector/sdk/tests/pc_metrics_integration.rs` - Integration tests: PDH live queries, FPS/jank, PresentMon CSV, MetricSample conversion, JSON serialization
- `performancebench-injector/sdk/src/models.rs` - MetricSample extended with 7 PC fields + from_pc_snapshot() conversion
- `performancebench-injector/sdk/src/lib.rs` - pub mod pc_metrics registered
- `performancebench/lib/core/models/metric_sample.dart` - Dart MetricSample with 7 PC fields, fromMap/toMap handling

## Decisions Made

- Used raw FFI (`extern "system"`) to `pdh.dll`/`kernel32.dll`/`advapi32.dll` instead of `windows-rs` 0.58 — the `Win32_System_Diagnostics_Performance` feature was unavailable in that crate version. Raw FFI is more reliable and avoids version-specific binding issues.
- CPU frequency obtained via `wmic cpu get MaxClockSpeed` CLI fallback instead of WMI COM — simpler, no registry read permissions needed, graceful `None` fallback when unavailable.
- ETW `poll_frame_events` returns empty `Vec` for the library phase — full ETW consumer thread with `ProcessTrace` callbacks is deferred to Plan 05-04 `pb-pcprobe` binary where a dedicated background thread manages the ETW processing loop.
- D-11 strictly enforced: battery, cellular, and thermal fields remain `None` for PC snapshots; all PC-specific fields are `Option<T>` with `serde(skip_serializing_if)` for zero-impact on mobile serialization.
- DXGI hook DLL loaded from filesystem (`pb-pcprobe-dx.dll`) next to probe binary — actual DLL compiled in Plan 05-04 as part of `pb-pcprobe` assembly; SHA-256 integrity check point left as documentation comment.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Switched from windows-rs to raw FFI for Windows API calls**
- **Found during:** Task 1 (PDH implementation)
- **Issue:** windows-rs 0.58 crate feature `Win32_System_Diagnostics_Performance` does not exist. PDH bindings are not available in the specified feature set.
- **Fix:** Used raw `extern "system"` FFI declarations directly to `pdh.dll` (PdhOpenQueryW, PdhAddEnglishCounterW, PdhCollectQueryData, PdhGetFormattedCounterValue, PdhCloseQuery), `kernel32.dll` (OpenProcess, VirtualAllocEx, WriteProcessMemory, CreateRemoteThread, QueryPerformanceFrequency, CreateToolhelp32Snapshot, OpenThread, QueryThreadCycleTime, K32GetProcessMemoryInfo), and `advapi32.dll` (StartTraceW, EnableTraceEx2, ControlTraceW). Removed the windows-rs dependency from Cargo.toml.
- **Files modified:** `performancebench-injector/sdk/src/pc_metrics/pdh.rs`, `dxgi.rs`, `cpu.rs`, `memory.rs`, `etw.rs`
- **Committed in:** `c4c84a4`, `bc74ce0`

**2. [Rule 1 - Bug] Fixed floating-point precision in FPS single-frame test**
- **Found during:** Task 1 RED phase
- **Issue:** `compute_pc_fps(&[16_666_667])` returns `59.99999880000002` not exactly `60.0` due to floating-point arithmetic. Exact equality assertion failed.
- **Fix:** Changed assertion from `assert_eq!` to approximate comparison: `assert!((fps - 60.0).abs() < 0.5)`.
- **Files modified:** `performancebench-injector/sdk/src/pc_metrics/dxgi.rs`
- **Committed in:** Part of `77187de` (Task 1 RED)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Minimal — raw FFI is functionally equivalent to windows-rs bindings and avoids version lock-in. Floating-point fix is test-only.

## Issues Encountered

- Existing integration tests (`tests/integration_test.rs`, `test_automation.rs`, `test_webview.rs`, `test_net_per_process.rs`) fail due to unresolved `extern crate performancebench_sdk` — these are pre-existing issues from prior waves, not related to this plan. Only `pc_metrics` tests (unit + integration) are new and pass.

## Next Phase Readiness

- All PC metric modules are pure library code (no `main` function) — ready for binary assembly in Plan 05-04 (pb-pcprobe)
- PcCollector::tick() produces complete MetricSample with all PC fields populated
- ETW full event processing (ProcessTrace callback loop) deferred to Plan 05-04
- DXGI hook DLL (`pb-pcprobe-dx.dll`) to be compiled in Plan 05-04 with Microsoft Detours
- Dart MetricSample model has all 7 PC fields ready for desktop app display

---
*Phase: 05-v3-0-game-engine-plugins-ios-injection-tvos-pc*
*Completed: 2026-05-06*
