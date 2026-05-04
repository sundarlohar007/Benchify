// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';

import '../theme.dart';

/// GPU unavailable badge — shows when GPU metrics are not available
/// (common on devices without GPU counters — UNIFIED-SPEC §4.3).
class GpuUnavailableBadge extends StatelessWidget {
  final String? reason;

  const GpuUnavailableBadge({super.key, this.reason});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bgInput,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.accentWarning.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 14, color: colors.accentWarning),
          const SizedBox(width: 4),
          Text(
            reason ?? 'GPU data unavailable',
            style: TextStyle(
              color: colors.accentWarning,
              fontSize: TextTokens.xs,
            ),
          ),
        ],
      ),
    );
  }
}
