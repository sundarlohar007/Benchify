# Phase 2: v1.5 Analysis + Platform Expansion — Discussion Log

**Date:** 2026-05-04
**Mode:** Default (interactive discuss)
**Areas discussed:** 6 (Drag-region, Threshold alerts, Video, iOS Windows, Auto start, Collections)

## Drag-Region Selection UX

- **Q:** How should user select a region on the session timeline?
- **Options:** Click-drag on chart (Recommended) / Handles + scrub bar / Time input fields
- **Selected:** Click-drag on chart
- **Notes:** Blue selection overlay on MetricChart. Same interaction pattern as video editing timeline.

## Threshold Alert Behavior

- **Q:** Where do alerts surface and what happens on breach?
- **Options:** Status bar badge / In-app toast / Session detail only
- **Action:** Auto-marker / Auto-marker + screenshot / Just log
- **Threshold types:** FPS / CPU / Memory / Battery
- **Selected:** Status bar badge + Auto-marker + FPS/CPU/Memory (Claude's recommendation, user accepted)
- **Defaults:** FPS < 30 for 10s, CPU > 85% for 5s, Memory growth > 100MB over 30s
- **Notes:** Battery drain left for post-session analytics. Config in Settings → Profiling. All default-off.

## Video Recording + Sync

- **Q:** Embedded player design?
- **Options:** Side-by-side / Tab overlay / Picture-in-picture
- **Selected:** Side-by-side (1)
- **Q:** Chunking strategy?
- **Options:** 5min time-based / 500MB size-based / Single file
- **Selected:** 5min chunks (A)
- **Notes:** Video panel left, charts right. Shared scrub bar. H.264 MP4 via screenrecord.

## iOS on Windows — tidevice vs Mac Proxy

- **Q:** Primary path for Windows users?
- **Options:** Mac proxy daemon / tidevice / Both with auto-detect
- **Selected:** Mac proxy daemon (1)
- **Q:** Mac proxy communication?
- **Options:** HTTP REST + WebSocket / Custom TCP / SSH tunnel
- **Selected:** HTTP REST + WebSocket (A)
- **Notes:** Zero-config via Bonjour/mDNS discovery. tidevice as documented fallback.

## Auto Session Start

- **Q:** How to detect app launch?
- **Options:** ADB logcat polling / Broadcast receiver / PID polling
- **Selected:** ADB logcat polling (1)
- **Q:** Multiple devices?
- **Options:** All devices / Pick first / Device selector
- **Selected:** All devices (A)
- **Notes:** 2s polling interval. User pre-selects watch packages in Settings.

## Session Collections

- **Q:** Organization model?
- **Options:** Flat tags / Hierarchical folders / Auto-group by app
- **Selected:** Flat tags (1)
- **Q:** Assignment timing?
- **Options:** Both / Post-hoc only / During session only
- **Selected:** Both (A)
- **Notes:** Tags + optional project_id field. Assignable during session start and editable post-hoc.

## Claude's Discretion Areas
- Drag-region overlay color and handle styling
- Threshold alert polling interval in MetricCollector
- Video chunk file naming convention
- Mac proxy daemon REST endpoints and WebSocket message format
- Logcat parsing regex
- Schema migration v2 DDL (from UNIFIED-SPEC.md)
- Linux smoke test scope
