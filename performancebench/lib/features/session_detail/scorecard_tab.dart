// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// Scorecard tab — loads session_stats from DB and displays in 2-column grid.
class ScorecardTab extends StatefulWidget {
  final String sessionId;

  const ScorecardTab({super.key, required this.sessionId});

  @override
  State<ScorecardTab> createState() => _ScorecardTabState();
}

class _ScorecardTabState extends State<ScorecardTab> {
  // Stats loaded from session_stats — displayed as placeholder until DB wired
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

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
                _StatRow('Median', '--', colors),
                _StatRow('Min', '--', colors),
                _StatRow('Max', '--', colors),
                _StatRow('1% Low', '--', colors),
                _StatRow('95th Pct', '--', colors),
                _StatRow('Stability', '--', colors),
                const SizedBox(height: 16),
                _SectionHeader('Memory', colors),
                _StatRow('Average', '--', colors),
                _StatRow('Peak', '--', colors),
                const SizedBox(height: 16),
                _SectionHeader('Battery', colors),
                _StatRow('Drain %/hr', '--', colors),
                _StatRow('Avg mA', '--', colors),
                _StatRow('Avg mV', '--', colors),
                _StatRow('Temp Peak', '--', colors),
                const SizedBox(height: 16),
                _SectionHeader('Thermal', colors),
                _StatRow('Peak', '--', colors),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader('Jank', colors),
                _StatRow('Small /min', '--', colors),
                _StatRow('Standard /min', '--', colors),
                _StatRow('Big /min', '--', colors),
                const SizedBox(height: 16),
                _SectionHeader('CPU', colors),
                _StatRow('Average', '--', colors),
                _StatRow('Peak', '--', colors),
                const SizedBox(height: 16),
                _SectionHeader('GPU', colors),
                _StatRow('Average', '--', colors),
                _StatRow('Peak', '--', colors),
                const SizedBox(height: 16),
                _SectionHeader('Network', colors),
                _StatRow('TX Total', '--', colors),
                _StatRow('RX Total', '--', colors),
                _StatRow('TX Avg', '--', colors),
                _StatRow('RX Avg', '--', colors),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
