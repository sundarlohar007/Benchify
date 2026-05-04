import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// Session screenshots tab — shows screenshots from a completed session.
/// Wired in Wave 4 (MP-17).
class ScreenshotsTab extends StatelessWidget {
  final String sessionId;

  const ScreenshotsTab({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image, size: 48, color: colors.textDisabled),
          const SizedBox(height: 12),
          Text(
            'Session screenshots will appear here',
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
