import 'package:flutter/material.dart';

import '../theme.dart';

/// Session scorecard widget — shows key metrics in a grid layout.
/// Stub — wired in Wave 3 (MP-11).
class ScorecardWidget extends StatelessWidget {
  final Map<String, String>? metrics;

  const ScorecardWidget({super.key, this.metrics});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final displayMetrics = metrics ?? _defaultMetrics;

    return GridView.count(
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      children: displayMetrics.entries.map((entry) {
        return Container(
          decoration: BoxDecoration(
            color: colors.bgElevated,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colors.borderSubtle, width: 0.5),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                entry.key,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: TextTokens.xs,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.value,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: TextTokens.monoValue,
                  fontFamily: monoFontFamily(),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

const _defaultMetrics = <String, String>{
  'FPS Med': '--',
  'FPS 1%': '--',
  'CPU Avg': '--',
  'CPU Peak': '--',
  'Mem Avg': '--',
  'Mem Peak': '--',
  'GPU Avg': '--',
  'Battery': '--',
};
