---
phase: 05-v3-0-game-engine-plugins-ios-injection-tvos-pc
plan: 02
subsystem: injection-ios-tvos
tags: [ios-injection, tvos, ipa, dylib, pyidevice, apple-signing, flutter]
requires: []
provides: [ipa-injection-engine, tvos-collector]
affects: [performancebench-injector, performancebench, ios_agents]
tech-stack:
  added: [apple-signing-methods, mach-o-parsing, tvos-metrics, pyidevice-dtxprotocol]
  patterns: [tdd-red-green, subprocess-bridge, platform-metric-masking, keychain-credentials]
key-files:
  created:
    - performancebench-injector/injector/ipa_injector.py
    - performancebench-injector/injector/apple_signing.py
    - performancebench-injector/injector/ipa_verifier.py
    - performancebench-injector/tests/test_ipa_injector.py
    - performancebench-injector/tests/test_apple_signing.py
    - performancebench-injector/tests/test_ipa_verifier.py
    - performancebench/lib/core/models/ipa_signing_config.dart
    - performancebench/lib/core/services/ipa_injection_service.dart
    - performancebench/lib/features/injection/ipa_injection_screen.dart
    - performancebench/lib/features/injection/ipa_signing_config.dart
    - performancebench/lib/features/injection/ipa_verification_progress.dart
    - ios_agents/tvos_collector.py
    - ios_agents/tests/test_tvos_collector.py
  modified:
    - performancebench-injector/injector_cli.py
    - performancebench/lib/core/services/ios_service.dart
    - performancebench/lib/features/device_list/device_card.dart
    - performancebench/lib/features/active_session/charts_tab.dart
decisions:
  - "Python IPA injection: zip-based extraction, macholib/otool for cryptid, install_name_tool for load commands"
  - "Apple signing: 3-method auto-detect (free/paid/cert) via xcrun altool + security find-identity"
  - "Flutter iOS tab: reuses Phase 4 injection screen TabBar pattern with drag-drop IPA + signing config"
  - "tvOS collector: separate script from iOS, shares DTXProtocol channels but masks battery/cellular"
  - "Metric masking: nullable fields pattern — battery/cellular fields always None for tvOS, UI hides charts"
metrics:
  duration: TBD
  completed_date: 2026-05-06
---

# Phase 5 Plan 2: iOS IPA Injection + tvOS pyidevice — Summary

**One-liner:** iOS IPA dylib injection with auto-detect 3 signing methods (free Apple ID / paid developer / user certificate), Flutter desktop injection UI with drag-drop and verification stepper, and tvOS pyidevice metric collector with battery/cellular masking.

## Tasks Executed

### Task 1: iOS IPA injection engine + Flutter desktop UI

**RED (test):** f124ab9
- 51 tests across 3 test files: ipa_injector (13), apple_signing (19), ipa_verifier (19)
- Tests cover FairPlay encryption detection, IPA extract/repack, Info.plist patching, framework embedding, signing method detection, credential storage, verification pipeline

**GREEN (Python):** 29fccb6
- `ipa_injector.py` (221 lines): Full 8-step injection pipeline — extract IPA, FairPlay cryptid check via otool, embed PerformanceBench.framework, patch Info.plist (MinimumOSVersion >= 14.0, UIDeviceFamily includes 1), insert LC_LOAD_DYLIB via install_name_tool, re-sign via apple_signing, verify via ipa_verifier, repack as zip
- `apple_signing.py` (254 lines): Auto-detect 3 signing methods — xcrun altool (free), ~/Library/MobileDevice/Provisioning Profiles (paid), security find-identity (cert). Keychain credential storage with app-specific password enforcement (format validation). Minimal entitlements.plist with get-task-allow=true
- `ipa_verifier.py` (187 lines): 5-step verification — IPA structure (zip + Payload/.app), framework presence (Frameworks/PerformanceBench.framework/PerformanceBench), load command check (otool -L), code signature (codesign -dv + --verify --deep --strict)

**GREEN (Flutter):** f1c4d70
- `ipa_signing_config.dart` (model): SigningMethod enum, IpaSigningConfig, IpaMetadata, IpaInjectionResult
- `ipa_injection_service.dart` (service): Flutter-to-Python subprocess bridge — injectIpa, verifyIpa, detectSigningMethods, getIpaMetadata. Follows Process.start() pattern identical to InjectionService
- `ipa_injection_screen.dart` (UI): Drag-drop IPA zone, metadata card (app name, bundle ID, version, encryption status), signing method auto-detect with radio buttons, credential fields per method, 7-day expiry warning, inject button, verification stepper
- `ipa_signing_config.dart` (widget): Method radio buttons, Apple ID + app-specific password fields (masked), Team ID, provisioning profile picker, certificate identity, Keychain remember toggle
- `ipa_verification_progress.dart` (widget): 9-step stepper matching Phase 4 Android pattern — Unpacking IPA, Checking encryption, Injecting SDK, Patching Info.plist, Inserting load command, Signing, Repacking IPA, Verifying signature, Done

