import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme.dart';

/// Filter state for session history.
class HistoryFilters {
  final String platform; // '', 'android', 'ios'
  final String deviceId;
  final String appPackage;
  final String search;

  const HistoryFilters({
    this.platform = '',
    this.deviceId = '',
    this.appPackage = '',
    this.search = '',
  });

  HistoryFilters copyWith({
    String? platform,
    String? deviceId,
    String? appPackage,
    String? search,
  }) {
    return HistoryFilters(
      platform: platform ?? this.platform,
      deviceId: deviceId ?? this.deviceId,
      appPackage: appPackage ?? this.appPackage,
      search: search ?? this.search,
    );
  }

  bool get isActive =>
      platform.isNotEmpty || deviceId.isNotEmpty || appPackage.isNotEmpty || search.isNotEmpty;
}

final historyFiltersProvider = StateProvider<HistoryFilters>((ref) => const HistoryFilters());

/// Session history list screen with filtering, sorting, and search.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final filters = ref.watch(historyFiltersProvider);

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        backgroundColor: colors.bgSidebar,
        title: Text(
          'Session History',
          style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.md),
        ),
      ),
      body: Column(
        children: [
          _FilterBar(colors: colors, filters: filters),
          const Divider(height: 1),
          _TableHeader(colors: colors),
          const Divider(height: 1),
          Expanded(
            child: _SessionList(filters: filters),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  final AppColors colors;
  final HistoryFilters filters;

  const _FilterBar({required this.colors, required this.filters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: colors.bgElevated,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          _FilterDropdown(
            label: 'Platform',
            value: filters.platform,
            items: const [
              ('', 'All'),
              ('android', 'Android'),
              ('ios', 'iOS'),
            ],
            onChanged: (v) => ref.read(historyFiltersProvider.notifier).state =
                filters.copyWith(platform: v ?? ''),
          ),
          const SizedBox(width: 8),
          _FilterDropdown(
            label: 'App',
            value: filters.appPackage,
            items: const [('', 'All Apps')],
            onChanged: (v) => ref.read(historyFiltersProvider.notifier).state =
                filters.copyWith(appPackage: v ?? ''),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 28,
              child: TextField(
                style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm),
                decoration: InputDecoration(
                  hintText: 'Search sessions...',
                  prefixIcon: Icon(Icons.search, size: 14, color: colors.textDisabled),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onChanged: (v) => ref.read(historyFiltersProvider.notifier).state =
                    filters.copyWith(search: v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<(String, String)> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.bgInput,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm),
          dropdownColor: colors.bgElevated,
          isDense: true,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item.$1,
              child: Text(item.$2, style: TextStyle(fontSize: TextTokens.sm)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
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
      color: colors.bgSidebar,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _HeaderCell(label: 'Date', flex: 2, colors: colors),
          _HeaderCell(label: 'App', flex: 3, colors: colors),
          _HeaderCell(label: 'Device', flex: 2, colors: colors),
          _HeaderCell(label: 'Duration', flex: 1, colors: colors),
          _HeaderCell(label: 'FPS', flex: 1, colors: colors),
          _HeaderCell(label: 'Tags', flex: 1, colors: colors),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  final AppColors colors;

  const _HeaderCell({required this.label, required this.flex, required this.colors});

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

class _SessionList extends ConsumerWidget {
  final HistoryFilters filters;

  const _SessionList({required this.filters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);

    // Placeholder: sessions load from DB — empty state for now
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 48, color: colors.textDisabled),
          const SizedBox(height: 12),
          Text(
            'No sessions recorded yet',
            style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.base),
          ),
          const SizedBox(height: 4),
          Text(
            'Connect a device and start profiling',
            style: TextStyle(color: colors.textDisabled, fontSize: TextTokens.sm),
          ),
        ],
      ),
    );
  }
}
