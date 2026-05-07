// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/metric_sample.dart';

/// Connection to a pb-pcprobe instance.
///
/// Holds the socket and provides stream/channel access to the probe's
/// NDJSON metric feed and command interface.
class PcProbeConnection {
  final Socket _socket;
  final String host;
  final int port;
  final StreamController<MetricSample> _sampleController =
      StreamController<MetricSample>.broadcast();
  final StreamController<PcProbeStatus> _statusController =
      StreamController<PcProbeStatus>.broadcast();
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Connection health: true when last heartbeat was within 15s.
  bool _healthy = true;
  Timer? _heartbeatTimer;
  DateTime _lastHeartbeat = DateTime.now();

  PcProbeConnection._({
    required this.host,
    required this.port,
    required Socket socket,
  }) : _socket = socket {
    _startReading();
    _startHeartbeat();
  }

  /// Stream of MetricSamples received from the probe.
  Stream<MetricSample> get metricStream => _sampleController.stream;

  /// Stream of probe status updates.
  Stream<PcProbeStatus> get statusStream => _statusController.stream;

  /// Stream of raw event maps (markers, screenshots, errors).
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  /// Whether the connection is currently healthy.
  bool get isHealthy => _healthy;

  /// The socket connection.
  Socket get socket => _socket;

  /// Start reading NDJSON lines from the socket.
  void _startReading() {
    // Accumulate data and parse line-by-line
    String buffer = '';
    _socket.listen(
      (data) {
        buffer += utf8.decode(data);
        while (buffer.contains('\n')) {
          final newlineIdx = buffer.indexOf('\n');
          final line = buffer.substring(0, newlineIdx).trim();
          buffer = buffer.substring(newlineIdx + 1);
          if (line.isNotEmpty) {
            _handleLine(line);
          }
        }
        _lastHeartbeat = DateTime.now();
      },
      onError: (error) {
        _healthy = false;
        _heartbeatTimer?.cancel();
        logError('PcProbeConnection read error: $error');
      },
      onDone: () {
        _healthy = false;
        _heartbeatTimer?.cancel();
        _sampleController.close();
        _statusController.close();
        _eventController.close();
      },
    );
  }

  /// Parse a single JSON line from the probe.
  void _handleLine(String line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;

      // Check if it's an event (has "type" field) or a MetricSample
      if (json.containsKey('type')) {
        final eventType = json['type'] as String? ?? '';

        switch (eventType) {
          case 'status':
            final status = PcProbeStatus.fromJson(json);
            _statusController.add(status);
            break;
          case 'marker':
          case 'screenshot':
          case 'video_status':
          case 'error':
            _eventController.add(json);
            break;
          default:
            // Unknown event type — forward as event
            _eventController.add(json);
        }
      } else {
        // Assume MetricSample
        final sample = MetricSample.fromMap(_toSnakeCase(json));
        _sampleController.add(sample);
      }
    } catch (e) {
      logError('Failed to parse probe line: $e');
    }
  }

  /// Convert JSON keys from snake_case for MetricSample.fromMap.
  Map<String, dynamic> _toSnakeCase(Map<String, dynamic> json) {
    // MetricSample.fromMap expects snake_case keys, which is what the probe sends.
    return json;
  }

  /// Start heartbeat ping every 5 seconds.
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_lastHeartbeat.isBefore(
          DateTime.now().subtract(const Duration(seconds: 15)))) {
        _healthy = false;
      }
    });
  }

  /// Send a JSON command to the probe.
  Future<void> _sendCommand(Map<String, dynamic> command) async {
    if (!_healthy) return;
    final json = jsonEncode(command);
    _socket.write('$json\n');
    await _socket.flush();
  }

  /// Start a profiling session.
  Future<void> startSession(String sessionId) async {
    await _sendCommand({'cmd': 'START', 'session_id': sessionId});
  }

  /// Stop the profiling session.
  Future<void> stopSession() async {
    await _sendCommand({'cmd': 'STOP'});
  }

  /// Add a marker during the session.
  Future<void> addMarker(String name, {String note = ''}) async {
    await _sendCommand({'cmd': 'MARKER', 'name': name, 'note': note});
  }

  /// Pause metric collection (keeps IPC alive).
  Future<void> pause() async {
    await _sendCommand({'cmd': 'PAUSE'});
  }

  /// Resume metric collection after pause.
  Future<void> resume() async {
    await _sendCommand({'cmd': 'RESUME'});
  }

  /// Start video recording with the given configuration.
  Future<void> startVideo(PcVideoConfig config) async {
    await _sendCommand({
      'cmd': 'VIDEO_START',
      'width': config.width,
      'height': config.height,
      'fps': config.fps,
      'bitrate_kbps': config.bitrateKbps,
      'capture_target': config.captureTarget,
    });
  }

  /// Stop video recording.
  Future<void> stopVideo() async {
    await _sendCommand({'cmd': 'VIDEO_STOP'});
  }

  /// Request probe status.
  Future<void> requestStatus() async {
    await _sendCommand({'cmd': 'STATUS'});
  }

  /// Close the connection and clean up resources.
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    try {
      await _sendCommand({'cmd': 'STOP'});
    } catch (_) {
      // Probe may already be stopped
    }
    await _socket.close();
    await _sampleController.close();
    await _statusController.close();
    await _eventController.close();
  }
}

