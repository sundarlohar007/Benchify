# Findings ledger — `audit/v0.1.x`

Numbered list. Append-only. Update fields in place; never delete entries. Cross-references in slice reports use these IDs only.

Schema per entry:

```
### B-### — Title
- **Severity:** BLOCKER | HIGH | MED | LOW | NIT
- **Where:** path/to/file.ext:line[-line]
- **User-visible symptom:** what the user/operator observes
- **Root cause:** why it happens
- **Fix:** description, or commit sha if applied
- **Status:** OPEN | FIXED:<sha> | DEFERRED-TO-S<NN> | WONTFIX (<reason>)
- **Related:** B-###, B-### (or `—`)
- **Found in:** S-NN
- **Discovered:** YYYY-MM-DD
```

---

### B-001 — Theme switcher silently no-ops

- **Severity:** HIGH
- **Where:** `performancebench/lib/app.dart:149-156`
- **User-visible symptom:** Choosing Light / High Contrast / System in Settings has zero visible effect; the UI stays in dark theme.
- **Root cause:** `MaterialApp.router(... themeMode: ThemeMode.dark)` is hardcoded. With `themeMode == ThemeMode.dark` and `darkTheme:` provided, Flutter ignores the dynamic `theme:` argument and always renders the dark variant. The `themeModeProvider` switch above computes the right `ThemeData` but the answer is thrown away by `MaterialApp`.
- **Fix:** Map `ThemeModeOption` to `ThemeMode` (`light | system`) so `MaterialApp` actually applies `theme:`. Drop the redundant `darkTheme:` argument.
- **Status:** FIXED in this slice (commit added at end of S-01)
- **Related:** B-003 (themes not persisted compounds the silent-no-op surprise)
- **Found in:** S-01
- **Discovered:** 2026-05-08

---

### B-002 — No top-level error guard

- **Severity:** MED
- **Where:** `performancebench/lib/main.dart:21-51`
- **User-visible symptom:** Any uncaught async exception kills the app with no log; users see the window vanish on a Future error and have nothing to report.
- **Root cause:** `main()` calls `runApp` directly. Neither `FlutterError.onError` (framework errors) nor `runZonedGuarded` (async / out-of-zone errors) is set, so unhandled errors are swallowed by the runtime.
- **Fix:** Wrap startup in `runZonedGuarded<Future<void>>(...)`; install `FlutterError.onError` that logs via `FlutterError.presentError` and prints the exception in debug builds. Hook for future structured logging is left as a TODO referencing the logging slice.
- **Status:** FIXED in this slice
- **Related:** —
- **Found in:** S-01
- **Discovered:** 2026-05-08

---

### B-003 — Theme selection not persisted

- **Severity:** MED
- **Where:** `performancebench/lib/app.dart:33-34`
- **User-visible symptom:** User picks Light theme; on next launch the app reverts to Dark.
- **Root cause:** `themeModeProvider` is a plain `StateProvider` defaulting to `ThemeModeOption.dark`. No persistence layer reads/writes the value.
- **Fix (planned):** Persist via `shared_preferences` (already in `pubspec.yaml`). Bind read on app boot, write on change. Couple to settings screen wiring.
- **Status:** DEFERRED-TO-S04
- **Related:** B-001
- **Found in:** S-01
- **Discovered:** 2026-05-08

---

### B-004 — `_AppState` registers `WindowListener` it never reacts to

- **Severity:** LOW
- **Where:** `performancebench/lib/app.dart:113-124`
- **User-visible symptom:** None directly; dead-code path — when window-event handling becomes needed (close confirmation, minimise tracking), the listener is registered but does nothing because no override is implemented.
- **Root cause:** `with WindowListener` mixes in the listener interface; `windowManager.addListener(this)` registers, but no `onWindow*` overrides exist.
- **Fix:** Strip the mixin + add/remove listener calls. `_AppState` becomes a plain `ConsumerWidget`. Re-add when an actual reactor exists.
- **Status:** FIXED in this slice
- **Related:** —
- **Found in:** S-01
- **Discovered:** 2026-05-08

---

### B-005 — `playheadSourceProvider` uses magic strings

- **Severity:** LOW
- **Where:** `performancebench/lib/shared/providers/playhead_provider.dart:27`; consumers `lib/features/session_detail/replay_charts_tab.dart:135`, `lib/features/session_detail/video_tab.dart:157`, `lib/shared/widgets/video_player_widget.dart:108`.
- **User-visible symptom:** None. Dev-side risk: a typo (`'cahrt'`) compiles but breaks the feedback-loop guard, causing infinite seek/scrub loops.
- **Root cause:** `StateProvider<String>` accepts arbitrary text. Allowed values (`'video'`, `'chart'`, `'scrub_bar'`, `'none'`) live only in the doc comment.
- **Fix (planned):** Replace with `enum PlayheadSource { none, video, chart, scrubBar }` and `StateProvider<PlayheadSource>`; update 3 callers.
- **Status:** DEFERRED-TO-S04
- **Related:** —
- **Found in:** S-01
- **Discovered:** 2026-05-08

---

### B-006 — `isMacOSProvider` is an orphan provider

- **Severity:** NIT
- **Where:** `performancebench/lib/main.dart:19`
- **User-visible symptom:** None. Dev-side: declares a Riverpod surface that no widget reads.
- **Root cause:** Provider was declared in anticipation of D-18 ("iOS video UI shown disabled on non-macOS") but no consumer was added. Grep for `isMacOSProvider` returns only the declaration. Real callers use `Platform.isMacOS` directly.
- **Fix:** Delete the provider. Re-introduce when an actual consumer is wired.
- **Status:** FIXED in this slice
- **Related:** —
- **Found in:** S-01
- **Discovered:** 2026-05-08

---

### B-007 — `ChartColors.cpuApp` and `cpuSystem` are identical

- **Severity:** NIT
- **Where:** `performancebench/lib/shared/theme.dart:17-18`
- **User-visible symptom:** None — `cpuSystem` is dimmed by `cpuSystemDim` (alpha 0x60) when used, so the two never overlap visually. But the field name suggests a distinct hue.
- **Root cause:** Likely intentional (system = same hue as app, dim variant for background fill), but the duplicated full-opacity constant is confusing and invites accidental misuse.
- **Fix (planned):** Either drop `cpuSystem` and have callers use `cpuApp`+`cpuSystemDim` directly, or comment the intent inline. Decide alongside the rest of `ChartColors` consumers.
- **Status:** DEFERRED-TO-S04
- **Related:** —
- **Found in:** S-01
- **Discovered:** 2026-05-08
