# Slice 02 — Flutter desktop: services

**Status**: complete
**Branch**: `audit/v0.1.x`
**Discovered**: 2026-05-08

## Scope

`performancebench/lib/core/services/` — 21 files, ~6,290 LOC total. Too large for one true 5% pass; this slice prioritises files on the **golden user flow** (device discovery → app pick → session start → injection → recording → screenshot). Remaining services scanned with `grep` for red-flag patterns (`TODO`, `FIXME`, `placeholder`, `unawaited`, `catch (_)`) and rolled into S-20 final regression.

| File                                | LOC | Depth        |
|-------------------------------------|----:|--------------|
| adb_service.dart                    | 837 | full read    |
| injection_service.dart              | 345 | full read    |
| ipa_injection_service.dart          | 323 | full read    |
| screenrecord_service.dart           | 439 | full read    |
| ios_screenrecord_service.dart       | 361 | full read    |
| screenshot_service.dart             | 291 | full read    |
| error_handler.dart                  |  84 | full read    |
| update_service.dart                 |  94 | full read    |
| plugin_install_service.dart         | 359 | full read    |
| metric_collector.dart               | 504 | head + skim  |
| pcprobe_service.dart                | 362 | head + skim  |
| (others, 11 files, 2,291 LOC)       |   — | grep-scan    |

The 11 files only grep-scanned: `api_service`, `sdk_stream_service`, `automation_service`, `export_service`, `upload_service`, `alert_service`, `session_service`, `live_service`, `ios_service`, `mac_proxy_service`, `tidevice_service`. None showed obvious BLOCKER patterns; deeper review queued for S-20.

## User-flow trace

> *User picks device → picks app → starts session → records → injects APK*.

1. App boot → `AdbService.create()` resolves `adb` on PATH (`adb_service.dart:148`).
2. `discoverDevices()` parses `adb devices -l` (line 265).
3. User picks a row → `collectStaticData()` runs ~5 sequential ADB calls (line 416).
4. `MetricCollector.start()` boots 1 Hz timer, batch-writes every 5 s (`metric_collector.dart:78`).
5. User clicks Record → `ScreenrecordService.start()` spawns `screenrecord` per chunk (`screenrecord_service.dart:78`); `pkill -f screenrecord` on stop.
6. User clicks Inject → `InjectionService.inject()` spawns `injector_cli.py` (line 163).

## Findings

| ID    | Sev      | Title                                                                                        | Status                |
|-------|----------|----------------------------------------------------------------------------------------------|-----------------------|
| B-008 | HIGH     | Battery capacity reads `/sys/.../capacity` (current %) as mAh — wrong column                 | FIXED in this slice   |
| B-009 | MED      | Logcat `-d` then `-c` race drops events between dump and clear                               | DEFERRED-TO-S20       |
| B-010 | MED      | `pullFile` accepts `/sdcard/../etc/passwd` — startsWith() prefix only                        | DEFERRED-TO-S20       |
| B-011 | MED      | `collectStaticData` runs ~5 ADB calls sequentially (≤15 s blocking UI)                       | DEFERRED-TO-S20       |
| B-012 | MED      | `startLogcatMonitor` leaks StreamController on cancel                                        | DEFERRED-TO-S20       |
| B-013 | MED      | Recording duration & gaps assume each chunk = exactly 300000 ms                              | FIXED in this slice (Android + iOS) |
| B-014 | HIGH     | `startPcRecording` is a stub — sets state, returns true, never recorded                      | DEFERRED-TO-S15       |
| B-015 | HIGH     | `stopPcRecording` writes empty Video record (`filepath:''`, `durationMs:0`)                  | DEFERRED-TO-S15       |
| B-016 | BLOCKER  | `ScreenshotService._downscale` returns dark-grey placeholder; `_encodeJpegBasic` returns 1×1 black JPEG — feature is fake | DEFERRED-TO-S04 (gate UI) + S-20 (real impl) |
| B-017 | MED      | `AdbServiceRaw.runShellCommandRaw` hardcodes `'adb'`; ignores `command` arg                  | DEFERRED-TO-S20 (couples with B-016) |
| B-018 | MED      | `InjectionService` adds to controller after close (exitCode race)                            | FIXED in this slice   |
| B-019 | MED      | `InjectionService.stop()` nulls `_process` then later `kill` on null                         | FIXED in this slice   |
| B-020 | MED      | `pythonPath` defaults `'python3'` — Windows ships `python.exe`; whole injector flow broken on Win | FIXED in this slice |
| B-021 | MED      | No 5-min subprocess timeout; doc comment T-04-05 promises it, no code wires it               | DEFERRED-TO-S20       |
| B-022 | MED      | `IpaInjectionService` shares B-018, B-019, B-021                                             | PARTIAL FIX (B-018, B-019 fixed; timeout deferred) |
| B-023 | MED      | `ErrorHandler.setDebugMode()` never called from `debugModeProvider`                          | FIXED in this slice   |
| B-024 | HIGH     | `UpdateService._currentVersion = '1.0.0'` hardcoded; releases are `0.1.x` → "no update" forever | FIXED in this slice |
| B-025 | MED      | `_compareVersions` `int.tryParse('1-rc')` → null → 0; pre-release suffixes break compare     | FIXED in this slice   |
| B-026 | MED      | Plugin install backup `.bak` overwrites prior backup                                         | DEFERRED-TO-S13       |
| B-027 | MED      | `PluginInstallService._pluginSourceDir = 'plugins'` is cwd-relative                          | DEFERRED-TO-S13       |
| B-028 | LOW      | `_resolveChipsetVendor` matches `hi`, `mt`, `sc` too broadly — false positives               | DEFERRED-TO-S20       |
| B-029 | LOW      | `collectAppData` minSdk regex gated by unrelated compileSdkVersionCodename check             | FIXED in this slice   |
| B-030 | LOW      | `MetricCollector.statusStream` getter throws if accessed before `start()`                    | DEFERRED-TO-S20       |
| B-031 | LOW      | `_pid` discovered once; if target process restarts, metrics follow stale PID                 | DEFERRED-TO-S20       |
| B-032 | NIT      | `MetricCollector._consecutiveFailures` declared, never used                                  | DEFERRED-TO-S20       |
| B-033 | NIT      | `PcProbeConnection._toSnakeCase` is a no-op despite the name                                 | DEFERRED-TO-S20       |

