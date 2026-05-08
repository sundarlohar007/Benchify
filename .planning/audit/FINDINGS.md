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
- **Status:** FIXED:4b895be
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
- **Status:** FIXED:4b895be
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
- **Status:** FIXED:4b895be
- **Related:** —
- **Found in:** S-01
- **Discovered:** 2026-05-08

---

### B-005 — `playheadSourceProvider` uses magic strings

- **Severity:** LOW
- **Where:** `performancebench/lib/shared/providers/playhead_provider.dart:27`; consumers `lib/features/session_detail/replay_charts_tab.dart:135`, `lib/features/session_detail/video_tab.dart:157`, `lib/shared/widgets/video_player_widget.dart:108`.
- **User-visible symptom:** None. Dev-side risk: a typo (`'cahrt'`) compiles but breaks the feedback-loop guard, causing infinite seek/scrub loops.
- **Root cause:** `StateProvider<String>` accepts arbitrary text. Allowed values (`'video'`, `'chart'`, `'scrub_bar'`, `'none'`) live only in the doc comment.
- **Fix:** Replaced with `enum PlayheadSource { none, video, chart, scrubBar }` and `StateProvider<PlayheadSource>`; migrated 3 caller sites (`replay_charts_tab.dart:135`, `video_tab.dart:157`, `video_player_widget.dart:108-111`). Typos in source values are now compile errors instead of runtime feedback-loop bugs.
- **Status:** FIXED:b4c0df1
- **Related:** —
- **Found in:** S-01
- **Resolved in:** S-04
- **Discovered:** 2026-05-08

---

### B-006 — `isMacOSProvider` is an orphan provider

- **Severity:** NIT
- **Where:** `performancebench/lib/main.dart:19`
- **User-visible symptom:** None. Dev-side: declares a Riverpod surface that no widget reads.
- **Root cause:** Provider was declared in anticipation of D-18 ("iOS video UI shown disabled on non-macOS") but no consumer was added. Grep for `isMacOSProvider` returns only the declaration. Real callers use `Platform.isMacOS` directly.
- **Fix:** Delete the provider. Re-introduce when an actual consumer is wired.
- **Status:** FIXED:4b895be
- **Related:** —
- **Found in:** S-01
- **Discovered:** 2026-05-08

---

### B-007 — `ChartColors.cpuApp` and `cpuSystem` are identical

- **Severity:** NIT
- **Where:** `performancebench/lib/shared/theme.dart:17-18`
- **User-visible symptom:** None — `cpuSystem` is dimmed by `cpuSystemDim` (alpha 0x60) when used, so the two never overlap visually. But the field name suggests a distinct hue.
- **Root cause:** Likely intentional (system = same hue as app, dim variant for background fill), but the duplicated full-opacity constant is confusing and invites accidental misuse.
- **Fix:** Inline doc comment on `ChartColors.cpuSystem` documents the deliberate hue-share with `cpuApp` (system-CPU is meant to read as a quieter sibling, not a separate metric). Pointer added so consumers reach for `cpuSystemDim` (alpha 0x60) for fills/backgrounds.
- **Status:** FIXED:b4c0df1
- **Related:** —
- **Found in:** S-01
- **Resolved in:** S-04
- **Discovered:** 2026-05-08

---

### B-008 — Battery design capacity reads the wrong sysfs file

- **Severity:** HIGH
- **Where:** `performancebench/lib/core/services/adb_service.dart:515-524` (pre-fix)
- **User-visible symptom:** `static_device.battery_capacity_mah` ends up holding the device's *current charge percentage* (0-100) instead of mAh design capacity. Comparison/trend dashboards built off this column are nonsense.
- **Root cause:** Fallback path read `/sys/class/power_supply/battery/capacity`, which the Linux power-supply class exports as the current charge fraction (0-100). The design-capacity field is `charge_full_design` (µAh).
- **Fix:** Read `charge_full_design`, divide by 1000, sanity-check the value (>100k µAh, <50 Ah) to reject misconfigured ROMs that keep the percentage layout.
- **Status:** FIXED:e4b1933
- **Related:** —
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-009 — `logcat -d` then `-c` race drops launch events

- **Severity:** MED
- **Where:** `adb_service.dart:799-820`
- **User-visible symptom:** Auto-detected app launches occasionally missed; the user has to start the session manually.
- **Root cause:** `runShellCommand('logcat -d')` dumps the buffer; the next call clears it (`logcat -c`). Lines that arrive between the two calls are wiped without ever being read.
- **Fix (planned):** Switch to `logcat -T <last-ts>` filter and stop clearing the buffer; or pipe logcat continuously instead of polling.
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-010 — `pullFile` accepts path-traversal in `remotePath`

- **Severity:** MED
- **Where:** `adb_service.dart:230-255`
- **User-visible symptom:** A caller passing `/sdcard/../etc/passwd` would read outside the intended sandbox.
- **Root cause:** Validation is `startsWith('/sdcard/')` / `startsWith('/data/local/tmp/')` only — `..` segments are not normalised.
- **Fix (planned):** Resolve `..` segments before checking; reject any path containing `..`.
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-011 — `collectStaticData` runs ADB calls sequentially

- **Severity:** MED
- **Where:** `adb_service.dart:416-579`
- **User-visible symptom:** Picking a device freezes the UI for ~10-15 s while five `adb shell` calls run back-to-back, each with 3 s timeout.
- **Root cause:** Calls are sequential `await`s; there is no `Future.wait` parallelisation.
- **Fix (planned):** Wrap independent calls in `Future.wait`; keep the 3 s per-call timeout.
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-012 — `startLogcatMonitor` leaks `StreamController` on cancel

- **Severity:** MED
- **Where:** `adb_service.dart:795-826`
- **User-visible symptom:** Long-lived sessions accrue memory; events emitted after a logical cancel can sneak through.
- **Root cause:** `onCancel` flips `stopped = true` but never closes the controller; the recursive `poll()` keeps a reference alive.
- **Fix (planned):** Close the controller in `onCancel`; null the field; guard `controller.add` against post-close state.
- **Status:** DEFERRED-TO-S20
- **Related:** B-018 (same shape in InjectionService — fixed there)
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-013 — Recording duration assumes every chunk is exactly 300 s

- **Severity:** MED
- **Where:** `screenrecord_service.dart:230-234, 257-261`; `ios_screenrecord_service.dart:271`
- **User-visible symptom:** A session stopped mid-chunk reports the wrong duration; gap-between-chunks calculation goes negative; UI scrub bar shows wrong total length.
- **Root cause:** Both services compute `chunkEnd = chunkStart + 300000` and `totalDuration = lastStart - firstStart + 300000`, regardless of when the chunk actually ended.
- **Fix:** Capture wall-clock `stopMs` once at top of `stop()`; per-chunk duration is `(nextChunk.startMs - chunkStartMs)` for non-last and `(stopMs - chunkStartMs)` for last; total duration is `stopMs - recordingStart`.
- **Status:** FIXED:e4b1933
- **Related:** —
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-014 — `startPcRecording` is a stub

- **Severity:** HIGH
- **Where:** `screenrecord_service.dart:357-377`
- **User-visible symptom:** User clicks Record on the PC-profiling screen; method returns true; nothing is recorded.
- **Root cause:** Method only mutates internal state and prints a log line. No probe message, no subprocess, no chunk timer.
- **Fix (planned):** Wire to `PcProbeConnection.startVideo` (already implemented in `pcprobe_service.dart:170`) and track chunk metadata via the probe's NDJSON stream.
- **Status:** DEFERRED-TO-S15
- **Related:** B-015
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-015 — `stopPcRecording` writes empty Video record

