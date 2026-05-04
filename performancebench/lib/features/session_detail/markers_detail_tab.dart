import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// Markers detail tab — shows marker timeline with stats for completed session.
/// Wired in Wave 3 (MP-11).
class MarkersDetailTab extends StatelessWidget {
  final String sessionId;

  const MarkersDetailTab({super.key, required this.sessionId});

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
            'Marker details will appear here',
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
