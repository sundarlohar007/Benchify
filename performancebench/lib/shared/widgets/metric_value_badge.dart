// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';

import '../theme.dart';

/// Small metric value badge used in status bar and sidebar.
/// Shows a label and monospace value with optional color.
class MetricValueBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const MetricValueBadge({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.bgInput,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: TextTokens.xs,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? colors.textPrimary,
              fontSize: TextTokens.xs,
              fontFamily: monoFontFamily(),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
