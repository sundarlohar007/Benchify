# Phase 2: v1.5 Analysis + Platform Expansion - Context

**Gathered:** 2026-05-04
**Status:** Ready for planning

<domain>
## Phase Boundary

Add drag-region analysis on session timeline, disk I/O activation, auto-detected issues (feature-flagged), threshold alerts with auto-markers, auto session start via ADB logcat, session collections with tags, Windows iOS support via Mac proxy daemon, Linux smoke test, Android video recording with synced playback, and schema migration v2. 13 requirements (V15-01 through V15-13). 5 days.
</domain>

<decisions>
## Implementation Decisions

### Drag-Region Selection
- **D-01:** Click-drag on replay chart to select time range — blue selection overlay on MetricChart. Emits start/end timestamps. Same interaction as video editing timeline.
- **D-02:** Region stats format matches per-marker stats format — same columns, same computation. Reuses MarkerStats model structure.

### Threshold Alerts
- **D-03:** Status bar badge shows alert count during session (reuses Phase 1 error badge pattern). Auto-marker created at each breach timestamp.
- **D-04:** Three threshold types: FPS < 30 for 10s, CPU > 85% for 5s, Memory growth > 100MB over 30s. Battery drain left for post-session analytics only.
- **D-05:** Threshold config in Settings → Profiling section. All thresholds default-off. User enables per threshold type. Config persisted via SharedPreferences.

### Video Recording + Sync
- **D-06:** Side-by-side playback — video panel (left) + charts panel (right). Single scrub bar controls both. Scrubbing video repositions chart cursor and vice versa.
- **D-07:** Chunk every 5 minutes. H.264 MP4 via `adb shell screenrecord`. Files: `<session_id>_chunk_001.mp4` in `data/videos/`. Auto-chunking — no user action needed.

### iOS on Windows Strategy
- **D-08:** Mac proxy daemon as primary path — Windows app connects to Mac on local network via HTTP REST (device/app listing) + WebSocket (1Hz metric stream). Mac runs pyidevice, streams results back.
- **D-09:** tidevice as documented fallback for users without Mac. ~8 metrics with documented gaps (GPU, thermal, battery current unavailable).

### Auto Session Start
- **D-10:** ADB logcat polling every 2 seconds — monitor `adb logcat -s ActivityManager:I` for "START u0" lines containing target package name. Low overhead, works on all Android versions.
- **D-11:** Start sessions on ALL connected devices simultaneously when target app detected. Each device gets its own session. User pre-selects "watch" packages in Settings.

### Session Collections
- **D-12:** Flat tags + optional `project_id` field on sessions table. Filter by tag or project in session history. No hierarchical nesting.
- **D-13:** Collection/tag assignment during session start (dropdown in AppPicker) AND editable post-hoc in session detail. Maximum flexibility.

### Claude's Discretion
- Drag-region overlay color and handle styling (VS Code Dark+ theme)
- Threshold alert polling interval within MetricCollector tick loop
- Video chunk file naming convention and directory structure
- Mac proxy daemon: exact REST endpoints, WebSocket message format, authentication (none — local network only)
- Logcat parsing regex for ActivityManager START lines
- Schema migration v2: exact DDL for detected_issues, collections, videos tables (from UNIFIED-SPEC.md Appendix C)
- Linux smoke test scope — verify app launches + ADB device discovery + 60s session

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Spec & Requirements
- `UNIFIED-SPEC.md` — Single source of truth. §6.9 (Auto-Detected Issues), §5 (Metrics — disk I/O fields), §8 + Appendix C (Schema DDL v2 — detected_issues, collections, videos tables), §9.6-9.8 (Session screens — region analysis, video player), §14 (Testing — Linux smoke test)
- `implementation_plan.md` — 12-week sprint breakdown for v1.0, phase-level goals for v1.5–v3.5

### Planning Documents
- `.planning/PROJECT.md` — Project context, core value, constraints (May 31 deadline), key decisions
- `.planning/REQUIREMENTS.md` — 13 v1.5 requirements (V15-01 through V15-13) for Phase 2
- `.planning/ROADMAP.md` — Phase 2 wave structure, dependency graph, risk register
- `.planning/config.json` — YOLO mode, coarse granularity, parallel execution

