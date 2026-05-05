# Linux Smoke Test Results

**Phase:** 2 — v1.5 Analysis + Platform Expansion
**Plan:** 04 — Platform Expansion (tidevice, Mac proxy, Linux)
**Requirement:** V15-10 — Linux first-class smoke test

## Test Environment

| Field | Value |
|-------|-------|
| Host OS | [Fill: Ubuntu 22.04 or later] |
| Kernel | [Fill: uname -r] |
| Flutter version | [Fill: flutter --version] |
| ADB version | [Fill: adb --version] |
| Android device/emulator | [Fill: device serial or emulator name] |
| Date | [Fill: YYYY-MM-DD] |

## Results

| # | Check | Expected | Actual | Status |
|---|-------|----------|--------|--------|
| 1 | App launch | No crash | [Fill] | [PASS/FAIL] |
| 2 | ADB on PATH | `adb --version` exits 0 | [Fill] | [PASS/FAIL] |
| 3 | ADB device discovery | Detects connected device | [Fill] | [PASS/FAIL] |
| 4 | 60s profiling session | Runs to completion | [Fill] | [PASS/FAIL] |

## Overall

**Status:** [PASS / FAIL / NOT YET RUN]

## Notes

- [Fill any observations, errors, or anomalies]
- CI workflow runs on push to main: `.github/workflows/linux_smoke_test.yml`
- Manual trigger available via `workflow_dispatch`

## Manual Verification (without CI)

```bash
# Run on a Linux host with ADB and Android device connected:
cd performancebench

# 1. Verify app builds
flutter build linux

# 2. Verify ADB discovery
adb devices

# 3. Launch app and start 60-second profiling session
flutter run -d linux

# 4. Run automated smoke test
flutter test test/platform/linux_smoke_test.dart --platform=linux
```
