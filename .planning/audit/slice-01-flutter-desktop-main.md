# Slice 01 — Flutter desktop: main + lifecycle

**Status**: in progress → complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-08

## Scope

| Path                                              | LOC | Read |
|---------------------------------------------------|----:|:----:|
| `performancebench/lib/main.dart`                  |  52 | yes  |
| `performancebench/lib/app.dart`                   | 213 | yes  |
| `performancebench/lib/shared/theme.dart`          | 411 | yes  |
| `performancebench/lib/shared/providers/playhead_provider.dart` | 28 | yes |

Also touched: scanned for orphan provider usage across `lib/**/*.dart` and `pubspec.yaml`.

## User-flow trace

> *Desktop user double-clicks installer → app launches → first window shows.*

1. `main()` runs (`main.dart:21`) → reads CLI args → initialises `windowManager`.
2. `windowManager.waitUntilReadyToShow(...)` shows the window.
3. `runApp(ProviderScope(child: const App()))`.
4. `App._AppState.build` (`app.dart:127`) reads `themeModeProvider` + `routerProvider`, returns `MaterialApp.router`.
5. Initial route `/` → `DeviceListScreen` (out of scope here, S-04).

## Findings

| ID    | Sev    | Title                                                       | Status                |
|-------|--------|-------------------------------------------------------------|-----------------------|
| B-001 | HIGH   | Theme switcher silently no-ops — `themeMode` hardcoded dark | FIXED in this slice   |
| B-002 | MED    | No top-level error guard; uncaught errors crash silently    | FIXED in this slice   |
| B-003 | MED    | Theme selection not persisted across launches               | DEFERRED-TO-S04       |
| B-004 | LOW    | `_AppState with WindowListener` subscribes but never reacts | FIXED in this slice   |
| B-005 | LOW    | `playheadSourceProvider` uses magic strings, not enum       | DEFERRED-TO-S04       |
| B-006 | NIT    | `isMacOSProvider` is an orphan `StateProvider`              | FIXED in this slice   |
| B-007 | NIT    | `ChartColors.cpuApp == ChartColors.cpuSystem` (same hex)    | DEFERRED-TO-S04       |

Detail of each finding lives in [`FINDINGS.md`](./FINDINGS.md).

## Cross-slice notes

- **B-003** needs `shared_preferences` wiring + a settings repository layer. `shared_preferences` is already in `pubspec.yaml` (line 31). Defer until S-04 (settings screen) so the persistence + UI land together.
- **B-005** has 3 caller sites (`replay_charts_tab.dart`, `video_tab.dart`, `video_player_widget.dart`). Replacing the magic string with an enum is a coordinated rename. Defer to S-04 where the callers are read.
- **B-007** is a small enum/spec call — bundle with S-04's chart-colour audit.

## Local fixes summary

- `app.dart`: replaced hardcoded `themeMode: ThemeMode.dark` with a `ThemeModeOption → ThemeMode` mapping; dropped redundant `darkTheme:` arg; converted `_AppState` from `ConsumerStatefulWidget with WindowListener` to a plain `ConsumerWidget` (no listeners were registered).
- `main.dart`: wrapped startup in `runZonedGuarded`, set `FlutterError.onError`; removed orphan `isMacOSProvider`.

## Verification

`flutter analyze` (manual, see commit) — clean for the touched files.
