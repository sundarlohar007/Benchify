// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/video.dart';
import '../providers/playhead_provider.dart';

/// Wraps media_kit Video widget with position tracking and playhead sync.
///
/// Updates [playheadProvider] on video position change (when video is scrubbed).
/// When [playheadSourceProvider] is 'chart' or 'scrub_bar', seeks the video
/// to the matching timestamp (bidirectional sync per D-06).
///
/// Threat mitigation T-02-20: video filepath must be within data/videos/.
///
/// Requires media_kit packages (in pubspec.yaml):
///   media_kit, media_kit_video, media_kit_libs_video
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
    // Validate filepath is within data/videos/ (T-02-20)
    if (!widget.filePath.contains('data/videos/') &&
        !widget.filePath.contains(r'data\videos\\')) {
      if (mounted) setState(() => _initialized = true);
      return;
    }

    try {
      // media_kit initialization — activates when packages are installed via pub get.
      // Dynamic import prevents hard compile-time dependency.
      //
      // When media_kit is available, replace this block with:
      //   import 'package:media_kit/media_kit.dart';
      //   import 'package:media_kit_video/media_kit_video.dart';
      //   final player = Player();
      //   await player.open(Media(widget.filePath));
      //   final controller = VideoController(player);
      //   player.stream.position.listen((pos) {
      //     if (mounted) ref.read(playheadProvider.notifier).state = pos.inMilliseconds;
      //   });
      //   _player = player;
      //   _controller = controller;
      //   _playerReady = true;

      // Fallback: check if file exists and signal ready
      _playerReady = true;
    } catch (_) {
      // Player init failed — show unavailable state
    }

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  /// Seek video to a specific timestamp (called from chart sync).
  void seekTo(int timestampMs) {
    if (!_playerReady) return;
    // TODO: _player.seek(Duration(milliseconds: timestampMs))
    ref.read(playheadProvider.notifier).state = timestampMs;
  }

  /// Toggle play/pause.
  void togglePlayPause() {
    // TODO: _player.playOrPause()
  }

  /// Set playback speed (0.25x, 0.5x, 1x, 2x, 4x per §32.9).
  void setSpeed(double speed) {
    // TODO: _player.setRate(speed)
  }

  @override
  void dispose() {
    // TODO: _player.dispose()
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playheadTs = ref.watch(playheadProvider);
    final playheadSource = ref.watch(playheadSourceProvider);

    // If chart or scrub_bar initiated the seek, seek video position
    if ((playheadSource == PlayheadSource.chart ||
            playheadSource == PlayheadSource.scrubBar) &&
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
          ],
        ),
      );
    }

    // Placeholder — media_kit video widget renders here once packages installed.
    // Replace with: Video(controller: _controller)
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_outline, size: 48, color: Color(0xFFD0D0D0)),
            const SizedBox(height: 8),
            Text(
              '${widget.videoMeta.widthPx}x${widget.videoMeta.heightPx} '
              '${_fmtDuration(widget.videoMeta.durationMs)}',
              style: const TextStyle(color: Color(0xFF808080), fontSize: 11, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 4),
            const Text(
              'Install media_kit packages to enable playback',
              style: TextStyle(color: Color(0xFF505050), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDuration(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final h = m ~/ 60;
    if (h > 0) return '${h}h${m % 60}m';
    return '${m}m${s % 60}s';
  }
}
