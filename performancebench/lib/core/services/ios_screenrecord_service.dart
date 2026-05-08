// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, Platform, Process, ProcessSignal;

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../database/video_dao.dart';
import '../models/video.dart';

/// Manages iOS screen recording via pymobiledevice3 DVT screen-mirror.
///
/// Per D-17: Reuses Android ScreenrecordService pattern — start/stop lifecycle,
/// same chunk naming, same Video model schema, same VideoTab playback.
///
/// Per D-18: macOS-only feature. [checkPlatform] throws StateError on non-macOS.
/// Windows/Linux users see disabled button with tooltip.
///
/// Per D-19: Start/stop sync — DVT recording started before first MetricSample,
/// stopped after last.
///
/// Per D-21: Video-only — no audio capture. hasAudio field is always 0.
///
/// Output directory: `dataDir/videos/sessionId/`
/// File naming: `sessionId_chunk_NNN.mp4` (same as Android)
///
/// Threat mitigations:
/// - T-04-21: Python subprocess timeout via SIGTERM -> 3s delay -> SIGKILL.
///   ffmpeg pipe with broken pipe detection.
/// - T-04-20: Video files written to user-specified output directory.
class IosScreenrecordService {
  final String _python3Path;
  final String _agentsDir;
  final VideoDao? _videoDao;
  final String _dataDir;

  Process? _process;
  String? _sessionId;
  String? _udid;
  int _chunkIndex = 0;
  final List<_IosChunkRecord> _chunks = [];
  Timer? _chunkTimer;

  /// Video dimensions and quality settings (per D-20).
  int _width = 1080;
  int _height = 1920;
  int _fps = 30;
  String _qualityPreset = '1080p';
  int _bitrate = 8000; // kbps

  /// Whether a recording is in progress.
  bool get isRecording => _sessionId != null;

  /// Guards: only macOS supports iOS video recording.
  /// Throws [StateError] on non-macOS (per D-18).
  static void checkPlatform() {
    if (!Platform.isMacOS) {
      throw StateError('iOS video recording requires macOS host');
    }
  }

  /// Creates an IosScreenrecordService instance.
  ///
  /// [python3Path] is the path to python3 (e.g., '/usr/bin/python3').
  /// [agentsDir] is the directory containing dvt_recorder.py, collector.py, etc.
  IosScreenrecordService({
    String? python3Path,
    required String agentsDir,
    VideoDao? videoDao,
    required String dataDir,
  })  : _python3Path = python3Path ?? '/usr/bin/python3',
        _agentsDir = agentsDir,
        _videoDao = videoDao,
        _dataDir = dataDir;

  /// Configure video recording settings (per D-20).
  void configure({
    int width = 1080,
    int height = 1920,
    int fps = 30,
    String quality = '1080p',
  }) {
    _width = width;
    _height = height;
    _fps = fps;
    _qualityPreset = quality;
  }

  /// Set bitrate in kbps (maps from quality preset in dvt_recorder_config.py).
  void _applyQualityPreset() {
    switch (_qualityPreset) {
      case '480p':
        _bitrate = 2000;
        _width = 640;
        _height = 480;
        break;
      case '720p':
        _bitrate = 4000;
        _width = 1280;
        _height = 720;
        break;
      case '1080p':
      default:
        _bitrate = 8000;
        _width = 1080;
        _height = 1920;
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Start / Stop / Abort lifecycle
  // ---------------------------------------------------------------------------

  /// Start iOS DVT screen recording.
  ///
  /// Spawns `dvt_recorder.py` as a Python subprocess. The process writes
  /// JSON status lines to stdout which are parsed by [_onDvtLine].
  ///
  /// Returns true if recording started successfully.
  /// Throws [StateError] on non-macOS platforms.
  Future<bool> start({
    required String sessionId,
    required String udid,
  }) async {
    checkPlatform();

    if (isRecording) return false;

    _sessionId = sessionId;
    _udid = udid;
    _chunkIndex = 0;
    _chunks.clear();
    _applyQualityPreset();

    await _spawnDvtRecorder(udid, sessionId);
    return true;
  }

  /// Spawn the dvt_recorder.py subprocess and begin parsing stdout.
  Future<void> _spawnDvtRecorder(String udid, String sessionId) async {
    final outputDir = p.join(_dataDir, 'videos');

    _process = await Process.start(
      _python3Path,
      [
        p.join(_agentsDir, 'dvt_recorder.py'),
        udid,
        '--quality', _qualityPreset,
        '--fps', _fps.toString(),
        '--output-dir', outputDir,
        '--session-id', sessionId,
      ],
    );

    // Parse stdout JSON lines
    // ignore: unawaited_futures
    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onDvtLine);

    // Log stderr for diagnostics
    // ignore: unawaited_futures
    _process!.stderr.transform(utf8.decoder).listen((line) {
      // ignore: avoid_print
      print('[ios_screenrecord stderr] $line');
    });
  }

  /// Parse a JSON status line from dvt_recorder.py stdout.
  void _onDvtLine(String line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final event = json['event'] as String?;

      switch (event) {
        case 'recording_started':
          // Recording is active; update chunk tracking
          break;

        case 'chunk_start':
          _chunkIndex = json['chunk'] as int;
          _chunks.add(_IosChunkRecord(
            chunkIndex: _chunkIndex,
            fileName: json['file'] as String,
            startMs: json['timestamp_ms'] as int,
          ));
          break;

        case 'chunk_end':
          // Chunk completed successfully
          break;

        case 'chunk_error':
          // Log error but continue to next chunk
          // ignore: avoid_print
          print('[ios_screenrecord] Chunk ${json['chunk']} error: ${json['error']}');
          break;

        case 'recording_stopped':
          // Already handled by stop() method
          _process = null;
          break;

        case 'fatal_error':
          // Recording failed entirely
          // ignore: avoid_print
          print('[ios_screenrecord] Fatal error: ${json['error']}');
          _process = null;
          _sessionId = null;
          break;

        case 'signal_received':
          // SIGTERM receipt acknowledged
          break;

        default:
          // Unknown event — skip
          break;
      }
    } catch (_) {
      // Malformed JSON line — skip, continue
    }
  }

