import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// Screenshots tab in session detail — shows captured screenshots for review.
class ScreenshotsTab extends StatefulWidget {
  final String sessionId;

  const ScreenshotsTab({super.key, required this.sessionId});

  @override
  State<ScreenshotsTab> createState() => _ScreenshotsTabState();
}

class _ScreenshotsTabState extends State<ScreenshotsTab> {
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
            'Session screenshots appear here',
            style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm),
          ),
          const SizedBox(height: 4),
          Text(
            'Screenshots saved during recording are available for review',
            style: TextStyle(color: colors.textDisabled, fontSize: TextTokens.xs),
          ),
        ],
      ),
    );
  }
}
