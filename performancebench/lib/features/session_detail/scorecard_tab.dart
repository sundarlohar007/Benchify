// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/database/session_stats_dao.dart';
import '../../core/models/session_stats.dart';
import '../../shared/theme.dart';

/// Scorecard tab — loads session_stats from DB and displays in 2-column grid.
class ScorecardTab extends StatefulWidget {
  final String sessionId;

  const ScorecardTab({super.key, required this.sessionId});

  @override
  State<ScorecardTab> createState() => _ScorecardTabState();
}

class _ScorecardTabState extends State<ScorecardTab> {
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: colors.accentBlue));
    }

    final s = _stats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader('FPS', colors),
                _StatRow('Median', _fmtFps(s?.fpsMedian), colors),
                _StatRow('Min', _fmtFps(s?.fpsMin), colors),
                _StatRow('Max', _fmtFps(s?.fpsMax), colors),
                _StatRow('1% Low', _fmtFps(s?.fps1pctLow), colors),
                _StatRow('95th Pct', _fmtMs(s?.frameTimeP95), colors),
                _StatRow('Stability', _fmtPct(s?.fpsStability), colors),
                const SizedBox(height: 16),
                _SectionHeader('Memory', colors),
                _StatRow('Average', _fmtMemMb(s?.memoryAvgKb), colors),
                _StatRow('Peak', _fmtMemMb(s?.memoryPeakKb), colors),
                const SizedBox(height: 16),
                _SectionHeader('Battery', colors),
                _StatRow('Drain %/hr', _fmtDrain(s?.batteryDrainPerHour), colors),
                _StatRow('Avg mA', '--', colors),
                _StatRow('Avg mV', '--', colors),
                _StatRow('Temp Peak', _fmtTemp(s?.batteryTempMaxC), colors),
                const SizedBox(height: 16),
                _SectionHeader('Thermal', colors),
                _StatRow('Peak', _fmtInt(s?.thermalPeak), colors),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader('Jank', colors),
                _StatRow('Small /min', _fmtJankPerMin(s?.jankSmallTotal, s?.durationMs), colors),
                _StatRow('Standard /min', _fmtJankPerMin(s?.jankTotal, s?.durationMs), colors),
                _StatRow('Big /min', _fmtJankPerMin(s?.jankBigTotal, s?.durationMs), colors),
                const SizedBox(height: 16),
                _SectionHeader('CPU', colors),
                _StatRow('Average', _fmtPct(s?.cpuAvgPct), colors),
                _StatRow('Peak', _fmtPct(s?.cpuPeakPct), colors),
                const SizedBox(height: 16),
                _SectionHeader('GPU', colors),
                _StatRow('Average', _fmtPct(s?.gpuAvgPct), colors),
                _StatRow('Peak', _fmtPct(s?.gpuPeakPct), colors),
                const SizedBox(height: 16),
                _SectionHeader('Network', colors),
                _StatRow('TX Total', _fmtNetKb(s?.netTotalTxKb), colors),
                _StatRow('RX Total', _fmtNetKb(s?.netTotalRxKb), colors),
                _StatRow('TX Avg', _fmtNetAvg(s?.netTotalTxKb, s?.durationMs), colors),
                _StatRow('RX Avg', _fmtNetAvg(s?.netTotalRxKb, s?.durationMs), colors),
              ],
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

String _fmtMemMb(int? kb) =>
    kb == null ? '--' : '${(kb / 1024).toStringAsFixed(0)} MB';

String _fmtDrain(double? v) =>
    v == null ? '--' : '${v.toStringAsFixed(1)} %/hr';

String _fmtTemp(double? v) =>
    v == null ? '--' : '${v.toStringAsFixed(1)} °C';

String _fmtInt(int? v) => v == null ? '--' : '$v';

String _fmtJankPerMin(int? total, int? durationMs) {
  if (total == null) return '--';
  if (durationMs == null || durationMs <= 0) return total.toString();
  final perMin = total / (durationMs / 60000.0);
  return perMin.toStringAsFixed(1);
}

String _fmtNetKb(double? kb) {
  if (kb == null) return '--';
  if (kb >= 1024) return '${(kb / 1024).toStringAsFixed(1)} MB';
  return '${kb.toStringAsFixed(1)} KB';
}

String _fmtNetAvg(double? totalKb, int? durationMs) {
  if (totalKb == null || durationMs == null || durationMs <= 0) return '--';
  final kbps = totalKb / (durationMs / 1000.0);
  return '${kbps.toStringAsFixed(1)} KB/s';
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final AppColors colors;

  const _SectionHeader(this.label, this.colors);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final AppColors colors;

  const _StatRow(this.label, this.value, this.colors);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              fontFamily: monoFontFamily(),
            ),
          ),
        ],
      ),
    );
  }
}
