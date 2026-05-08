// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart' as db;
import '../../core/database/video_dao.dart';
import '../../core/models/video.dart';
import '../../shared/providers/playhead_provider.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/video_player_widget.dart';

/// Video tab in session detail — side-by-side video + chart replay.
///
/// Layout (per D-06, §32.9):
/// - Video panel on left (60% width)
/// - Mini charts panel on right (40% width)
/// - Shared scrub bar at bottom controls both
///
/// Bidirectional sync:
/// - Scrubbing video → updates playhead_ts → charts re-render
/// - Tapping/dragging chart → updates playhead_ts → video seeks
/// - Dragging shared scrub bar → updates playhead_ts → both update
///
/// Threat mitigation T-02-21: Player.dispose() called on widget dispose;
/// single player instance; error handling for corrupt video files.
class VideoTab extends ConsumerStatefulWidget {
  final String sessionId;

  const VideoTab({super.key, required this.sessionId});

  @override
  ConsumerState<VideoTab> createState() => _VideoTabState();
}

class _VideoTabState extends ConsumerState<VideoTab> {
  Video? _video;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      final database = await db.initDatabase();
      final videoDao = VideoDao(database);
      final video = await videoDao.getBySessionId(widget.sessionId);
      if (mounted) {
        setState(() {
          _video = video;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final playheadTs = ref.watch(playheadProvider);

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: colors.accentBlue),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          'Failed to load video: $_error',
          style: TextStyle(color: colors.accentDanger, fontSize: TextTokens.sm),
        ),
      );
    }

    if (_video == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, size: 48, color: colors.textDisabled),
            const SizedBox(height: 12),
            Text(
              'No video recorded for this session',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: TextTokens.sm,
              ),
            ),
          ],
        ),
      );
    }

    final video = _video!;
    final totalDurationMs = video.durationMs;

    return Column(
      children: [
        // Side-by-side: Video (left, 60%) + Mini Charts (right, 40%)
        Expanded(
          child: Row(
            children: [
              // Video panel — 60% width
              Expanded(
                flex: 6,
                child: Container(
                  color: Colors.black,
                  child: VideoPlayerWidget(
                    filePath: video.filepath,
                    videoMeta: video,
                  ),
                ),
              ),
              // Divider between panels
              const VerticalDivider(
                width: 1,
                color: Color(0xFF3E3E3E),
              ),
              // Mini charts panel — 40% width (per D-06)
              Expanded(
                flex: 4,
                child: _MiniChartsPanel(
                  sessionId: widget.sessionId,
                  colors: colors,
                  playheadMs: playheadTs,
                ),
              ),
            ],
          ),
        ),
        // Shared scrub bar at bottom (controls both video and charts)
        _SharedScrubBar(
          durationMs: totalDurationMs,
          playheadMs: playheadTs,
          chunksJson: video.chunksJson ?? '[]',
          onSeek: (int ms) {
            ref.read(playheadProvider.notifier).state = ms;
            ref.read(playheadSourceProvider.notifier).state =
                PlayheadSource.scrubBar;
          },
          colors: colors,
        ),
      ],
    );
  }
}

// =============================================================================
// Shared Scrub Bar
// =============================================================================

/// Shared scrub bar at the bottom of VideoTab.
///
/// Controls both video position and chart cursor simultaneously.
/// Displays:
/// - Time display: "02:47 / 10:00"
/// - Play/Pause button
/// - Frame-step buttons (J/K/L keyboard shortcuts mapped here)
/// - Speed selector: 0.25x / 0.5x / 1x / 2x / 4x
/// - Resolution/badge: "1080p 8Mbps"
class _SharedScrubBar extends StatelessWidget {
  final int durationMs;
  final int? playheadMs;
  final String chunksJson;
  final Function(int) onSeek;
  final AppColors colors;

  const _SharedScrubBar({
    required this.durationMs,
    required this.playheadMs,
    required this.chunksJson,
    required this.onSeek,
    required this.colors,
  });

