---
phase: 02-v1-5-analysis-platform-expansion
plan: 05
type: execute
wave: 5
depends_on:
  - 04
files_modified:
  - performancebench/lib/core/services/screenrecord_service.dart
  - performancebench/lib/core/services/adb_service.dart
  - performancebench/lib/core/database/video_dao.dart
  - performancebench/lib/core/models/video.dart
  - performancebench/lib/features/session_detail/video_tab.dart
  - performancebench/lib/features/session_detail/detail_screen.dart
  - performancebench/lib/features/session_detail/replay_charts_tab.dart
  - performancebench/lib/shared/widgets/video_player_widget.dart
  - performancebench/lib/shared/providers/playhead_provider.dart
  - performancebench/test/core/services/screenrecord_service_test.dart
  - performancebench/test/widgets/video_chart_sync_test.dart
autonomous: true
requirements:
  - V15-11
  - V15-12

must_haves:
  truths:
    - "Android screen recording saves H.264 MP4 chunks to data/videos/ during profiling session"
    - "Each chunk is 5 minutes, named <session_id>_chunk_001.mp4, auto-created without user action"
    - "Session detail has Video tab with video player (left) and charts panel (right)"
    - "Scrubbing the video repositions chart cursor to matching timestamp"
    - "Scrubbing any chart seeks the video to matching timestamp"
    - "Shared scrub bar at bottom controls both video and charts simultaneously"
  artifacts:
    - path: "performancebench/lib/core/services/screenrecord_service.dart"
      provides: "Manages adb shell screenrecord subprocess — starts/stops recording, auto-chunks every 5 minutes"
      exports: ["ScreenrecordService", "start", "stop", "isRecording"]
      min_lines: 100
    - path: "performancebench/lib/features/session_detail/video_tab.dart"
      provides: "Side-by-side video + charts layout per D-06 — video panel left, charts right, shared scrub bar"
      contains: ["VideoPlayerWidget", "shared scrub bar", "chart sync"]
      min_lines: 120
    - path: "performancebench/lib/shared/providers/playhead_provider.dart"
      provides: "Riverpod StateProvider<int> for shared playhead_ts in milliseconds — synced between video and charts"
      exports: ["playheadProvider"]
  key_links:
    - from: "video_tab.dart VideoPlayerWidget"
      to: "playhead_provider.dart"
      via: "Player.seek() on video scrub → update playhead_ts"
      pattern: "seek.*playhead"
    - from: "replay_charts_tab.dart chart GestureDetector"
      to: "playhead_provider.dart"
      via: "onHorizontalDrag* → update playhead_ts → video_tab reads and seeks"
      pattern: "playhead.*seek"
    - from: "screenrecord_service.dart _chunkTimer"
      to: "adb shell screenrecord"
      via: "ADB subprocess spawns new recording every 5 minutes"
      pattern: "screenrecord.*chunk"
</objective>

<objective>
Video features: Android screen recording via `adb shell screenrecord` with 5-minute auto-chunking, and side-by-side video player UI with bidirectional chart scrub sync.

Purpose: Enables users to record gameplay/app video alongside performance metrics, with synchronized playback for visual analysis of performance issues. The video-chart sync is the defining feature — scrubbing either the video or chart timeline moves the other.

Output: ScreenrecordService, Video model/DAO, Video tab in session detail with media_kit player, bidirectional scrub sync via shared playhead provider.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/02-v1-5-analysis-platform-expansion/02-CONTEXT.md

### Spec references (MUST READ during execution)
@UNIFIED-SPEC.md §32 (Video Recording — lines 5730-5820: screenrecord, chunking, schema, player UI, chart sync)
@UNIFIED-SPEC.md §9.7.2 (Charts Tab replay — pan/zoom on saved data)
@UNIFIED-SPEC.md Appendix D (ADB screenrecord command)
@performancebench/lib/core/services/adb_service.dart (add screenrecord command execution)
@performancebench/lib/core/database/video_dao.dart (created in Wave 1 — use for storing video metadata)
@performancebench/lib/core/models/video.dart (created in Wave 1 — use for video record)

### Phase 2 CONTEXT decisions
- D-06: Side-by-side — video panel left, charts right, single scrub bar controls both
- D-07: 5-minute chunks, H.264 MP4, data/videos/<session_id>_chunk_NNN.mp4
- Claude's discretion: video chunk naming convention, exact media_kit API usage

