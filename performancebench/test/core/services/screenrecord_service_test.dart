// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/database/video_dao.dart';
import 'package:performancebench/core/models/video.dart';
import 'package:performancebench/core/services/adb_service.dart';
import 'package:performancebench/core/services/screenrecord_service.dart';

/// A fake ADB shell that records all commands for verification.
/// Allows tests to control command outcomes and inspect what was called.
class _FakeAdbShell extends AdbShell {
  final List<_AdbCall> calls = [];
  final Map<String, dynamic> _responses = <String, dynamic>{};
  bool allCommandsSucceed = true;

  /// Register a canned response for a command substring match.
  void whenCommandContains(String substring, dynamic response) {
    _responses[substring] = response;
  }

  @override
  Future<String?> runShellCommand(
    String serial,
    String command, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    calls.add(_AdbCall('shell', serial, command, timeout));
    if (!allCommandsSucceed) return null;

    // Check for canned responses
    for (final entry in _responses.entries) {
      if (command.contains(entry.key)) {
        final resp = entry.value;
        if (resp is String?) return resp;
        return resp.toString();
      }
    }
    return 'OK'; // default success
  }

  @override
  Future<bool> pullFile(
    String serial,
    String remotePath,
    String localPath, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    calls.add(_AdbCall('pull', serial, '$remotePath -> $localPath', timeout));
    return allCommandsSucceed;
  }
}

class _AdbCall {
  final String type; // 'shell' or 'pull'
  final String serial;
  final String command;
  final Duration timeout;
  const _AdbCall(this.type, this.serial, this.command, this.timeout);
}

