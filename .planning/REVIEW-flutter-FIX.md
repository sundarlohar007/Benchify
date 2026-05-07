---
phase: flutter-review
fixed_at: 2026-05-07T00:00:00Z
review_path: .planning/REVIEW-flutter.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Flutter Desktop App Code Review Fix Report

**Fixed at:** 2026-05-07
**Source review:** .planning/REVIEW-flutter.md
**Iteration:** 1

**Summary:**
- Findings in scope: 4
- Fixed: 4
- Skipped: 0

## Fixed Issues

### BUG-01: Keystore credentials exposed in CLI process list

**Files modified:** `performancebench/lib/core/services/injection_service.dart`, `performancebench-injector/injector_cli.py`
**Applied fix:** Removed `--keystore-password` and `--key-password` from the CLI argument list in `buildInjectArgs()`. Replaced with `--keystore-passwords-via-stdin` flag. Modified `_spawnProcess()` to accept an optional `KeystoreConfig? keystore` parameter and write password JSON to the subprocess stdin when the flag is present. Updated the Python `inject` command with a `_read_stdin_json()` helper and `--keystore-passwords-via-stdin` Click option to read passwords from stdin.

### BUG-02: Apple ID app-specific password exposed in CLI process list

**Files modified:** `performancebench/lib/core/services/ipa_injection_service.dart`, `performancebench-injector/injector_cli.py`
**Applied fix:** Removed `--app-specific-password` from the CLI argument list in `_buildInjectArgs()`. Replaced with `--password-via-stdin` flag. Modified `_spawnProcess()` to accept an optional `String? appSpecificPassword` parameter and write password JSON to the subprocess stdin when the flag is present. Updated the Python `ipa-inject` command with `--password-via-stdin` Click option to read the password from stdin.

### BUG-03: `stop()` called without `await` causes data loss

**Files modified:** `performancebench/lib/core/services/metric_collector.dart`
**Applied fix:** Cancel the periodic `_timer` and set it to null BEFORE calling `unawaited(stop())` when 5 consecutive failures are detected. This prevents new ticks from firing while `stop()` flushes the pending batch, and documents the fire-and-forget intent via `unawaited()`.

### BUG-04: `HttpClient` never closed, resource leak on every update check

**Files modified:** `performancebench/lib/core/services/update_service.dart`
**Applied fix:** Moved `HttpClient` instantiation outside the `try` block and added `client.close()` in a `finally` block. This ensures the HTTP client's native OS resources (connection pool, sockets) are released on every code path, including early returns and caught exceptions.

---

_Fixed: 2026-05-07_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
