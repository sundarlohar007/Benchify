---
phase: 04-v2-5-android-sdk-injection
plan: 01
subsystem: performancebench-injector
tags: [python, apk-injection, apktool, smali, flutter, desktop-injection-ui]
requires: []
provides: [v25-01-injector-repo, v25-02-smali-patching, v25-04-resigning]
affects: [performancebench-injector, performancebench-desktop]
tech-stack:
  added: [python-3.10+, click, lxml, shared_preferences]
  patterns: [subprocess-wrapper, smali-bytecode-patch, xml-manifest-patch, tdd-red-green, desktop-injection-wizard]
key-files:
  created:
    - performancebench-injector/injector_cli.py
    - performancebench-injector/injector/smali_patcher.py
    - performancebench-injector/injector/manifest_patcher.py
    - performancebench-injector/injector/apk_decompiler.py
    - performancebench-injector/injector/aab_converter.py
    - performancebench-injector/injector/proguard_helper.py
    - performancebench-injector/injector/resigner.py
    - performancebench-injector/injector/verifier.py
    - performancebench-injector/tests/conftest.py
    - performancebench-injector/tests/test_smali_patcher.py
    - performancebench-injector/tests/test_manifest_patcher.py
    - performancebench-injector/tests/test_apk_decompiler.py
    - performancebench-injector/tests/test_aab_converter.py
    - performancebench-injector/tests/test_resigner.py
    - performancebench-injector/tests/test_verifier.py
    - performancebench-injector/requirements.txt
    - performancebench-injector/README.md
    - performancebench/lib/core/models/keystore_config.dart
    - performancebench/lib/core/services/injection_service.dart
    - performancebench/lib/features/injection/injection_screen.dart
    - performancebench/lib/features/injection/injection_method_card.dart
    - performancebench/lib/features/injection/keystore_config.dart
    - performancebench/lib/features/injection/verification_progress.dart
    - performancebench/test/features/injection/injection_screen_test.dart
    - performancebench/test/features/injection/injection_service_test.dart
    - performancebench/test/features/injection/keystore_config_test.dart
  modified:
    - performancebench/pubspec.yaml
    - performancebench/lib/app.dart
decisions:
  - "Smali injection at Application.onCreate() via in-place bytecode patch (not ContentProvider per D-04)"
  - "5 permissions added: SYSTEM_ALERT_WINDOW, INTERNET, FOREGROUND_SERVICE, FOREGROUND_SERVICE_SPECIAL_USE, POST_NOTIFICATIONS"
  - "SDK classes use dev.benchify namespace (not net.performancebench.sdk)"
  - "Verification uses port 8080 (not 27182 from spec §18)"
  - "Frida method card rendered but disabled until Plan 04-03"
metrics:
  duration: "~45 minutes"
  completed_date: "2026-05-06"
---

# Phase 4 Plan 1: Python APK Injection Toolchain + Flutter Desktop Injection UI Summary

**One-liner:** Python toolchain with apktool/Smali patching, manifest modification, re-signing, and 3-step verification, wrapped by a Flutter desktop drag-drop injection wizard.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Create injector monorepo + Python APK injection engine | 5619bf1 | injector_cli.py, smali_patcher.py, manifest_patcher.py, apk_decompiler.py, aab_converter.py, proguard_helper.py, resigner.py (stub), verifier.py (stub), 17 files total |
| 2 | Implement APK re-signing engine + Flutter desktop injection UI | dd09022 | resigner.py (full), verifier.py (full), injection_screen.dart, injection_service.dart, keystore_config.dart (model + widget), verification_progress.dart, injection_method_card.dart, 13 files total |

## Test Results

- **Python:** 43 tests passing (smali patcher: 13, manifest patcher: 10, apk decompiler: 7, aab converter: 3, resigner: 3, verifier: 7)
- **Flutter/Dart:** 16 tests passing (injection screen: 7, injection service: 5, keystore config: 4)
- **Dart analyzer:** 0 issues
- **Total:** 59 tests, 0 failures, 0 errors

## TDD Gate Compliance

| Gate | Task 1 | Task 2 |
|------|--------|--------|
| RED commit (failing tests) | Implicit — created tests first, confirmed imports failed before implementation | Tests created first, modules already stubbed from Task 1 |
| GREEN commit (passing tests) | 5619bf1 — 33/33 Python tests passing | dd09022 — 59/59 total tests passing |
| REFACTOR commit | None needed — implementation clean on first pass | None needed — used existing theme patterns correctly |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed import error in test_smali_patcher.py**
- **Found during:** Task 1
- **Issue:** Test imported `resolve_obfuscated_application` from `smali_patcher.py` but it lives in `proguard_helper.py`
- **Fix:** Split import to source from correct module
- **Files modified:** tests/test_smali_patcher.py
- **Commit:** 5619bf1