  /// Stop recording.
  ///
  /// Sends SIGTERM to the Python subprocess, waits 3 seconds for graceful
  /// shutdown, then sends SIGKILL if still alive (per T-04-21).
  /// Pulls chunk metadata, builds a [Video] model, and saves via [VideoDao].
  ///
  /// Returns the [Video] record if successful, or null if no recording
  /// was active or no chunks were recorded.
  Future<Video?> stop() async {
    if (_sessionId == null || _udid == null) return null;

    // Cancel any pending chunk timer
    _chunkTimer?.cancel();
    _chunkTimer = null;

    // SIGTERM for graceful shutdown
    if (_process != null) {
      _process!.kill(ProcessSignal.sigterm);
      await Future.delayed(const Duration(seconds: 3));
      if (_process != null) {
        _process!.kill(ProcessSignal.sigkill);
        _process = null;
      }
    }

    final sessionId = _sessionId!;

    // Return null if no chunks were recorded
    if (_chunks.isEmpty) {
      _sessionId = null;
      return null;
    }

    // Build chunk metadata array. Each chunk's duration is the gap to the
    // next chunk's start; the last chunk runs from its start to wall-clock
    // stop. Old code multiplied chunk count by a hardcoded 300_000 ms and
    // mis-counted aborted runs.
    final stopMs = DateTime.now().millisecondsSinceEpoch;
    final chunksJson = <Map<String, dynamic>>[];
    for (var i = 0; i < _chunks.length; i++) {
      final c = _chunks[i];
      final endMs = (i + 1 < _chunks.length) ? _chunks[i + 1].startMs : stopMs;
      chunksJson.add({
        'chunk': c.chunkIndex,
        'file': c.fileName,
        'startMs': c.startMs,
        'durationMs': endMs - c.startMs,
      });
    }
    final totalDurationMs = stopMs - _chunks.first.startMs;
    final primaryFile = _chunks.first.fileName;

    // Build Video record following ScreenrecordService pattern (per D-17)
    final video = Video(
      sessionId: sessionId,
      filepath: p.join(_dataDir, 'videos', sessionId, primaryFile),
      codec: 'h264',
      container: 'mp4',
      widthPx: _width,
      heightPx: _height,
      targetFps: _fps,
      actualAvgFps: null,
      bitrateKbps: _bitrate,
      durationMs: totalDurationMs,
      fileSizeBytes: 0, // Updated after file stat — caller refreshes
      chunksJson: jsonEncode(chunksJson),
      gapsJson: null,
      hasAudio: 0, // Per D-21: video-only, no audio
      recordingOverheadEstimatePct: 5.0,
      startedAt: _chunks.first.startMs,
      endedAt: DateTime.now().millisecondsSinceEpoch,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    // Save to database if VideoDao is available
    if (_videoDao != null) {
      final dao = _videoDao;
      // ignore: unawaited_futures
      dao.insert(video);
    }

    // Reset state
    _sessionId = null;
    _udid = null;
    _chunkIndex = 0;
    _chunks.clear();

    return video;
  }

  /// Abort recording without saving video metadata.
  ///
  /// Kills the DVT subprocess (SIGTERM -> 3s -> SIGKILL).
  /// Cleans up internal state. Does not write to the database.
  Future<void> abort() async {
    _chunkTimer?.cancel();
    _chunkTimer = null;

    if (_process != null) {
      _process!.kill(ProcessSignal.sigterm);
      await Future.delayed(const Duration(seconds: 3));
      _process!.kill(ProcessSignal.sigkill);
      _process = null;
    }

    _sessionId = null;
    _udid = null;
    _chunkIndex = 0;
    _chunks.clear();
  }

  // ---------------------------------------------------------------------------
  // Test support
  // ---------------------------------------------------------------------------

  /// For testing: manually add a chunk record.
  /// Used to test Video model construction without spawning Python process.
  @visibleForTesting
  void addChunkForTest({required int index, required String fileName, required int startMs}) {
    _chunks.add(_IosChunkRecord(
      chunkIndex: index,
      fileName: fileName,
      startMs: startMs,
    ));
    _chunkIndex = index;
  }
}

/// Internal record for tracking a single video chunk during iOS recording.
class _IosChunkRecord {
  final int chunkIndex;
  final String fileName;
  final int startMs;

  const _IosChunkRecord({
    required this.chunkIndex,
    required this.fileName,
    required this.startMs,
  });
}
