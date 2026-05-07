## Flutter Desktop App Code Review — HIGH and MEDIUM Severity Findings

**Reviewed:** 2026-05-07
**Scope:** `performancebench/lib/` — all Dart source files (core services, parsers, analytics, database, features, shared)
**Reviewer:** Claude (gsd-code-reviewer)

---

### [BUG-01] Severity: HIGH — Keystore credentials exposed in CLI process list

- **File:** `performancebench/lib/core/services/injection_service.dart:132-138`
- **Problem:** Keystore passwords are passed as command-line arguments (`--keystore-password`, `--key-password`). Any user/process on the system can see them via `ps aux` or `/proc/*/cmdline`. The doc comment at line 83-84 claims "T-04-02: Keystore passwords passed via stdin, not CLI args visible in process list" but the code does the opposite.
- **Fix:** Remove password args from the argument list. Write passwords to a temp file with restrictive permissions (`0600`), pass the file path as an argument, or pipe them through `Process.start().stdin`. Example:

```dart
// Remove from args:
// args.addAll(['--keystore-password', keystore.keystorePassword, ...]);

// Pass via stdin after spawning:
final process = await Process.start(args.first, args.sublist(1));
final passwordJson = jsonEncode({
  'keystore_password': keystore.keystorePassword,
  'key_password': keystore.keyPassword,
});
process.stdin.write(passwordJson);
await process.stdin.close();
```

---

### [BUG-02] Severity: HIGH — Apple ID app-specific password exposed in CLI process list

- **File:** `performancebench/lib/core/services/ipa_injection_service.dart:183-185`
- **Problem:** `--app-specific-password` is passed as a command-line argument, visible in the process table. This is a user credential. Same fundamental issue as BUG-01.
- **Fix:** Pass the app-specific password via stdin instead of CLI args. Use the same stdin pipe pattern described in BUG-01.

---

### [BUG-03] Severity: HIGH — `stop()` called without `await` causes data loss

- **File:** `performancebench/lib/core/services/metric_collector.dart:260-262`
- **Problem:** When 5 consecutive metric collection failures occur, `stop()` is called on line 261 but is *never awaited*. `stop()` returns `Future<List<MetricSample>>` and the `_flushBatch()` inside it is async. The function returns a future that is silently discarded — unflushed buffered samples in `_pendingBatch` are lost. The `_tick()` method itself is async-void (on line 222-232 the catch block does not rethrow). This means session data can be silently discarded on connection loss.
- **Fix:** Ensure `stop()` is awaited, or restructure to chain the stop properly. The simplest approach:

```dart
// Line 258-264, after the connection loss detection:
if (_consecutiveFailures >= 5) {
  _controller?.addError(
    'ADB connection lost after 5 consecutive total failures',
  );
  // Fire-and-forget stop, but mark state to prevent further ticks
  _timer?.cancel();
  _timer = null;
  unawaited(stop()); // Document that it's fire-and-forget
  return;
}
```

At minimum, cancel the timer before calling stop so no new ticks fire while flushing.

---

### [BUG-04] Severity: HIGH — `HttpClient` never closed, resource leak on every update check

- **File:** `performancebench/lib/core/services/update_service.dart:46-78`
- **Problem:** A new `HttpClient()` is created on line 46 inside `checkForUpdate()` but is never closed. `HttpClient` owns OS-level resources (connection pool, sockets). Over extended app uptime with periodic checks, this leaks native sockets. The response stream from `request.close()` is also never explicitly drained on the error path, potentially keeping the connection open.
- **Fix:** Use `client.close()` in a `finally` block or wrap with `try/finally`:

```dart
final client = HttpClient();
client.connectionTimeout = const Duration(seconds: 10);
try {
  final request = await client.getUrl(Uri.parse(_repoUrl));
  // ... existing logic ...
} finally {
  client.close();
}
```

---

### [BUG-05] Severity: MEDIUM — Chunk timer overwritten without cancellation (race condition)

- **File:** `performancebench/lib/core/services/screenrecord_service.dart:133-135`
- **Problem:** `_chunkTimer` is a single field that gets overwritten on every call to `_startChunk()` (line 133). Since `_startChunk()` can be called both from `start()` (line 90) and from the timer callback (line 134), there is a window where a new chunk could start while the previous timer hasn't fired yet. The old timer is overwritten without `cancel()`, leaving a dangling periodic timer that could fire and call `_startChunk()` concurrently, creating unexpected parallel screenrecord processes.
- **Fix:** Cancel the previous timer before replacing it:

```dart
_chunkTimer?.cancel();
_chunkTimer = Timer(const Duration(minutes: 4, seconds: 55), () {
  _startChunk();
});
```

---

### [BUG-06] Severity: MEDIUM — `StreamController` leak in `ReplayChartsTab`