- **Severity:** HIGH
- **Where:** `screenrecord_service.dart:383-419`
- **User-visible symptom:** A PC-profiling session ends with a `Video` row that has `filepath=''`, `durationMs=0`, `fileSizeBytes=0`. Session detail view appears broken.
- **Root cause:** Counterpart to B-014 — `stopPcRecording` writes whatever default state was set, since nothing populated it.
- **Fix (planned):** Land alongside B-014 — pull chunk metadata from probe `eventStream`.
- **Status:** DEFERRED-TO-S15
- **Related:** B-014
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-016 — `ScreenshotService` saves identical 1×1 black JPEGs

- **Severity:** BLOCKER
- **Where:** `screenshot_service.dart:185-265`
- **User-visible symptom:** Every screenshot stored is the same hardcoded 1×1 black-pixel JPEG. The "Screenshots" tab in session detail shows what looks like a corrupted gallery.
- **Root cause:** `_downscale` returns a solid dark grey buffer (no PNG decode logic at all); `_encodeJpegBasic` returns the result of `_minimalJpeg()`, a 256-byte hardcoded literal. The class commentary even says "placeholder that compiles". The PNG dimensions parser at the top is real, but everything past `_parsePngDimensions` is fake.
- **Fix (planned):** Two-step:
  1. **S-04 (UI)**: hide / disable the screenshot toggle until the real implementation lands. Avoids polluting the DB with junk. **DONE in S-04** — `ScreenshotsTab` empty state now reads "Screenshot capture is not enabled in this build" rather than promising thumbnails. (See also B-050.)
  2. **S-20 (or follow-up slice)**: add `image: ^4.x` to pubspec, implement real PNG decode + JPEG encode using `img.copyResize` + `img.encodeJpg`.
- **Status:** PARTIAL FIX (UI gate FIXED:b4c0df1); real impl DEFERRED-TO-S20
- **Related:** B-017, B-050
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-017 — `AdbServiceRaw.runShellCommandRaw` ignores its arguments

- **Severity:** MED
- **Where:** `screenshot_service.dart:268-291`
- **User-visible symptom:** Bypasses the resolved ADB path; ignores the caller's `command`. Couples B-016 to the wrong execution surface.
- **Root cause:** Extension hardcodes `Process.run('adb', ['-s', deviceSerial, 'exec-out', 'screencap', '-p'])`. Caller's `command` parameter is dropped.
- **Fix (planned):** Use the resolved `_adbPath`; honour `command` (split into argv); land alongside B-016 since they're the same code path.
- **Status:** DEFERRED-TO-S20
- **Related:** B-016
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-018 — `_controller.add` after `close()` race

- **Severity:** MED
- **Where:** `injection_service.dart:280-291` and `ipa_injection_service.dart:284-295` (pre-fix)
- **User-visible symptom:** Injection occasionally crashes the desktop app with `Bad state: Cannot add new events after calling close`. Repro is timing-dependent: stdout listener emits the terminal `done` event and closes the controller, then `exitCode.then` fires for a non-zero code and tries to add an `error` event to the closed controller.
- **Root cause:** No `isClosed` guard around `_controller?.add`.
- **Fix:** Added `_safeAdd` / `_safeClose` helpers that consult `isClosed` before mutating; rewired all add/close call sites.
- **Status:** FIXED:e4b1933
- **Related:** B-019, B-022
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-019 — `stop()` nulls `_process` before delayed sigkill

- **Severity:** MED
- **Where:** `injection_service.dart:306-319` and `ipa_injection_service.dart:309-322` (pre-fix)
- **User-visible symptom:** SIGKILL fallback never fires; if the Python process ignores SIGTERM, the user has to kill it via Task Manager / `kill -9`.
- **Root cause:** `_process = null` was set synchronously, then a `Future.delayed(3s)` callback referenced `_process!.kill(sigkill)` — the bang fails because `_process` is now null.
- **Fix:** Capture local `p = _process` before clearing; delayed callback closes over `p`. Wrapped in `try/catch` to swallow "already exited".
- **Status:** FIXED:e4b1933
- **Related:** B-018, B-022
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-020 — `pythonPath` default `'python3'` breaks injector on Windows

- **Severity:** MED
- **Where:** `injection_service.dart:97`
- **User-visible symptom:** Windows users see "step=error, status=fail" with stderr `'python3' is not recognized as an internal or external command`. The entire APK injection flow is unusable on the most common dev platform.
- **Root cause:** Default value hardcoded as `'python3'`. Windows ships `python.exe` (no `3` suffix); the launcher only works inside virtualenvs / Anaconda.
- **Fix:** Constructor calls `_defaultPython()` which returns `'python'` on Windows and `'python3'` elsewhere. Caller can still override.
- **Status:** FIXED:e4b1933
- **Related:** —
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-021 — No 5-min subprocess timeout despite T-04-05 doc comment

- **Severity:** MED
- **Where:** `injection_service.dart` class-level docstring + `_spawnProcess`
- **User-visible symptom:** A wedged Python injector hangs indefinitely; user has to abort manually.
- **Root cause:** Comment promises "T-04-05: Subprocess timeout at 5 minutes. SIGTERM -> SIGKILL." but no `Timer` or `.timeout()` is wired.
- **Fix (planned):** Wrap process spawn in a 5-min watchdog timer that calls `stop()` on expiry; expose timeout duration as a constructor argument.
- **Status:** DEFERRED-TO-S20
- **Related:** B-022
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-022 — `IpaInjectionService` shares B-018 / B-019 / B-021

- **Severity:** MED
- **Where:** `ipa_injection_service.dart`
- **User-visible symptom:** Same race + signal + timeout problems as the Android-side `InjectionService`, but on macOS-only IPA path.
- **Root cause:** The IPA service was modeled on the APK service and inherited the same bugs verbatim.
- **Fix:** B-018 (close-after-add) and B-019 (process-null race) ported across; B-021 (timeout) deferred together with the Android side.
- **Status:** PARTIAL FIX (B-018, B-019 fixed at e4b1933); B-021 portion DEFERRED-TO-S20
- **Related:** B-018, B-019, B-021
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-023 — `ErrorHandler.setDebugMode()` never called from `--debug` flag

- **Severity:** MED
- **Where:** `error_handler.dart:32` + `main.dart` (caller side)
- **User-visible symptom:** Running with `--debug` correctly populates `debugModeProvider`, but the singleton `ErrorHandler` keeps its default `_debugMode = false` — error logs print one-line release format with no stack trace, even in debug runs.
- **Root cause:** No code path calls `ErrorHandler().setDebugMode(...)`. The Riverpod provider and the singleton are decoupled.
- **Fix:** `main.dart` now calls `ErrorHandler().setDebugMode(debugMode)` immediately after parsing `args.contains('--debug')`.
- **Status:** FIXED:e4b1933
- **Related:** B-002
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-024 — `UpdateService._currentVersion = '1.0.0'` shadows real release line

