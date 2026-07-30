// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/database/session_stats_dao.dart';
import '../../core/models/session_stats.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/fps_histogram_chart.dart';

/// FPS Analysis tab — histogram bar chart + percentile stats panel.
class FpsAnalysisTab extends StatefulWidget {
  final String sessionId;

  const FpsAnalysisTab({super.key, required this.sessionId});

  @override
  State<FpsAnalysisTab> createState() => _FpsAnalysisTabState();
}

class _FpsAnalysisTabState extends State<FpsAnalysisTab> {
  SessionStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final db = await initDatabase();
      final stats = await SessionStatsDao(db).getBySessionId(widget.sessionId);
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _stats = null;
          _loading = false;
        });
      }
    }
  }

  Map<int, int>? _parseHistogram(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return null;
      final result = <int, int>{};
      for (final entry in decoded.entries) {
        final key = int.tryParse(entry.key.toString());
        final value = entry.value;
        if (key != null && value is num) {
          result[key] = value.toInt();
        }
      }
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: colors.accentBlue));
    }

    final s = _stats;
    final histogram = _parseHistogram(s?.fpsHistogram);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.bgSidebar,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: colors.borderSubtle, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FPS STATISTICS', style: TextStyle(
                  color: colors.textSecondary, fontSize: 10,
                  fontWeight: FontWeight.w600, letterSpacing: 1.2,
                )),
                const SizedBox(height: 12),
                Wrap(spacing: 24, runSpacing: 12, children: [
                  _StatTile('Median', _fmtFps(s?.fpsMedian), colors),
                  _StatTile('Min', _fmtFps(s?.fpsMin), colors),
                  _StatTile('Max', _fmtFps(s?.fpsMax), colors),
                  _StatTile('1% Low', _fmtFps(s?.fps1pctLow), colors),
                  _StatTile('95th Pct', _fmtMs(s?.frameTimeP95), colors),
                  _StatTile('Stability', _fmtPct(s?.fpsStability), colors),
                  _StatTile('Small Jank', _fmtInt(s?.jankSmallTotal), colors),
                  _StatTile('Jank', _fmtInt(s?.jankTotal), colors),
                  _StatTile('Big Jank', _fmtInt(s?.jankBigTotal), colors),
                  _StatTile('Jank/min', _fmtRate(s?.jankPerMin), colors),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: FpsHistogramChart(
              histogram: histogram,
              medianFps: s?.fpsMedian ?? 0,
              p1Low: s?.fps1pctLow ?? 0,
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtFps(double? v) => v == null ? '--' : v.toStringAsFixed(1);

String _fmtMs(double? v) => v == null ? '--' : '${v.toStringAsFixed(1)} ms';

String _fmtPct(double? v) => v == null ? '--' : '${v.toStringAsFixed(1)}%';

String _fmtInt(int? v) => v == null ? '--' : '$v';

String _fmtRate(double? v) => v == null ? '--' : v.toStringAsFixed(1);

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final AppColors colors;
  const _StatTile(this.label, this.value, this.colors);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.xs)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(
        color: colors.textPrimary, fontSize: TextTokens.monoValue,
        fontFamily: monoFontFamily(), fontWeight: FontWeight.w600,
      )),
    ]);
  }
}