**2. [Rule 1 - Bug] Fixed missing APK files in mock tests**
- **Found during:** Task 1
- **Issue:** DecompileApk tests referenced APK paths but didn't create actual files for `validate_apk()` to pass
- **Fix:** Added `_create_fake_apk()` helper creating valid ZIP files with proper magic bytes; used `injector.apk_decompiler.subprocess.run` patch target instead of global `subprocess.run`
- **Files modified:** tests/test_apk_decompiler.py, tests/test_aab_converter.py
- **Commit:** 5619bf1

**3. [Rule 1 - Bug] Fixed AppColors field name mismatches across injection widgets**
- **Found during:** Task 2
- **Issue:** Widgets used `colors.bgCard`, `colors.accent`, `colors.accentGreen`, `colors.error`, `colors.warning`, `colors.border` which don't exist in the project's `AppColors` ThemeExtension
- **Fix:** Mapped to correct names: `bgElevated`, `accentBlue`, `accentSuccess`, `accentDanger`, `accentWarning`, `borderSubtle`; used `withValues(alpha: N)` instead of `withOpacity(N)`
- **Files modified:** injection_method_card.dart, keystore_config.dart, verification_progress.dart, injection_screen.dart, injection_screen_test.dart
- **Commit:** dd09022

**4. [Rule 1 - Bug] Fixed test comparing enum to string**
- **Found during:** Task 2
- **Issue:** `injection_service_test.dart` compared `result!.step` (InjectionStep enum) with string `'decompile'`
- **Fix:** Changed to `InjectionStep.decompile`
- **Files modified:** test/features/injection/injection_service_test.dart
- **Commit:** dd09022

**5. [Rule 1 - Bug] Fixed missing InjectionMethodCard import in test**
- **Found during:** Task 2
- **Issue:** Test imported `InjectionMethodCard` from `injection_screen.dart` where it's not exported
- **Fix:** Added direct import from `injection_method_card.dart`
- **Files modified:** test/features/injection/injection_screen_test.dart
- **Commit:** dd09022

**6. [Rule 2 - Missing critical functionality] Added shared_preferences dependency**
- **Found during:** Task 2
- **Issue:** Plan required `InjectionService.saveKeystorePath()` using shared_preferences, but package wasn't in pubspec.yaml
- **Fix:** Added `shared_preferences: ^2.4.0` to pubspec.yaml
- **Files modified:** performancebench/pubspec.yaml
- **Commit:** dd09022

**7. [Rule 2 - Missing critical functionality] Added ProGuard helper + idempotency guards**
- **Found during:** Task 1 implementation
- **Issue:** Plan referenced `proguard_helper.py` and required idempotent Smali/manifest patching but these weren't explicitly detailed
- **Fix:** Implemented `parse_mapping()` for ProGuard/R8 mapping.txt; added "already patched" checks in `patch_smali()` and `patch_manifest()` to prevent double-injection
- **Files modified:** proguard_helper.py, smali_patcher.py, manifest_patcher.py
- **Commit:** 5619bf1

### Auth Gates

None — no external authentication required for local toolchain.

## Known Stubs

| Stub | File | Line | Reason |
|------|------|------|--------|
| Frida gadget method card disabled | injection_screen.dart | ~205 | Frida injection not implemented until Plan 04-03 per D-02 |
| Keystore file picker delegates to `onKeystorePathChanged` | keystore_config.dart | ~115 | Actual file_picker dialog opened by parent screen's `_pickKeystore()` |
| injector_cli.py imports resigner/verifier which are fully implemented | injector_cli.py | ~25 | Both modules complete — no stubs remain |

## Threat Flags

No new threat surface beyond what's documented in the plan's threat model. All T-04 threats addressed:
- T-04-01: ZIP magic byte validation in apk_decompiler.py
- T-04-02: Keystore passwords not exposed in logs; verification module runs separately
- T-04-03: Additive-only manifest patching; idempotent smali patching
- T-04-04: apksigner verify runs before any ADB operations
- T-04-05: Subprocess timeout at 5 minutes; SIGTERM->SIGKILL pattern from IosService
- T-04-06: Password fields use obscureText; keystore path only saved when user opts in

## Architecture Notes

- **Python CLI contract:** JSON lines on stdout — `{"step": "...", "status": "...", "detail": "..."}`
- **Desktop -> CLI bridge:** `InjectionService._spawnProcess()` mirrors `IosService._spawnCollector()` pattern
- **Keystore persistence:** SharedPreferences stores path only (no passwords) per D-03
- **Injection method separation:** Smali path active now; Frida path wired in Plan 04-03 per D-25
- **Port convention:** 8080 for SDK IPC (plan-specified), distinct from spec's 27182

## Self-Check: PASSED

- [x] performancebench-injector/injector_cli.py exists
- [x] performancebench-injector/injector/smali_patcher.py contains `invoke-static {p0}, Ldev/benchify/SdkLoader;->init`
- [x] performancebench-injector/injector/resigner.py contains `apksigner sign`
- [x] performancebench/lib/features/injection/injection_screen.dart contains `DragTarget`
- [x] Commit 5619bf1 exists (Task 1)
- [x] Commit dd09022 exists (Task 2)
- [x] 43 Python tests pass
- [x] 16 Flutter tests pass
- [x] 0 dart analyze issues
