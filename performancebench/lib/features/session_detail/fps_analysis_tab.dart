import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// FPS Analysis tab — histogram, frame time distribution, jank breakdown.
/// Wired in Wave 3 (MP-11).
class FpsAnalysisTab extends StatelessWidget {
  final String sessionId;

  const FpsAnalysisTab({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart, size: 48, color: colors.textDisabled),
          const SizedBox(height: 12),
          Text(
            'FPS analysis will appear here',
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
