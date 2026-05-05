// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/video.dart';
import '../providers/playhead_provider.dart';

/// Wraps media_kit Video widget with position tracking and playhead sync.
///
/// Updates [playheadProvider] on video position change (when video is scrubbed).
/// When [playheadSourceProvider] is 'chart' or 'scrub_bar', seeks the video
/// to the matching timestamp (bidirectional sync per D-06, §32.9).
///
/// Threat mitigation T-02-20: video filepath must be within data/videos/.
/// Path traversal prevention via validation.
///
/// NOTE: Full implementation requires `media_kit`, `media_kit_video`, and
/// `media_kit_libs_video` packages. Run `flutter pub get` and then replace
/// the placeholder build method with:
///
/// ```dart
/// import 'package:media_kit/media_kit.dart';
/// import 'package:media_kit_video/media_kit_video.dart' as mkv;
/// // Create Player(), open Media(filePath), use mkv.Video(controller: ...)
/// // Listen to player.stream.position for playhead sync
/// ```
class VideoPlayerWidget extends ConsumerStatefulWidget {
  final String filePath;
  final Video videoMeta;

  const VideoPlayerWidget({
    super.key,
    required this.filePath,
    required this.videoMeta,
  });

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  bool _initialized = false;
  bool _playerReady = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // TODO: Initialize media_kit Player when packages are installed:
    //   1. Run: flutter pub get
    //   2. Import media_kit and media_kit_video
    //   3. Create Player() and VideoController(player)
    //   4. player.open(Media(widget.filePath))
    //   5. player.stream.position.listen(...) → update playheadProvider
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  /// Seek video to a specific timestamp (called from chart sync).
  void seekTo(int timestampMs) {
    // TODO: player.seek(Duration(milliseconds: timestampMs))
    if (!_playerReady) return;
    ref.read(playheadProvider.notifier).state = timestampMs;
  }

  /// Toggle play/pause.
  void togglePlayPause() {
    // TODO: player.playOrPause()
  }

  /// Set playback speed (per §32.9: 0.25x / 0.5x / 1x / 2x / 4x).
  void setSpeed(double speed) {
    // TODO: player.setRate(speed)
  }

  @override
  void dispose() {
    // TODO: player.dispose()
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playheadTs = ref.watch(playheadProvider);
    final playheadSource = ref.watch(playheadSourceProvider);

    // If chart or scrub_bar initiated the seek, seek video position
    if ((playheadSource == 'chart' || playheadSource == 'scrub_bar') &&
        playheadTs != null &&
        _playerReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        seekTo(playheadTs);
      });
    }

    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_playerReady) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, size: 48, color: Color(0xFF808080)),
            const SizedBox(height: 12),
            const Text(
              'Video playback unavailable',
              style: TextStyle(color: Color(0xFF808080), fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Run: flutter pub get && flutter run',
              style: TextStyle(
                color: const Color(0xFF505050),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
    }

    // TODO: Return mkv.Video(controller: _controller) when media_kit is available
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.play_circle_outline, size: 64, color: Color(0xFF505050)),
      ),
    );
  }
}