- **Severity:** HIGH
- **Where:** `update_service.dart:28`
- **User-visible symptom:** All current releases are `0.1.x`. Comparing `0.1.x` against `1.0.0` always returns "you're up to date", so the in-app update banner never fires.
- **Root cause:** Constant pinned to `'1.0.0'` and never updated.
- **Fix:** Interim hardcode to `'0.1.1'` (matches the only published GitHub release as of audit time) with a TODO referencing S-19 to wire `package_info_plus` so the version follows the build number.
- **Status:** FIXED:e4b1933
- **Related:** B-025
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-025 — `_compareVersions` can't parse pre-release suffixes

- **Severity:** MED
- **Where:** `update_service.dart:84-93`
- **User-visible symptom:** Latest release `0.1.1-rc.6` is parsed as `[0, 1, null]` (since `int.tryParse('1-rc') == null`), which collapses to `[0, 1, 0]` and gives a wrong "newer" verdict.
- **Root cause:** Splits on `.` then tries each segment as int — pre-release suffixes break the parse.
- **Fix:** Strip everything from `-` onward before splitting. Strict semver pre-release ordering deferred — sufficient for the "is there a new release line" question that the banner answers.
- **Status:** FIXED:e4b1933
- **Related:** B-024
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-026 — Plugin install backup `.bak` overwrites prior backup

- **Severity:** MED
- **Where:** `plugin_install_service.dart:91, 140, 265, 320`
- **User-visible symptom:** Run install → uninstall → reinstall → uninstall → the `.bak` written first round is gone, replaced by a backup of the *modified* manifest. User can't roll back to the original.
- **Root cause:** Backup path is always `'$manifestPath.bak'`. Each run clobbers prior copies.
- **Fix (planned):** Suffix backup with timestamp or a monotonic counter; only write backup when `.bak` doesn't already exist.
- **Status:** DEFERRED-TO-S13
- **Related:** B-027
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-027 — `PluginInstallService._pluginSourceDir = 'plugins'` is cwd-relative

- **Severity:** MED
- **Where:** `plugin_install_service.dart:37`
- **User-visible symptom:** Engine plugin install fails with "Plugin source files not bundled with this build" unless the user happened to launch the app from the right directory.
- **Root cause:** Constant path `'plugins'` resolves against `pwd`, not the app's bundle directory.
- **Fix (planned):** Resolve via `Platform.resolvedExecutable` and walk up to the app's bundle/data root; fall back to a packaged-asset path for installer builds.
- **Status:** DEFERRED-TO-S13
- **Related:** B-026
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-028 — `_resolveChipsetVendor` matches too broadly

- **Severity:** LOW
- **Where:** `adb_service.dart:601-616`
- **User-visible symptom:** Some devices get the wrong chipset vendor in static metadata (e.g. anything with `mt` in `ro.board.platform` is tagged MediaTek; `hi`-prefixed boards become HiSilicon).
- **Root cause:** Substring matches like `lower.contains('hi')`, `lower.contains('mt')`, `lower.contains('sc')` are too permissive.
- **Fix (planned):** Anchor matches to word boundaries; bias toward known-good prefix patterns (`mt6`, `sm[0-9]+`, `hi3`, …).
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-029 — `collectAppData` minSdk regex blocked by unrelated gate

- **Severity:** LOW
- **Where:** `adb_service.dart:684-691` (pre-fix)
- **User-visible symptom:** `static_app.min_sdk` mostly stayed null because the gate was structurally wrong, even though the regex itself worked.
- **Root cause:** The minSdk match was nested inside `if (compileSdkVersionCodename match == null)` — leftover from an earlier refactor. The gate happens to evaluate as true for typical lines, so it usually did fire, but the dependency was confusing and brittle.
- **Fix:** Match `minSdkVersion=(\d+)` directly without the unrelated gate.
- **Status:** FIXED:e4b1933
- **Related:** —
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-030 — `MetricCollector.statusStream` getter throws if accessed before `start()`

- **Severity:** LOW
- **Where:** `metric_collector.dart:94`
- **User-visible symptom:** A widget that subscribes to `statusStream` before the collector has started will crash with `Null check operator used on a null value`.
- **Root cause:** Getter does `_statusController!`. The controller is only created inside `start()`.
- **Fix (planned):** Lazy-init the controller on first access, or return `Stream.empty()` until `start()` runs.
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-031 — `MetricCollector._pid` discovered once; stale across restarts

- **Severity:** LOW
- **Where:** `metric_collector.dart:155-185, 35`
- **User-visible symptom:** If the target Android app crashes and Android assigns a new PID, the collector continues to read `/proc/<old-pid>` paths and silently returns no useful samples.
- **Root cause:** PID resolved once during `_initSession`; never refreshed.
- **Fix (planned):** Periodically re-resolve PID (every N seconds, or on consecutive failure threshold) via `pidof`.
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-032 — `MetricCollector._consecutiveFailures` declared, never used

- **Severity:** NIT
- **Where:** `metric_collector.dart:44`
- **User-visible symptom:** None.
- **Root cause:** Field reserved for a back-off / abort policy that wasn't implemented.
- **Fix (planned):** Either implement the back-off (auto-stop after N failed ticks) or delete the field.
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-033 — `PcProbeConnection._toSnakeCase` is a no-op despite the name

- **Severity:** NIT
- **Where:** `pcprobe_service.dart:121-124`
- **User-visible symptom:** None.
- **Root cause:** Comment explains the probe already emits snake_case, so the method just returns the input. The method name is misleading.
- **Fix (planned):** Inline the call site or rename the method to `_passThrough` to match what it does.
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-02
- **Discovered:** 2026-05-08

---

### B-034 — `cpu_parser._extractPidTicks` mis-parses comm names containing ')'

- **Severity:** MED
- **Where:** `performancebench/lib/core/parsers/cpu_parser.dart:225-242`
- **User-visible symptom:** Apps whose process name contains parentheses (e.g. `com.foo:my_proc(test)`) report wildly wrong CPU% — the parser splits on the first `)` and shifts every field index by one.
- **Root cause:** `pidStat.indexOf(')')` returns the position of the first close-paren. /proc/`<pid>`/stat's `comm` field can contain spaces and parens, so only the *last* `)` reliably terminates `comm`. The Rust SDK parser at `performancebench-injector/sdk/src/metrics/cpu.rs::parse_proc_self_stat` already uses `rfind(')')`; the Dart side drifted.
- **Fix:** Switch to `lastIndexOf(')')`; doc comment updated to point readers at the Rust side as the canonical implementation.
- **Status:** FIXED:be467cc
- **Related:** B-031 (stale PID compounds the symptom)
- **Found in:** S-03
- **Discovered:** 2026-05-08

---

### B-035 — `_extractSystemTicks` omits `steal` from total ticks

