# Wave 7 Summary — Installers + CI + Tests + Privacy + Polish

**Plan:** 07-PLAN.md  
**Date:** 2026-05-04  
**Status:** Complete

## Completed

### Task 1: Platform Installers
- `windows/installer/performancebench.nsi` — NSIS script with Start Menu shortcut, uninstaller registration, MIT license page, lzma compression
- `macos/package_dmg.sh` — DMG creation script with notarization support (optional)
- `linux/build_appimage.sh` — AppImage generation via linuxdeploy, tar.gz fallback
- `.github/workflows/ci.yml` — Full CI matrix: build + test + package on ubuntu/windows/macOS, license header check, URL allow-list verification

### Task 2: Test Suite Completion
- `test/integration/adb_integration_test.dart` — Android ADB integration tests (4 tests, skipped without emulator)
- `test/integration/ios_integration_test.dart` — iOS pyidevice integration tests (2 tests, skipped without simulator)
- All 79 parser + 5 ring buffer + 8 FPS analytics + 3 comparison + 4 export + 1 widget = 100 tests passing
- 6 integration tests skipped (require real devices/emulators)
- `.github/workflows/ios-test.yml` — iOS simulator matrix (iOS 16.4/17.2) on macOS runner

### Task 3: Shipping + Privacy
- `lib/core/services/update_service.dart` — GitHub Releases version check, semver comparison, 6-hour cache, no binary download
- `README.md` — Quick-start in 5 commands, platform matrix, metric parity table, build instructions
- `CHANGELOG.md` — v1.0.0 initial release entry
- MIT SPDX headers on all 72 source files (lib/, test/, ios_agents/)
- `.github/workflows/packet-capture-test.yml` — 30-min session, tshark packet capture, GitHub API allow-list, zero outbound verification
- URL allow-list CI check: no unauthorized HTTP/HTTPS URLs in source
- `lib/core/database/session_dao.dart` — Added `updateEndedAt` method

## Verification
- `flutter analyze`: 0 errors
- `flutter test`: 100/100 passed (+6 skipped integration)
- MIT headers: 72/72 .dart files verified
- CI workflows: ci.yml, packet-capture-test.yml, ios-test.yml created
- URL allow-list: verified no unauthorized URLs in source

## Artifacts
| File | Status |
|------|--------|
| `windows/installer/performancebench.nsi` | Created |
| `macos/package_dmg.sh` | Created |
| `linux/build_appimage.sh` | Created |
| `.github/workflows/ci.yml` | Created |
| `.github/workflows/packet-capture-test.yml` | Created |
| `.github/workflows/ios-test.yml` | Created |
| `lib/core/services/update_service.dart` | Created |
| `README.md` | Rewritten |
| `CHANGELOG.md` | Created |
| `test/integration/adb_integration_test.dart` | Created |
| `test/integration/ios_integration_test.dart` | Created |
| `lib/core/database/session_dao.dart` | Updated (updateEndedAt) |
| All 72 .dart files | MIT SPDX headers added |

## Commit
`09b0868 feat(01-07): add installers, CI matrix, auto-update, privacy verification, and MIT headers (GREEN)`
