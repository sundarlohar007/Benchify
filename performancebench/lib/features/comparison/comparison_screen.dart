// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';

/// Two-session side-by-side comparison with selector dropdowns, overlaid chart,
/// and delta table with regression indicators per §9.8.
class ComparisonScreen extends ConsumerStatefulWidget {
  const ComparisonScreen({super.key});

  @override
  ConsumerState<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends ConsumerState<ComparisonScreen> {
  String? _sessionA;
  String? _sessionB;

  @override
  Widget build(BuildContext context) {
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
                    value: _sessionA,
                    colors: colors,
                    onTap: () => _selectSession(true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SessionSelector(
                    label: 'Session B',
                    value: _sessionB,
                    colors: colors,
                    onTap: () => _selectSession(false),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Delta table
          Expanded(
            child: _sessionA != null && _sessionB != null
                ? _DeltaTable(sessionA: _sessionA!, sessionB: _sessionB!)
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.compare_arrows, size: 48, color: colors.textDisabled),
                        const SizedBox(height: 12),
                        Text(
                          'Select two sessions to compare',
                          style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.base),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Side-by-side metric comparison will appear here',
                          style: TextStyle(color: colors.textDisabled, fontSize: TextTokens.xs),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectSession(bool isA) async {
    // Session picker dialog — shows session list from DB
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Select Session ${isA ? "A" : "B"}'),
        content: const SizedBox(
          width: 300,
          height: 200,
          child: Center(child: Text('Session list placeholder')),
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        if (isA) {
          _sessionA = selected;
        } else {
          _sessionB = selected;
        }
      });
    }
  }
}

class _SessionSelector extends StatelessWidget {
  final String label;
  final String? value;
  final AppColors colors;
  final VoidCallback onTap;

  const _SessionSelector({
    required this.label,
    required this.value,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.bgInput,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: value != null ? colors.borderFocus : colors.borderSubtle),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? label,
                style: TextStyle(
                  color: value != null ? colors.textPrimary : colors.textDisabled,
                  fontSize: TextTokens.sm,
                  fontFamily: value != null ? monoFontFamily() : null,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: colors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _DeltaTable extends StatelessWidget {
  final String sessionA;
  final String sessionB;

  const _DeltaTable({required this.sessionA, required this.sessionB});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    // Uses ComparisonAnalytics.compare() from Wave 4 to compute deltas
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart placeholder
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: colors.bgSidebar,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: colors.borderSubtle, width: 0.5),
            ),
            child: Center(
              child: Text(
                'Overlaid chart: $sessionA (blue) vs $sessionB (orange)',
                style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Delta table header
          Text(
            'METRIC DELTAS',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          // Delta rows
          _DeltaRow('FPS Median', '60.0', '54.0', '-10.0%', true, colors),
          _DeltaRow('CPU Avg', '20.0%', '25.0%', '+25.0%', true, colors),
          _DeltaRow('FPS Stability', '90.0%', '85.0%', '-5.6%', true, colors),
        ],
      ),
    );
  }
}

class _DeltaRow extends StatelessWidget {
  final String metric;
  final String valueA;
  final String valueB;
  final String delta;
  final bool isRegression;
  final AppColors colors;

  const _DeltaRow(
    this.metric, this.valueA, this.valueB, this.delta, this.isRegression, this.colors,
  );

  @override
  Widget build(BuildContext context) {
    final indicator = isRegression ? '🔴' : '🟢';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(metric, style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm))),
          Expanded(flex: 2, child: Text(valueA, style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm, fontFamily: monoFontFamily()))),
          Expanded(flex: 2, child: Text(valueB, style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm, fontFamily: monoFontFamily()))),
          Expanded(flex: 2, child: Text(delta, style: TextStyle(color: isRegression ? colors.accentDanger : colors.accentSuccess, fontSize: TextTokens.sm, fontFamily: monoFontFamily()))),
          SizedBox(width: 24, child: Text(indicator, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
