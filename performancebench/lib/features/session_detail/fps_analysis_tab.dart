// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';

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
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

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
                  _StatTile('Median', '--', colors),
                  _StatTile('Min', '--', colors),
                  _StatTile('Max', '--', colors),
                  _StatTile('1% Low', '--', colors),
                  _StatTile('95th Pct', '--', colors),
                  _StatTile('Stability', '--', colors),
                  _StatTile('Small Jank', '--', colors),
                  _StatTile('Jank', '--', colors),
                  _StatTile('Big Jank', '--', colors),
                  _StatTile('Jank/min', '--', colors),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: FpsHistogramChart(histogram: null, medianFps: 0, p1Low: 0),
          ),
        ],
      ),
    );
  }
}

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
