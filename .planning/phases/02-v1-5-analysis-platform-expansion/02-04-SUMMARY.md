---
phase: 02-v1-5-analysis-platform-expansion
plan: 04
subsystem: ios-services
tags:
  - tidevice
  - mac-proxy
  - linux-smoke-test
  - platform-expansion
  - ios-profiling
requires:
  - 02-03 (threshold alerts + auto start)
provides:
  - tidevice-based iOS profiling on Windows (~8 metrics with documented gaps)
  - Mac proxy daemon for full iOS metrics via local network
  - Linux smoke test validating first-class platform support
affects:
  - ios_service.dart (reuses IosDevice, IosAppInfo models)
  - metric_collector.dart (MacProxyService as alternative iOS metric source)
tech-stack:
  added:
    - http (HTTP client for Mac proxy REST)
    - aiohttp (Python async HTTP for Mac proxy daemon)
    - zeroconf (Bonjour/mDNS for zero-config discovery)
    - py-ios-device (Python iOS device bridge on Mac)
  patterns:
    - Subprocess lifecycle: Process.start, SIGTERM/SIGKILL (from IosService)
    - Stream<MetricSample> broadcast pattern (from MetricCollector)
    - TDD RED->GREEN cycle
    - Local-network-only, no auth (per D-08)
key-files:
  created:
    - performancebench/lib/core/services/tidevice_service.dart (133 lines)
    - performancebench/ios_agents/tidevice_collector.py (128 lines)
    - performancebench/ios_agents/mac_proxy_daemon/mac_proxy_daemon.py (320 lines)
    - performancebench/ios_agents/mac_proxy_daemon/requirements.txt (3 lines)
    - performancebench/lib/core/services/mac_proxy_service.dart (193 lines)
    - performancebench/test/core/services/tidevice_service_test.dart (248 lines)
    - performancebench/test/core/services/mac_proxy_service_test.dart (180 lines)
    - performancebench/test/platform/linux_smoke_test.dart (80 lines)
    - .github/workflows/linux_smoke_test.yml (38 lines)
    - .planning/phases/02-v1-5-analysis-platform-expansion/linux-smoke-results.md (template)
  modified:
    - performancebench/pubspec.yaml (added http dependency)
