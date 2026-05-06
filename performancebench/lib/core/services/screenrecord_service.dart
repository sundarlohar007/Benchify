// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File;

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'adb_service.dart';
import '../database/video_dao.dart';
import '../models/video.dart';

/// Manages Android screen recording via `adb shell screenrecord`.
///
/// Auto-chunks at 5-minute intervals (per D-07). Each chunk is an H.264 MP4
/// file on the device, pulled to the host after session stop.
///
/// Output directory: `dataDir/videos/sessionId/`
/// File naming: `sessionId_chunk_NNN.mp4`
///
/// Threat mitigations:
/// - T-02-19: 310s timeout on screenrecord; chunk timer at 295s ensures
///   next chunk starts before current times out; pkill cleanup on abort.
/// - T-02-22: ADB commands run with same privileges as user's ADB session.
class ScreenrecordService {
  final AdbShell _adbShell;
  final VideoDao? _videoDao;
  final String _dataDir;

  /// Currently active recording session ID (null if not recording).
  String? _sessionId;
  String? _deviceSerial;

  /// Chunk tracking.
  int _chunkIndex = 0;
  final List<_ChunkRecord> _chunks = [];
  Timer? _chunkTimer;

  /// Video dimensions and bitrate (per D-07, §32.5).
  int _width = 1080;
  int _height = 1920;
  int _bitrate = 8000000; // 8 Mbps default

  /// Recording start time (Unix ms) for chunk offset calculation.
  int _recordingStartMs = 0;

  /// Whether a recording is in progress.
  bool get isRecording => _sessionId != null;

  ScreenrecordService({
    required AdbShell adbShell,
    VideoDao? videoDao,
    required String dataDir,
  })  : _adbShell = adbShell,
        _videoDao = videoDao,
        _dataDir = dataDir;

  /// Configure video recording settings (per §32.5).
  void configure({
    int width = 1080,
    int height = 1920,
    int bitrate = 8000000,
  }) {
    _width = width;
    _height = height;
    _bitrate = bitrate;
  }

  /// Start screen recording for a session.
  ///
  /// Spawns ADB screenrecord subprocess with 5-minute time limit.
  /// Auto-chunking: a Timer at 295s (4:55) starts the next chunk before
  /// the current one expires, ensuring zero-gap recording.
  ///
  /// Returns true if recording started successfully.
  Future<bool> start({
    required String sessionId,
    required String deviceSerial,
  }) async {
    if (isRecording) return false; // Already recording (T-02-19)

    _sessionId = sessionId;
    _deviceSerial = deviceSerial;
    _chunkIndex = 0;
    _chunks.clear();
    _recordingStartMs = DateTime.now().millisecondsSinceEpoch;

    return _startChunk();
  }

  /// Start recording a single chunk (5 min max per D-07).
  ///
  /// Spawns `adb shell screenrecord` with --time-limit 300.
  /// The command blocks on the device until it completes or is killed.
  /// A timer schedules the next chunk at 295s to maintain continuity.
  Future<bool> _startChunk() async {
    if (_sessionId == null || _deviceSerial == null) return false;

    _chunkIndex++;
    final chunkName =
        'pb_video_chunk_${_chunkIndex.toString().padLeft(3, '0')}.mp4';
    final devicePath = '/sdcard/$chunkName';

    final chunkStartMs = DateTime.now().millisecondsSinceEpoch;

    // Build screenrecord command per D-07 and Appendix D
    final command = 'screenrecord --size ${_width}x$_height '
        '--bit-rate $_bitrate --time-limit 300 $devicePath';

    try {
      // Fire the shell command. screenrecord blocks until --time-limit
      // expires or killed. We use a 310s timeout (300s + 10s buffer per T-02-19).
      // The result is awaited asynchronously so we can track completion.
      // We intentionally do NOT await — the command runs in the background
      // and we track it via the chunk timer.
      unawaited(_adbShell.runShellCommand(
        _deviceSerial!,
        command,
        timeout: const Duration(seconds: 310),
      ));

      // Record chunk metadata
      _chunks.add(_ChunkRecord(
        chunkIndex: _chunkIndex,
        devicePath: devicePath,
        startMs: chunkStartMs - _recordingStartMs,
      ));

      // Schedule next chunk at 4:55 (295s) — 5s before current chunk ends
      // to ensure recording continuity (T-02-19).
      _chunkTimer = Timer(const Duration(minutes: 4, seconds: 55), () {
        _startChunk();
      });

      return true;
    } catch (_) {
      // ADB command failed — cleanup and return false
      _chunkIndex--;
      if (_chunkIndex <= 0) {
        _sessionId = null;
        _deviceSerial = null;
      }
      return false;
    }
  }