/// PC video recording configuration sent to the probe.
class PcVideoConfig {
  final int width;
  final int height;
  final int fps;
  final int bitrateKbps;
  final String captureTarget; // "full_screen" or "window"

  const PcVideoConfig({
    this.width = 1920,
    this.height = 1080,
    this.fps = 30,
    this.bitrateKbps = 8000,
    this.captureTarget = 'full_screen',
  });

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'fps': fps,
        'bitrate_kbps': bitrateKbps,
        'capture_target': captureTarget,
      };
}

/// Probe status received from pb-pcprobe.
class PcProbeStatus {
  final String status; // "running" or "idle"
  final bool paused;
  final String? sessionId;
  final int uptimeS;
  final String? processName;
  final int? processId;

  const PcProbeStatus({
    this.status = 'idle',
    this.paused = false,
    this.sessionId,
    this.uptimeS = 0,
    this.processName,
    this.processId,
  });

  factory PcProbeStatus.fromJson(Map<String, dynamic> json) {
    return PcProbeStatus(
      status: json['status'] as String? ?? 'idle',
      paused: json['paused'] as bool? ?? false,
      sessionId: json['session_id'] as String?,
      uptimeS: json['uptime_s'] as int? ?? 0,
      processName: json['process'] as String?,
      processId: json['pid'] as int?,
    );
  }

  bool get isRunning => status == 'running';
}

/// Service for managing pb-pcprobe connections.
///
/// Handles TCP connection, auto-discovery via mDNS (future), and provides
/// a high-level API for starting/stopping sessions, adding markers, and
/// controlling video recording.
class PcprobeService {
  PcProbeConnection? _connection;

  /// Currently active connection, if any.
  PcProbeConnection? get connection => _connection;
  bool get isConnected => _connection != null;
  bool get isHealthy => _connection?.isHealthy ?? false;

  /// Connect to a pb-pcprobe instance.
  ///
  /// If [host] is null, attempts auto-discovery via mDNS first,
  /// then falls back to 127.0.0.1:27184 (same-machine default).
  Future<PcProbeConnection> connect({
    String? host,
    int? port,
  }) async {
    // Disconnect existing connection first
    await disconnect();

    final connectHost = host ?? '127.0.0.1';
    final connectPort = port ?? 27184;

    // Future: mDNS auto-discovery
    // if (host == null) {
    //   final discovered = await _discoverProbe();
    //   if (discovered != null) {
    //     connectHost = discovered.address;
    //     connectPort = discovered.port;
    //   }
    // }

    final socket = await Socket.connect(
      connectHost,
      connectPort,
      timeout: const Duration(seconds: 10),
    );

    _connection = PcProbeConnection._(
      host: connectHost,
      port: connectPort,
      socket: socket,
    );

    return _connection!;
  }

  /// Start a profiling session on the connected probe.
  Future<void> startSession(String sessionId) async {
    await _connection?.startSession(sessionId);
  }

  /// Stop the profiling session.
  Future<void> stopSession() async {
    await _connection?.stopSession();
  }

  /// Add a marker.
  Future<void> addMarker(String name, {String note = ''}) async {
    await _connection?.addMarker(name, note: note);
  }

  /// Pause collection.
  Future<void> pause() async {
    await _connection?.pause();
  }

  /// Resume collection.
  Future<void> resume() async {
    await _connection?.resume();
  }

  /// Start video recording.
  Future<void> startVideo(PcVideoConfig config) async {
    await _connection?.startVideo(config);
  }

  /// Stop video recording.
  Future<void> stopVideo() async {
    await _connection?.stopVideo();
  }

  /// Disconnect from the probe.
  Future<void> disconnect() async {
    if (_connection != null) {
      await _connection!.disconnect();
      _connection = null;
    }
  }
}

/// Simple logging helper (replace with proper logging in production).
void logError(String message) {
  // ignore: avoid_print
  print('[PcprobeService ERROR] $message');
}