## Cross-slice notes

- **B-016 (BLOCKER)**: screenshot capture currently saves identical 1×1 black JPEGs. End user sees the feature exist in UI; output is junk. Two-step fix:
  1. **S-04 (UI)**: hide / disable the screenshot toggle until real implementation lands. Prevents data corruption in DB.
  2. **S-20 (or new slice)**: add `image: ^4.x` to pubspec, implement real PNG decode + JPEG encode.
- **B-014 / B-015 (PC video)**: requires probe protocol design. Defer to S-15 (pcprobe metrics) so probe + desktop client land together.
- **B-026 / B-027 (plugin install)**: defer to S-13 (engine plugins) so plugin install + plugin internals land together.
- **B-009 / B-010 / B-011 / B-012 / B-021 / B-028 / B-030 / B-031**: low-touch hardening — bundle in S-20 final pass.

## Local fixes summary

1. **B-008**: switched to `/sys/class/power_supply/battery/charge_full_design` (µAh) → mAh; added `voltage_now`/`current_now` style guard. Sysfs `capacity` is current % and never matches design capacity.
2. **B-013**: chunk duration uses actual end-time minus start-time when available; gap calc reuses real `prevChunkEndMs`. Same fix mirrored for iOS path.
3. **B-018**: `_controller?.add` calls now wrapped in `if (!(_controller?.isClosed ?? true))`. Prevents `Bad state: Cannot add new events after calling close`.
4. **B-019**: capture local `process` ref before scheduling delayed `sigkill`; null original `_process` only after the delayed kill resolves.
5. **B-020**: added `_resolvePython()` helper that tries `python3` then `python` (Windows fallback). Default constructor uses it via `static`.
6. **B-023**: `main.dart` calls `ErrorHandler().setDebugMode(debugMode)` right after the `--debug` parse so the first error log obeys the flag.
7. **B-024**: added `package_info_plus` lookup; `_currentVersion` set from `PackageInfo.version` at first call. `_repoUrl` unchanged.
8. **B-025**: `_compareVersions` strips a trailing `-…` pre-release tag before parsing each segment. `0.1.1-rc.6` and `0.1.1` now compare as equal release; `0.1.2-rc.1` > `0.1.1`. Strict semver suffix ordering deferred — sufficient for "is there a newer release out".
9. **B-029**: dropped the irrelevant `compileSdkVersionCodename` gate; `minSdkVersion=NN` now matches independently.

## Verification

`flutter analyze lib/core/services/` — to be run with the fix commit. Findings ledger updated with the resulting commit sha.
