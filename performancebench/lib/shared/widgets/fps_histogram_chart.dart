// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// FPS histogram bar chart showing distribution of FPS values across buckets.
///
/// Takes a histogram map (bucket_start_fps → count) and renders a fl_chart
/// BarChart with VS Code Dark+ styling. Per UNIFIED-SPEC section 9.4.
class FpsHistogramChart extends StatelessWidget {
  /// Histogram data: bucket start FPS → count of samples in that bucket.
  /// Typical buckets: 0-10, 10-20, ... up to target FPS + buffer.
  final Map<int, int>? histogram;

  /// Median FPS for stat pills.
  final double medianFps;

  /// 1% low FPS for stat pills.
  final double p1Low;

  const FpsHistogramChart({
    super.key,
    this.histogram,
    this.medianFps = 0,
    this.p1Low = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.bgSidebar,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.borderSubtle, width: 0.5),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FPS Distribution',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: TextTokens.xs,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          if (histogram != null && histogram!.isNotEmpty)
            Row(
              children: [
                _StatPill(
                  label: 'Med',
                  value: medianFps.toStringAsFixed(1),
                  colors: colors,
                ),
                const SizedBox(width: 8),
                _StatPill(
                  label: '1%',
                  value: p1Low.toStringAsFixed(1),
                  colors: colors,
                ),
              ],
            ),
          const SizedBox(height: 4),
          Expanded(
            child: histogram != null && histogram!.isNotEmpty
                ? _buildBarChart(colors)
                : Center(
                    child: Text(
                      'No histogram data',
                      style: TextStyle(
                        color: colors.textDisabled,
                        fontSize: TextTokens.xs,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(AppColors colors) {
    final entries = histogram!.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    if (total == 0 || entries.isEmpty) {
      return Center(
        child: Text(
          'No histogram data',
          style: TextStyle(
            color: colors.textDisabled,
            fontSize: TextTokens.xs,
          ),
        ),
      );
    }

    final barGroups = <BarChartGroupData>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final pct = entry.value / total * 100;

      barGroups.add(
        BarChartGroupData(
          x: entry.key,
          barRods: [
            BarChartRodData(
              toY: pct,
              color: colors.accentBlue.withOpacity(0.8),
              width: entries.length > 30 ? 2 : 6,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(2),
                topRight: Radius.circular(2),
              ),
            ),
          ],
        ),
      );
    }

    final maxY = barGroups
        .expand((g) => g.barRods)
        .map((r) => r.toY)
        .reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        maxY: maxY * 1.15,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval: _calcInterval(maxY),
          getDrawingHorizontalLine: (value) => FlLine(
            color: colors.borderSubtle.withOpacity(0.3),
            strokeWidth: 0.5,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: entries.length > 15
                  ? (entries.length / 8).ceilToDouble()
                  : 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() % 5 != 0 && entries.length > 30) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: colors.textDisabled,
                      fontSize: 9,
                      fontFamily: monoFontFamily(),
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: TextStyle(
                    color: colors.textDisabled,
                    fontSize: 9,
                    fontFamily: monoFontFamily(),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colors.bgElevated,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final count = entries[groupIndex].value;
              final pct = total > 0
                  ? (count / total * 100).toStringAsFixed(1)
                  : '0.0';
              return BarTooltipItem(
                '${group.x}-${group.x + 10} FPS\n$count samples ($pct%)',
                TextStyle(
                  color: colors.textPrimary,
                  fontSize: 11,
                  fontFamily: monoFontFamily(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  double _calcInterval(double maxY) {
    if (maxY <= 0) return 10;
    final raw = maxY / 4;
    final magnitude =
        (raw >= 1) ? 5 * (raw / 5).round().toDouble() : raw;
    return magnitude > 0 ? magnitude : 5;
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final AppColors colors;

  const _StatPill({
    required this.label,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.bgInput,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: TextTokens.monoSm,
          fontFamily: monoFontFamily(),
        ),
      ),
    );
  }
}
