import 'package:flutter/material.dart';

import '../theme.dart';

/// Reusable metric chart widget (line chart for real-time and replay).
/// Accepts data points, metric label, color, and optional fill gradient.
/// Stub — wired with fl_chart in Wave 2 (MP-06).
class MetricChart extends StatelessWidget {
  final String label;
  final String unit;
  final Color lineColor;
  final Color? fillColor;
  final List<double>? data;
  final double currentValue;

  const MetricChart({
    super.key,
    required this.label,
    required this.unit,
    required this.lineColor,
    this.fillColor,
    this.data,
    this.currentValue = 0,
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
          // Label row
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: TextTokens.xs,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                unit,
                style: TextStyle(
                  color: colors.textDisabled,
                  fontSize: TextTokens.xs,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Current value
          Text(
            currentValue.toStringAsFixed(1),
            style: TextStyle(
              color: lineColor,
              fontSize: TextTokens.lg,
              fontFamily: monoFontFamily(),
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Chart placeholder
          Expanded(
            child: Center(
              child: Text(
                data == null ? 'No data' : 'Chart',
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
}
