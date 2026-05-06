// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:convert';

/// Service for sending ADB broadcast automation commands to the injected app.
///
/// Per D-22: Full command set via ADB broadcast:
///   START_SESSION, STOP_SESSION, PAUSE, RESUME, MARKER, SCREENSHOT, EXPORT
///
/// Per D-23: Command via `com.benchify.COMMAND` intent with `action` and
/// `payload` extras. Payload is a JSON string.
///
/// Per D-24: Desktop CLI mode for CI — `pb automark --session <id> --note <text>`.
/// Convenience methods: startSession, stopSession, addMarker, etc.
///
/// The `runShell` callback isolates this service from the concrete ADB implementation,
/// making it testable with a fake.
class AutomationService {
  /// Function signature: (serial, command, {timeout}) -> stdout string or null.
  final Future<String?> Function(
    String serial,
    String command, {
    Duration timeout,
  }) _runShell;

  /// The 7 supported broadcast actions per D-22.
  static const List<String> supportedActions = [
    'START_SESSION',
    'STOP_SESSION',
    'PAUSE',
    'RESUME',
    'MARKER',
    'SCREENSHOT',
    'EXPORT',
  ];

  /// Create an AutomationService with the provided shell execution callback.
  ///
  /// In production, pass `(serial, cmd, {timeout}) => adbService.runShellCommand(serial, cmd)`.
  /// In tests, pass a fake that records calls.
  AutomationService({
    required Future<String?> Function(
      String serial,
      String command, {
      Duration timeout,
    })
    runShell,
  }) : _runShell = runShell;

  /// Send a command to the injected app on the device.
  ///
  /// Constructs the `adb shell am broadcast` command per D-23, sends it via
  /// the shell callback, and parses the response.
  ///
  /// Returns parsed JSON response map, or null on timeout/error/invalid action.
  Future<Map<String, dynamic>?> sendCommand({
    required String deviceSerial,
    required String action,
    Map<String, dynamic>? payload,
  }) async {
    // Validate serial
    if (deviceSerial.isEmpty) return null;

    // Validate action is in supported list
    if (!supportedActions.contains(action)) return null;

    // Build ADB shell command per D-23:
    // adb shell am broadcast -a com.benchify.COMMAND --es action "<action>" --es payload '<json>'
    final payloadJson = payload != null ? jsonEncode(payload) : '{}';

    // Escape single quotes in the JSON payload for shell
    final escapedPayload = payloadJson.replaceAll("'", "'\\''");

    final command = 'am broadcast'
        ' -a com.benchify.COMMAND'
        " --es action $action"
        " --es payload '$escapedPayload'";

    // Execute via ADB shell
    final output = await _runShell(
      deviceSerial,
      command,
      timeout: const Duration(seconds: 5),
    );

    if (output == null) return null;

    // Parse ADB broadcast output for status
    // ADB broadcast returns: "Broadcast completed: result=0"
    // The response broadcast is received asynchronously, but the ADB command
    // itself returns a result code. result=0 means the broadcast was sent
    // successfully. The actual command result comes via com.benchify.RESPONSE.
    try {
      return {
        'action': action,
        'status': output.contains('result=0') ? 'ok' : 'error',
        'detail': 'Broadcast sent',
      };
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Convenience methods (per D-24: CLI-friendly for CI/CD)
  // ---------------------------------------------------------------------------

  /// Start profiling session.
  /// Equivalent to `pb automark --session <id> start` (CLI mode).
  Future<Map<String, dynamic>?> startSession({
    required String deviceSerial,
    required String sessionId,
  }) async {
    return sendCommand(
      deviceSerial: deviceSerial,
      action: 'START_SESSION',
      payload: {'session_id': sessionId},
    );
  }

  /// Stop profiling session.
  Future<Map<String, dynamic>?> stopSession({
    required String deviceSerial,
  }) async {
    return sendCommand(
      deviceSerial: deviceSerial,
      action: 'STOP_SESSION',
    );
  }

  /// Pause metric collection (TCP stays open).
  Future<Map<String, dynamic>?> pause({
    required String deviceSerial,
  }) async {
    return sendCommand(
      deviceSerial: deviceSerial,
      action: 'PAUSE',
    );
  }

  /// Resume paused metric collection.
  Future<Map<String, dynamic>?> resume({
    required String deviceSerial,
  }) async {
    return sendCommand(
      deviceSerial: deviceSerial,
      action: 'RESUME',
    );
  }

  /// Insert a session marker at current timestamp.
  /// Convention: `pb automark --session <id> --note 'boss fight start'`
  Future<bool> addMarker({
    required String deviceSerial,
    required String sessionId,
    required String note,
  }) async {
    final response = await sendCommand(
      deviceSerial: deviceSerial,
      action: 'MARKER',
      payload: {'session_id': sessionId, 'note': note},
    );
    return response?['status'] == 'ok';
  }

  /// Capture a screenshot with a label.
  Future<Map<String, dynamic>?> screenshot({
    required String deviceSerial,
    String label = 'screenshot',
  }) async {
    return sendCommand(
      deviceSerial: deviceSerial,
      action: 'SCREENSHOT',
      payload: {'label': label},
    );
  }

  /// Export accumulated session data to device storage as JSON.
  Future<Map<String, dynamic>?> exportSession({
    required String deviceSerial,
  }) async {
    return sendCommand(
      deviceSerial: deviceSerial,
      action: 'EXPORT',
    );
  }
}