### Tech notes
- `media_kit` Flutter package (libmpv backend, MIT license — free) — USE THIS for video playback
- `adb shell screenrecord --size WxH --bit-rate N /sdcard/output.mp4` — Android built-in
- Android screenrecord auto-stops at 3 minutes by default — use --time-limit 300 for 5 min chunks
</context>

<tasks>

<task type="tdd" tdd="true">
  <name>Task 1: Android video recording via screenrecord (V15-11)</name>
  <files>
    performancebench/lib/core/services/screenrecord_service.dart
    performancebench/lib/core/services/adb_service.dart
    performancebench/lib/core/database/video_dao.dart
    performancebench/lib/core/models/video.dart
    performancebench/test/core/services/screenrecord_service_test.dart
  </files>

  <read_first>
  - Read `UNIFIED-SPEC.md` lines 5730-5820 (§32 Video Recording — screenrecord, chunking, storage, schema, perf overhead)
  - Read `UNIFIED-SPEC.md` lines 5768-5793 (videos table DDL — exact column definitions)
  - Read `UNIFIED-SPEC.md` Appendix D (ADB screenrecord command)
  - Read `performancebench/lib/core/services/adb_service.dart` (runShellCommand method — use for screenrecord)
  - Read `performancebench/lib/core/database/video_dao.dart` (created in Wave 1)
  - Read `performancebench/lib/core/models/video.dart` (created in Wave 1)
  - Read Phase 2 CONTEXT.md D-07 (5-min chunks, H.264 MP4, data/videos/, auto-chunking)
  </read_first>

  <behavior>
    Screenrecord service test expectations (screenrecord_service_test.dart):
    Test 1: start() spawns `adb shell screenrecord --size 1080x1920 --bit-rate 8000000 --time-limit 300 /sdcard/pb_video_chunk_001.mp4` with correct arguments
    Test 2: After 5 minutes, ScreenrecordService auto-starts a NEW screenrecord for chunk 002 without user action
    Test 3: On session stop, all chunks are pulled from device via `adb pull` into data/videos/<session_id>/
    Test 4: Video metadata written to videos table with correct filepath, width, height, bitrate, duration, file_size_bytes, chunks_json
    Test 5: sessions.has_video set to 1 after recording completes
    Test 6: Chunks JSON contains array [{chunk: 1, startMs: 0, durationMs: 300000}, {chunk: 2, startMs: 300000, durationMs: 270000}]
    Test 7: start() when already recording → returns error/false, does not spawn duplicate process
    Test 8: stop() when not recording → no-op, no crash
    Test 9: ADB command timeout (3s) → graceful failure, session continues without video
  </behavior>

  <action>
  **Create `performancebench/lib/core/services/screenrecord_service.dart`** (per D-07):

  ```dart
  import 'dart:async';
  import 'dart:io' show Directory, File, Platform;
  import 'package:path/path.dart' as p;
  import 'adb_service.dart';
  import '../database/video_dao.dart';
  import '../models/video.dart';

  /// Manages Android screen recording via `adb shell screenrecord`.
  ///
  /// Auto-chunks at 5-minute intervals (per D-07). Each chunk is an H.264 MP4
  /// file on the device, pulled to the host after session stop.
  ///
  /// Output directory: <data_dir>/videos/<session_id>/
  /// File naming: <session_id>_chunk_<NNN>.mp4 (Claude's discretion)
  class ScreenrecordService {
    final AdbService _adbService;
    final VideoDao _videoDao;
    final String _dataDir;

    /// Currently active recording session ID (null if not recording).
    String? _sessionId;
    String? _deviceSerial;

    /// Chunk tracking.
    int _chunkIndex = 0;
    final List<Map<String, dynamic>> _chunks = []; // [{chunk, startMs, durationMs, devicePath}]
    Timer? _chunkTimer;

    /// Video dimensions and bitrate.
    int _width = 1080;
    int _height = 1920;
    int _bitrate = 8000000; // 8 Mbps default (per §32.6)

    /// Recording start time (Unix ms) for chunk offset calculation.
    int _recordingStartMs = 0;

    /// Whether a recording is in progress.
    bool get isRecording => _sessionId != null;

    ScreenrecordService({
      required AdbService adbService,
      required VideoDao videoDao,
      required String dataDir,
    }) : _adbService = adbService, _videoDao = videoDao, _dataDir = dataDir;

    /// Configure video recording settings.
    void configure({int width = 1080, int height = 1920, int bitrate = 8000000}) {
      _width = width;
      _height = height;
      _bitrate = bitrate;
    }

    /// Start screen recording for a session.
    ///
    /// Spawns ADB screenrecord subprocess with 5-minute time limit.
    /// Auto-chunking: when the 5-min limit is reached, a new recording starts
    /// immediately for the next chunk. This repeats until [stop] is called.
    ///
    /// Returns true if recording started successfully.
    Future<bool> start({
      required String sessionId,
      required String deviceSerial,
    }) async {
      if (isRecording) return false; // Already recording

      _sessionId = sessionId;
      _deviceSerial = deviceSerial;
      _chunkIndex = 0;
      _chunks.clear();
      _recordingStartMs = DateTime.now().millisecondsSinceEpoch;

      return _startChunk();
    }

    /// Start recording a single chunk (5 min max).
    Future<bool> _startChunk() async {
      if (_sessionId == null || _deviceSerial == null) return false;

      _chunkIndex++;
      final chunkName = 'pb_video_chunk_${_chunkIndex.toString().padLeft(3, '0')}.mp4';
      final devicePath = '/sdcard/$chunkName';

      final chunkStartMs = DateTime.now().millisecondsSinceEpoch;

      // Run screenrecord command (async — we don't wait for it to finish)
      // screenrecord blocks until --time-limit reached or killed
      // Use adb shell with nohup-style background: screenrecord with --time-limit
      final command = 'screenrecord --size ${_width}x$_height --bit-rate $_bitrate --time-limit 300 $devicePath';

      try {
        // Fire-and-forget — screenrecord will run for 5 minutes on device
        // We track when to start the next chunk via Timer
        _adbService.runShellCommand(_deviceSerial!, command,
          timeout: const Duration(seconds: 310)); // 5 min + 10s buffer

        // Record chunk metadata
        _chunks.add({
          'chunk': _chunkIndex,
          'devicePath': devicePath,
          'startMs': chunkStartMs - _recordingStartMs,
        });

        // Schedule next chunk at 4:55 (5s before current chunk ends) to ensure continuity
        _chunkTimer = Timer(const Duration(minutes: 4, seconds: 55), () {
          _startChunk();
        });

        return true;
      } catch (e) {
        return false;
      }
    }

    /// Stop recording and pull all chunks from device.
    ///
    /// Returns the Video record if successful, or null if no recording was active.
    Future<Video?> stop() async {
      if (!isRecording || _sessionId == null) return null;

      // Cancel chunk timer
      _chunkTimer?.cancel();
      _chunkTimer = null;

      // Kill any running screenrecord processes on device
      await _adbService.runShellCommand(_deviceSerial!, 'pkill -f screenrecord');

      // Wait briefly for MP4 finalization
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
        final devicePath = chunk['devicePath'] as String;
        final chunkNum = chunk['chunk'] as int;
        final chunkStartMs = chunk['startMs'] as int;

        // Get file size on device
        final statResult = await _adbService.runShellCommand(
          _deviceSerial!, 'stat -c %s $devicePath 2>/dev/null || echo 0',
        );

        final hostFileName = '${sessionId}_chunk_${chunkNum.toString().padLeft(3, '0')}.mp4';
        final hostPath = p.join(videoDir.path, hostFileName);

        // Pull from device
        final pullResult = await _adbService.runShellCommand(
          _deviceSerial!, 'cat $devicePath',
        );
        if (pullResult != null) {
          // Write pulled data to host file
          final hostFile = File(hostPath);
          // Note: actual pull uses `adb pull` not cat — this is pseudocode
          // Implementation should call: Process.run('adb', ['-s', serial, 'pull', devicePath, hostPath])

          final hostFileSize = await hostFile.length();

          pulledChunks.add({
            'chunk': chunkNum,
            'file': hostFileName,
            'startMs': chunkStartMs,
            'fileSizeBytes': hostFileSize,
          });

          // Calculate gap from previous chunk end
          if (prevChunkEndMs != null) {
            gaps.add(chunkStartMs - prevChunkEndMs);
          }
          prevChunkEndMs = chunkStartMs + 300000; // ~5 min per chunk

          // Clean up device file
          await _adbService.runShellCommand(_deviceSerial!, 'rm -f $devicePath');
        }
      }

      if (pulledChunks.isEmpty) {
        _sessionId = null;
        _deviceSerial = null;
        return null;
      }

      // Calculate total duration from chunk timing
      final firstChunkStart = pulledChunks.first['startMs'] as int;
      final lastChunkStart = pulledChunks.last['startMs'] as int;
      final totalDurationMs = lastChunkStart - firstChunkStart + 300000; // last chunk is ~300s
      final totalSizeBytes = pulledChunks.fold<int>(0, (sum, c) => sum + (c['fileSizeBytes'] as int));

      // Build Video record per §32.8 schema
      final video = Video(
        sessionId: sessionId,
        filepath: p.join(videoDir.path, '${sessionId}_chunk_001.mp4'), // Primary file
        codec: 'h264',
        container: 'mp4',
        widthPx: _width,
        heightPx: _height,
        targetFps: 30, // screenrecord default
        actualAvgFps: null, // Computed if frame counting available
        bitrateKbps: _bitrate ~/ 1000,
        durationMs: totalDurationMs,
        fileSizeBytes: totalSizeBytes,
        chunksJson: _encodeJson(pulledChunks),
        gapsJson: _encodeJson(gaps),
        hasAudio: 0,
        recordingOverheadEstimatePct: 5.0, // Default estimate per §32.7 (3-5% on flagship)
        startedAt: _recordingStartMs,
        endedAt: DateTime.now().millisecondsSinceEpoch,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      // Save to database
      await _videoDao.insert(video);

      // Update sessions.has_video
      // (done by caller via session management)

      // Reset state
      _sessionId = null;
      _deviceSerial = null;
      _chunkIndex = 0;
      _chunks.clear();

      return video;
    }

    /// Abort recording (no video saved).
    Future<void> abort() async {
      _chunkTimer?.cancel();
      _chunkTimer = null;
      if (_deviceSerial != null) {
        await _adbService.runShellCommand(_deviceSerial!, 'pkill -f screenrecord');
        // Clean up device files
        for (final chunk in _chunks) {
          await _adbService.runShellCommand(_deviceSerial!, 'rm -f ${chunk['devicePath']}');
        }
      }
      _sessionId = null;
      _deviceSerial = null;
      _chunkIndex = 0;
      _chunks.clear();
    }

    String _encodeJson(dynamic obj) {
      return '[]'; // Placeholder — use dart:convert jsonEncode
    }
  }
  ```

  **Extend `performancebench/lib/core/services/adb_service.dart`:**

  Add a `pullFile` method for pulling video chunks:
  ```dart
  /// Pull a file from device to host.
  Future<bool> pullFile(String serial, String remotePath, String localPath) async {
    if (!_isValidSerial(serial)) return false;
    try {
      final result = await Process.run(
        _adbPath, ['-s', serial, 'pull', remotePath, localPath],
      ).timeout(const Duration(seconds: 30)); // Video files can be large
      return result.exitCode == 0;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }
  ```

  **Wire into session start/stop flow:**

  In the session start handler (ActiveSessionScreen or equivalent):
  ```dart
  if (config.enableVideoRecording && session.isAndroid) {
    await _screenrecordService.start(
      sessionId: session.id,
      deviceSerial: session.deviceId,
    );
  }
  ```

  In the session stop handler:
  ```dart
  if (_screenrecordService.isRecording) {
    final video = await _screenrecordService.stop();
    if (video != null) {
      await _sessionDao.setHasVideo(sessionId, true);
    }
  }
  ```

  **Create test** (`test/core/services/screenrecord_service_test.dart`):
  - Test all 9 behavior cases above
  - Mock AdbService to verify correct screenrecord command arguments
  - Mock Process.run for ADB pull verification
  - Test chunk naming convention
  - Test auto-chunking timer logic

  After tests pass, commit: `docs(02-05): add Android screen recording with 5-min chunks`
  </action>

  <verify>
    <automated>cd D:/OpenCode/Benchify && dart test test/core/services/screenrecord_service_test.dart</automated>
  </verify>

  <done>
  - ScreenrecordService starts/stops ADB screenrecord with correct arguments per D-07
  - 5-minute auto-chunking works — new chunk starts at 4:55 without user action
  - Chunks pulled from device and saved to data/videos/<session_id>/ after session stop
  - Video metadata written to videos table per §32.8 schema
  - sessions.has_video = 1 after successful recording
  - 9 test cases pass covering happy path, error, and edge cases
  </done>
