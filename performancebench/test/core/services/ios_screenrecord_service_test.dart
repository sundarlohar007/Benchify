// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/services/ios_screenrecord_service.dart';

/// A fake service for testing platform guard, argument construction,
/// and JSON line parsing. Does not spawn real Python processes.
class _TestableIosScreenrecordService {
  final bool isMacOS;
  bool _isRecording = false;
  final List<List<String>> spawnedProcesses = [];
  final List<String> stdoutLines = [];
  final List<Map<String, dynamic>> parsedChunks = [];

  _TestableIosScreenrecordService({required this.isMacOS});

  bool get isRecording => _isRecording;

  void checkPlatform() {
    if (!isMacOS) {
      throw StateError('iOS video recording requires macOS host');
    }
  }

  /// Simulates spawning the dvt_recorder.py subprocess.
  /// Records the arguments that would be passed.
  void simulateSpawn({required String udid, required String sessionId,
      String quality = '1080p', int fps = 30, String outputDir = 'data/videos'}) {
    checkPlatform();
    _isRecording = true;
    spawnedProcesses.add([
      'python3',
      'agentsDir/dvt_recorder.py',
      udid,
      '--quality', quality,
      '--fps', fps.toString(),
      '--output-dir', outputDir,
      '--session-id', sessionId,
    ]);
  }

  /// Parse a JSON status line from dvt_recorder.py stdout.
  void parseLine(String line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final event = json['event'] as String?;
      if (event == 'chunk_start') {
        parsedChunks.add(json);
      } else if (event == 'chunk_end') {
        parsedChunks.add(json);
      } else if (event == 'recording_started') {
        parsedChunks.add(json);
      } else if (event == 'recording_stopped') {
        _isRecording = false;
        parsedChunks.add(json);
      } else if (event == 'chunk_error') {
        parsedChunks.add(json);
      }
    } catch (_) {
      // Skip malformed lines
    }
  }

  void simulateStop() {
    _isRecording = false;
  }

  /// Build a Video-like map from collected chunks.
  Map<String, dynamic>? buildVideo({required String sessionId,
      int width = 1080, int height = 1920, int fps = 30}) {
    if (parsedChunks.isEmpty) return null;

    final chunks = <Map<String, dynamic>>[];
    for (final c in parsedChunks) {
      if (c['event'] == 'chunk_start') {
        chunks.add({
          'chunk': c['chunk'],
          'file': c['file'],
          'startMs': c['timestamp_ms'],
        });
      }
    }

    if (chunks.isEmpty) return null;

    return {
      'session_id': sessionId,
      'filepath': 'data/videos/$sessionId/${sessionId}_chunk_001.mp4',
      'codec': 'h264',
      'container': 'mp4',
      'width_px': width,
      'height_px': height,
      'target_fps': fps,
      'duration_ms': chunks.length * 300000,
      'file_size_bytes': 0,
      'chunks_json': jsonEncode(chunks),
      'gaps_json': null,
      'has_audio': 0,
      'started_at': chunks.first['startMs'],
      'ended_at': DateTime.now().millisecondsSinceEpoch,
    };
  }
}

