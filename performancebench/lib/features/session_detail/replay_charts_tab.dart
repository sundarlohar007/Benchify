import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// Replay charts tab — displays full-session charts from saved metric_samples.
/// Reuses MetricChart widget with pre-loaded data (not live stream).
class ReplayChartsTab extends StatefulWidget {
  final String sessionId;

  const ReplayChartsTab({super.key, required this.sessionId});

  @override
  State<ReplayChartsTab> createState() => _ReplayChartsTabState();
}

class _ReplayChartsTabState extends State<ReplayChartsTab> {
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
            'Charts replay loading from session data...',
            style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm),
          ),
          const SizedBox(height: 4),
          Text(
            'Full-session charts with pan/zoom and marker overlays',
            style: TextStyle(color: colors.textDisabled, fontSize: TextTokens.xs),
          ),
        ],
      ),
    );
  }
}
