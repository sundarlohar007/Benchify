# Phase 5: v3.0 Game Engine Plugins + iOS Injection + tvOS + PC — Discussion Log

> **Audit trail only.** Decisions captured in CONTEXT.md.

**Date:** 2026-05-06
**Phase:** 5-v3.0-game-engine-plugins-ios-injection-tvos-pc
**Areas discussed:** Game engine plugins, iOS IPA injection + tvOS, PC profiling agent
**Mode:** Default interactive

## Game Engine Plugins

| # | Decision | Selected |
|---|----------|----------|
| 1 | Architecture | Shared Rust core + per-engine wrappers |
| 2 | Marker API | BeginMarker/EndMarker — match Phase 1 pattern |
| 3 | Editor tooling | Stats dashboard in editor (read-only) |
| 4 | Distribution | Desktop app unified installer |
| 5 | Per-engine distribution | Standard per-engine as fallback |

## iOS IPA Injection + tvOS

| # | Decision | Selected |
|---|----------|----------|
| 6 | Signing | Auto-detect all 3 methods (free altool, paid account, user cert) |
| 7 | Tooling location | Desktop UI only — extend injection screen with iOS tab |
| 8 | tvOS support | Full pyidevice parity — available metrics |

## PC Profiling Agent

| # | Decision | Selected |
|---|----------|----------|
| 9 | pb-pcprobe binary | Rust — reuse Phase 4 SDK modules |
| 10 | Video recording | Platform-native per OS — Rust orchistrates |
| 11 | Metric depth | PC-appropriate — match where sensible |