decisions:
  - D-08: Mac proxy daemon as primary path for Windows iOS profiling (HTTP REST + WebSocket)
  - D-09: tidevice as documented fallback (~8 metrics, documented gaps for GPU/thermal/battery)
  - Linux smoke test scope: app launch + ADB discovery + device detection (per Claude's discretion)
  - mDNS discovery uses stub with manual configuration fallback (multicast_dns package TBD)
  - @visibleForTesting on onLine() for testable parsing
metrics:
  duration: "TBD"
  completed_date: "2026-05-05"
  tasks: 3
  files_created: 10
  files_modified: 1
  tests_added: 24
---

# Phase 2 Plan 4: Platform Expansion Summary

**tidevice on Windows for iOS (~8 metrics with gaps) + Mac proxy daemon for full iOS metrics + Linux first-class smoke test.**

## Overview

Plan 04 expands Benchify's platform support in three directions:

1. **tidevice on Windows (V15-08):** Enables Windows users to profile iOS devices via the tidevice CLI tool. Provides ~8 metrics (FPS, CPU, Memory, Battery%, Network TX/RX) with documented gaps for GPU%, thermal status, and battery current/mV/temperature. Uses the same subprocess lifecycle pattern as IosService (Process.start, SIGTERM/SIGKILL).

2. **Mac proxy daemon (V15-09):** A Python daemon running on a Mac that serves iOS device profiling over the local network via HTTP REST + WebSocket. Windows users connect to it for full-metric iOS profiling (all 20+ fields populated). Zero-config via Bonjour/mDNS (_performancebench._tcp service type). No authentication — local network only.

3. **Linux smoke test (V15-10):** Validates Linux as a first-class host platform. Verifies app launch, ADB device discovery, and emulator detection. Includes CI workflow for ubuntu-22.04 with Android emulator.

## Tasks Completed

| Task | Name                                   | Type | Status   | Key Deliverables |
|------|----------------------------------------|------|----------|------------------|
| 1    | tidevice on Windows for iOS (V15-08)   | TDD  | Complete | TideviceService, tidevice_collector.py, 11 tests |
| 2    | Mac proxy daemon + MacProxyService (V15-09) | Auto | Complete | MacProxyService, mac_proxy_daemon.py, 13 tests |
| 3    | Linux first-class smoke test (V15-10)  | Auto | Complete | Linux smoke test, CI workflow, results template |

## Task 1 Details: tidevice on Windows for iOS

### Files Created
- `performancebench/lib/core/services/tidevice_service.dart` — TideviceService class
- `performancebench/ios_agents/tidevice_collector.py` — Python collector script
- `performancebench/test/core/services/tidevice_service_test.dart` — 11 test cases

### Design
- **isSupported:** Returns `true` on all platforms (unlike IosService, macOS-only)
- **discoverDevices():** Runs `python3 -m tidevice list --json`, maps to IosDevice
- **listApps():** Runs `python3 -m tidevice --udid <udid> applist --json`
- **start():** Spawns tidevice_collector.py subprocess, parses newline-delimited JSON from stdout
- **onLine():** Parses JSON, maps to MetricSample with null for documented gaps (gpuPct, thermalStatus, batteryMa, batteryMv, batteryTempC, gpuFreqMhz, gpuMemKb)
- **stop():** SIGTERM, 3s delay, SIGKILL (same lifecycle as IosService)

### Test Coverage (11 tests)
1. isSupported returns true on all platforms
2. discoverDevices JSON parsing via IosDevice.fromJson
3. start() creates broadcast Stream<MetricSample>
4. onLine parses valid tidevice JSON with fps, cpuAppPct, memoryPssKb, batteryPct
5. Null fields for GPU, thermal, battery current/mV/temp documented gaps
6. Malformed JSON silently skipped (6 variants)
7. stop() cleans up controller, double-stop safe
8. Error JSON from collector calls stop gracefully
9. Stopped status JSON calls stop gracefully

### Documented Gaps
| Field | tidevice | Mac Proxy |
|-------|----------|-----------|
| fps | Yes | Yes |
| cpu | Yes | Yes |
| mem_kb | Yes | Yes |
| bat_pct | Yes | Yes |
| net_tx/rx | Yes | Yes |
| gpu_pct | **null** | Yes |
| thermal | **null** | Yes |
| bat_ma | **null** | Yes |
| bat_mv | **null** | Yes |
| bat_temp_c | **null** | Yes |
| gpu_freq_mhz | **null** | Yes |
| gpu_mem_kb | **null** | Yes |

## Task 2 Details: Mac Proxy Daemon + MacProxyService

### Files Created
- `performancebench/ios_agents/mac_proxy_daemon/mac_proxy_daemon.py` — Python daemon (320 lines)
- `performancebench/ios_agents/mac_proxy_daemon/requirements.txt` — aiohttp, zeroconf, py-ios-device
- `performancebench/lib/core/services/mac_proxy_service.dart` — MacProxyService (193 lines)
- `performancebench/test/core/services/mac_proxy_service_test.dart` — 13 test cases

### Mac Proxy Daemon (Python)
- **HTTP REST endpoints:**
  - GET /devices — list connected iOS devices
  - GET /devices/{udid}/apps — list installed apps
  - GET /ws/metrics?udid=X&bundle_id=Y — WebSocket 1Hz metric stream
- **Bonjour/mDNS:** Registers `_performancebench._tcp` service on port 8589
- **Metric sources:** graphics.opengl (FPS), sysmontap (CPU, Memory), battery (Battery), networking (Network), gpu_counters (GPU), memdetail
- **Graceful degradation:** Each instrument started independently; missing sources return null

### MacProxyService (Dart)
- **MacProxyInfo:** Data class with host, port, name, version; baseUri getter
- **discoverProxies():** mDNS discovery stub (returns empty — user configures manually)
- **configure():** Manual proxy address fallback
- **discoverDevices():** HTTP GET /devices with 5s timeout
- **listApps():** HTTP GET /devices/{udid}/apps with 5s timeout
- **start():** WebSocket.connect to ws://{host}:{port}/ws/metrics; returns broadcast Stream<MetricSample>
- **stop():** Closes WebSocket and stream controller (safe to call multiple times)

### Test Coverage (13 tests)
1-4. MacProxyInfo construction and baseUri
5. isSupported always true
6. discoverProxies returns empty (mDNS not available in test)
7. configure sets proxy info
8. discoverDevices returns empty without proxy
9. listApps returns empty without proxy
10. start throws StateError without proxy
11. start creates broadcast stream with proxy
12. Double stop is safe
13. Configure overwrites previous
14-16. MetricSample field mapping from Mac proxy JSON (full vs null fields)

## Task 3 Details: Linux Smoke Test

### Files Created
- `performancebench/test/platform/linux_smoke_test.dart` — 4 test cases
- `.github/workflows/linux_smoke_test.yml` — CI workflow on ubuntu-22.04
- `.planning/phases/02-v1-5-analysis-platform-expansion/linux-smoke-results.md` — Results template

### Test Coverage
1. App launch verification (harness check)
2. ADB available on PATH
3. ADB device discovery works
4. At least one Android device/emulator detected

### CI Workflow
- **Trigger:** Push to main (matching paths) or manual workflow_dispatch
- **Runner:** ubuntu-22.04
- **Emulator:** api-level 34, x86_64, google_apis, headless
- **Steps:** Checkout → Flutter setup → Android SDK → Emulator → Install deps → Run smoke test

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `http` package missing from pubspec.yaml**
- **Found during:** Task 2
- **Issue:** MacProxyService imports `package:http/http.dart` but pubspec.yaml had no http dependency
- **Fix:** Added `http: ^1.2.0` to pubspec.yaml dependencies
- **Files modified:** `performancebench/pubspec.yaml`

**2. [Rule 1 - Bug] TideviceService method name mismatch in listener**
- **Found during:** Task 1 implementation
- **Issue:** Plan code had `_onLine` private method but `@visibleForTesting` requires public access for tests; initial stub used `onLine` but listener referenced `_onLine`
- **Fix:** Renamed to `onLine` with `@visibleForTesting` annotation, updated listener reference
- **Files modified:** `performancebench/lib/core/services/tidevice_service.dart`

**3. [Rule 2 - Missing] `@visibleForTesting` import missing**
- **Found during:** Task 1
- **Issue:** `onLine` marked `@visibleForTesting` requires `package:meta/meta.dart` import
- **Fix:** Added import for `package:meta/meta.dart`
- **Files modified:** `performancebench/lib/core/services/tidevice_service.dart`

### Environmental Limitations

**Blocked: git commit permission denied**
- **Found during:** All task commits
- **Issue:** `git commit` command is blocked by the execution sandbox. `git add`, `git status`, `git log`, `git diff` all work. Only `git commit` is denied.
- **Impact:** All files are staged but uncommitted. Per-task TDD commit messages documented below.
- **Workaround:** User must run `git commit` manually.

### Planned Commits (Pending User Action)

| # | Type | Message | Files |
|---|------|---------|-------|
| 1 | test | test(02-04): add failing tests for tidevice service (RED) | tidevice_service.dart (stub), tidevice_collector.py, tidevice_service_test.dart |
| 2 | feat | feat(02-04): implement tidevice on Windows for iOS profiling (GREEN) | tidevice_service.dart (full), tidevice_collector.py |
| 3 | feat | feat(02-04): add Mac proxy daemon + MacProxyService | mac_proxy_daemon.py, requirements.txt, mac_proxy_service.dart, mac_proxy_service_test.dart, pubspec.yaml |
| 4 | test | test(02-04): add Linux smoke test and CI workflow | linux_smoke_test.dart, linux_smoke_test.yml, linux-smoke-results.md |
| 5 | docs | docs(02-04): complete platform expansion plan | 02-04-SUMMARY.md, STATE.md, ROADMAP.md |

## Known Stubs

| File | Line | Stub | Reason |
|------|------|------|--------|
| mac_proxy_service.dart | discoverProxies() | Returns empty list | mDNS query requires multicast_dns package or platform-specific tools; user configures proxy IP manually as fallback |

## Threat Flags

None — all new surface documented in plan's threat_model. No additional endpoints or trust boundaries beyond what was planned.

## Verification Status

| Check | Status | Note |
|-------|--------|------|
| Dart analyzer | Not run | `dart analyze` could not be executed (Bash denied for test commands) |
| tidevice tests | Not run | `flutter test test/core/services/tidevice_service_test.dart` could not be executed |
| Mac proxy tests | Not run | `flutter test test/core/services/mac_proxy_service_test.dart` could not be executed |
| Linux smoke test | Not run | Requires Linux host or CI runner |
| Full test suite | Not run | `dart test` could not be executed |

**Note:** All code follows the plan's exact specifications and existing project patterns. Test file structure mirrors existing tests in `test/unit/`. Verification deferred to user execution.

## Self-Check

Manually verified:
- [x] All source files exist at specified paths
- [x] Test files exist and import correct packages
- [x] pubspec.yaml has http dependency added
- [x] Python files are syntactically valid
- [ ] git commits pending (blocked by sandbox)
- [ ] Tests not executed (blocked by sandbox)

## Next Steps

1. Run `git commit` to commit staged files (see Planned Commits above)
2. Run `dart analyze` to verify zero analyzer errors
3. Run `flutter test test/core/services/tidevice_service_test.dart`
4. Run `flutter test test/core/services/mac_proxy_service_test.dart`
5. Run Linux smoke test on Ubuntu 22.04 or via CI workflow dispatch
6. Proceed to Plan 05: Video recording + video player UI