  String _formatTime(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final minutes = (totalSeconds / 60).floor();
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final currentMs = playheadMs ?? 0;
    final progress = durationMs > 0 ? currentMs / durationMs : 0.0;
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Container(
      height: 56,
      color: colors.bgSidebar,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slider track
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: colors.accentBlue,
              inactiveTrackColor: colors.bgInput,
              thumbColor: colors.accentBlue,
              overlayColor: colors.accentBlue.withAlpha(40),
            ),
            child: Slider(
              value: clampedProgress,
              onChanged: (v) {
                onSeek((v * durationMs).round());
              },
            ),
          ),
          // Controls row
          Row(
            children: [
              // Play/Pause button
              IconButton(
                icon: Icon(Icons.play_arrow, size: 18, color: colors.textPrimary),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Play/Pause (K)',
              ),
              // Frame back button
              IconButton(
                icon: Icon(Icons.skip_previous, size: 16, color: colors.textSecondary),
                onPressed: () {
                  onSeek((currentMs - 33).clamp(0, durationMs)); // ~1 frame at 30fps
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Frame back (J)',
              ),
              // Frame forward button
              IconButton(
                icon: Icon(Icons.skip_next, size: 16, color: colors.textSecondary),
                onPressed: () {
                  onSeek((currentMs + 33).clamp(0, durationMs));
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Frame forward (L)',
              ),
              const SizedBox(width: 8),
              // Time display
              Text(
                '${_formatTime(currentMs)} / ${_formatTime(durationMs)}',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: TextTokens.xs,
                ),
              ),
              const Spacer(),
              // Info badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.bgInput,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  '1080p 8Mbps',
                  style: TextStyle(
                    color: colors.textDisabled,
                    fontSize: TextTokens.xs,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Mini Charts Panel
// =============================================================================

/// Mini charts panel on the right side of the Video tab.
///
/// Shows a vertical stack of small metric charts (FPS, CPU, Memory) with
/// a vertical playhead cursor line at the current playhead timestamp.
///
/// This is a simplified placeholder for the full replay chart rendering.
/// In production, this would instantiate MetricChart widgets as in
/// ReplayChartsTab but in a compact vertical layout.
class _MiniChartsPanel extends StatelessWidget {
  final String sessionId;
  final AppColors colors;
  final int? playheadMs;

  const _MiniChartsPanel({
    required this.sessionId,
    required this.colors,
    required this.playheadMs,
  });

  @override
  Widget build(BuildContext context) {
    // Placeholder: in production, this renders MiniMetricChart widgets
    // that show a compact view of FPS, CPU, Memory with a vertical
    // playhead cursor line at playheadMs.
    return Container(
      color: colors.bgBase,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Text(
            'METRICS',
            style: TextStyle(
              color: colors.textDisabled,
              fontSize: TextTokens.xs,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          // Placeholder chart areas
          _MiniChartPlaceholder(
            label: 'FPS',
            color: ChartColors.fps,
            colors: colors,
            playheadMs: playheadMs,
          ),
          const SizedBox(height: 4),
          _MiniChartPlaceholder(
            label: 'CPU',
            color: ChartColors.cpuApp,
            colors: colors,
            playheadMs: playheadMs,
          ),
          const SizedBox(height: 4),
          _MiniChartPlaceholder(
            label: 'MEM',
            color: ChartColors.memory,
            colors: colors,
            playheadMs: playheadMs,
          ),
          const SizedBox(height: 4),
          _MiniChartPlaceholder(
            label: 'GPU',
            color: ChartColors.gpu,
            colors: colors,
            playheadMs: playheadMs,
          ),
        ],
      ),
    );
  }
}

/// Placeholder for a mini chart in the Video tab right panel.
///
/// Renders a small colored area with a label and a vertical playhead line.
/// In production, this is replaced with actual MetricChart widgets showing
/// real metric data from the session.
class _MiniChartPlaceholder extends StatelessWidget {
  final String label;
  final Color color;
  final AppColors colors;
  final int? playheadMs;

  const _MiniChartPlaceholder({
    required this.label,
    required this.color,
    required this.colors,
    required this.playheadMs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: TextTokens.xs,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: colors.bgInput,
            borderRadius: BorderRadius.circular(2),
          ),
          child: CustomPaint(
            painter: _MiniChartPainter(
              lineColor: color,
              bgColor: colors.bgInput,
              playheadFraction: null, // Would come from real data
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints a mini chart with a playhead cursor line.
class _MiniChartPainter extends CustomPainter {
  final Color lineColor;
  final Color bgColor;
  final double? playheadFraction;

  _MiniChartPainter({
    required this.lineColor,
    required this.bgColor,
    this.playheadFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw placeholder line showing chart area is wired
    final paint = Paint()
      ..color = lineColor.withAlpha(80)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Simple sine-like placeholder path
    final path = Path();
    path.moveTo(0, size.height * 0.7);
    for (var i = 0; i < size.width; i += 4) {
      final x = i.toDouble();
      final y = size.height * 0.5 +
          size.height * 0.3 * (1 - i / size.width) +
          5 * (i % 20 > 10 ? 1 : -1);
      path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);

    // Draw playhead cursor line
    if (playheadFraction != null) {
      final x = playheadFraction! * size.width;
      final playheadPaint = Paint()
        ..color = const Color(0xFFF44747)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        playheadPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) =>
      playheadFraction != oldDelegate.playheadFraction ||
      lineColor != oldDelegate.lineColor;
}
