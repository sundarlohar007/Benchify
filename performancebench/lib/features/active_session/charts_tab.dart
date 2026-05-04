import 'package:flutter/material.dart';

import '../../shared/theme.dart';

/// Charts tab — 2-column grid of real-time metric chart cards.
/// Placeholder grid; wired with live data in Wave 2 (MP-06).
class ChartsTab extends StatelessWidget {
  final String sessionId;

  const ChartsTab({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.6,
        children: List.generate(
          6,
          (i) => _ChartPlaceholder(colors: colors, index: i),
        ),
      ),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  final AppColors colors;
  final int index;

  const _ChartPlaceholder({required this.colors, required this.index});

  static const _labels = ['FPS', 'CPU', 'Memory', 'Battery', 'Network', 'GPU'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.borderSubtle, width: 0.5),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _labels[index],
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: TextTokens.xs,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Center(
            child: Text(
              '--',
              style: TextStyle(
                color: colors.textDisabled,
                fontSize: TextTokens.lg,
                fontFamily: monoFontFamily(),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
