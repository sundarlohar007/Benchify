import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// Scorecard tab — shows session_stats summary widget.
/// Wired in Wave 3 (MP-11).
class ScorecardTab extends StatelessWidget {
  final String sessionId;

  const ScorecardTab({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assessment, size: 48, color: colors.textDisabled),
          const SizedBox(height: 12),
          Text(
            'Session scorecard will appear here',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: TextTokens.sm,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'End a recording session to compute stats',
            style: TextStyle(
              color: colors.textDisabled,
              fontSize: TextTokens.xs,
            ),
          ),
        ],
      ),
    );
  }
}
