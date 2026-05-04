import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';

/// Session history list — sortable, filterable past sessions.
/// Table header with columns: Date, App, Device, Duration, FPS, Tag.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        backgroundColor: colors.bgSidebar,
        title: Text(
          'Session History',
          style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.md),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: colors.textSecondary),
            onPressed: () {
              // Filter — wired in Wave 5
            },
          ),
          IconButton(
            icon: Icon(Icons.sort, color: colors.textSecondary),
            onPressed: () {
              // Sort — wired in Wave 5
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Table header
          _TableHeader(colors: colors),
          const Divider(height: 1),
          // Empty state
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 48, color: colors.textDisabled),
                  const SizedBox(height: 12),
                  Text(
                    'No sessions recorded yet',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: TextTokens.base,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Connect a device and start profiling',
                    style: TextStyle(
                      color: colors.textDisabled,
                      fontSize: TextTokens.sm,
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

class _TableHeader extends StatelessWidget {
  final AppColors colors;

  const _TableHeader({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.bgElevated,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _HeaderCell(label: 'Date', flex: 2, colors: colors),
          _HeaderCell(label: 'App', flex: 3, colors: colors),
          _HeaderCell(label: 'Device', flex: 2, colors: colors),
          _HeaderCell(label: 'Duration', flex: 1, colors: colors),
          _HeaderCell(label: 'FPS', flex: 1, colors: colors),
          _HeaderCell(label: 'Tag', flex: 1, colors: colors),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  final AppColors colors;

  const _HeaderCell({
    required this.label,
    required this.flex,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: TextTokens.xs,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
