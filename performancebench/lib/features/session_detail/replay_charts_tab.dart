import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// Replay charts tab — shows historical metric charts for a completed session.
/// Wired in Wave 3 (MP-11).
class ReplayChartsTab extends StatelessWidget {
  final String sessionId;

  const ReplayChartsTab({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 48, color: colors.textDisabled),
          const SizedBox(height: 12),
          Text(
            'Replay charts will appear here',
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
