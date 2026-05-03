---
phase: "01"
plan: "07"
type: execute
wave: 7
depends_on: ["01-05", "01-06"]
files_modified:
  - .github/workflows/ci.yml
  - .github/workflows/packet-capture-test.yml
  - .github/workflows/ios-test.yml
  - README.md
  - CHANGELOG.md
  - LICENSE
  - lib/*
  - test/unit/*
  - test/integration/*
  - integration_test/*
  - windows/installer/performancebench.nsi
  - macos/package_dmg.sh
  - linux/build_appimage.sh
autonomous: true
requirements: [MVP-22, MVP-25, MVP-26, MVP-27, MVP-28, MVP-29]

must_haves:
  truths:
    - "Windows installer (NSIS) produces performancebench-setup.exe that installs to Program Files with Start Menu shortcut"
    - "macOS DMG contains performancebench.app that can be dragged to Applications"
    - "Linux AppImage runs on Ubuntu 22.04+ with double-click"
    - "CI matrix builds green on windows-latest, macos-latest, ubuntu-latest on every push"
    - "All unit tests pass with critical-path 100% branch coverage (parsers, analytics, DB) per D-09"
    - "Integration tests pass on Android emulator (CI) and iOS simulator (macOS runner) per D-10"
    - "Auto-update strategy checks GitHub Releases for new version, displays notification, links to download page — no binary download"
    - "README.md quick-start reproducible in <=5 commands by a fresh user"
    - "Packet capture test in CI verifies zero outbound connections during 30-min session per D-18/D-19/D-20"
    - "Every source file has MIT license header (SPDX-License-Identifier: MIT)"
  artifacts:
    - path: "windows/installer/performancebench.nsi"
      provides: "NSIS installer script for Windows"
    - path: "macos/package_dmg.sh"
      provides: "Shell script to create macOS DMG from .app bundle"
    - path: "linux/build_appimage.sh"
      provides: "Shell script to generate Linux AppImage"
    - path: ".github/workflows/packet-capture-test.yml"
      provides: "CI workflow that runs 30-min session and verifies zero outbound packets via tshark"
    - path: "README.md"
      provides: "Project overview, quick-start, build instructions, license info"
  key_links:
    - from: ".github/workflows/ci.yml"
      to: "windows/installer/performancebench.nsi"
      via: "makensis to build Windows installer"
      pattern: "makensis"
    - from: ".github/workflows/packet-capture-test.yml"
      to: "lib/"
      via: "runs app in profiling mode while tshark monitors network"
      pattern: "tshark"
    - from: "README.md"
      to: "pubspec.yaml"
      via: "flutter pub get command"
      pattern: "flutter pub get"
---

<objective>
Ship Phase 1: Build Windows NSIS installer, macOS DMG, Linux AppImage. Implement CI matrix builds on all 3 platforms (D-11, D-12). Full test suite (unit + integration per D-08/D-09/D-10). Auto-update strategy with version check only (D-25). Privacy verification via automated packet capture in CI (D-18/D-19/D-20). README with <=5 command quick-start. MIT license headers on all source files. This is the final ship-it wave.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@UNIFIED-SPEC.md lines 74-84 (§D Definition of Done — v1.0)
@UNIFIED-SPEC.md lines 86-95 (§E Hard Stop-Gates)
@UNIFIED-SPEC.md lines 96-108 (§F Forbidden Patterns)
@UNIFIED-SPEC.md lines 2857-2918 (§14 Testing Strategy — unit tests, integration tests, platform matrix, device matrix)
@UNIFIED-SPEC.md lines 2899-2907 (§14.3 Platform Test Matrix)
@UNIFIED-SPEC.md lines 2922-2952 (§15 Security Model)

<interfaces>
Already exist:
- Full app codebase (lib/)
- All test files (test/unit/)
- CI workflow skeleton (.github/workflows/ci.yml)
- Packet capture test skeleton (.github/workflows/packet-capture-test.yml)
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Build Windows NSIS installer + macOS DMG + Linux AppImage packages</name>
  <files>
    windows/installer/performancebench.nsi
    macos/package_dmg.sh
    linux/build_appimage.sh
    .github/workflows/ci.yml
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 2675-2774 (§12 File Structure for build artifacts)
  </read_first>
  <action>
    1. Create `windows/installer/performancebench.nsi` — NSIS installer script:
       - Product name: "PerformanceBench"
       - Publisher: "PerformanceBench Contributors"
       - Install directory: `$PROGRAMFILES64\PerformanceBench` (with user-customizable path).
       - Icons: Start Menu shortcut + Desktop shortcut (optional checkbox, default checked).
       - Uninstaller: registered in Add/Remove Programs with proper registry keys.
       - File list: includes the Flutter Windows build output (`build/windows/x64/runner/Release/*`).
       - Include ADB platform tools bundled? No — prompt user to install ADB separately with link to Android SDK Platform Tools. (Bundling ADB requires accepting Google's license terms, which is complex.)
       - License page: display MIT license text.
       - Sections: "Main Application" (required), "Desktop Shortcut" (optional).
       - Version: extracted from build script or hardcoded as v1.0.0.
       - Compression: lzma solid.
       - Output: `performancebench-setup-${VERSION}.exe`.
    
    2. Create `macos/package_dmg.sh` — DMG creation script:
       ```bash
       #!/bin/bash
       # Build: flutter build macos --release
       # Sign (if certificate available): codesign --deep --force --verify --verbose --sign "Developer ID Application" build/macos/Build/Products/Release/PerformanceBench.app
       # Create DMG: hdiutil create -volname "PerformanceBench" -srcfolder build/macos/Build/Products/Release/PerformanceBench.app -ov -format UDZO "PerformanceBench-${VERSION}.dmg"
       ```
       - DMG has app icon + Applications folder shortcut (drag-to-install).
       - Handle notarization if `APPLE_NOTARY_PROFILE` env var is set (CI secret). If not set, skip notarization with warning.
       - Script exits with error code if flutter build fails.
    
    3. Create `linux/build_appimage.sh` — AppImage generation script:
       ```bash
       #!/bin/bash
       # Build: flutter build linux --release
       # Requires linuxdeploy and linuxdeploy-plugin-flutter
       # Download linuxdeploy if not present
       # Package: linuxdeploy --appdir AppDir --plugin flutter --output appimage
       # Output: PerformanceBench-${VERSION}-x86_64.AppImage
       ```
       - AppImage includes bundled Flutter runtime.
       - Make AppImage executable: chmod +x.
       - Test: verify AppImage launches on clean Ubuntu 22.04 VM.
    
    4. Update `.github/workflows/ci.yml` to include packaging steps:
       - Windows job: after `flutter build windows`, run `makensis windows/installer/performancebench.nsi` → upload setup.exe as artifact.
       - macOS job: after `flutter build macos --release`, run `bash macos/package_dmg.sh` → upload .dmg as artifact.
       - Linux job: after `flutter build linux --release`, run `bash linux/build_appimage.sh` → upload .AppImage as artifact.
       - All artifacts retained for 7 days.
       - Trigger: on push to main and on pull requests to main.
       - Version: extracted from git tag (if tagged push) or from pubspec.yaml version field.
    
    DO NOT: Sign Windows executables (requires EV certificate). Document that CI builds are unsigned — users can self-sign.
    DO NOT: Automatically upload to GitHub Releases (manual trigger only for release tags).
    DO NOT: Bundle proprietary software in installers.
  </action>
  <acceptance_criteria>
    - `windows/installer/performancebench.nsi` builds with makensis producing a .exe installer
    - `macos/package_dmg.sh` produces a .dmg file from flutter build macos output
    - `linux/build_appimage.sh` produces an AppImage from flutter build linux output
    - CI workflow produces all 3 platform artifacts (setup.exe, .dmg, .AppImage) on push
    - Windows installer includes Start Menu shortcut + uninstaller registration
    - macOS DMG has drag-to-install layout (app icon + Applications shortcut)
    - Linux AppImage is executable and launches on Ubuntu 22.04
    - All 3 artifacts uploaded as CI run artifacts
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && grep -l "flutter build" .github/workflows/ci.yml</automated>
  </verify>
  <done>All 3 platform installers build in CI: Windows NSIS setup.exe, macOS DMG, Linux AppImage. Artifacts uploaded per CI run.</done>
</task>

<task type="auto">
  <name>Task 2: Complete test suite — all unit tests, integration tests, CI-only integration tests per D-09/D-10</name>
  <files>
    test/unit/export_service_test.dart
    test/unit/ring_buffer_test.dart
    test/integration/adb_integration_test.dart
    test/integration/ios_integration_test.dart
    integration_test/app_test.dart
    .github/workflows/ios-test.yml
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 2857-2918 (§14 Testing Strategy — all required test cases, coverage targets, integration test specs)
  </read_first>
  <action>
    1. Verify all unit tests exist and pass:
       - `test/unit/fps_parser_test.dart` — all §5.1 acceptance criteria (9 tests, Wave 2)
       - `test/unit/cpu_parser_test.dart` — all §5.2 acceptance criteria (6 tests, Wave 2)
       - `test/unit/memory_parser_test.dart` — all §5.3 acceptance criteria (6 tests, Wave 2)
       - `test/unit/battery_parser_test.dart` — all §5.4 acceptance criteria (10 tests, Wave 2)
       - `test/unit/network_parser_test.dart` — all §5.5 acceptance criteria (4 tests, Wave 2)
       - `test/unit/thermal_parser_test.dart` — all §5.6 acceptance criteria (3 tests, Wave 2)
       - `test/unit/gpu_parser_test.dart` — all §5.7 acceptance criteria (3 tests, Wave 2)
       - `test/unit/fps_analytics_test.dart` — all §6.1 acceptance criteria (8 tests, Wave 4)
       - `test/unit/comparison_analytics_test.dart` — all §6.4 acceptance criteria (3 tests, Wave 4)
       - `test/unit/ring_buffer_test.dart` — all ring buffer edge cases (5 tests, Wave 3)
       - `test/unit/export_service_test.dart` — all export tests (4 tests, Wave 5)
       - Total: ~60+ unit tests. Run `flutter test test/unit/` — all must pass.
       - Coverage: use `flutter test --coverage` + `genhtml` or `lcov`. Verify critical path parsers + analytics + DB operations have 100% branch coverage per D-09.
    
    2. Create `test/integration/adb_integration_test.dart` — per §14.2:
       - Prerequisites: Android emulator running at `emulator-5554` (CI-managed).
       - Test 1: 30s Android session on emulator → ≥ 28 non-null fps samples.
       - Test 2: All samples: fps non-null and > 0 for ≥ 20 samples in 30s.
       - Test 3: battery_pct non-null in all samples.
       - Test 4: cpu_app_pct non-null in all samples after first (first sample is null — no delta).
       - Uses real ADB against emulator. Requires `adb` in PATH.
       - Tagged with `@Tags(['integration', 'device'])` so they can be filtered.
    
    3. Create `test/integration/ios_integration_test.dart` — per §14.2:
       - Prerequisites: macOS runner with connected iPhone (or iOS simulator).
       - Test 1: 60s iOS session → fps, cpu, mem, battery_pct all have non-null values.
       - Test 2: battery_ma null for iPhone 8+ (assert null, not assert value).
       - Tagged with `@Tags(['integration', 'ios', 'device'])`.
    
    4. Create `integration_test/app_test.dart` — basic app integration test:
       - Test 1: App launches without crashing, device list screen renders.
       - Test 2: Navigation works — can navigate to History, Settings screens.
       - Uses Flutter `integration_test` package.
    
    5. Create `.github/workflows/ios-test.yml` — iOS-specific CI per D-05/D-06:
       - Trigger: on push to main, on PR. Only runs on macOS runner.
       - Steps: checkout, install Flutter, `flutter pub get`, install pyidevice (`pip3 install py-ios-device`), run iOS integration tests against simulator.
       - Matrix: test on both iOS 16 and iOS 17 simulators.
       - Artifacts: test results report.
    
    6. Ensure CI test script:
       - `flutter test test/unit/` runs on all platforms.
       - `flutter test test/integration/` tagged with 'device' runs only on macOS (Android emulator) and tagged with 'ios' runs only on macOS (iOS simulator).
       - Integration tests skipped on ubuntu-latest (no Android emulator in CI for Linux).
    
    DO NOT: Skip tests that fail. Fix code until tests pass. Per D-09, critical path = 100% coverage.
    DO NOT: Use mock ADB output for integration tests — integration tests connect to real emulator/simulator.
    DO NOT: Run iOS integration tests on Windows or Linux — gate with Platform.isMacOS check.
  </action>
  <acceptance_criteria>
    - `flutter test test/unit/` — all 60+ unit tests pass on all 3 platforms
    - Parser tests achieve 100% branch coverage (verified by coverage report)
    - Analytics tests achieve 100% function coverage (every stat function tested)
    - `flutter test test/integration/adb_integration_test.dart` passes on macOS with Android emulator
    - `flutter test test/integration/ios_integration_test.dart` passes on macOS with iOS simulator
    - `flutter test integration_test/` passes (app smoke test)
    - `.github/workflows/ios-test.yml` runs on macOS runner in CI
    - Zero failing tests in CI on any platform
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter test test/unit/ && echo "ALL UNIT TESTS PASS"</automated>
  </verify>
  <done>Full test suite passes: 60+ unit tests with 100% critical-path branch coverage, integration tests on Android emulator + iOS simulator in CI.</done>
</task>

<task type="auto">
  <name>Task 3: Auto-update strategy, README, privacy verification, MIT license headers, final polish</name>
  <files>
    README.md
    CHANGELOG.md
    LICENSE
    lib/**/*.dart
    test/**/*.dart
    ios_agents/**/*.py
    .github/workflows/packet-capture-test.yml
    lib/core/services/update_service.dart
  </files>
  <read_first>
    @UNIFIED-SPEC.md lines 74-84 (§D Definition of Done v1.0 — final checklist)
    @UNIFIED-SPEC.md lines 2922-2952 (§15 Security Model — Local Only, Storage, Export)
  </read_first>
  <action>
    1. Implement auto-update strategy (MVP-25):
       - Create `lib/core/services/update_service.dart` — `UpdateService` class.
       - `Future<UpdateInfo?> checkForUpdate()`:
         a. Fetches `https://api.github.com/repos/sundarlohar007/Benchify/releases/latest` — ONLY endpoint. Uses GitHub's public API (no auth required).
         b. Parses JSON response: `tag_name` (version), `html_url` (release page), `body` (release notes).
         c. Compares against current version (from pubspec.yaml or hardcoded constant).
         d. If remote version > current: return UpdateInfo with new version, release URL, release notes.
         e. If remote version <= current: return null (up to date).
         f. On error (no network, rate limited, etc.): return null silently. Never block app startup.
       - UI: If update available, show a non-intrusive notification bar at top of app (VS Code-style blue info bar): "PerformanceBench v1.0.1 available. [View Release] [Dismiss]".
       - "View Release" opens GitHub Releases page in default browser (via `url_launcher` package — add to pubspec.yaml if not present).
       - No binary download. No auto-install. User manually downloads from GitHub.
       - Check frequency: once per app launch (not periodic). Configurable: Settings > About > "Check for updates".
       - If `url_launcher` is not in pubspec.yaml, add `url_launcher: ^6.2.0` as dependency. This is acceptable because it only opens browser URLs — no data transmission.
    
    2. Write `README.md` — quick-start reproducible in <=5 commands per MVP-27:
       ```markdown
       # PerformanceBench
       Free, open-source mobile performance profiler. GameBench alternative at $0.
       
       ## Quick Start
       1. Download from [GitHub Releases](https://github.com/sundarlohar007/Benchify/releases)
       2. Install ADB: `brew install android-platform-tools` (macOS) or `choco install adb` (Windows)
       3. Enable USB Debugging on Android device (Settings > Developer Options)
       4. Launch PerformanceBench and connect device
       5. Select app and click Start Profiling
       
       ## Build from Source
       1. `git clone https://github.com/sundarlohar007/Benchify`
       2. `cd Benchify && flutter pub get`
       3. `flutter run -d windows` (or `macos`, `linux`)
       
       ## Features
       - Real-time FPS, CPU, Memory, Battery, Network, Thermal, GPU metrics at 1Hz
       - Android + iOS (macOS) support
       - VS Code-inspired dark theme
       - Session history, comparison, JSON/CSV export
       - 100% local — no data ever leaves your machine
       
       ## License
       MIT — see [LICENSE](LICENSE)
       ```
       - Include build status badge from GitHub Actions.
       - Include platform support matrix table (Windows/macOS/Linux × Android/iOS).
       - Include metric parity matrix showing which metrics available per platform.
       - Link to full UNIFIED-SPEC.md for detailed documentation.
    
    3. Create `CHANGELOG.md`:
       - Entry for v1.0.0: "Initial release — External Profiling MVP. Android + iOS (macOS) profiling with 20+ metrics, real-time charts, session history/comparison/export, VS Code dark theme."
    
    4. Ensure `LICENSE` file exists with MIT license text:
       ```
       MIT License
       Copyright (c) 2024 PerformanceBench Contributors
       
       Permission is hereby granted, free of charge, ...
       ```
       - Add to root if not already present from flutter create.
    
    5. Add MIT license headers to ALL source files per MVP-29:
       - Every `.dart` file in `lib/` and `test/`: add header comment:
         ```dart
         // Copyright (c) 2024 PerformanceBench Contributors
         // SPDX-License-Identifier: MIT
         ```
       - Every `.py` file in `ios_agents/`: add header comment:
         ```python
         # Copyright (c) 2024 PerformanceBench Contributors
         # SPDX-License-Identifier: MIT
         ```
       - Every shell script (`.sh`): add header.
       - Verify: `grep -r "SPDX-License-Identifier: MIT" lib/ test/ ios_agents/` returns all source files.
       - Use batch processing: write a script that prepends headers to all source files, or use a tool like `reuse lint`.
    
    6. Implement privacy verification — packet capture test per D-18/D-19/D-20:
       - Flesh out `.github/workflows/packet-capture-test.yml`:
         - Runs on ubuntu-latest (Linux has good tshark support).
         - Steps:
           a. Install tshark: `sudo apt-get install -y tshark`.
           b. Start packet capture: `sudo tshark -i any -w session.pcap -f "not host 127.0.0.1 and not host ::1" &` (exclude localhost).
           c. Build and launch app in headless mode: `xvfb-run flutter run -d linux --release &`. Wait for app to start.
           d. Simulate a 30-minute idle session (app open but not actively profiling — or use a scripted profiling session via flutter driver).
           e. Stop tshark: `sudo pkill tshark`.
           f. Analyze: `tshark -r session.pcap -T fields -e ip.dst -e ip.src | grep -v "127.0.0.1" | grep -v "::1"`.
           g. Assert: zero outbound packets (no rows returned from step f). If ANY outbound packet found → test FAILS.
           h. Known exceptions: DNS queries for update check (github.com). Allow-list: `github.com` (140.82.x.x) for update check only. Any other destination → FAIL.
           i. If test passes: "PRIVACY VERIFIED: Zero outbound connections detected (excluding GitHub update check)."
         - This test gates PR merges — required check for main branch.
       - Network access deny-list enforced in CI (D-19): Any HTTP/HTTPS URL in code not matching allow-listed domains (github.com for update check only) = CI failure.
         - Add step: `grep -rn "http://\|https://" lib/ --include="*.dart" | grep -v "github.com" | grep -v "localhost" | grep -v "127.0.0.1"`. If results found → CI failure.
    
    7. Final cleanup:
       - Run `flutter analyze` across entire project → fix all warnings/errors.
       - Run `dart format lib/ test/` → format all code.
       - Remove any TODO comments that reference deferred features (belong in other phases).
       - Verify no `print()` statements in release code (use proper logging).
    
    DO NOT: Add any new dependencies that make network calls (except url_launcher for browser only).
    DO NOT: Add auto-update binary download — version check only per §F.
    DO NOT: Ship with debug printing enabled in release builds.
  </action>
  <acceptance_criteria>
    - UpdateService checks GitHub Releases API, shows notification bar if new version available
    - Update notification has "View Release" (opens browser) and "Dismiss" buttons
    - No binary download — links to GitHub Releases page only
    - README.md has quick-start reproducible in <=5 commands by fresh user
    - CHANGELOG.md exists with v1.0.0 entry
    - LICENSE file exists with MIT license text
    - `grep -r "SPDX-License-Identifier: MIT" lib/ test/ ios_agents/` returns all .dart and .py files
    - Packet capture test in CI: zero outbound connections (except allow-listed github.com for update check)
    - `grep -rn "http://\|https://" lib/ --include="*.dart" | grep -v github.com | grep -v localhost | grep -v 127.0.0.1` returns zero results
    - `flutter analyze` — zero errors, zero warnings
    - All CI checks pass: build matrix, unit tests, integration tests, packet capture test
  </acceptance_criteria>
  <verify>
    <automated>cd performancebench && flutter analyze && flutter test test/unit/ && grep -r "SPDX-License-Identifier: MIT" lib/ test/ ios_agents/ | wc -l</automated>
  </verify>
  <done>v1.0 shippable: installers build in CI, full test suite green, auto-update version check works, README quick-start is <=5 commands, privacy verified by packet capture, MIT license on all files.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| App → GitHub Releases API | Outbound HTTPS request to api.github.com for version check. Only outbound connection in the app. |
| CI Environment → GitHub Actions | Build artifacts and test results stored in GitHub-managed CI environment. |
| User browser → GitHub Releases | User clicks link to open browser for manual download. Boundary outside app. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-25 | Information Disclosure | update_service.dart — GitHub API request metadata | accept | Only outbound connection in the app. Sends no user/session data — only HTTP GET to public API endpoint. GitHub sees IP address and User-Agent (standard HTTP). Risk accepted per privacy model. |
| T-01-26 | Spoofing | update_service.dart — fake GitHub Releases response | mitigate | HTTPS enforced for api.github.com (no HTTP fallback). GitHub API returns JSON with verified tag_name. Version string validated with semver regex before comparison. |
| T-01-27 | Denial of Service | update_service.dart — GitHub API rate limiting | mitigate | Single request per app launch. On failure (rate limit, no network), return null silently. Never block app startup. Cache result for 6 hours to minimize requests. |
| T-01-28 | Information Disclosure | packet-capture-test.yml — CI artifacts | accept | Test runs in ephemeral CI runner. PCAP file discarded after analysis. No session data involved — tests structural network behavior only. |
| T-01-29 | Tampering | NSIS/DMG/AppImage — installer integrity | mitigate | Document that CI builds are unsigned. Provide SHA256 checksums alongside release artifacts. Users verify checksums manually. Code signing requires EV certs (future). |
</threat_model>

<verification>
- Run README.md quick-start commands on clean machine → app launches within 5 commands
- Run packet capture test → zero outbound connections (excluding github.com)
- Verify all source files have MIT SPDX header
- Build all 3 installers in CI → all succeed
- Run full test suite → all 60+ unit tests pass, integration tests pass
- GitHub Actions CI: all checks green (build, test, analyze, packet-capture, license check)
</verification>

<success_criteria>
1. Windows NSIS installer, macOS DMG, and Linux AppImage all build successfully in CI
2. Full CI matrix (windows-latest, macos-latest, ubuntu-latest) passes on every push per D-12
3. All 60+ unit tests pass with critical-path 100% branch coverage per D-09
4. Integration tests pass on Android emulator (CI) and iOS simulator (macOS runner) per D-10
5. Auto-update checks GitHub Releases, shows notification bar, links to download page only — no binary download
6. README.md quick-start reproducible in <=5 commands by fresh user
7. Packet capture test in CI confirms zero outbound connections during 30-min session per D-18/D-19/D-20
8. Every source file (.dart, .py, .sh) has MIT license header per MVP-29
9. Definition of Done v1.0 checklist (§D) — all 9 items ticked
</success_criteria>

<output>
After completion, create `.planning/phases/01-v1-0-external-profiling-mvp/07-SUMMARY.md`
</output>
