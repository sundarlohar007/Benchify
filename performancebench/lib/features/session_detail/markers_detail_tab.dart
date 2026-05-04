import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// Markers detail tab — sortable table of per-marker stats.
class MarkersDetailTab extends StatefulWidget {
  final String sessionId;

  const MarkersDetailTab({super.key, required this.sessionId});

  @override
  State<MarkersDetailTab> createState() => _MarkersDetailTabState();
}

class _MarkersDetailTabState extends State<MarkersDetailTab> {
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
            'Markers placed during session appear here',
            style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm),
          ),
          const SizedBox(height: 4),
          Text(
            'Per-marker stats computed after session ends',
            style: TextStyle(color: colors.textDisabled, fontSize: TextTokens.xs),
          ),
        ],
      ),
    );
  }
}
