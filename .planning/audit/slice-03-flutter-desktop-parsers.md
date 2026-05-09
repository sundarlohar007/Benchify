# Slice 03 — Flutter desktop: parsers

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-08

## Scope

`performancebench/lib/core/parsers/` (8 files) + `lib/core/sdk/sdk_state.dart`. Originally carved as "parsers + utils" but `lib/core/utils/` doesn't exist; folded `sdk_state.dart` into this slice instead.

| File                       | LOC | Read |
|----------------------------|----:|:----:|
| cpu_parser.dart            | 293 | full |
| battery_parser.dart        | 196 | full |
| fps_parser.dart            | 194 | full |
| memory_parser.dart         | 170 | full |
| network_parser.dart        | 146 | full |
| disk_io_parser.dart        | 105 | full |
| gpu_parser.dart            |  91 | full |
| thermal_parser.dart        |  68 | full |
| sdk/sdk_state.dart         |  35 | full |

Parsers are mostly tight. They share a deliberate contract: pure synchronous string→struct, all fields nullable, never throw, never block. That contract holds well across the slice.

## User-flow trace

> *MetricCollector ticks at 1 Hz → calls each parser with raw stdout from ADB → composes `MetricSample` → DAO insert.*

1. `cpu_parser.parse(/proc/<pid>/stat, /proc/stat)` — delta-based CPU%.
2. `cpu_parser.parseCoreFreqs(sysfs glob)` — per-core freqs.
3. `battery_parser.parseDumpsysBattery / parseCurrentNow / parseVoltageNow / parseWifiState`.
4. `fps_parser.parse(SurfaceFlinger latency)` — fps + 4 jank counts + frametimes JSON.
5. `memory_parser.parse(dumpsys meminfo)` — PSS + 6 sub-categories.
6. `network_parser.parse(/proc/net/dev)` — cumulative bytes per class.
7. `disk_io_parser.parse(/proc/diskstats)` — KB/s deltas.
8. `gpu_parser.parseAny(sysfs)` — Adreno or Mali %.
9. `thermal_parser.parseThermalService / parseGetprop` — 0-3 status.

## Findings

| ID    | Sev  | Title                                                                                           | Status              |
|-------|------|-------------------------------------------------------------------------------------------------|---------------------|
| B-034 | MED  | `cpu_parser._extractPidTicks` uses `indexOf(')')` — wrong utime/stime if comm contains ')'      | FIXED in this slice |
| B-035 | LOW  | `_extractSystemTicks` omits `steal` field from total ticks                                      | DEFERRED-TO-S20     |
| B-036 | LOW  | `parseDumpsysBattery` returns `chargingSource='none'` while `charging=true` (status 2/5, no source) | FIXED in this slice |
| B-037 | NIT  | `parseDumpsysBattery` `? true : false` redundant ternary on already-boolean expression          | FIXED in this slice |
| B-038 | NIT  | `fps_parser` `fps < 0 ? 0 : fps` dead check (fps always ≥ 0 from positive mean delta)           | FIXED in this slice |
| B-039 | LOW  | `memory_parser` regex assumes Android 7+ dumpsys format                                         | DEFERRED-TO-S20     |
| B-040 | LOW  | `disk_io_parser` device list missing `nvme*` (modern UFS-NVMe phones)                           | DEFERRED-TO-S20     |
| B-041 | LOW  | `SdkState` is mutable shared state without synchronization                                      | DEFERRED-TO-S20     |

## Cross-slice notes

- **B-034** is a sibling of the Rust SDK's parser (which already uses `rfind(')')` via `metrics/cpu.rs::parse_proc_self_stat`). The Dart side drifted; aligning closes the gap.
- **B-035 / B-039 / B-040**: format-coverage hardening. Bundle into S-20 with the rest of the format/dialect work surfaced in S-02 (B-028 chipset vendor regex, etc.).
- **B-041**: real impact only manifests when multiple async writers touch `SdkState` simultaneously. Surfaces in S-04 (settings UI mutations) or S-20 (live mode).

## Local fixes summary

1. **B-034**: `indexOf(')')` → `lastIndexOf(')')`. Multi-paren comm names like `(my_app(test))` now parse correctly.
2. **B-036**: status 2/5 with no source now returns `chargingSource='unknown'`, not `'none'`, so consumers see "charging from unknown source" rather than "not charging".
3. **B-037**: dropped redundant `?true:false`.
4. **B-038**: dropped dead `fps<0?0:fps`.

## Verification

`flutter analyze lib/core/parsers/cpu_parser.dart lib/core/parsers/battery_parser.dart lib/core/parsers/fps_parser.dart` — clean.