void main() {
  group('ScreenrecordService', () {
    late _FakeAdbShell fakeShell;
    late ScreenrecordService service;
    // We use an in-memory VideoDao — the service calls insert/updates,
    // we verify through the _FakeVideoDao.
    // For brevity, we use a real VideoDao against a test DB, or we stub.
    // Since Database requires FFI, we test the service through the ADB interface
    // and test the VideoDao integration separately.

    setUp(() {
      fakeShell = _FakeAdbShell();
      service = ScreenrecordService(
        adbShell: fakeShell,
        videoDao: null, // Will be provided when integration DB is available
        dataDir: 'test/videos',
      );
      service.configure(width: 1080, height: 1920, bitrate: 8000000);
    });

    // ── Test 1: start() spawns correct screenrecord command ──
    test('start() spawns screenrecord with correct arguments', () async {
      final result = await service.start(
        sessionId: 'test-session-001',
        deviceSerial: 'emulator-5554',
      );

      expect(result, isTrue);
      expect(fakeShell.calls.length, greaterThanOrEqualTo(1));

      final screenrecordCall = fakeShell.calls.firstWhere(
        (c) => c.command.contains('screenrecord'),
      );
      expect(
        screenrecordCall.command,
        contains('--size 1080x1920'),
      );
      expect(
        screenrecordCall.command,
        contains('--bit-rate 8000000'),
      );
      expect(
        screenrecordCall.command,
        contains('--time-limit 300'),
      );
      expect(
        screenrecordCall.command,
        contains('/sdcard/pb_video_chunk_001.mp4'),
      );
      expect(screenrecordCall.serial, 'emulator-5554');
      // Verify timeout is 310s (5 min + 10s buffer per T-02-19)
      expect(screenrecordCall.timeout.inSeconds, 310);
    });

    // ── Test 2: Auto-chunking — second call increments chunk counter ──
    test('auto-chunking creates chunk_002 after first chunk scheduled', () async {
      await service.start(
        sessionId: 'test-session-002',
        deviceSerial: 'emulator-5554',
      );

      // Manually trigger the chunk timer callback to simulate 5-minute expiry
      await service.triggerNextChunkForTest();

      // Should now have two screenrecord calls
      final screenrecordCalls =
          fakeShell.calls.where((c) => c.command.contains('screenrecord')).toList();
      expect(screenrecordCalls.length, 2);

      // Second chunk should be 002
      expect(
        screenrecordCalls[1].command,
        contains('pb_video_chunk_002.mp4'),
      );
    });

    // ── Test 3: On session stop, chunks are pulled from device ──
    test('stop() pulls all chunks from device and returns Video', () async {
      await service.start(
        sessionId: 'test-session-003',
        deviceSerial: 'emulator-5554',
      );
      // Trigger one more chunk
      await service.triggerNextChunkForTest();

      // Stop recording — should pull both chunks
      final video = await service.stop();

      expect(video, isNotNull);
      // Verify pullFile was called for each chunk
      final pullCalls = fakeShell.calls.where((c) => c.type == 'pull').toList();
      expect(pullCalls.length, 2);
      expect(pullCalls[0].command, contains('pb_video_chunk_001.mp4'));
      expect(pullCalls[1].command, contains('pb_video_chunk_002.mp4'));
    });

    // ── Test 4: Video metadata has correct fields ──
    test('Video metadata has correct dimensions, codec, bitrate', () async {
      await service.start(
        sessionId: 'test-session-004',
        deviceSerial: 'emulator-5554',
      );
      final video = await service.stop();

      expect(video, isNotNull);
      expect(video!.sessionId, 'test-session-004');
      expect(video.codec, 'h264');
      expect(video.container, 'mp4');
      expect(video.widthPx, 1080);
      expect(video.heightPx, 1920);
      expect(video.bitrateKbps, 8000); // 8000000 bps / 1000
      expect(video.hasAudio, 0);
      expect(video.recordingOverheadEstimatePct, closeTo(5.0, 0.1));
      expect(video.filepath, contains('test-session-004_chunk_001.mp4'));
    });

    // ── Test 5: isRecording transitions correctly ──
    test('isRecording returns correct state through lifecycle', () async {
      expect(service.isRecording, isFalse);

      await service.start(
        sessionId: 'test-session-005',
        deviceSerial: 'emulator-5554',
      );
      expect(service.isRecording, isTrue);

      await service.stop();
      expect(service.isRecording, isFalse);
    });

    // ── Test 6: Chunks JSON contains correct array ──
    test('chunks_json contains array with correct chunk metadata', () async {
      await service.start(
        sessionId: 'test-session-006',
        deviceSerial: 'emulator-5554',
      );
      await service.triggerNextChunkForTest();
      final video = await service.stop();

      expect(video, isNotNull);
      expect(video!.chunksJson, isNotNull);
      final chunks = jsonDecode(video.chunksJson!) as List<dynamic>;
      expect(chunks.length, 2);
      expect(chunks[0]['chunk'], 1);
      expect(chunks[0]['startMs'], isA<int>());
      expect(chunks[0]['file'], 'test-session-006_chunk_001.mp4');
      expect(chunks[1]['chunk'], 2);
      expect(chunks[1]['startMs'], isA<int>());
      expect(chunks[1]['file'], 'test-session-006_chunk_002.mp4');
    });

    // ── Test 7: start() when already recording → returns false ──
    test('start() when already recording returns false', () async {
      final first = await service.start(
        sessionId: 'test-session-007',
        deviceSerial: 'emulator-5554',
      );
      expect(first, isTrue);

      final second = await service.start(
        sessionId: 'test-session-007b',
        deviceSerial: 'emulator-5554',
      );
      expect(second, isFalse);

      // Only one screenrecord call should have been made
      final screenrecordCalls =
          fakeShell.calls.where((c) => c.command.contains('screenrecord')).toList();
      expect(screenrecordCalls.length, 1);
    });

    // ── Test 8: stop() when not recording → returns null, no crash ──
    test('stop() when not recording returns null', () async {
      expect(service.isRecording, isFalse);
      final video = await service.stop();
      expect(video, isNull);
      // No crash, no ADB calls for cleanup
    });

    // ── Test 9: ADB command timeout → graceful failure ──
    test('start() when ADB shell fails → returns false', () async {
      fakeShell.allCommandsSucceed = false;

      final result = await service.start(
        sessionId: 'test-session-009',
        deviceSerial: 'emulator-5554',
      );

      expect(result, isFalse);
      expect(service.isRecording, isFalse);
    });
  });
}
