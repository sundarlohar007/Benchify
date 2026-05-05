// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/database/region_stats_dao.dart';
import '../../core/models/region_stats.dart';
import '../../shared/theme.dart';

/// Regions tab — displays per-region stats for a session.
/// Same format as MarkersDetailTab with columns: Label | Duration | FPS Med |
/// FPS Min | 1% Low | Stability | CPU Avg | Mem Peak | GPU Avg |
/// Battery Drain | Jank/min.
class RegionTab extends StatefulWidget {
  final String sessionId;

  const RegionTab({super.key, required this.sessionId});

  @override
  State<RegionTab> createState() => RegionTabState();
}

class RegionTabState extends State<RegionTab> {
  List<RegionStats>? _regions;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    final db = await initDatabase();
    final dao = RegionStatsDao(db);
    final regions = await dao.getBySessionId(widget.sessionId);
    if (mounted) setState(() => _regions = regions);
  }

  /// Public refresh — called when new region stats are computed.
  Future<void> refresh() => _loadRegions();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final regions = _regions;

    if (regions == null || regions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.select_all, size: 48, color: colors.textDisabled),
            const SizedBox(height: 12),
            Text(
              'Drag-select a region on the Charts tab to see stats here',
              style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm),
            ),
            const SizedBox(height: 4),
            Text(
              'Region stats match per-marker stats format',
              style: TextStyle(color: colors.textDisabled, fontSize: TextTokens.xs),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 16,
          headingTextStyle: TextStyle(
            color: colors.textSecondary,
            fontSize: TextTokens.xs,
            fontWeight: FontWeight.w600,
            fontFamily: monoFontFamily(),
          ),
          dataTextStyle: TextStyle(
            color: colors.textPrimary,
            fontSize: TextTokens.monoSm,
            fontFamily: monoFontFamily(),
          ),
          columns: const [
            DataColumn(label: Text('Label')),
            DataColumn(label: Text('Duration')),
            DataColumn(label: Text('FPS Med')),
            DataColumn(label: Text('FPS Min')),
            DataColumn(label: Text('1% Low')),
            DataColumn(label: Text('Stability')),
            DataColumn(label: Text('CPU Avg')),
            DataColumn(label: Text('Mem Peak')),
            DataColumn(label: Text('GPU Avg')),
            DataColumn(label: Text('Battery')),
            DataColumn(label: Text('Jank/min')),
          ],
          rows: regions.map((r) {
            return DataRow(
              color: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) return colors.bgHover;
                return null;
              }),
              cells: [
                DataCell(Text(r.label)),
                DataCell(Text(_fmtMs(r.durationMs))),
                DataCell(Text(_fmtDouble(r.fpsMedian, 'fps'))),
                DataCell(Text(_fmtDouble(r.fpsMin, 'fps'))),
                DataCell(Text(_fmtDouble(r.fps1pctLow, 'fps'))),
                DataCell(Text(_fmtPct(r.fpsStability))),
                DataCell(Text(_fmtPct(r.cpuAvgPct))),
                DataCell(Text(_fmtKb(r.memoryPeakKb))),
                DataCell(Text(_fmtPct(r.gpuAvgPct))),
                DataCell(Text(_fmtPct(r.batteryDrainPct))),
                DataCell(Text(_fmtDouble(r.jankPerMin, 'j/min'))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _fmtMs(int? ms) {
    if (ms == null || ms == 0) return '—';
    if (ms < 1000) return '${ms}ms';
    final sec = ms / 1000;
    if (sec < 60) return '${sec.toStringAsFixed(1)}s';
    final min = sec / 60;
    return '${min.toStringAsFixed(1)}m';
  }

  String _fmtDouble(double? v, String _) {
    if (v == null) return '—';
    return v.toStringAsFixed(1);
  }

  String _fmtPct(double? v) {
    if (v == null) return '—';
    return '${v.toStringAsFixed(1)}%';
  }

  String _fmtKb(int? v) {
    if (v == null) return '—';
    if (v >= 1024 * 1024) return '${(v / (1024 * 1024)).toStringAsFixed(1)} GB';
    if (v >= 1024) return '${(v / 1024).toStringAsFixed(1)} MB';
    return '$v KB';
  }
}
