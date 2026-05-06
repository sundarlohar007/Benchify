// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Socket, SocketException;

import '../models/metric_sample.dart';

/// Desktop TCP client for the PerformanceBench SDK JSON stream.
///
/// Connects to the injected SDK's TCP server (port 8080) via ADB port forwarding.
/// Parses newline-delimited JSON lines into MetricSample objects.
///
/// Pattern follows ios_service.dart exactly:
///   Socket → utf8.decoder → LineSplitter() → jsonDecode → MetricSample.fromMap().
///
/// Threat mitigations (T-04-11):
/// - ADB port forward only active during profiling session.
/// - Disconnect removes forward.
/// - Socket connection is local-only via ADB tunnel.
/// - Malformed JSON lines are skipped with a warning, not crashed.
class SdkStreamService {
  Socket? _socket;
  StreamController<MetricSample>? _controller;
  bool _stopped = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  static const Duration _reconnectDelay = Duration(seconds: 5);

  /// Whether a connection to the SDK is currently active.
  bool get isConnected => _socket != null && !_stopped;

  /// Connect to the SDK TCP server on the device via ADB port forwarding.
  ///
  /// Steps:
  /// 1. ADB forward: `adb -s <serial> forward tcp:<port> tcp:<port>
  /// 2. Connect raw TCP socket to localhost:<port>
  /// 3. Pipe socket through utf8 decoder + LineSplitter
  /// 4. Parse each line as JSON into MetricSample.fromMap()
  ///
  /// Returns a broadcast [Stream<MetricSample>] emitting one sample per second.
  /// Call [disconnect] to stop and remove the ADB forward.
  ///
  /// [adhShell] is a function that runs ADB shell commands. Typically provided
  /// by AdbService.runShellCommand.
  Stream<MetricSample> connect(
    String deviceSerial, {
    int port = 8080,
    required Future<String?> Function(String serial, String command) adbShell,
  }) {
    _controller = StreamController<MetricSample>.broadcast();
    _stopped = false;
    _reconnectAttempts = 0;

    _connectAndStream(deviceSerial, port, adbShell);

    return _controller!.stream;
  }

  Future<void> _connectAndStream(
    String deviceSerial,
    int port,
    Future<String?> Function(String, String) adbShell,
  ) async {
    try {
      // Step 1: Set up ADB port forwarding
      final forwardResult = await adbShell(
        deviceSerial,
        'forward tcp:$port tcp:$port',
      );
      if (forwardResult == null) {
        _controller?.addError('Failed to set up ADB port forward tcp:$port');
        _controller?.close();
        return;
      }

      // Step 2: Connect TCP socket to localhost:<port>
      _socket = await Socket.connect('localhost', port,
          timeout: const Duration(seconds: 10));

      // Step 3: Pipe socket through decoder chain
      _socket!
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        _onLine,
        onError: (error) {
          _handleConnectionError(
              error, deviceSerial, port, adbShell);
        },
        onDone: () {
          if (!_stopped) {
            _handleConnectionError(
                'Connection closed by SDK',
                deviceSerial,
                port,
                adbShell);
          }
        },
        cancelOnError: false,
      );
    } on SocketException catch (e) {
      _handleConnectionError(e, deviceSerial, port, adbShell);
    } catch (e) {
      _controller?.addError(e);
      _controller?.close();
    }
  }

  /// Parse a single JSON line from the SDK TCP stream.
  void _onLine(String line) {
    if (_stopped) return;

    try {
      final json = jsonDecode(line) as Map<String, dynamic>;

      // Check for error signals from SDK
      if (json.containsKey('error')) {
        _controller?.addError(json['error']);
        return;
      }

      // Parse into MetricSample using the same fromMap() as iOS service
      final sample = MetricSample.fromMap(json);
      _controller?.add(sample);
    } on FormatException {
      // Malformed JSON — skip line, log warning, continue (don't crash)
      // ignore: avoid_print
      print('[sdk_stream_service] Skipping malformed JSON line: '
          '${line.length > 100 ? '${line.substring(0, 100)}...' : line}');
    } catch (e) {
      // Skip unparseable lines — don't crash the stream
      // ignore: avoid_print
      print('[sdk_stream_service] Error parsing line: $e');
    }
  }

  /// Handle connection errors with auto-reconnect logic.
  /// Retries up to 3 times with 5-second delays.
  void _handleConnectionError(
    Object error,
    String deviceSerial,
    int port,
    Future<String?> Function(String, String) adbShell,
  ) {
    if (_stopped) return;

    _reconnectAttempts++;
    if (_reconnectAttempts <= _maxReconnectAttempts) {
      // ignore: avoid_print
      print('[sdk_stream_service] Connection error (attempt '
          '$_reconnectAttempts/$_maxReconnectAttempts): $error. '
          'Reconnecting in ${_reconnectDelay.inSeconds}s...');

      Future.delayed(_reconnectDelay, () {
        if (!_stopped) {
          _connectAndStream(deviceSerial, port, adbShell);
        }
      });
    } else {
      _controller?.addError(
        'Failed to maintain SDK stream connection after '
        '$_maxReconnectAttempts attempts: $error',
      );
      _controller?.close();
    }
  }

  /// Disconnect from the SDK stream and remove ADB port forward.
  Future<void> disconnect(
    String deviceSerial, {
    int port = 8080,
    required Future<String?> Function(String serial, String command) adbShell,
  }) async {
    _stopped = true;

    // Close socket
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;

    // Remove ADB port forward
    try {
      await adbShell(deviceSerial, 'forward --remove tcp:$port');
    } catch (_) {}

    await _controller?.close();
    _controller = null;
  }

  /// Abort the stream immediately (same as disconnect but fire-and-forget).
  void abort() {
    _stopped = true;
    _socket?.destroy();
    _socket = null;
    _controller?.close();
    _controller = null;
  }
}
