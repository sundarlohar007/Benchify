import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';

/// Two-session side-by-side comparison screen.
/// Session selector dropdowns + empty delta table (MP-14).
class ComparisonScreen extends ConsumerWidget {
  const ComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        backgroundColor: colors.bgSidebar,
        title: Text(
          'Compare Sessions',
          style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.md),
        ),
      ),
      body: Column(
        children: [
          // Session selectors
          Container(
            color: colors.bgElevated,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _SessionSelector(
                    label: 'Session A',
                    colors: colors,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SessionSelector(
                    label: 'Session B',
                    colors: colors,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Delta table placeholder
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.compare_arrows, size: 48,
                      color: colors.textDisabled),
                  const SizedBox(height: 12),
                  Text(
                    'Select two sessions to compare',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: TextTokens.base,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Side-by-side metric comparison will appear here',
                    style: TextStyle(
                      color: colors.textDisabled,
                      fontSize: TextTokens.xs,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionSelector extends StatelessWidget {
  final String label;
  final AppColors colors;

  const _SessionSelector({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.bgInput,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.textDisabled, fontSize: TextTokens.sm),
            ),
          ),
          Icon(Icons.arrow_drop_down, color: colors.textSecondary, size: 20),
        ],
      ),
    );
  }
}
