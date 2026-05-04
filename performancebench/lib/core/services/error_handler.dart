// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// Centralized error handler with Debug/Release dual mode (D-16).
///
/// Debug mode: full stack traces printed to console and stored.
/// Release mode: minimal one-line messages, stack traces not stored.
///
/// Never throws — the handler itself must be infallible.
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._();

  factory ErrorHandler() => _instance;

  ErrorHandler._();

  bool _debugMode = false;
  final List<ErrorEntry> _errors = [];
  static const int _maxEntries = 1000;

  bool get isDebugMode => _debugMode;
  int get errorCount => _errors.length;
  List<ErrorEntry> get errors => List.unmodifiable(_errors);

  /// Enable or disable debug mode (set from --debug CLI flag in main.dart).
  void setDebugMode(bool enabled) {
    _debugMode = enabled;
  }

  /// Log an error. Source is the component name, error is the object,
  /// stack is optional and only stored in debug mode.
  void logError(String source, dynamic error, [StackTrace? stack]) {
    final message = error.toString();
    final entry = ErrorEntry(
      timestamp: DateTime.now(),
      source: source,
      message: message,
      stackTrace: _debugMode ? stack : null,
    );

    if (_debugMode) {
      // ignore: avoid_print
      print('[ERROR] [$source] $message');
      if (stack != null) {
        // ignore: avoid_print
        print(stack);
      }
    } else {
      // ignore: avoid_print
      print('[ERROR] $message');
    }

    _errors.add(entry);
    while (_errors.length > _maxEntries) {
      _errors.removeAt(0);
    }
  }

  /// Clear all stored errors.
  void clearErrors() {
    _errors.clear();
  }
}

/// A single logged error entry.
class ErrorEntry {
  final DateTime timestamp;
  final String source;
  final String message;
  final StackTrace? stackTrace;

  const ErrorEntry({
    required this.timestamp,
    required this.source,
    required this.message,
    this.stackTrace,
  });
}
