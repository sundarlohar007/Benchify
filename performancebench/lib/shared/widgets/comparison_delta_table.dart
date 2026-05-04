import 'package:flutter/material.dart';

import '../theme.dart';

/// Session comparison delta table — side-by-side metric comparison
/// with delta values and color-coded regressions.
/// Stub — wired in Wave 5 (MP-14).
class ComparisonDeltaTable extends StatelessWidget {
  final List<Map<String, dynamic>>? data;

  const ComparisonDeltaTable({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (data == null || data!.isEmpty) {
      return Center(
        child: Text(
          'Select two sessions to compare',
          style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm),
        ),
      );
    }

    // Placeholder table
    return Column(
      children: data!.map((row) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.borderSubtle)),
          ),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text('${row['metric'] ?? '--'}',
                  style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm))),
              Expanded(child: Text('${row['value_a'] ?? '--'}',
                  style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm,
                      fontFamily: monoFontFamily()))),
              Expanded(child: Text('${row['value_b'] ?? '--'}',
                  style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm,
                      fontFamily: monoFontFamily()))),
              Expanded(child: Text('${row['delta'] ?? '--'}',
                  style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm,
                      fontFamily: monoFontFamily()))),
            ],
          ),
        );
      }).toList(),
    );
  }
}
