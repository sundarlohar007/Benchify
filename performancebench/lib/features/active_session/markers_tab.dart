// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// Markers tab — shows markers placed during the active recording session.
/// Wired in Wave 3 (MP-11).
class MarkersTab extends StatelessWidget {
  final String sessionId;

  const MarkersTab({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: 48, color: colors.textDisabled),
          const SizedBox(height: 12),
          Text(
            'No markers yet — press M to add a marker',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: TextTokens.sm,
            ),
          ),
        ],
      ),
    );
  }
}