</task>

<task type="tdd" tdd="true">
  <name>Task 2: Video player UI + bidirectional chart scrub sync (V15-12)</name>
  <files>
    performancebench/lib/shared/providers/playhead_provider.dart
    performancebench/lib/shared/widgets/video_player_widget.dart
    performancebench/lib/features/session_detail/video_tab.dart
    performancebench/lib/features/session_detail/detail_screen.dart
    performancebench/lib/features/session_detail/replay_charts_tab.dart
    performancebench/test/widgets/video_chart_sync_test.dart
  </files>

  <read_first>
  - Read `UNIFIED-SPEC.md` lines 5795-5819 (§32.9 Player UI — layout, media_kit, shared playhead_ts, J/K/L shortcuts, speed control)
  - Read `performanchench/lib/shared/widgets/metric_chart.dart` (existing chart — extend with playhead awareness)
  - Read `performancebench/lib/features/session_detail/replay_charts_tab.dart` (wire playhead sync)
  - Read `performancebench/lib/features/session_detail/detail_screen.dart` (add Video tab at position 7)
  - Read `performancebench/lib/core/models/video.dart` (created in Wave 1 — load for video_tab)
  - Read `performancebench/lib/core/database/video_dao.dart` (getBySessionId for loading video record)
  - Read Phase 2 CONTEXT.md D-06 (side-by-side layout: video left, charts right, shared scrub bar)
  - MUST READ: `media_kit` package docs for Flutter — `Player` class, `Video` widget, `Player.seek()`, `Player.stream.position`
  </read_first>

  <behavior>
    Video chart sync test expectations (video_chart_sync_test.dart):
    Test 1: Video scrub via position slider → playhead_ts Riverpod provider updates to matching timestamp
    Test 2: Chart tap (GestureDetector.onTapDown on MetricChart) → playhead_ts updates → video seeks to matching position
    Test 3: Shared scrub bar at bottom — dragging scrub bar updates BOTH video position and chart cursor
    Test 4: VideoTab layout has video on left (60% width) and mini-charts on right (40% width)
    Test 5: SessionDetailScreen tab count is 8 (added Video tab)
    Test 6: VideoTab empty state when no video recorded — shows "No video recorded for this session" message
    Test 7: chunks_json with 3 chunks — player loads chunk_001.mp4, user can scrub past chunk boundary, player seamlessly loads next chunk
  </behavior>

  <action>
  **Step 1 — Add `media_kit` dependency:**

  In `pubspec.yaml`:
  ```yaml
  dependencies:
    media_kit: ^1.1.11
    media_kit_video: ^1.2.5
    media_kit_libs_video: ^1.0.5
  ```
  Run `flutter pub get`

  **Step 2 — Create shared playhead provider** (`performancebench/lib/shared/providers/playhead_provider.dart`):

  ```dart
  import 'package:flutter_riverpod/flutter_riverpod.dart';

  /// Shared playhead timestamp in milliseconds — synced between video player
  /// and chart replay. Updated by both video scrub and chart drag/tap.
  ///
  /// When the video position changes → charts re-render with cursor at this timestamp.
  /// When chart is tapped/dragged → video seeks to this timestamp.
  final playheadProvider = StateProvider<int?>((ref) => null);

  /// Whether the playhead was last moved by the video (true) or chart (false).
  /// Prevents feedback loops where video seeks chart which seeks video.
  final playheadSourceProvider = StateProvider<String>((ref) => 'none'); // 'video' | 'chart' | 'scrub_bar' | 'none'
  ```

  **Step 3 — Create VideoPlayerWidget** (`performancebench/lib/shared/widgets/video_player_widget.dart`):

  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:media_kit/media_kit.dart';
  import 'package:media_kit_video/media_kit_video.dart';
  import '../providers/playhead_provider.dart';
  import '../../core/models/video.dart';

  /// Wraps media_kit Video widget with position tracking.
  /// Updates playheadProvider on position change (when video is scrubbed).
  class VideoPlayerWidget extends ConsumerStatefulWidget {
    final String filePath;
    final Video videoMeta;

    const VideoPlayerWidget({super.key, required this.filePath, required this.videoMeta});

    @override
    ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
  }

  class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
    late final Player _player;
    late final VideoController _controller;

    @override
    void initState() {
      super.initState();
      _player = Player();
      _controller = VideoController(_player);

      // Open the video file
      _player.open(Media(widget.filePath));

      // Listen for position changes from video scrubbing
      _player.stream.position.listen((duration) {
        final source = ref.read(playheadSourceProvider);
        if (source == 'chart') return; // Don't override chart-initiated seeks
        ref.read(playheadProvider.notifier).state = duration.inMilliseconds;
        ref.read(playheadSourceProvider.notifier).state = 'video';
      });
    }

    @override
    void dispose() {
      _player.dispose();
      super.dispose();
    }

    /// Seek video to a specific timestamp (called from chart sync).
    void seekTo(int timestampMs) {
      _player.seek(Duration(milliseconds: timestampMs));
    }

    @override
    Widget build(BuildContext context) {
      final playheadTs = ref.watch(playheadProvider);
      final playheadSource = ref.watch(playheadSourceProvider);

      // If chart initiated the seek, update video position
      if (playheadSource == 'chart' && playheadTs != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _player.seek(Duration(milliseconds: playheadTs));
        });
      }

      return Video(
        controller: _controller,
        fit: BoxFit.contain,
        controls: null, // Custom controls below
      );
    }
  }
  ```

  **Step 4 — Create VideoTab** (`performancebench/lib/features/session_detail/video_tab.dart`) (per D-06):

  Side-by-side layout: video panel (left, ~60%) + mini-charts panel (right, ~40%). Shared scrub bar at bottom.

  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import '../../shared/theme.dart';
  import '../../shared/widgets/video_player_widget.dart';
  import '../../shared/providers/playhead_provider.dart';
  import '../../core/database/video_dao.dart';
  import '../../core/models/video.dart';

  class VideoTab extends ConsumerStatefulWidget {
    final String sessionId;
    const VideoTab({super.key, required this.sessionId});

    @override
    ConsumerState<VideoTab> createState() => _VideoTabState();
  }

  class _VideoTabState extends ConsumerState<VideoTab> {
    Video? _video;
    bool _loading = true;

    @override
    void initState() {
      super.initState();
      _loadVideo();
    }

    Future<void> _loadVideo() async {
      // Load video record from VideoDao
      // final video = await videoDao.getBySessionId(widget.sessionId);
      // setState(() { _video = video; _loading = false; });
    }

    @override
    Widget build(BuildContext context) {
      final colors = AppColors.of(context);
      final playheadTs = ref.watch(playheadProvider);

      if (_loading) {
        return Center(child: CircularProgressIndicator(color: colors.accentBlue));
      }

      if (_video == null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off, size: 48, color: colors.textDisabled),
              const SizedBox(height: 12),
              Text('No video recorded for this session',
                style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm)),
            ],
          ),
        );
      }

      return Column(
        children: [
          // Side-by-side: Video (left) + Mini Charts (right)
          Expanded(
            child: Row(
              children: [
                // Video panel — 60% width
                Expanded(
                  flex: 6,
                  child: Container(
                    color: Colors.black,
                    child: VideoPlayerWidget(
                      filePath: _video!.filepath,
                      videoMeta: _video!,
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, color: AppColors.borderSubtleStatic),
                // Mini charts panel — 40% width (D-06: charts on right)
                Expanded(
                  flex: 4,
                  child: _MiniChartsPanel(sessionId: widget.sessionId, colors: colors),
                ),
              ],
            ),
          ),
          // Shared scrub bar at bottom (controls both video and charts)
          _SharedScrubBar(
            durationMs: _video!.durationMs,
            playheadMs: playheadTs,
            chunksJson: _video!.chunksJson,
            onSeek: (ms) {
              ref.read(playheadProvider.notifier).state = ms;
              ref.read(playheadSourceProvider.notifier).state = 'scrub_bar';
            },
            colors: colors,
          ),
          // Marker labels overlaid on timeline
          if (_video!.chunksJson != null)
            _MarkerTimeline(sessionId: widget.sessionId, colors: colors),
        ],
      );
    }
  }
  ```

  **Step 5 — Shared scrub bar** (`_SharedScrubBar` in video_tab.dart):

  ```dart
  class _SharedScrubBar extends StatelessWidget {
    final int durationMs;
    final int? playheadMs;
    final String? chunksJson;
    final Function(int) onSeek;
    final AppColors colors;

    // Custom SliderTheme — VS Code Dark+ style
    // Play/Pause, Frame-step buttons per §32.9 (J/K/L keys)
    // Speed selector: 0.25x / 0.5x / 1x / 2x / 4x
    // Time display: "02:47 / 10:00"
    // Chunk boundary markers shown as small ticks on scrub bar
  }
  ```

  **Step 6 — Wire chart sync in ReplayChartsTab** (`replay_charts_tab.dart`):

  Add playhead awareness to the replay charts:
  ```dart
  // Each MetricChart in replay mode includes a vertical playhead line
  // at the current playheadTs position

  // When user taps or drags on a chart:
  GestureDetector(
    onTapDown: (details) {
      final tappedMs = _xToTimestamp(details.localPosition.dx);
      ref.read(playheadProvider.notifier).state = tappedMs;
      ref.read(playheadSourceProvider.notifier).state = 'chart';
    },
    // ... chart rendering with vertical line at playheadTs
  )
  ```

  **Step 7 — Add Video tab to SessionDetailScreen** (`detail_screen.dart`):

  Change tab count: `length: 7` → `length: 8`
  Add tabs in order: `[Scorecard, Charts, FPS Analysis, Markers, Regions, Issues, Video, Screenshots]`
  Add `VideoTab(sessionId: sessionId)` to TabBarView children at index 6.

  **Step 8 — Keyboard shortcuts** (per §32.9):

  Add keyboard listener in VideoTab:
  - J: frame back (←)
  - K: pause
  - L: frame forward (→)
  - 1/2/3/4: speed 0.25x/0.5x/1x/2x/4x

  **Create test** (`test/widgets/video_chart_sync_test.dart`):
  - Test all 7 behavior cases above
  - Use `flutter_test` for widget testing with mock VideoDao

  After tests pass, commit: `docs(02-05): add video player UI with bidirectional chart scrub sync`
  </action>

  <verify>
    <automated>cd D:/OpenCode/Benchify && flutter test test/widgets/video_chart_sync_test.dart</automated>
  </verify>

  <done>
  - Video Tab appears in session detail when session has video recorded
  - Side-by-side layout: video panel left (60%), mini charts right (40%)
  - Shared scrub bar controls both video position and chart cursor
  - Scrubbing video repositions charts; scrubbing charts seeks video (bidirectional)
  - Empty state shown for sessions without video
  - J/K/L keyboard shortcuts for frame-stepping
  - Speed control: 0.25x/0.5x/1x/2x/4x
  - 7 test cases pass
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| ADB shell → screenrecord subprocess | Video recording command spawned on device |
| Video file → media_kit Player | Locally-stored MP4 file loaded for playback |
| User scrub input → chart/video sync | GestureDetector positions drive playhead state |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-02-19 | Denial of Service | screenrecord_service.dart _startChunk() | mitigate | 310s timeout on screenrecord command; chunk timer at 295s ensures next chunk starts before current times out; pkill cleanup on abort |
| T-02-20 | Tampering | video_player_widget.dart file path | mitigate | Video file path validated — must be within data/videos/ directory; no path traversal |
| T-02-21 | Denial of Service | video_tab.dart media_kit Player | mitigate | Player.dispose() called on widget dispose; single player instance; error handling for corrupt video files |
| T-02-22 | Elevation of Privilege | screenrecord_service.dart adb pull | accept | ADB commands run with same privileges as user's ADB session; no escalation path |
</threat_model>

<verification>
1. Run screenrecord tests: `cd D:/OpenCode/Benchify && dart test test/core/services/screenrecord_service_test.dart`
2. Run video-chart sync tests: `cd D:/OpenCode/Benchify && flutter test test/widgets/video_chart_sync_test.dart`
3. Run full test suite: `cd D:/OpenCode/Benchify && dart test && flutter test`
4. Verify: `cd D:/OpenCode/Benchify && flutter analyze` shows 0 errors
</verification>

<success_criteria>
1. `adb shell screenrecord` captures 5-minute H.264 MP4 chunks during Android profiling session
2. Chunks pulled to data/videos/<session_id>/ and metadata stored in videos table
3. Video tab shows side-by-side video + charts with shared scrub bar
4. Scrubbing video moves chart cursor to matching timestamp; scrubbing chart seeks video (bidirectional sync)
5. J/K/L frame-stepping works; speed control (0.25x–4x) works
6. All new tests pass, 0 analyzer errors
</success_criteria>

<output>
After completion, create `.planning/phases/02-v1-5-analysis-platform-expansion/02-05-SUMMARY.md`
</output>
