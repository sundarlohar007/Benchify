# Phase 4: v2.5 Android SDK Injection — Discussion Log

> **Audit trail only.** Decisions captured in CONTEXT.md.

**Date:** 2026-05-06
**Phase:** 4-v2.5-android-sdk-injection
**Areas discussed:** APK injection strategy, Native SDK architecture, iOS video recording, Automation + WebView
**Mode:** Default interactive

## APK Injection Strategy

| # | Decision | Selected |
|---|----------|----------|
| 1 | CLI vs Desktop UI | Desktop UI only — drag-drop workflow |
| 2 | apktool vs Frida | User picks per APK |
| 3 | Keystore handling | Desktop file picker + password |
| 4 | Smali hook location | Application.onCreate() |
| 5 | APK compatibility | Full — AAB + ProGuard support |
| 6 | Repo location | Monorepo sibling — performancebench-injector/ |
| 7 | Re-signing | Full resign — user keystore |
| 8 | Injection verification | Multi-step — checks at each stage |
| 9 | CI/CD injection | GUI only — CI uses Frida |

## Native SDK Architecture

| # | Decision | Selected |
|---|----------|----------|
| 10 | SDK scope | Full replacement — no ADB needed |
| 11 | Socket protocol | JSON over TCP port 8080 |
| 12 | FPS overlay | Pill widget — draggable, color-coded |
| 13 | SDK lifecycle | Always-on from app start |
| 14 | .so compilation | cargo-ndk — all Android ABIs |
| 15 | WebView JS | addJavascriptInterface bridge |
| 16 | Network stats | Process-level totals /proc/pid/net/dev |

## iOS Video Recording

| # | Decision | Selected |
|---|----------|----------|
| 17 | Integration | Reuse Android ScreenrecordService pattern |
| 18 | Platform support | macOS-only — disable on other platforms |
| 19 | Sync | Start/stop match — same as Android |
| 20 | Quality | Configurable — 480p/720p/1080p, 15/30/60fps |
| 21 | Audio | Video-only — no audio |

## Automation + CI/CD

| # | Decision | Selected |
|---|----------|----------|
| 22 | Command set | Full — 7 actions (start/stop/pause/resume/marker/screenshot/export) |
| 23 | Broadcast format | Intent extras + JSON payload |
| 24 | CI/CD integration | Desktop CLI mode — pb automark |
| 25 | Injection in CI | No — GUI only, CI uses Frida |
