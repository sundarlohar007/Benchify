# Wave 4 Summary — Post-Session Analytics + iOS pyidevice Support

**Plan:** 04-PLAN.md  
**Date:** 2026-05-04  
**Status:** Complete

## Completed

### Task 1: Analytics Engine (TDD)
- `lib/core/analytics/fps_analytics.dart` — `FpsAnalytics.compute(List<double>)` → `FpsStats`:
  - Median, min, max, 1% low (bottom 1%), p95 frame time (5th percentile FPS → ms)
  - Stability % (frames within 80%-120% of median), histogram (5fps buckets → JSON)
  - Variability index (mean of consecutive abs diffs)
- `lib/core/analytics/comparison_analytics.dart` — `ComparisonAnalytics.compare(A, B)`:
  - 9 metric deltas with regression detection (FPS lower=regression, CPU/Memory/Jank higher=regression)
- `lib/core/analytics/analytics_service.dart` — `AnalyticsService`:
  - `computeSessionStats(sessionId)` — full §6 computation:
    - FPS: all 8 stats from FpsAnalytics
    - CPU: avg/peak for app %, freq-normalized
    - Memory: avg/peak for PSS + 7 subsections, growth KB, trend slope (linear regression)
    - GPU: avg/peak
    - Battery/Power: drain pct, drain per hour, temp max, mAh (trapezoidal integration), avg mW, total mWh, estimated playtime, charging period detection
    - Jank: 4 totals + per-minute rate
    - Network: per-interface TX/RX totals, WiFi/Cellular average Kbps
    - Thermal: peak status
    - Duration: ms, launch_complete_ms from marker
  - `computeMarkerStats(sessionId)` — per-marker stats for all ended range markers
- 11 new tests: 8 FPS analytics + 3 comparison analytics

### Task 2: iOS pyidevice Support
- `ios_agents/collector.py` — Full Python 3.10+ metrics collector:
  - DTXProtocol instruments: graphics.opengl, sysmontap, memdetail, battery, networking, gpu_counters
  - 3-tier jank classification (small/medium/big) with rolling window
  - Frame ratio jank computation
  - 1Hz JSON newline-delimited output per §5.10 field mapping
  - Graceful SIGTERM shutdown, pyidevice import error handling
- `ios_agents/device_list.py` — iOS device discovery (JSON array)
- `ios_agents/app_list.py` — Installed app listing via installation_proxy
- `ios_agents/requirements.txt` — `py-ios-device>=2.0.0`
- `lib/core/services/ios_service.dart` — `IosService`:
  - Python subprocess lifecycle: start → stdout JSON stream → SIGTERM(3s) → SIGKILL
  - `discoverDevices()`, `listApps(udid)`, `start(udid, bundleId)` → `Stream<MetricSample>`
  - JSON field mapping per §5.10: fps→fps, jank.small→jank_small_count, mem_bytes/1024→memory_pss_kb, etc.
  - CPU NOT normalized per core (iOS difference)
  - Malformed JSON: skip line, continue
  - macOS platform guard: `Platform.isMacOS` — throws StateError on non-macOS
  - pyidevice not installed → returns empty lists

## Verification
- `flutter analyze`: 0 errors
- `flutter test`: 96/96 passed (79 parser + 5 ring buffer + 8 FPS analytics + 3 comparison + 1 widget)
- Python syntax: collector.py, device_list.py, app_list.py all valid Python 3.10+

## Artifacts
| File | Status |
|------|--------|
| `lib/core/analytics/fps_analytics.dart` | Created |
| `lib/core/analytics/comparison_analytics.dart` | Created |
| `lib/core/analytics/analytics_service.dart` | Created |
| `lib/core/services/ios_service.dart` | Created |
| `ios_agents/collector.py` | Created |
| `ios_agents/device_list.py` | Created |
| `ios_agents/app_list.py` | Created |
| `ios_agents/requirements.txt` | Created |
| `test/unit/fps_analytics_test.dart` | Created |
| `test/unit/comparison_analytics_test.dart` | Created |

## Commit
`bb64204 feat(01-04): implement post-session analytics engine and iOS pyidevice support (GREEN)`