- **File:** `performancebench/lib/features/session_detail/replay_charts_tab.dart:107-114`
- **Problem:** A `StreamController<MetricSample>.broadcast()` is created on every `build()` call (which happens on every UI rebuild) but is never closed. Broadcast stream controllers hold resources until explicitly closed. Each UI rebuild creates a new controller, leaking the previous one.
- **Fix:** Close the controller in `dispose()` or reuse it:

```dart
// Add field to state:
StreamController<MetricSample>? _chartController;

@override
void dispose() {
  _chartController?.close();
  super.dispose();
}

// In build():
_chartController?.close();
_chartController = StreamController<MetricSample>.broadcast();
```

---

### [BUG-07] Severity: MEDIUM — `_handleStop` does not terminate the profiling session

- **File:** `performancebench/lib/features/active_session/active_session_screen.dart:68-72`
- **Problem:** `_handleStop()` only stops the local stopwatch and navigates away. It does not call any session service to stop the metric collector, flush pending batches, compute analytics, or update the session end-time in the database. The active session is left in an un-terminated state.
- **Fix:** Call the session termination pipeline before navigating away:

```dart
void _handleStop() async {
  _stopwatch.stop();
  _elapsedTimer?.cancel();
  // TODO: Call the active session service to stop collection, flush, and finalize
  // await ref.read(sessionServiceProvider).stopSession(sessionId);
  if (mounted) {
    context.go('/');
  }
}
```

---

### [BUG-08] Severity: MEDIUM — API token stored in plaintext `SharedPreferences`

- **File:** `performancebench/lib/core/services/api_service.dart:22-27`
- **Problem:** The API token (bearer token for server auth) is stored in plaintext via `SharedPreferences`. On Windows, this writes to the registry unencrypted. On macOS, it writes to a plist file. Any process running as the same user can read this token. For a desktop app that acts as a profiling client, an exposed API token could allow unauthorized data upload/manipulation.
- **Fix:** Use platform-level credential storage (e.g., `flutter_secure_storage` package for keychain/DPAPI encryption) or encrypt the token with a device-derived key before storing.

```dart
// Replace SharedPreferences for api_token with:
final storage = FlutterSecureStorage();
await storage.write(key: 'api_token', value: apiToken);
```

---

### [BUG-09] Severity: MEDIUM — ErrorHandler singleton mutable state without synchronization

- **File:** `performancebench/lib/core/services/error_handler.dart:14-57`
- **Problem:** The `ErrorHandler` is a singleton (`factory ErrorHandler() => _instance`) with mutable internal state (`_errors` list, `_debugMode`) accessed from multiple async contexts (different Timer callbacks, Service callbacks, UI callbacks). List operations (`add`, `removeAt`) performed concurrently from different isolates/event-loop microtasks can cause `ConcurrentModificationError` or corrupted state since Dart's `List` is not thread-safe within a single isolate when mutated during iteration. The `while (_errors.length > _maxEntries)` loop on line 54-56 iterates and mutates the same list simultaneously.
- **Fix:** Either synchronize access or use a lock-free ring buffer. At minimum, copy before reading:

```dart
List<ErrorEntry> get errors {
  try {
    return List.unmodifiable(List.from(_errors));
  } catch (_) {
    return [];
  }
}
```

For the trimming loop, use `_errors.removeRange(0, _errors.length - _maxEntries)` which is a single operation rather than a loop.

---

### [BUG-10] Severity: MEDIUM — `MetricCollector._tick()` catch block silently swallows all errors

- **File:** `performancebench/lib/core/services/metric_collector.dart:322-324`
- **Problem:** The catch block on `_tick()` catches *all* exceptions and only increments `_consecutiveFailures`. No error is logged, no diagnostic information is preserved. If a real bug exists (e.g., a null pointer from a parser), it will be silently masked, making debugging nearly impossible. After 5 consecutive failures, the session stops with a generic "ADB connection lost" message that may be misleading (the real cause might be a parser bug, not ADB).
- **Fix:** Log the error before swallowing it:

```dart
} catch (e, stack) {
  ErrorHandler().logError('MetricCollector._tick', e, stack);
  _consecutiveFailures++;
}
```

---

### [BUG-11] Severity: MEDIUM — `SessionDetailScreen` re-initializes the database on every operation

- **File:** `performancebench/lib/features/session_detail/detail_screen.dart:60, 87, 214-227`
- **Problem:** `initDatabase()` is called separately for loading data (line 60), saving edits (line 87), and computing region stats (line 214-227). Each call opens a new `Database` instance (sqflite connection pool). While SQLite supports multiple connections, creating and tearing down connections for every user operation wastes resources and could cause `SQLITE_BUSY` contention on the WAL checkpoint.
- **Fix:** Initialize the database once at the screen level and share it across all operations:

```dart
class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  Database? _db;
  // ...

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    _db = await initDatabase();
    await _loadData();
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }
}
```

---

**Summary:** 11 findings — 4 HIGH, 7 MEDIUM. The most critical are the credential exposure bugs (BUG-01, BUG-02) which violate the app's own stated threat model and expose user secrets via the OS process table.
