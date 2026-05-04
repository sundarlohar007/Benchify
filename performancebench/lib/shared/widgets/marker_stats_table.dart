// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';

import '../theme.dart';

/// Per-marker analytics table — shows marker-level stats for a session.
/// Stub — wired in Wave 3 (MP-11).
class MarkerStatsTable extends StatelessWidget {
  final List<Map<String, dynamic>>? data;

  const MarkerStatsTable({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (data == null || data!.isEmpty) {
      return Center(
        child: Text(
          'No marker data available',
          style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm),
        ),
      );
    }

    return Column(
      children: data!.map((row) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.borderSubtle)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  '${row['label'] ?? '--'}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: TextTokens.sm,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${row['fps_median'] ?? '--'}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: TextTokens.sm,
                    fontFamily: monoFontFamily(),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${row['jank_per_min'] ?? '--'}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: TextTokens.sm,
                    fontFamily: monoFontFamily(),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
