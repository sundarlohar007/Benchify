# Slice 15 — pcprobe: PC metrics modules

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-09

## Scope

All PC metrics modules in `sdk/src/pc_metrics/`.

| Path                                   | LOC | Read |
|----------------------------------------|----:|:----:|
| `pc_metrics/mod.rs`                    |  26 | full |
| `pc_metrics/collector.rs`              | 401 | full |
| `pc_metrics/cpu.rs`                    | 300 | full |
| `pc_metrics/pdh.rs`                    | 836 | full |
| `pc_metrics/memory.rs`                 | 192 | full |
| `pc_metrics/disk_io.rs`               |  54 | full |
| `pc_metrics/gpu.rs`                    |  62 | full |
| `pc_metrics/network.rs`               |  54 | full |
| `pc_metrics/dxgi.rs`                  | 813 | full |
| `pc_metrics/etw.rs`                   | 377 | full |

## Key themes

### 1. Rate calculation bugs (collector.rs)
Disk I/O and network rate calculations had two bugs:
- **First-tick spike**: `last_value = 0` on first tick → entire cumulative value emitted as "rate"
- **Zero-delta suppression**: idle periods (zero I/O) silently dropped as `None`

### 2. Security: PDH counter path injection (pdh.rs)
Process name validation allowed PDH metacharacters `( ) * # %` which can break or redirect counter paths. Fixed by expanding the blocked character set.

### 3. Data quality gaps (deferred)
- Thread CPU % always 0.0 (cycle time deltas never computed)
- Page faults field is cumulative count, not per-second rate
- CPU frequency via `wmic` — deprecated on modern Windows 11

### 4. Unsafe memory patterns (deferred)
- ETW `EventTraceProperties.wnode.buffer_size` doesn't account for appended session name strings → potential heap corruption
- DXGI injection returns DLL path address as ring buffer handle → garbage frame data if that code path were ever reached

## Findings

| ID    | Sev  | Title                                                              | Status              |
|-------|------|--------------------------------------------------------------------|---------------------|
| B-142 | MED  | Disk I/O rate emits cumulative value on first tick                 | FIXED in this slice |
| B-143 | MED  | Network rate has same first-tick bug                               | FIXED in this slice |
| B-144 | HIGH | PDH process name allows parentheses (injection)                   | FIXED in this slice |
| B-145 | MED  | `page_faults_per_s` is cumulative count, not rate                  | DEFERRED-TO-S20     |
| B-146 | MED  | Thread CPU % always 0.0 (no delta computation)                     | DEFERRED-TO-S20     |
| B-147 | LOW  | `wmic` CPU frequency deprecated on Win11                           | DEFERRED-TO-S20     |
| B-148 | HIGH | ETW buffer_size too small (heap corruption risk)                   | DEFERRED-TO-S20     |
| B-149 | HIGH | DXGI inject_dx_hook returns path address, not ring buffer          | DEFERRED-TO-S20     |

## Verification

```
$ cargo test -- --test-threads=1  (SDK)
212 passed; 0 failed; 0 ignored

$ cargo check  (pcprobe)
Finished — 0 errors, pre-existing warnings only
```