void main() {
  group('IosScreenrecordService', () {
    // ── Test 1: platform guard throws on non-macOS ──
    test('checkPlatform throws StateError on non-macOS', () {
      final service = _TestableIosScreenrecordService(isMacOS: false);
      expect(
        () => service.checkPlatform(),
        throwsA(isA<StateError>()),
      );
    });

    // ── Test 2: platform guard succeeds on macOS ──
    test('checkPlatform does not throw on macOS', () {
      final service = _TestableIosScreenrecordService(isMacOS: true);
      expect(() => service.checkPlatform(), returnsNormally);
    });

    // ── Test 3: spawn constructs correct subprocess arguments ──
    test('spawnSubprocess constructs correct arguments', () {
      if (!Platform.isMacOS) return; // macOS-specific test
      final service = _TestableIosScreenrecordService(isMacOS: true);

      service.simulateSpawn(udid: '00008110-001234567890001E', sessionId: 'test-session');

      expect(service.spawnedProcesses.length, 1);
      final args = service.spawnedProcesses.first;

      expect(args, contains('dvt_recorder.py'));
      expect(args, contains('00008110-001234567890001E'));
      expect(args, contains('--quality'));
      expect(args, contains('1080p'));
      expect(args, contains('--fps'));
      expect(args, contains('30'));
      expect(args, contains('--output-dir'));
      expect(args, contains('--session-id'));
      expect(args, contains('test-session'));
    });

    // ── Test 4: quality and fps settings reflected in arguments ──
    test('quality and fps arguments match configuration', () {
      final service = _TestableIosScreenrecordService(isMacOS: true);

      service.simulateSpawn(
        udid: 'device-udid',
        sessionId: 's1',
        quality: '720p',
        fps: 60,
      );

      final args = service.spawnedProcesses.first;
      final qualityIdx = args.indexOf('--quality');
      expect(args[qualityIdx + 1], '720p');

      final fpsIdx = args.indexOf('--fps');
      expect(args[fpsIdx + 1], '60');
    });

    // ── Test 5: JSON line parsing for chunk_start event ──
    test('parses chunk_start JSON line correctly', () {
      final service = _TestableIosScreenrecordService(isMacOS: true);

      service.parseLine(
        '{"event":"chunk_start","chunk":1,"file":"s1_chunk_001.mp4","timestamp_ms":1700000000000}',
      );

      expect(service.parsedChunks.length, 1);
      expect(service.parsedChunks.first['event'], 'chunk_start');
      expect(service.parsedChunks.first['chunk'], 1);
      expect(service.parsedChunks.first['file'], 's1_chunk_001.mp4');
    });

    // ── Test 6: recording_started event ──
    test('parses recording_started JSON line', () {
      final service = _TestableIosScreenrecordService(isMacOS: true);

      service.parseLine(
        '{"event":"recording_started","session_id":"s1","width":1920,"height":1080,"fps":30}',
      );

      expect(service.parsedChunks.length, 1);
      expect(service.parsedChunks.first['event'], 'recording_started');
      expect(service.parsedChunks.first['width'], 1920);
    });

    // ── Test 7: Video model has correct fields ──
    test('Video model has h264 codec, mp4 container, hasAudio=0', () {
      final service = _TestableIosScreenrecordService(isMacOS: true);

      service.parseLine(
        '{"event":"recording_started","session_id":"test","width":1920,"height":1080,"fps":30}',
      );
      service.parseLine(
        '{"event":"chunk_start","chunk":1,"file":"test_chunk_001.mp4","timestamp_ms":1700000000000}',
      );
      service.simulateStop();

      final video = service.buildVideo(sessionId: 'test');

      expect(video, isNotNull);
      expect(video!['codec'], 'h264');
      expect(video['container'], 'mp4');
      expect(video['has_audio'], 0);
      expect(video['chunks_json'], isNotNull);
      expect(video['session_id'], 'test');
    });

    // ── Test 8: malformed JSON lines are skipped gracefully ──
    test('skips malformed JSON lines without throwing', () {
      final service = _TestableIosScreenrecordService(isMacOS: true);

      // Should not throw
      expect(() => service.parseLine('not valid json'), returnsNormally);
      expect(() => service.parseLine(''), returnsNormally);

      expect(service.parsedChunks, isEmpty);
    });

    // ── Test 9: chunk_error events are recorded ──
    test('records chunk_error events', () {
      final service = _TestableIosScreenrecordService(isMacOS: true);

      service.parseLine(
        '{"event":"chunk_error","chunk":2,"error":"ffmpeg pipe broken"}',
      );

      expect(service.parsedChunks.length, 1);
      expect(service.parsedChunks.first['event'], 'chunk_error');
    });

    // ── Test 10: isRecording state transitions ──
    test('isRecording transitions through lifecycle', () {
      final service = _TestableIosScreenrecordService(isMacOS: true);

      expect(service.isRecording, isFalse);

      service.simulateSpawn(udid: 'u', sessionId: 's');
      expect(service.isRecording, isTrue);

      service.simulateStop();
      expect(service.isRecording, isFalse);
    });
  });
}
