import 'package:flutter/material.dart';

import '../theme.dart';

/// FPS histogram chart — bar chart showing FPS distribution.
/// Stub — wired with fl_chart in Wave 3 (MP-11).
class FpsHistogramChart extends StatelessWidget {
  final Map<int, int>? histogram;
  final double medianFps;
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
        color: colors.bgElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.borderSubtle, width: 0.5),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FPS Distribution',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: TextTokens.xs,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (histogram != null)
            Row(
              children: [
                _StatPill(label: 'Med', value: medianFps.toStringAsFixed(1), colors: colors),
                const SizedBox(width: 8),
                _StatPill(label: '1%', value: p1Low.toStringAsFixed(1), colors: colors),
              ],
            ),
          const Spacer(),
          Center(
            child: Text(
              histogram == null ? 'No data' : 'Histogram',
              style: TextStyle(
                color: colors.textDisabled,
                fontSize: TextTokens.xs,
              ),
            ),
          ),
        ],
      ),
    );
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
