# Slice 04 — Flutter desktop: UI screens

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-08

## Scope

`performancebench/lib/features/` — 37 files, ~10,683 LOC across 11 feature folders, plus `lib/shared/widgets/` (9 files). Far too large to fully read in one 5% slice; this slice prioritises:

- the **golden user flow** entry points (device list, app picker, active session, session detail)
- everything that touches **deferred items from S-01..S-03** (B-003 theme persist, B-005 playhead enum, B-007 ChartColors, B-016 screenshot UI gate)

Files read in full:
| Path                                                                  | LOC |
|-----------------------------------------------------------------------|----:|
| `features/settings/settings_screen.dart`                              | 656 |
| `features/active_session/screenshots_tab.dart`                        | 248 |
| `features/active_session/active_session_screen.dart`                  | 245 |
| `features/session_detail/replay_charts_tab.dart`                      | 290 |
| `features/session_detail/video_tab.dart` (head + tail)                | 474 |
| `shared/widgets/video_player_widget.dart` (head + relevant)           | (n) |
| `shared/providers/playhead_provider.dart`                             |  28 |
| `shared/theme.dart` (re-touch for B-007)                              | 411 |
| `features/app_picker/app_picker_screen.dart` (head)                   | 318 |
| `core/services/session_service.dart` (called from active session)     |  83 |

Other 28 feature files grep-scanned for `TODO`, `FIXME`, empty `onPressed: () {}`, `catch (_)`, `placeholder`. Headlines surfaced (B-047, B-048, B-049) added below; remaining files queued for S-20.

## User-flow trace

> *device list → app picker → start session → screenshots/charts/markers tab → stop → session detail → replay/video/issues*.

1. `DeviceListScreen` → `AppPickerScreen(deviceId)` → constructs `MetricCollector` and friends.
2. `ActiveSessionScreen` runs the live tab triple. **B-047**: `_handleStop` does NOT call `SessionService.stopSession`; it just navigates away. Pending batch + session end-time lost.
3. Replay path: `SessionDetailScreen` → `ReplayChartsTab` (full charts) + `VideoTab` (player + scrub bar). `playheadSourceProvider` ties them; pre-fix, the source was a `String` with magic values (B-005).
4. `SettingsScreen` exposes theme, paths, alerts, charts, shortcuts, server, about. **B-042**: theme dropdown was wired with `current.name` (enum string) against display-label items, never matched any item.

## Findings

| ID    | Sev   | Title                                                                                          | Status              |
|-------|-------|------------------------------------------------------------------------------------------------|---------------------|
| B-042 | HIGH  | Settings theme dropdown value mismatch: `current.name` vs display-label items                  | FIXED in this slice |
| B-043 | MED   | Many settings rows (sample rate, screenshot interval, chart window, font, etc.) have no `onChanged` wiring | DEFERRED-TO-S20 |
| B-044 | HIGH  | `SettingsScreen._buildAboutSection` hardcodes `'Version','1.0.0'` — sister of B-024            | FIXED in this slice |
| B-045 | MED   | Settings "Reset Onboarding" button has empty `onPressed`                                       | DEFERRED-TO-S20     |
| B-046 | NIT   | Settings GitHub URL row is plain text, not a clickable link                                    | DEFERRED-TO-S20     |
| B-047 | HIGH  | `ActiveSessionScreen._handleStop` skips `SessionService.stopSession` — data loss on session end | DEFERRED-TO-S20    |
| B-048 | MED   | `ActiveSessionScreen._handleScreenshot` empty stub                                             | DEFERRED-TO-S20     |
| B-049 | LOW   | `AppPickerScreen._loadCollections` swallows DB errors silently (`catch (_)`)                   | DEFERRED-TO-S20     |
| B-050 | LOW   | `ScreenshotsTab` empty-state implies feature works ("will appear during recording")            | FIXED in this slice |

## Resolved deferrals from earlier slices

| ID    | Originally from | Resolution this slice                                                          |
|-------|-----------------|--------------------------------------------------------------------------------|
| B-003 | S-01            | **Still DEFERRED.** Persistence requires a Riverpod `Notifier` rewrite + boot-time async load. Out of scope for "low-risk local". Re-targeted to S-20 with note. |
| B-005 | S-01            | **FIXED.** New `enum PlayheadSource { none, video, chart, scrubBar }`; 4 caller sites migrated. Typos are now compile errors. |
| B-007 | S-01            | **FIXED.** Inline comment on `ChartColors.cpuSystem` documents the deliberate hue-share with `cpuApp`; consumers should reach for `cpuSystemDim` for fills. |
| B-016 | S-02 (UI gate)  | **FIXED (UI gate).** `ScreenshotsTab` empty-state now reads "Screenshot capture is not enabled in this build" + explains the encoder is queued. Real impl still DEFERRED-TO-S20. |

## Cross-slice notes

- **B-003 (theme persist)**: needs `NotifierProvider<ThemeModeNotifier, ThemeModeOption>` that loads from `SharedPreferences` on construction and writes on every mutation. Roughly:
  ```dart
  class ThemeModeNotifier extends Notifier<ThemeModeOption> { ... build() async { ... }}
  ```
  But Riverpod 2 requires `AsyncNotifier` for boot-async load, which changes every reader (`ref.watch(themeModeProvider)` returns `AsyncValue<ThemeModeOption>` instead of `ThemeModeOption`). That cascade trims into ~6 widgets; deferred until the persistence pattern is confirmed.
- **B-047** is the most user-visible regression remaining: today the user clicks Stop, the screen navigates back to device list, and the last 0–5 s of samples + the session's `endedAt` field never make it to disk. Local fix would need: spawn-time `SessionService.setActiveCollector(...)` plumbing; provider for `SessionService`; load `Session` row by id before passing to `stopSession`. Roughly 30 LOC across 3 files. Worth its own slice.
- **B-016 (real impl)**: still pinned to S-20. UI gate in this slice means any user trying it sees an honest "not implemented" message rather than a corrupted gallery.

## Local fixes summary

1. **B-005 (PlayheadSource enum)**:
   - `playhead_provider.dart`: introduced `enum PlayheadSource { none, video, chart, scrubBar }`; `playheadSourceProvider` is now `StateProvider<PlayheadSource>`.
   - `replay_charts_tab.dart:135`: `'chart'` → `PlayheadSource.chart`.
   - `video_tab.dart:157`: `'scrub_bar'` → `PlayheadSource.scrubBar`.
   - `video_player_widget.dart:108-111`: string compare → enum compare.
2. **B-007 (ChartColors.cpuSystem)**: inline doc comment explains the hue-share with `cpuApp` is deliberate; pointer to `cpuSystemDim` for fills.
3. **B-016 (UI gate)**: `screenshots_tab.dart` empty-state replaced with an honest "not enabled in this build" notice.
4. **B-042 (theme dropdown)**: `displayLabel` now derived via switch on `ThemeModeOption`, matching the dropdown items. Selecting an option no longer leaves the dropdown in an invalid-value state.
5. **B-044 (settings version)**: `'1.0.0'` → `'0.1.1'`; TODO references S-19 for `package_info_plus` wiring.

## Verification

`flutter analyze` on touched files: 7 pre-existing infos (deprecated `Radio.activeColor`/`groupValue`/`onChanged`, stylistic `unnecessary_underscores`); no new issues introduced.
