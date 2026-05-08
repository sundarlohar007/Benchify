# Slice 05 — Flutter mobile companion app

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-08

## Scope

`performancebench-mobile/lib/` — 9 files, 817 LOC. The carving doc called this slice "Flutter mobile — runtime (FPS overlay, sample bridge, native channels)" but the **FPS overlay actually lives in the Android/iOS native side of the SDK** (S-06 / S-07 / S-11). The mobile module on disk is a *companion viewer app* that reads from the desktop's HTTP API. Re-scoped accordingly.

| Path                                              | LOC | Read |
|---------------------------------------------------|----:|:----:|
| `main.dart`                                       |   9 | full |
| `app.dart`                                        |  76 | full |
| `routes/app_router.dart`                          |  47 | full |
| `services/api_service.dart`                       |  63 | full |
| `screens/settings/server_settings_screen.dart`    | 139 | full |
| `screens/sessions/session_list_screen.dart`       | 102 | full |
| `screens/sessions/session_detail_screen.dart`     | 146 | full |
| `screens/trends/trends_screen.dart`               | 133 | full |
| `widgets/session_card.dart`                       | 103 | full |

## User-flow trace

> *Install APK → open → enter server URL + token → connect → see sessions → tap row → detail.*

1. `main.dart` runs `BenchifyMobileApp`.
2. `_BenchifyMobileAppState.initState` calls `ApiService.fromPreferences()` — reads saved `server_url` + `api_token`.
3. **Pre-fix** (B-051): on every rebuild, `AppRouter.create(_apiService)` produced a brand-new `GoRouter`, throwing away nav state.
4. **Pre-fix** (B-052): `ServerSettingsScreen.onConnected(api)` only `go('/sessions')` — but the captured `api` in the route closures was still null. First-connect navigation crashed on `api!`.
5. After fix: shell holds a `GoRouterHandle`, recreates only when `_setApi` mutates state, then explicitly navigates.

## Findings

| ID    | Sev   | Title                                                                                            | Status              |
|-------|-------|--------------------------------------------------------------------------------------------------|---------------------|
| B-051 | HIGH  | `app.dart` rebuilds the entire `GoRouter` on every `build()`                                     | FIXED in this slice |
| B-052 | HIGH  | First-connect flow crashes: `onConnected` doesn't propagate the new `ApiService` back to routes  | FIXED in this slice |
| B-053 | MED   | `ApiService.get`/`post` have no timeout — UI hangs forever on flaky mobile connections           | FIXED in this slice |
| B-054 | MED   | API token persisted in `SharedPreferences` plaintext — should use `flutter_secure_storage`       | DEFERRED-TO-S20     |
| B-055 | MED   | `SessionCard` colors fps badge by `target_fps` (the configured target), not `actual_avg_fps`     | DEFERRED-TO-S19     |
| B-056 | MED   | `main.dart` has no top-level error guard — sister of B-002                                       | FIXED in this slice |
| B-057 | MED   | `api!` non-null assertions across routes crash if api null at navigate time                      | FIXED via redirect (covered by B-052 fix) |
| B-058 | LOW   | Server URL accepts `http://` — no HTTPS enforcement; token sent over cleartext                   | DEFERRED-TO-S20     |
| B-059 | LOW   | Token-clear path leaves a stale token in `SharedPreferences`                                     | DEFERRED-TO-S20     |
| B-060 | LOW   | `SessionCard` `(session['id'] as String?)?.substring(0, 8)` crashes on short ids                 | FIXED in this slice |
| B-061 | LOW   | `TrendsScreen` date formatting via `toIso8601String().split('T')[0]` uses local time, may drift  | DEFERRED-TO-S20     |
| B-062 | NIT   | `ServerSettingsScreen._isConnecting` not reset on success                                        | DEFERRED-TO-S20     |
| B-063 | NIT   | `SessionDetailScreen` computes display vars during loading state                                 | DEFERRED-TO-S20     |
| B-064 | NIT   | `app.dart` had unused `shared_preferences` import                                                | FIXED in this slice (incidental) |

## Cross-slice notes

- **B-054 / B-058**: token + transport security. Bundle into S-20 with the rest of the security hardening (B-010 path traversal, B-021 timeouts).
- **B-055**: needs server API contract check — does `/api/v1/sessions` actually return `actual_avg_fps`? If yes, switch to it. Defer to S-19 (build/CI pulls in server contract context).
- **B-061**: ISO date split. Trivial fix (use UTC explicitly), but trends UI is partly stub already; bundle.

## Local fixes summary

1. **B-051 + B-052 (combined fix, the headline)**:
   - `app.dart`: state owns a `GoRouterHandle?`; recreated only when `_setApi` mutates. Splash screen renders during initial prefs read.
   - `routes/app_router.dart`: `create(...)` now takes `api` + `onConnected`; returns a `GoRouterHandle` wrapper. Added a `redirect:` that bounces any post-connect navigation lacking a live api back to `/settings` rather than crashing on `api!`.
   - `screens/settings/server_settings_screen.dart`: unchanged — its `onConnected(api)` callback now correctly propagates up.
2. **B-053**: 15-second timeout on every `ApiService` GET/POST.
3. **B-056**: `main.dart` mirrors the desktop `runZonedGuarded` + `FlutterError.onError` pair from B-002.
4. **B-060**: defensive length-check before `substring(0, 8)`; falls back to the full id when shorter.
5. **B-064**: dropped the orphan `shared_preferences` import from `app.dart`.
6. **B-057**: covered by the `redirect:` in B-052's fix.

## Verification

`flutter analyze lib/` — No issues found.