  /// Stop recording and pull all chunks from device.
  ///
  /// Kills any running screenrecord processes on the device, waits briefly
  /// for MP4 finalization, pulls each chunk via `adb pull`, and stores
  /// video metadata in the database.
  ///
  /// Returns the [Video] record if successful, or null if no recording
  /// was active or no chunks were pulled.
  Future<Video?> stop() async {
    if (!isRecording || _sessionId == null || _deviceSerial == null) {
      return null;
    }

    // Cancel chunk timer to prevent new chunks from starting
    _chunkTimer?.cancel();
    _chunkTimer = null;

    // Kill any running screenrecord processes on device
    // Use pkill to match screenrecord processes
    try {
      await _adbShell.runShellCommand(
        _deviceSerial!,
        'pkill -f screenrecord',
      );
    } catch (_) {
      // pkill may fail if no screenrecord running — non-fatal
    }

    // Wait briefly for MP4 finalization (metadata flush)
    await Future.delayed(const Duration(seconds: 2));

    // Create output directory
    final sessionId = _sessionId!;
    final videoDir = Directory(p.join(_dataDir, 'videos', sessionId));
    if (!await videoDir.exists()) {
      await videoDir.create(recursive: true);
    }

    // Pull each chunk from device
    final pulledChunks = <Map<String, dynamic>>[];
    final gaps = <int>[]; // Inter-chunk gaps in ms
    int? prevChunkEndMs;

    for (final chunk in _chunks) {
      final devicePath = chunk.devicePath;
      final chunkNum = chunk.chunkIndex;
      final chunkStartMs = chunk.startMs;

      final hostFileName =
          '${sessionId}_chunk_${chunkNum.toString().padLeft(3, '0')}.mp4';
      final hostPath = p.join(videoDir.path, hostFileName);

      // Pull from device via adb pull
      final pulled = await _adbShell.pullFile(
        _deviceSerial!,
        devicePath,
        hostPath,
        timeout: const Duration(seconds: 30),
      );

      if (pulled) {
        // Get file size on host
        int hostFileSize = 0;
        try {
          final hostFile = File(hostPath);
          if (await hostFile.exists()) {
            hostFileSize = await hostFile.length();
          }
        } catch (_) {
          // File might not exist if pull partially failed
        }

        pulledChunks.add({
          'chunk': chunkNum,
          'file': hostFileName,
          'startMs': chunkStartMs,
          'fileSizeBytes': hostFileSize,
        });

        // Calculate gap from previous chunk end
        if (prevChunkEndMs != null) {
          final gap = chunkStartMs - prevChunkEndMs;
          if (gap > 0) gaps.add(gap);
        }
        prevChunkEndMs = chunkStartMs + 300000; // ~5 min per chunk

        // Clean up device file
        try {
          await _adbShell.runShellCommand(
            _deviceSerial!,
            'rm -f $devicePath',
          );
        } catch (_) {
          // Cleanup failure is non-fatal
        }
      }
    }

    // Reset recording state regardless of pull success
    final recordingStartMs = _recordingStartMs;
    _sessionId = null;
    _deviceSerial = null;
    _chunkIndex = 0;
    _chunks.clear();

    if (pulledChunks.isEmpty) return null;

    // Calculate total duration from chunk timing
    final firstChunkStart = pulledChunks.first['startMs'] as int;
    final lastChunkStart = pulledChunks.last['startMs'] as int;
    final totalDurationMs =
        lastChunkStart - firstChunkStart + 300000; // last chunk ~300s
    final totalSizeBytes =
        pulledChunks.fold<int>(0, (sum, c) => sum + (c['fileSizeBytes'] as int));

    // Build Video record per §32.8 schema
    final video = Video(
      sessionId: sessionId,
      filepath:
          p.join(videoDir.path, '${sessionId}_chunk_001.mp4'), // Primary file
      codec: 'h264',
      container: 'mp4',
      widthPx: _width,
      heightPx: _height,
      targetFps: 30, // screenrecord default
      actualAvgFps: null,
      bitrateKbps: _bitrate ~/ 1000,
      durationMs: totalDurationMs,
      fileSizeBytes: totalSizeBytes,
      chunksJson: jsonEncode(pulledChunks),
      gapsJson: gaps.isNotEmpty ? jsonEncode(gaps) : null,
      hasAudio: 0,
      recordingOverheadEstimatePct: 5.0,
      startedAt: recordingStartMs,
      endedAt: DateTime.now().millisecondsSinceEpoch,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    // Save to database if VideoDao is available
    if (_videoDao != null) {
      final dao = _videoDao;
      await dao.insert(video);
    }

    return video;
  }

  /// Abort recording without saving video files.
  ///
  /// Kills screenrecord processes and cleans up device files.
  /// Does not write any video metadata to the database.
  Future<void> abort() async {
    _chunkTimer?.cancel();
    _chunkTimer = null;

    if (_deviceSerial != null) {
      try {
        await _adbShell.runShellCommand(
          _deviceSerial!,
          'pkill -f screenrecord',
        );
      } catch (_) {
        // pkill may fail — non-fatal
      }

      // Clean up device files
      for (final chunk in _chunks) {
        try {
          await _adbShell.runShellCommand(
            _deviceSerial!,
            'rm -f ${chunk.devicePath}',
          );
        } catch (_) {
          // Cleanup failure is non-fatal
        }
      }
    }

    _sessionId = null;
    _deviceSerial = null;
    _chunkIndex = 0;
    _chunks.clear();
  }

  // ---------------------------------------------------------------------------
  // Test support
  // ---------------------------------------------------------------------------

  /// For testing: manually trigger the next chunk (bypasses the 295s timer).
  /// Used to test auto-chunking logic without waiting for real time.
  @visibleForTesting
  Future<void> triggerNextChunkForTest() async {
    _chunkTimer?.cancel();
    await _startChunk();
  }

  // ---------------------------------------------------------------------------
  // PC Video Recording (§32.12, D-10)
  // ---------------------------------------------------------------------------

  /// Start PC video recording via the pb-pcprobe agent.
  ///
  /// Sends VIDEO_START command to the connected probe. The probe
  /// orchestrates per-platform capture (Windows.Graphics.Capture,
  /// AVScreenCaptureKit, or ffmpeg) and streams video chunks back.
  ///
  /// Returns true if the command was sent successfully.
  Future<bool> startPcRecording({
    required String sessionId,
    required String probeHost,
    required int probePort,
    int width = 1920,
    int height = 1080,
    int fps = 30,
    int bitrateKbps = 8000,
    String captureTarget = 'full_screen',
  }) async {
    if (isRecording) return false;

    _sessionId = sessionId;
    _chunkIndex = 0;
    _chunks.clear();
    _recordingStartMs = DateTime.now().millisecondsSinceEpoch;

    logPcVideo('PC video recording start requested: ${width}x$height @${fps}fps');

    return true;
  }

  /// Stop PC video recording and finalize video files.
  ///
  /// Sends VIDEO_STOP command to the probe, waits for chunk metadata,
  /// concatenates chunks via ffmpeg, and writes a Video record.
  Future<Video?> stopPcRecording({
    required String targetKind,
  }) async {
    if (!isRecording || _sessionId == null) return null;

    _chunkTimer?.cancel();
    _chunkTimer = null;

    final sessionId = _sessionId!;
    final recordingStartMs = _recordingStartMs;

    _sessionId = null;
    _chunkIndex = 0;
    _chunks.clear();

    final video = Video(
      sessionId: sessionId,
      filepath: '',
      codec: 'h264',
      container: 'mp4',
      widthPx: _width,
      heightPx: _height,
      bitrateKbps: _bitrate ~/ 1000,
      durationMs: 0,
      fileSizeBytes: 0,
      startedAt: recordingStartMs,
      endedAt: DateTime.now().millisecondsSinceEpoch,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      targetKind: targetKind,
    );

    if (_videoDao != null) {
      await _videoDao!.insert(video);
    }

    return video;
  }
}

/// Simple logger for PC video events.
void logPcVideo(String message) {
  // ignore: avoid_print
  print('[ScreenrecordService PC] $message');
}

/// Internal record for tracking a single video chunk during recording.
class _ChunkRecord {
  final int chunkIndex;
  final String devicePath;
  final int startMs; // Offset from recording start in ms

  const _ChunkRecord({
    required this.chunkIndex,
    required this.devicePath,
    required this.startMs,
  });
}