- **Severity:** LOW
- **Where:** `cpu_parser.dart:245-280`
- **User-visible symptom:** On virtualised hosts (cloud / emulator), system CPU% is slightly off because hypervisor steal time is excluded from `totalTicks`.
- **Root cause:** Sums `user + nice + system + idle + iowait + irq + softirq` — stops at field 7 (softirq). `steal` (field 8) and `guest`/`guest_nice` (9, 10) are not included.
- **Fix (planned):** Sum through `steal` (and ignore `guest`/`guest_nice` since they're already counted inside `user`). Verify against §5.2 once.
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-03
- **Discovered:** 2026-05-08

---

### B-036 — `chargingSource='none'` while `charging=true` on status 2/5 fallback

- **Severity:** LOW
- **Where:** `battery_parser.dart:74-88` (pre-fix)
- **User-visible symptom:** Some ROMs expose `status: 2` (charging) but no AC/USB/Wireless/Dock flag. The parser used to flag the device as charging while reporting `chargingSource='none'`, which is the same value it returns when *not* charging — consumers couldn't distinguish the two.
- **Root cause:** Final `else` branch wrote `'none'` for the fallback case.
- **Fix:** Return `'unknown'` for the status-2/5-with-no-source case so consumers can branch on it.
- **Status:** FIXED:be467cc
- **Related:** —
- **Found in:** S-03
- **Discovered:** 2026-05-08

---

### B-037 — Redundant `? true : false` ternary on already-boolean expression

- **Severity:** NIT
- **Where:** `battery_parser.dart:72`
- **User-visible symptom:** None.
- **Root cause:** `(anyPowered || status == 2 || status == 5) ? true : false` is just `anyPowered || status == 2 || status == 5`.
- **Fix:** Removed the ternary.
- **Status:** FIXED:be467cc
- **Related:** —
- **Found in:** S-03
- **Discovered:** 2026-05-08

---

### B-038 — Dead `fps < 0 ? 0 : fps` check

- **Severity:** NIT
- **Where:** `fps_parser.dart:186` (pre-fix)
- **User-visible symptom:** None.
- **Root cause:** `fps = 1000.0 / meanDelta` where `meanDelta > 0` (filtered upstream); the branch always passed through. The empty-deltas branch sets fps to 0.0 directly. Branch was unreachable as negative.
- **Fix:** Drop the guard; pass `fps` through.
- **Status:** FIXED:be467cc
- **Related:** —
- **Found in:** S-03
- **Discovered:** 2026-05-08

---

### B-039 — `memory_parser` regex assumes Android 7+ dumpsys format

- **Severity:** LOW
- **Where:** `memory_parser.dart:73-99`
- **User-visible symptom:** Devices on Android 6 and earlier may produce mostly-null memory subsections; the `TOTAL` line still works.
- **Root cause:** `dumpsys meminfo` reformatted between Android 5/6 and 7; the parser anchors on Android 7+ headers (`Java Heap`, `Native Heap`, `EGL mtrack`, …). Older builds use different labels.
- **Fix (planned):** Either drop pre-Android 7 support explicitly (most users are on 8+) or add a fallback table for the older labels.
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-03
- **Discovered:** 2026-05-08

---

### B-040 — `disk_io_parser` device list missing `nvme*`

- **Severity:** LOW
- **Where:** `disk_io_parser.dart:53`
- **User-visible symptom:** Newer flagships using NVMe storage (e.g. some 2024+ Pixels and Snapdragon-X laptops booted as Android-on-x86) report null disk I/O.
- **Root cause:** Hardcoded match for `sda`, `mmcblk0`, `vda`. Modern devices may expose primary storage as `nvme0n1`.
- **Fix (planned):** Match `nvme0n1` (and similar) in addition to the existing list.
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-03
- **Discovered:** 2026-05-08

---

### B-041 — `SdkState` mutable shared state without synchronization

- **Severity:** LOW
- **Where:** `core/sdk/sdk_state.dart`
- **User-visible symptom:** None observed yet. Risk: a settings UI mutation racing with a live profiling tick reads a partially updated config.
- **Root cause:** All five fields are plain mutable bools / ints, with no `ChangeNotifier` or lock guarding them. Riverpod isn't aware of the writes.
- **Fix (planned):** Convert to a Riverpod `StateNotifier` so reads go through the framework's read-your-writes guarantee, and writes invalidate dependents. Couples to settings UI in S-04.
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-03
- **Discovered:** 2026-05-08

---

### B-042 — Settings theme dropdown value mismatch

- **Severity:** HIGH
- **Where:** `performancebench/lib/features/settings/settings_screen.dart:241-253` (pre-fix)
- **User-visible symptom:** Theme dropdown in Settings appeared frozen or showed no current selection. Picking a value also looked broken because Flutter logged an internal assertion when `value:` didn't match any item.
- **Root cause:** `_DropdownRow('Theme', current.name, ...)` used the enum's `.name` (`'dark'`, `'light'`, `'highContrast'`, `'system'`) as the `value:` argument, but the items list used display labels (`'Dark'`, `'Light'`, `'High Contrast'`, `'System'`). Mismatch.
- **Fix:** Map `ThemeModeOption` → display label via switch before passing to `_DropdownRow`. The dropdown's `value:` now always matches one of its items; selection round-trips through the enum mapping that already existed in `onChanged`.
- **Status:** FIXED:b4c0df1
- **Related:** B-001, B-003
- **Found in:** S-04
- **Discovered:** 2026-05-08

---

### B-043 — Settings rows have no `onChanged` wiring

- **Severity:** MED
- **Where:** `settings_screen.dart` — Sample rate, Screenshot interval, Chart time window, Auto-detect layer name, Show null gaps, Animate chart scroll, Monospace font, FPS histogram bucket, Chart grid columns; "Paths" rows; "Keyboard Shortcuts" rows.
- **User-visible symptom:** ~12 settings appear functional (toggle slides, dropdown opens) but changing them has no effect; no provider is mutated, nothing is persisted.
- **Root cause:** Riverpod plumbing was only added for the alert thresholds + theme. The rest of the UI shipped as scaffolding with `onChanged: null` (or default no-op constructors).
- **Fix (planned):** Per-row provider wiring. Group similar rows (sample rate, screenshot interval, chart window) under a single `ProfilingSettings` notifier. Couple to `SdkState` rewrite (B-041).
- **Status:** DEFERRED-TO-S20
- **Related:** B-041, B-045
- **Found in:** S-04
- **Discovered:** 2026-05-08

---

### B-044 — Settings About section hardcodes `'1.0.0'`

- **Severity:** HIGH
- **Where:** `settings_screen.dart:291` (pre-fix)
- **User-visible symptom:** About screen says "Version: 1.0.0" while all releases are `0.1.x`. Misleads bug reporters about which build they're running.
- **Root cause:** Direct sister of B-024 — same hardcoded string in a different file.
- **Fix:** Bumped the literal to `'0.1.1'` to match the latest published release. TODO references S-19 to wire `package_info_plus` so the value follows the build.
- **Status:** FIXED:b4c0df1
- **Related:** B-024
- **Found in:** S-04
- **Discovered:** 2026-05-08

---

### B-045 — "Reset Onboarding" button has empty `onPressed`

- **Severity:** MED
- **Where:** `settings_screen.dart:295-300`
- **User-visible symptom:** Button visible in Settings but clicking it does nothing; user can't replay the onboarding flow without nuking app data.
- **Root cause:** Stubbed during the skeleton-first scaffold (D-02). The `onPressed: () { /* Reset onboarding flag */ }` body is a comment with no implementation.
- **Fix (planned):** Read/clear the onboarding flag from `SharedPreferences`; couple with whichever flag the onboarding feature uses (`features/onboarding/`). Also navigate to `/onboarding` so the user sees the result.
- **Status:** DEFERRED-TO-S20
- **Related:** B-003 (both need shared_preferences plumbing)
- **Found in:** S-04
- **Discovered:** 2026-05-08

---

### B-046 — Settings GitHub URL row is plain text, not a link

- **Severity:** NIT
- **Where:** `settings_screen.dart:293`
- **User-visible symptom:** User can't click the GitHub URL to open the repo; has to copy-paste manually.
- **Root cause:** `_InfoRow` just renders text with no gesture detector.
- **Fix (planned):** Wrap the value in `InkWell` + `launchUrl` (already a transitive dep via flutter SDK). Cosmetic.
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-04
- **Discovered:** 2026-05-08

---

### B-047 — `ActiveSessionScreen._handleStop` skips `SessionService.stopSession`

- **Severity:** HIGH
- **Where:** `performancebench/lib/features/active_session/active_session_screen.dart:68-76`
- **User-visible symptom:** When the user clicks Stop, the screen navigates back to the device list, BUT:
  - the last 0–5 s of pending samples in `MetricCollector._pendingBatch` are never flushed (lost),
  - `session.endedAt` and `durationMs` are never updated in the DB,
  - `AnalyticsService.computeSessionStats` / `computeMarkerStats` never run,
  - `DetectedIssuesService.runAllRules` (D-03 opt-in) never fires.
  Session detail view loads a row with `endedAt = null`, no stats, no markers stats.
- **Root cause:** The screen was scaffolded with a `// TODO: Call the active session service to stop collection, flush, and finalize` comment. The plumbing it needs (a `sessionServiceProvider`, the active session row, the active collector reference) was never added.
- **Fix (planned, ~30 LOC across 3 files):**
  1. Add `final sessionServiceProvider = Provider<SessionService>(...)` in `core/services/session_service.dart` (or wherever the DAO providers live).
  2. Wire the running `MetricCollector` into the service via `setActiveCollector(...)` at session start.
  3. In `_handleStop`: load the `Session` row by id (`SessionDao.getById`), `await ref.read(sessionServiceProvider).stopSession(session)`, then navigate.
- **Status:** DEFERRED-TO-S20
- **Related:** B-031 (stale PID compounds the symptom for long sessions)
- **Found in:** S-04
- **Discovered:** 2026-05-08

---

### B-048 — `ActiveSessionScreen._handleScreenshot` empty stub

- **Severity:** MED
- **Where:** `active_session_screen.dart:78-80`
- **User-visible symptom:** Manual screenshot button does nothing during a session.
- **Root cause:** Stubbed pending integration with `ScreenshotService` (which itself is fake — see B-016).
- **Fix (planned):** Wire after B-016's real implementation lands. Until then, the button should be visibly disabled.
- **Status:** DEFERRED-TO-S20
- **Related:** B-016, B-050
- **Found in:** S-04
- **Discovered:** 2026-05-08

---

### B-049 — `AppPickerScreen._loadCollections` swallows DB errors silently

- **Severity:** LOW
- **Where:** `app_picker/app_picker_screen.dart:55-71`
- **User-visible symptom:** If the DB fails to open, the user sees an empty Collections list with no indication something went wrong. Same for any future schema migration error.
- **Root cause:** `catch (_) { setState(() => _collectionsLoaded = true); }` — the error is dropped.
- **Fix (planned):** Route the exception through `ErrorHandler().logError(...)` (already imported elsewhere) and surface a one-line "Failed to load collections" banner.
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-04
- **Discovered:** 2026-05-08

---

### B-050 — `ScreenshotsTab` empty-state implies feature works

- **Severity:** LOW
- **Where:** `features/active_session/screenshots_tab.dart:69-94` (pre-fix)
- **User-visible symptom:** With no captures yet, the tab said "Screenshots will appear here during recording" — promising a feature that doesn't actually run (B-016: `ScreenshotService` is fake AND never instantiated).
- **Root cause:** Empty-state text was written under the assumption that the screenshot pipeline would be live by ship.
- **Fix:** Replaced the empty-state with a clear "Screenshot capture is not enabled in this build" banner that explicitly says encoding is queued. Removes the false promise.
- **Status:** FIXED:b4c0df1
- **Related:** B-016, B-048
- **Found in:** S-04
- **Discovered:** 2026-05-08

---

### B-051 — `app.dart` rebuilds the entire `GoRouter` on every `build()`

- **Severity:** HIGH
- **Where:** `performancebench-mobile/lib/app.dart:32` (pre-fix)
- **User-visible symptom:** Tapping a list row on the mobile companion sometimes leaves the back gesture unable to return to the list — the navigation stack mysteriously resets between gestures. Triggered by any rebuild (e.g. orientation change, theme update from MediaQuery).
- **Root cause:** `final router = AppRouter.create(_apiService);` was inside `build()`. Every rebuild minted a brand-new `GoRouter` whose internal stack was empty.
- **Fix:** Shell now caches a `GoRouterHandle` in state; recreated only when `_setApi` runs. Splash screen covers the boot-time prefs read.
- **Status:** FIXED:0fe69f5
- **Related:** B-052
- **Found in:** S-05
- **Discovered:** 2026-05-08

---

### B-052 — First-connect flow crashes on `api!`

- **Severity:** HIGH
- **Where:** `performancebench-mobile/lib/routes/app_router.dart:22-25` (pre-fix), `screens/sessions/session_list_screen.dart`, `screens/sessions/session_detail_screen.dart`, `screens/trends/trends_screen.dart`
- **User-visible symptom:** Brand-new install: enter URL + token → click Connect → app immediately crashes with `Null check operator used on a null value`. Companion app unusable on first run.
- **Root cause:** Routes captured `api` via closure when `AppRouter.create(api)` first ran (with `api == null`). `ServerSettingsScreen.onConnected(api)` only called `GoRouter.of(context).go('/sessions')`; the new `api` never made it to the route closures, so `api!` exploded.
- **Fix:**
  - Added `void Function(ApiService) onConnected` parameter to `AppRouter.create`.
  - Shell's `_setApi` rebuilds the router with the fresh `api` before navigating.
  - Added `redirect:` that bounces any non-`/settings` navigation lacking a live api back to settings, as a guardrail for future paths.
- **Status:** FIXED:0fe69f5
- **Related:** B-051, B-057
- **Found in:** S-05
- **Discovered:** 2026-05-08

---

### B-053 — `ApiService` calls have no timeout

- **Severity:** MED
- **Where:** `performancebench-mobile/lib/services/api_service.dart:33-62` (pre-fix)
- **User-visible symptom:** On a flaky cellular connection, `Connect` (or any session/trends load) hangs indefinitely — UI stays on "Connecting..." or the spinner forever.
- **Root cause:** `http.Client.get` / `http.Client.post` have no default timeout.
- **Fix:** 15-second `.timeout()` on every request. Throws `TimeoutException`, surfaced through existing error handling.
- **Status:** FIXED:0fe69f5
- **Related:** —
- **Found in:** S-05
- **Discovered:** 2026-05-08

---

### B-054 — API token persisted in `SharedPreferences` plaintext

- **Severity:** MED
- **Where:** `performancebench-mobile/lib/screens/settings/server_settings_screen.dart:54-57`, `services/api_service.dart:19`
- **User-visible symptom:** None directly. Risk: any process / backup / debug bridge with read access to the app's prefs file can extract the bearer token.
- **Root cause:** `SharedPreferences.setString('api_token', token)` writes to the plain prefs XML on Android / `NSUserDefaults` on iOS — neither is encrypted at rest.
- **Fix (planned):** Move to `flutter_secure_storage` (Keychain on iOS, EncryptedSharedPreferences on Android).
- **Status:** DEFERRED-TO-S20
- **Related:** B-058
- **Found in:** S-05
- **Discovered:** 2026-05-08

---

### B-055 — `SessionCard` colors fps badge by `target_fps`

- **Severity:** MED
- **Where:** `performancebench-mobile/lib/widgets/session_card.dart:21-26`
- **User-visible symptom:** A session that targeted 60 fps but actually ran at 12 fps shows up as a green "60 fps" badge — implying the run was healthy when it was terrible.
- **Root cause:** Color logic keys off `session['target_fps']` (the configured target) rather than `session['actual_avg_fps']` (what the device delivered).
- **Fix (planned):** Switch to `actual_avg_fps`. Needs a contract check on the server `/api/v1/sessions` response shape — defer to S-19 where build/CI carries the server contract context.
- **Status:** DEFERRED-TO-S19
- **Related:** —
- **Found in:** S-05
- **Discovered:** 2026-05-08

---

### B-056 — Mobile `main.dart` has no top-level error guard

- **Severity:** MED
- **Where:** `performancebench-mobile/lib/main.dart:6-9` (pre-fix)
- **User-visible symptom:** Any uncaught async exception kills the app silently. Sister of B-002.
- **Root cause:** `main()` calls `runApp` directly with no `runZonedGuarded` / `FlutterError.onError`.
- **Fix:** Mirror desktop `main.dart` — install `FlutterError.onError` + wrap startup in `runZonedGuarded<Future<void>>`.
- **Status:** FIXED:0fe69f5
- **Related:** B-002
- **Found in:** S-05
- **Discovered:** 2026-05-08

---

### B-057 — `api!` non-null assertions across routes

- **Severity:** MED
- **Where:** `app_router.dart:30, 36, 42` (pre-fix)
- **User-visible symptom:** Subset of B-052 — any post-connect path that loses the api crashes on `api!`.
- **Root cause:** Defensive coding gap: routes assumed api always non-null at navigate time, with no fallback.
- **Fix:** Covered by B-052's `redirect:` — any non-`/settings` route bounces back when api is null.
- **Status:** FIXED:0fe69f5 (subsumed by B-052)
- **Related:** B-052
- **Found in:** S-05
- **Discovered:** 2026-05-08

---

### B-058 — Server URL accepts `http://` — no HTTPS enforcement

- **Severity:** LOW
- **Where:** `screens/settings/server_settings_screen.dart:42-67`
- **User-visible symptom:** None visible; security posture problem. A user pointing the app at `http://192.168.…` sends the bearer token in cleartext on the LAN.
- **Root cause:** No URL validation in the connect flow.
- **Fix (planned):** Reject non-`https://` URLs unless the user has flagged a "I'm on a trusted LAN" override (rare). Couples to B-054.
- **Status:** DEFERRED-TO-S20
- **Related:** B-054
- **Found in:** S-05
- **Discovered:** 2026-05-08

---

### B-059 — Token-clear leaves stale token in prefs

- **Severity:** LOW
- **Where:** `screens/settings/server_settings_screen.dart:55-58`
- **User-visible symptom:** If the user blanks the token field and reconnects, the old token still lives in `SharedPreferences` until reinstall.
- **Root cause:** `if (token.isNotEmpty) prefs.setString(...)` — empty case never `prefs.remove(...)`.
- **Fix (planned):** Else-branch to `prefs.remove('api_token')`.
- **Status:** DEFERRED-TO-S20
- **Related:** B-054
- **Found in:** S-05
- **Discovered:** 2026-05-08

---

### B-060 — `SessionCard.substring(0, 8)` crashes on short ids

- **Severity:** LOW
- **Where:** `widgets/session_card.dart:18` (pre-fix)
- **User-visible symptom:** A malformed or truncated `session.id` (under 8 chars) would crash the list card with `RangeError`.
- **Root cause:** Hardcoded `substring(0, 8)` with no length check.
- **Fix:** Length-guard before substring; falls back to the full id when too short.
- **Status:** FIXED:0fe69f5
- **Related:** —
- **Found in:** S-05
- **Discovered:** 2026-05-08

---

### B-061 — `TrendsScreen` date formatting uses local time

- **Severity:** LOW
- **Where:** `screens/trends/trends_screen.dart:36-37`
- **User-visible symptom:** Around DST transitions or when the device is in a timezone east/west of UTC midnight, the trend window can shift by a day.
- **Root cause:** `DateTime.now().toIso8601String().split('T')[0]` uses local time.
- **Fix (planned):** Convert to UTC before formatting (`DateTime.now().toUtc()`).
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-05
- **Discovered:** 2026-05-08

---

### B-062 — `ServerSettingsScreen._isConnecting` not reset on success

- **Severity:** NIT
- **Where:** `screens/settings/server_settings_screen.dart:33-67`
- **User-visible symptom:** On the rare race where `onConnected` runs but the screen lingers (e.g. an extra frame before route switch), the button still says "Connecting...".
- **Root cause:** No `_isConnecting = false` on the success path.
- **Fix (planned):** Reset flag before invoking `onConnected`.
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-05
- **Discovered:** 2026-05-08

---

### B-063 — `SessionDetailScreen` computes display vars during loading state

- **Severity:** NIT
- **Where:** `screens/sessions/session_detail_screen.dart:48-56`
- **User-visible symptom:** None.
- **Root cause:** Build method extracts `appName`, `deviceId`, `dateStr`, etc. *before* the `_isLoading` ternary, so the work runs every frame even while the spinner is showing.
- **Fix (planned):** Move the var extraction inside the loaded branch.
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-05
- **Discovered:** 2026-05-08

---

### B-064 — `app.dart` had unused `shared_preferences` import

- **Severity:** NIT
- **Where:** `performancebench-mobile/lib/app.dart:4` (pre-fix)
- **User-visible symptom:** None.
- **Root cause:** Direct `SharedPreferences` access used to live in `_loadApiService`; later refactored to delegate to `ApiService.fromPreferences()`, but the import wasn't pruned.
- **Fix:** Dropped the import in the same edit that fixed B-051 / B-052.
- **Status:** FIXED:0fe69f5
- **Related:** —
- **Found in:** S-05
- **Discovered:** 2026-05-08

---

### B-065 — `INTERNET` permission missing from main `AndroidManifest.xml`

- **Severity:** HIGH
- **Where:** `performancebench-mobile/android/app/src/main/AndroidManifest.xml` (pre-fix)
- **User-visible symptom:** Release / profile APK launches but every API call fails with `SocketException: failed host lookup` or "Failed to connect" toast. The companion app is unusable when distributed via the Release artifact (`performancebench-mobile-*.apk` from `release.yml`). Debug builds work because `app/src/debug/AndroidManifest.xml` declares `INTERNET` separately.
- **Root cause:** `INTERNET` was added to the debug + profile manifests during scaffolding, but the main manifest never got it. AGP merges per-build-type manifests — so release builds inherit only the main manifest plus the (empty) release-specific tweaks.
- **Fix:** Added `<uses-permission android:name="android.permission.INTERNET"/>` to the main manifest with a comment explaining why the debug-only declaration isn't enough.
- **Status:** FIXED:d71ab23
- **Related:** B-067, B-053
- **Found in:** S-06
- **Discovered:** 2026-05-08

---

### B-066 — App label is the raw module name

- **Severity:** MED
- **Where:** `performancebench-mobile/android/app/src/main/AndroidManifest.xml:3` (pre-fix)
- **User-visible symptom:** Launcher icon labelled `performancebench_mobile`. Looks unfinished and doesn't match the in-app branding (`MaterialApp.title = 'Benchify Mobile'`).
- **Root cause:** Flutter project scaffolder's default; never replaced.
- **Fix:** Bumped to `"Benchify Mobile"` to align with the in-app title.
- **Status:** FIXED:d71ab23
- **Related:** —
- **Found in:** S-06
- **Discovered:** 2026-05-08

---

### B-067 — No `usesCleartextTraffic` config

- **Severity:** MED
- **Where:** `performancebench-mobile/android/app/src/main/AndroidManifest.xml`
- **User-visible symptom:** A user pointing the app at a `http://192.168.…` server (B-058) succeeds at the network layer but Android 9+ blocks the cleartext connection by default. Confusing failure mode: connect succeeds in DNS but the actual request silently fails.
- **Root cause:** No `android:usesCleartextTraffic` or `networkSecurityConfig` set; default = false on `targetSdk >= 28`.
- **Fix (planned):** Either explicitly set `usesCleartextTraffic="false"` and reject HTTP in the connect dialog (B-058) or expose a per-host LAN exception via `networkSecurityConfig`. Decide alongside B-058 in S-20.
- **Status:** DEFERRED-TO-S20
- **Related:** B-058, B-053
- **Found in:** S-06
- **Discovered:** 2026-05-08

---

### B-068 — No backup / data extraction rules

- **Severity:** LOW
- **Where:** `performancebench-mobile/android/app/src/main/AndroidManifest.xml`
- **User-visible symptom:** None directly. Risk: API token persisted via `SharedPreferences` (B-054) is auto-backed-up to Google Drive on Android 6+, becoming a credential exfiltration vector if the user's Google account is compromised.
- **Root cause:** Android Auto Backup is on by default for `targetSdk >= 23`. No `android:fullBackupContent` / `android:dataExtractionRules` exclusion declared.
- **Fix (planned):** Bundle with B-054 — opt the prefs file out of cloud backup once tokens are moved to `flutter_secure_storage`.
- **Status:** DEFERRED-TO-S20
- **Related:** B-054
- **Found in:** S-06
- **Discovered:** 2026-05-08

---

### B-069 — Release `signingConfig` falls back to debug keys

- **Severity:** LOW
- **Where:** `performancebench-mobile/android/app/build.gradle.kts:33-39`
- **User-visible symptom:** Each CI release generates an ephemeral debug key. Users who installed an earlier build must uninstall before installing a new release (Android refuses signature mismatches on update). The `release.yml` notes already warn about this.
- **Root cause:** Scaffold default; no upload-key generation / signing configuration wired into Gradle.
- **Fix (planned):** Provision a stable upload key (likely via GitHub Secrets), inject keystore + alias + passwords through env vars, and switch `signingConfig` accordingly. Pinned to S-19 (build/CI) where the release.yml lives.
- **Status:** DEFERRED-TO-S19
- **Related:** —
- **Found in:** S-06
- **Discovered:** 2026-05-08

---

### B-070 — Launch theme flashes white before Flutter renders

- **Severity:** NIT
- **Where:** `performancebench-mobile/android/app/src/main/res/values/styles.xml`, `drawable/launch_background.xml` (pre-fix)
- **User-visible symptom:** Launching the app on Android < API 21 (or in light mode on newer devices) shows a brief white flash before the dark Flutter UI takes over. The `values-night/styles.xml` already used `Theme.Black.NoTitleBar`, but the day variant hadn't been aligned.
- **Root cause:** Flutter project scaffolder defaults `LaunchTheme` to `Theme.Light.NoTitleBar` + `@android:color/white` background. The companion app currently ships dark-only.
- **Fix:** Re-parented `LaunchTheme` and `NormalTheme` to `Theme.Black.NoTitleBar`; swapped the day drawable's `@android:color/white` to `?android:colorBackground` to match the v21+ drawable's pattern.
- **Status:** FIXED:d71ab23
- **Related:** —
- **Found in:** S-06
- **Discovered:** 2026-05-08

---

### B-071 — `CFBundleDisplayName` mis-cased "Performancebench Mobile"

- **Severity:** MED
- **Where:** `performancebench-mobile/ios/Runner/Info.plist:9-10` (pre-fix)
- **User-visible symptom:** iOS home-screen label reads "Performancebench Mobile" — wrong branding. Doesn't match the Android `android:label="Benchify Mobile"` (post-B-066) or the in-app `MaterialApp.title="Benchify Mobile"`.
- **Root cause:** Flutter scaffolder default; never updated when the project was rebranded.
- **Fix:** `CFBundleDisplayName` → `"Benchify Mobile"`.
- **Status:** FIXED:1d86ba1
- **Related:** B-066, B-072
- **Found in:** S-07
- **Discovered:** 2026-05-08

---

### B-072 — `CFBundleName` is raw module name `performancebench_mobile`

- **Severity:** MED
- **Where:** `performancebench-mobile/ios/Runner/Info.plist:17-18` (pre-fix)
- **User-visible symptom:** Some system UIs (Settings → General → iPhone Storage, App Switcher in some cases) fall back to `CFBundleName` when `CFBundleDisplayName` isn't surfaced. User saw `performancebench_mobile` snake-case there.
- **Root cause:** Same scaffolder leak as B-071.
- **Fix:** `CFBundleName` → `"Benchify Mobile"`.
- **Status:** FIXED:1d86ba1
- **Related:** B-071, B-066
- **Found in:** S-07
- **Discovered:** 2026-05-08

---

### B-073 — No `NSAppTransportSecurity` config

- **Severity:** MED
- **Where:** `performancebench-mobile/ios/Runner/Info.plist`
- **User-visible symptom:** A user pointing the app at a `http://192.168.…` self-hosted server silently fails — iOS 14+ blocks cleartext by default. Same flavour as Android B-067 + B-058.
- **Root cause:** No `NSAppTransportSecurity` block declared. iOS default = HTTPS only; cleartext exceptions must be opted in via `NSAllowsArbitraryLoads` or `NSExceptionDomains`.
- **Fix (planned):** Decide alongside B-067 / B-058 / B-054 in S-20 — either explicitly forbid HTTP in the connect dialog (clean) or expose a per-host LAN exception via `NSExceptionDomains` (more permissive but riskier).
- **Status:** DEFERRED-TO-S20
- **Related:** B-058, B-067, B-054
- **Found in:** S-07
- **Discovered:** 2026-05-08

---

### B-074 — `RunnerTests.swift` is empty Xcode stub

- **Severity:** NIT
- **Where:** `performancebench-mobile/ios/RunnerTests/RunnerTests.swift`
- **User-visible symptom:** None. Dev-side: native iOS test target exists but has zero tests, signalling the iOS side has no smoke coverage even when the Dart side does.
- **Root cause:** Default Xcode template; never replaced.
- **Fix (planned):** Either add a basic launch / engine-init smoke test, or delete the test target entirely. Decide alongside the rest of the testing-coverage gap in S-20.
- **Status:** DEFERRED-TO-S20
- **Related:** —
- **Found in:** S-07
- **Discovered:** 2026-05-08

---

### B-075 — Android launcher icons are the default Flutter logo

- **Severity:** MED
- **Where:** `performancebench-mobile/android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`
- **User-visible symptom:** User installs the APK and gets the generic blue Flutter "F" on the home screen. Indistinguishable from any other Flutter dev project; reduces trust ("did I download the right APK?").
- **Root cause:** Flutter scaffolder default; never replaced. All five mipmap densities still ship the canonical Flutter logo.
- **Fix (planned):** Generate a real brand mark (SVG → PNG at 48/72/96/144/192 px). Couples to B-076 (iOS) — same source asset.
- **Status:** DEFERRED-TO-S20
- **Related:** B-076
- **Found in:** S-08
- **Discovered:** 2026-05-08

---

### B-076 — iOS app icons are the default Flutter logo

- **Severity:** MED
- **Where:** `performancebench-mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png` (16 sizes)
- **User-visible symptom:** Same as B-075 but on iOS — sideloaded app shows the default Flutter logo on the home screen.
- **Root cause:** Flutter scaffolder default. The 1024×1024 master is also default; all derivative sizes follow.
- **Fix (planned):** Same source asset as B-075; render through Xcode's Assets catalog or `flutter_launcher_icons`.
- **Status:** DEFERRED-TO-S20
- **Related:** B-075
- **Found in:** S-08
- **Discovered:** 2026-05-08

---

### B-077 — `pubspec.yaml` description was scaffolder default

- **Severity:** MED
- **Where:** `performancebench-mobile/pubspec.yaml:2` (pre-fix)
- **User-visible symptom:** Description string `"A new Flutter project."` would appear on any future App Store / Play Store listing and in `flutter pub` metadata.
- **Root cause:** Flutter scaffolder default; never updated when the project was rebranded.
- **Fix:** One-sentence description naming the project ("Benchify Mobile — companion viewer for Benchify performance profiling sessions...") + clarifying that profiling happens on the desktop side.
- **Status:** FIXED:<pending-S08>
- **Related:** —
- **Found in:** S-08
- **Discovered:** 2026-05-08

---

### B-078 — `pubspec.yaml` package name `performancebench_mobile`

- **Severity:** MED
- **Where:** `performancebench-mobile/pubspec.yaml:1`
- **User-visible symptom:** None directly; the snake-cased package name leaks into Dart import paths, the Android `applicationId`, the iOS `CFBundleIdentifier`, etc. — already mostly hidden by display-name overrides (B-066 / B-071) but inconsistent across the stack.
- **Root cause:** Module identifier from `flutter create`. Renaming cascades.
- **Fix (planned):** Coordinated rename: `pubspec.yaml` `name:`, Android `namespace` + `applicationId` in `app/build.gradle.kts`, iOS bundle identifier in `project.pbxproj`. Bundle into S-20 with the rest of the rebrand cleanup.
- **Status:** DEFERRED-TO-S20
- **Related:** B-066, B-071, B-072
- **Found in:** S-08
- **Discovered:** 2026-05-08

---

### B-079 — `pubspec.yaml` version drift from desktop release line

- **Severity:** LOW
- **Where:** `performancebench-mobile/pubspec.yaml:19` (pre-fix)
- **User-visible symptom:** Embedded version metadata (Android `versionName`, iOS `CFBundleShortVersionString`) was `0.1.0`, while the published APK filename was `performancebench-mobile-0.1.1-rc.6.apk`. Bug reporters quoting the in-app build version contradicted the filename they downloaded.
- **Root cause:** Mobile pubspec wasn't bumped in lockstep with the desktop pubspec / `release.yml` tag.
- **Fix:** Bumped `0.1.0+1` → `0.1.1+2`. Build-number incremented to keep Android's `versionCode` strictly increasing (Play Store requirement, applies even to sideloaded APKs that may later be uploaded).
- **Status:** FIXED:<pending-S08>
- **Related:** B-024, B-044
- **Found in:** S-08
- **Discovered:** 2026-05-08

---

### B-080 — `README.md` was the Flutter scaffolder default

- **Severity:** LOW
- **Where:** `performancebench-mobile/README.md` (pre-fix)
- **User-visible symptom:** Anyone landing on the mobile sub-project from GitHub saw "# performancebench_mobile / A new Flutter project" with three Flutter learning links and nothing else. No install instructions, no link back to the parent project.
- **Root cause:** `flutter create` README, never replaced.
- **Fix:** Wrote a proper README — install matrix per platform, first-run walkthrough, build-from-source commands, link back to parent Releases page, call-outs for known UX gaps (B-054, B-069, B-083) so contributors landing here see the open work.
- **Status:** FIXED:<pending-S08>
- **Related:** —
- **Found in:** S-08
- **Discovered:** 2026-05-08

---

### B-081 — First-run UX: server URL field has no guidance

- **Severity:** MED
- **Where:** `performancebench-mobile/lib/screens/settings/server_settings_screen.dart:97-101`
- **User-visible symptom:** User installs the app, opens it, lands on Connect — sees an empty `Server URL` field with placeholder `https://192.168.1.100:3000` and no idea what URL to actually type. Bug reports likely to look like "Connect button doesn't work" when really the user has no idea what their desktop is exposing.
- **Root cause:** Skeleton UX — no help link, no "How do I find this?" affordance, no tooltip or expandable hint.
- **Fix (planned):** Add an info button next to the field that pops a sheet explaining how to find the desktop's API URL (Settings → Server section on desktop). Couples to B-082 (mDNS) and B-083 (token).
- **Status:** DEFERRED-TO-S20
- **Related:** B-082, B-083
- **Found in:** S-08
- **Discovered:** 2026-05-08

---

### B-082 — No mDNS / Bonjour discovery for the desktop server

- **Severity:** LOW
- **Where:** `performancebench-mobile/lib/screens/settings/server_settings_screen.dart`
- **User-visible symptom:** User has to manually type the desktop's LAN IP. On most home networks the IP changes when the desktop reconnects, so the saved URL silently breaks.
- **Root cause:** Manual config only. The desktop server doesn't advertise via mDNS, and the mobile app doesn't browse for `_benchify._tcp.local.` peers.
- **Fix (planned):** Add `multicast_dns` to the mobile pubspec; advertise via the desktop's `multicast_dns` package or platform mDNS; show a "Discovered servers" list above the manual URL field.
- **Status:** DEFERRED-TO-S20
- **Related:** B-081
- **Found in:** S-08
- **Discovered:** 2026-05-08

---

### B-083 — No token-generation flow surfaced to the user

- **Severity:** LOW
- **Where:** Cross-cuts mobile `server_settings_screen.dart` + desktop server settings.
- **User-visible symptom:** Even after the URL field is solved, users have no clear path to obtain an API token. Best-case: they manually open `~/.config/benchify/server.json` (or wherever) and copy the token. Many will give up.
- **Root cause:** No "Generate token" button on the desktop server screen, no QR code that the mobile app can scan.
- **Fix (planned):** Two-pronged in S-20:
  1. Desktop server settings (S-04 follow-up): expose a "Pair mobile" button that generates a fresh token + QR.
  2. Mobile connect screen (this slice): add a QR scanner camera path next to the manual fields.
- **Status:** DEFERRED-TO-S20
- **Related:** B-081, B-082
- **Found in:** S-08
- **Discovered:** 2026-05-08
