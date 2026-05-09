# Slice 13 — Injector: engine_core + game-engine plugins

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-09

## Scope

All engine core modules in `sdk/src/engine_core/`.

| Path                                             | LOC | Read |
|--------------------------------------------------|----:|:----:|
| `sdk/src/engine_core/mod.rs`                     |  15 | full |
| `sdk/src/engine_core/marker.rs`                  | 227 | full |
| `sdk/src/engine_core/auto_marker.rs`             |  98 | full |
| `sdk/src/engine_core/metrics.rs`                 | 219 | full |

**Note:** No separate game-engine plugin wrappers (C#/C++/GDScript) exist yet — per UNIFIED-SPEC §4.2, engine plugins are v3.0 scope. This slice audits the shared Rust core that those wrappers will call.

## User-flow trace

> *Game engine wrappers (Unity C# / Unreal C++ / Godot GDScript) call into engine_core via FFI. The marker subsystem creates scoped markers for scene loads, lifecycle events, and user annotations. The metrics subsystem receives engine-specific stats (draw calls, GPU frame time, GC alloc). All data is serialized to JSON and pushed to the TCP transport queue for the desktop app.*

## Findings

| ID    | Sev   | Title                                                                               | Status              |
|-------|-------|-------------------------------------------------------------------------------------|---------------------|
| B-124 | HIGH  | `marker_event_json` vulnerable to JSON injection via unescaped strings              | FIXED in this slice |
| B-125 | MED   | `on_scene_load` emitted JSON before `end_marker` — always `duration_ms:null`        | FIXED in this slice |
| B-126 | MED   | `UnrealFrameStats::to_json` inlines `stat_unit_json` without validation             | FIXED in this slice |
| B-127 | MED   | All auto-marker functions push to never-drained EVENT_QUEUE (→ B-105)               | DEFERRED-TO-S20     |
| B-128 | LOW   | `ScopedMarker` schema doesn't match spec `markers` DDL field names                  | DEFERRED-TO-S20     |
| B-129 | NIT   | `begin_marker` / `begin_scene_marker` code duplication                              | DEFERRED-TO-S20     |
| B-130 | NIT   | `MARKER_HISTORY.drain` uses O(n) Vec (same as B-102)                                | DEFERRED-TO-S20     |
| B-131 | LOW   | Engine `to_json()` uses `format!` — NaN/Infinity produces invalid JSON              | DEFERRED-TO-S20     |

## Local fixes summary

1. **B-124 (HIGH)** — `marker.rs`: Added `escape_json_string()` helper for JSON-safe string escaping. Applied to `marker.name` and `scene_name` in `marker_event_json()`. Added serde round-trip test.
2. **B-125 (MED)** — `auto_marker.rs`: Reordered `on_scene_load` to call `end_marker` BEFORE `marker_event_json`, so the duration is included in the emitted JSON.
3. **B-126 (MED)** — `metrics.rs`: Added serde_json validation for `stat_unit_json` before inlining into the JSON template. Invalid/empty JSON falls back to `null`. Added 2 tests.

## Verification

```
$ cargo test -- --test-threads=1
212 passed; 0 failed; 0 ignored
```

New tests added: 3 (marker_json_escaping, unreal_invalid_stat_unit_json_fallback, unreal_empty_stat_unit_json_fallback). Existing serde validation test `test_all_stats_serialize_valid_json` strengthened to actually parse output with serde_json.