**CLI updates:** Added `ipa-inject`, `ipa-verify`, `signing-detect`, `ipa-metadata` commands to `injector_cli.py`

### Task 2: tvOS pyidevice support

**RED (test):** 4393194
- 17 tests: TvosDevice model (3), device discovery (4), nullable fields (3), available channels (4), metric formatting (3)

**GREEN:** 4bdd4d3
- `tvos_collector.py` (249 lines): Apple TV discovery via `pyidevice devices list --json` filtering DeviceClass:AppleTV. USB-C gen 1/2 detection with clear error. Metric collection loop at 1Hz via pyidevice DTXProtocol channels (FPS/CPU/Memory/Network/Thermal/GPU). Battery and cellular fields explicitly NULL. JSON newline-delimited stdout matching iOS collector format
- `ios_service.dart` updates: TargetKind enum (ios/tvos) with hiddenFields and powerLabel. discoverDevices detects both iOS and tvOS. _spawnCollector routes to correct Python script. shouldShowField helper for UI masking. platform field tracking from collector output
- `device_card.dart` updates: tvOS platform icon (Icons.tv), tvOS OS label detection, proper platform detection from device name
- `charts_tab.dart` updates: Conditionally hides battery charts for tvOS (mains-powered). Shows "Power: Mains" placeholder card with explanatory text ("tvOS — battery unavailable"). Optional targetKind parameter

## Verification Results

| Task | Tests | Status |
|------|-------|--------|
| Task 1 Python | 51/51 | All passing |
| Task 2 tvOS | 17/17 | All passing |
| Task 1 Flutter | dart analyze | No issues found |
| Task 2 Flutter | dart analyze | No issues found |

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| f124ab9 | test | Add failing tests for iOS IPA injection engine |
| 29fccb6 | feat | Implement iOS IPA injection engine with auto-detect signing |
| f1c4d70 | feat | Add Flutter desktop iOS IPA injection UI |
| 4393194 | test | Add failing tests for tvOS pyidevice collector |
| 4bdd4d3 | feat | Implement tvOS pyidevice collector and Flutter tvOS support |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed detect_available_methods logic for altool availability**
- **Found during:** Task 1 testing
- **Issue:** altool check returned FREE_APPLE_ID on any returncode (including auth failure), causing false positives
- **Fix:** Changed to two-step detection — xcrun --find altool first (verify tool exists), then altool --list-providers for auth check
- **Files modified:** apple_signing.py, test_apple_signing.py

**2. [Rule 1 - Bug] Fixed signing function tests requiring app bundle path discovery**
- **Found during:** Task 1 testing
- **Issue:** _find_app_bundle_in_dir calls os.path.isdir/os.listdir on unmocked paths, causing None returns
- **Fix:** Patched _find_app_bundle_in_dir directly in signing tests to return mock app bundle paths
- **Files modified:** test_apple_signing.py

**3. [Rule 1 - Bug] Fixed IPA zip structure checks for missing directory entries**
- **Found during:** Task 1 testing
- **Issue:** ZipFile.write doesn't add explicit directory entries, causing .app/ detection to fail
- **Fix:** Updated verify_ipa_structure and _find_app_bundle_in_ipa to check for files within .app bundles
- **Files modified:** ipa_verifier.py, test_ipa_verifier.py

**4. [Rule 3 - Blocking] Fixed os.listdir crash in detect_available_methods Check 2**
- **Found during:** Task 1 testing
- **Issue:** os.listdir called on non-existent ~/Library/MobileDevice/Provisioning Profiles directory without try/except
- **Fix:** Wrapped Check 2 in try/except (OSError, PermissionError)
- **Files modified:** apple_signing.py

## Threat Flags

No new threat surface beyond what was documented in the plan's threat model. All mitigations implemented:
- T-05-06: xcrun path validated via `xcrun --find` before use
- T-05-07: App-specific password enforced (format validation), Keychain storage via security add-generic-password
- T-05-08: Injected dylib is localhost-only (no network capability)
- T-05-10: Early FairPlay detection via cryptid check before any IPA modification

## TDD Gate Compliance

| Gate | Commit | Status |
|------|--------|--------|
| RED (Task 1) | f124ab9 | test(05-02): add failing tests for iOS IPA injection engine |
| GREEN (Task 1 Python) | 29fccb6 | feat(05-02): implement iOS IPA injection engine with auto-detect signing |
| GREEN (Task 1 Flutter) | f1c4d70 | feat(05-02): add Flutter desktop iOS IPA injection UI |
| RED (Task 2) | 4393194 | test(05-02): add failing tests for tvOS pyidevice collector |
| GREEN (Task 2) | 4bdd4d3 | feat(05-02): implement tvOS pyidevice collector and Flutter tvOS support |

All TDD gates present and in correct sequence order.