### Prior Phase Context
- `.planning/phases/01-v1-0-external-profiling-mvp/01-CONTEXT.md` — 20 decisions from Phase 1 (D-01 through D-20). All carry forward.
- `.planning/phases/01-v1-0-external-profiling-mvp/01-SUMMARY.md` through `07-SUMMARY.md` — What was built in Phase 1

### Codebase Integration Points
- `performancebench/lib/core/analytics/analytics_service.dart` — Extend for region stats and auto-detected issues computation
- `performancebench/lib/shared/widgets/metric_chart.dart` — Extend with drag-selection handler + video scrub sync
- `performancebench/lib/core/services/adb_service.dart` — Add screenrecord command, logcat monitoring
- `performancebench/lib/core/services/ios_service.dart` — Pattern reference for Mac proxy daemon subprocess management
- `performancebench/lib/core/database/` — All DAOs extend for v2 schema (collections, videos, detected_issues)
- `performancebench/lib/features/session_detail/` — Add Video tab, region analysis panel
- `performancebench/lib/features/settings/` — Add threshold alert config section

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **MetricChart widget** — Can be extended with `onDragSelection` callback emitting (startIndex, endIndex). Already handles touch interaction for tooltips.
- **AnalyticsService.computeMarkerStats()** — Region stats computation is identical to marker stats logic. Extract shared helper.
- **StatusBar error badge** — Reuse exact pill pattern for threshold alert count badge (red background, count number, clickable).
- **IosService subprocess pattern** — Mac proxy daemon follows same start/SIGTERM/SIGKILL lifecycle. Reuse Process.start(), utf8.decoder, LineSplitter.
- **Settings panel** — Add "Threshold Alerts" subsection to Profiling category. Reuse _ToggleRow, _DropdownRow components.
- **ComparisonAnalytics** — Per-region delta between regions works same as per-session delta. Same MetricDelta data class.

### Established Patterns
- TDD throughout — RED → GREEN → REFACTOR per parser and analytics pattern from Phase 1
- VS Code Dark+ theme — all new UI uses AppColors tokens, never hardcoded hex
- DAO pattern — one class per table, parameterized queries, ConflictAlgorithm for upsert
- Stream-based metrics — MetricCollector Stream<MetricSample> pattern; Mac proxy WebSocket stream follows same pattern
- Schema migration — Add new tables via Database onCreate/onUpgrade, match Appendix C exactly

### Integration Points
- **Session detail screen** — Add 6th tab (Video) + region analysis panel above charts. Existing 5-tab layout extends cleanly.
- **ActiveSessionScreen** — StatusBar alert badge integration for threshold breaches during recording.
- **AppPickerScreen** — Add collection/project dropdown + "watch for auto-start" checkbox.
- **HistoryScreen** — Extend filters for collection tag search + project filter dropdown.
- **Database.onUpgrade** — Schema v1→v2 migration: add detected_issues, collections, videos tables.

</code_context>

<specifics>
## Specific Ideas

- User expects drag-region to feel like video editing timeline — blue overlay during drag, snap to nearest data point
- Threshold alerts should be non-intrusive during profiling — badge only, no popups
- Video-chart sync is bidirectional — scrub either one, the other follows. Shared timeline bar at bottom.
- Mac proxy daemon should be zero-config — auto-discover Mac on local network via Bonjour/mDNS
- Auto session start is a "set and forget" feature — user configures once in Settings, then it watches on every device connect

</specifics>

<deferred>
## Deferred Ideas

- Battery drain threshold alert — better suited for post-session analytics (Phase 1 already computes drain %/hr)
- tidevice as primary iOS-on-Windows path — Mac proxy daemon provides full metrics, tidevice is fallback
- Hierarchical collection folders — flat tags are simpler and sufficient for v1.5
- Single-device auto-start mode — all-devices mode covers multi-device testing, simpler to implement
- Picture-in-picture video — complex on desktop Flutter, side-by-side layout is sufficient

</deferred>

---
*Phase: 2-v1.5 Analysis + Platform Expansion*
*Context gathered: 2026-05-04*
