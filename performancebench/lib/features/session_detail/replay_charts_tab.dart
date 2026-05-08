// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart' as db;
import '../../core/database/metric_dao.dart';
import '../../core/models/metric_sample.dart';
import '../../shared/providers/playhead_provider.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/metric_chart.dart';

/// Replay charts tab — displays full-session charts from saved metric_samples.
/// Supports drag-selection to create region stats (v1.5) and playhead sync
/// with Video tab (v1.5 D-06 — bidirectional video-chart scrub sync).
class ReplayChartsTab extends ConsumerStatefulWidget {
  final String sessionId;
  /// Callback when a region is drag-selected on any chart.
  /// Emits the timestamp range in ms.
  final void Function(int startMs, int endMs)? onRegionSelected;

  const ReplayChartsTab({
    super.key,
    required this.sessionId,
    this.onRegionSelected,
  });

  @override
  ConsumerState<ReplayChartsTab> createState() => _ReplayChartsTabState();
}

class _ReplayChartsTabState extends ConsumerState<ReplayChartsTab> {
  List<MetricSample>? _samples;
  bool _loading = true;
  String? _error;
  StreamController<MetricSample>? _chartController;

  @override
  void initState() {
    super.initState();
    _loadSamples();
  }

  @override
  void dispose() {
    _chartController?.close();
    super.dispose();
  }

  Future<void> _loadSamples() async {
    try {
      final database = await db.initDatabase();
      final metricDao = MetricDao(database);
      final samples = await metricDao.getBySessionId(widget.sessionId);
      if (mounted) {
        setState(() {
          _samples = samples;
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
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          'Failed to load session data: $_error',
          style: TextStyle(color: colors.accentDanger, fontSize: TextTokens.sm),
        ),
      );
    }

    if (_samples == null || _samples!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 48, color: colors.textDisabled),
            const SizedBox(height: 12),
            Text(
              'No metric data for this session',
              style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm),
            ),
            const SizedBox(height: 4),
            Text(
              'Drag-select a region on any chart to compute per-region stats',
              style: TextStyle(color: colors.textDisabled, fontSize: TextTokens.xs),
            ),
          ],
        ),
      );
    }

    final samples = _samples!;
    // Create a broadcast stream from pre-loaded samples
    _chartController?.close();
    _chartController = StreamController<MetricSample>.broadcast();
    final controller = _chartController!;

    // Schedule sample emission after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final s in samples) {
        controller.add(s);
      }
    });

    void onDrag(int startIndex, int endIndex) {
      if (startIndex >= 0 &&
          endIndex < samples.length &&
          startIndex < endIndex) {
        final startMs = samples[startIndex].timestamp;
        final endMs = samples[endIndex].timestamp;
        widget.onRegionSelected?.call(startMs, endMs);

        // Sync playhead to region end for video-chart bidirectional sync (D-06)
        ref.read(playheadProvider.notifier).state = endMs;
        ref.read(playheadSourceProvider.notifier).state = PlayheadSource.chart;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Drag horizontally on any chart to select a time region',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: TextTokens.xs,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildFpsChart(samples, controller.stream, onDrag, colors),
                const SizedBox(height: 8),
                _buildCpuChart(samples, controller.stream, onDrag, colors),
                const SizedBox(height: 8),
                _buildMemChart(samples, controller.stream, onDrag, colors),
                const SizedBox(height: 8),
                _buildGpuChart(samples, controller.stream, onDrag, colors),
                const SizedBox(height: 8),
                _buildBatteryChart(samples, controller.stream, onDrag, colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFpsChart(
    List<MetricSample> samples,
    Stream<MetricSample> stream,
    void Function(int, int) onDrag,
    AppColors colors,
  ) {
    return SizedBox(
      height: 200,
      child: MetricChart(
        label: 'FPS',
        lineColor: ChartColors.fps,
        stream: stream,
        extractValue: (s) => s.fps,
        valueFormatter: (v) => v?.toStringAsFixed(1) ?? '—',
        statCalculator: (_) => [],
        targetLineY: 60,
        showJankRow: true,
        unit: 'fps',
        enableDragSelection: true,
        onDragSelection: onDrag,
      ),
    );
  }

  Widget _buildCpuChart(
    List<MetricSample> samples,
    Stream<MetricSample> stream,
    void Function(int, int) onDrag,
    AppColors colors,
  ) {
    return SizedBox(
      height: 200,
      child: MetricChart(
        label: 'CPU (App)',
        lineColor: ChartColors.cpuApp,
        stream: stream,
        extractValue: (s) => s.cpuAppPct,
        valueFormatter: (v) => v != null ? '${v.toStringAsFixed(1)}%' : '—',
        statCalculator: (_) => [],
        unit: '%',
        enableDragSelection: true,
        onDragSelection: onDrag,
      ),
    );
  }

  Widget _buildMemChart(
    List<MetricSample> samples,
    Stream<MetricSample> stream,
    void Function(int, int) onDrag,
    AppColors colors,
  ) {
    return SizedBox(
      height: 200,
      child: MetricChart(
        label: 'Memory (PSS)',
        lineColor: ChartColors.memory,
        stream: stream,
        extractValue: (s) => s.memoryPssKb?.toDouble(),
        valueFormatter: (v) => v != null ? '${(v / 1024).toStringAsFixed(0)} MB' : '—',
        statCalculator: (_) => [],
        unit: 'KB',
        enableDragSelection: true,
        onDragSelection: onDrag,
      ),
    );
  }

  Widget _buildGpuChart(
    List<MetricSample> samples,
    Stream<MetricSample> stream,
    void Function(int, int) onDrag,
    AppColors colors,
  ) {
    return SizedBox(
      height: 200,
      child: MetricChart(
        label: 'GPU',
        lineColor: ChartColors.gpu,
        stream: stream,
        extractValue: (s) => s.gpuPct,
        valueFormatter: (v) => v != null ? '${v.toStringAsFixed(1)}%' : '—',
        statCalculator: (_) => [],
        unit: '%',
        enableDragSelection: true,
        onDragSelection: onDrag,
      ),
    );
  }

  Widget _buildBatteryChart(
    List<MetricSample> samples,
    Stream<MetricSample> stream,
    void Function(int, int) onDrag,
    AppColors colors,
  ) {
    return SizedBox(
      height: 200,
      child: MetricChart(
        label: 'Battery',
        lineColor: ChartColors.batteryPct,
        stream: stream,
        extractValue: (s) => s.batteryPct?.toDouble(),
        valueFormatter: (v) => v != null ? '${v.toInt()}%' : '—',
        statCalculator: (_) => [],
        unit: '%',
        enableDragSelection: true,
        onDragSelection: onDrag,
      ),
    );
  }
}
