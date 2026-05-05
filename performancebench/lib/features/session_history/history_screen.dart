// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme.dart';
import '../../core/database/session_dao.dart';
import '../../core/models/session.dart';
import '../../core/database/database.dart';
import '../../core/services/api_service.dart';
import '../../core/services/upload_service.dart';

/// Extended filter state for session history (v1.5 enhanced).
class HistoryFilters {
  final String search;
  final String tag;
  final String deviceModel;
  final String appPackage;
  final String chipset;
  final String collectionId;

  const HistoryFilters({
    this.search = '',
    this.tag = '',
    this.deviceModel = '',
    this.appPackage = '',
    this.chipset = '',
    this.collectionId = '',
  });

  HistoryFilters copyWith({
    String? search,
    String? tag,
    String? deviceModel,
    String? appPackage,
    String? chipset,
    String? collectionId,
  }) {
    return HistoryFilters(
      search: search ?? this.search,
      tag: tag ?? this.tag,
      deviceModel: deviceModel ?? this.deviceModel,
      appPackage: appPackage ?? this.appPackage,
      chipset: chipset ?? this.chipset,
      collectionId: collectionId ?? this.collectionId,
    );
  }

  bool get isActive =>
      search.isNotEmpty ||
      tag.isNotEmpty ||
      deviceModel.isNotEmpty ||
      appPackage.isNotEmpty ||
      chipset.isNotEmpty ||
      collectionId.isNotEmpty;

  /// Returns list of active filter chips for display.
  List<_ActiveFilter> get activeFilters {
    final result = <_ActiveFilter>[];
    if (tag.isNotEmpty) result.add(_ActiveFilter('Tag', tag, 'tag'));
    if (deviceModel.isNotEmpty) result.add(_ActiveFilter('Device', deviceModel, 'deviceModel'));
    if (appPackage.isNotEmpty) result.add(_ActiveFilter('App', appPackage, 'appPackage'));
    if (chipset.isNotEmpty) result.add(_ActiveFilter('Chipset', chipset, 'chipset'));
    if (collectionId.isNotEmpty) result.add(_ActiveFilter('Collection', collectionId, 'collectionId'));
    return result;
  }

  /// Clear a specific filter by key.
  HistoryFilters clearFilter(String key) {
    switch (key) {
      case 'tag':
        return copyWith(tag: '');
      case 'deviceModel':
        return copyWith(deviceModel: '');
      case 'appPackage':
        return copyWith(appPackage: '');
      case 'chipset':
        return copyWith(chipset: '');
      case 'collectionId':
        return copyWith(collectionId: '');
      default:
        return this;
    }
  }
}

class _ActiveFilter {
  final String label;
  final String value;
  final String key;
  const _ActiveFilter(this.label, this.value, this.key);
}

final historyFiltersProvider = StateProvider<HistoryFilters>((ref) => const HistoryFilters());

/// Session history list screen with enhanced filter bar (v1.5: tag, device,
/// chipset, collection filters + text search).
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<Session> _sessions = [];
  bool _loading = true;
  Timer? _debounce;
  final _searchController = TextEditingController();
  bool _multiSelectMode = false;
  final Set<String> _selectedIds = {};
  bool _hasServerConfig = false;
  UploadService? _uploadService;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _checkServerConfig();
  }

  Future<void> _checkServerConfig() async {
    final api = await ApiService.fromPreferences();
    if (mounted) {
      setState(() {
        _hasServerConfig = api != null;
        if (_hasServerConfig) {
          _uploadService = UploadService(api: api!);
        }
      });
    }
  }

  void _toggleMultiSelect() {
    setState(() {
      _multiSelectMode = !_multiSelectMode;
      if (!_multiSelectMode) _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _uploadSelected() async {
    if (_uploadService == null || _selectedIds.isEmpty) return;
    final selectedSessions = _sessions.where((s) => _selectedIds.contains(s.id)).toList();
    _uploadService!.addToQueue(selectedSessions);
    setState(() {
      _multiSelectMode = false;
      _selectedIds.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${selectedSessions.length} session(s) added to upload queue'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final filters = ref.read(historyFiltersProvider);
    try {
      final db = await initDatabase();
      final dao = SessionDao(db);

      List<Session> results;
      if (filters.isActive) {
        if (filters.search.isNotEmpty) {
          results = await dao.searchSessions(filters.search);
        } else {
          results = await dao.filterSessions(
            tag: filters.tag.isNotEmpty ? filters.tag : null,
            deviceModel: filters.deviceModel.isNotEmpty ? filters.deviceModel : null,
            appPackage: filters.appPackage.isNotEmpty ? filters.appPackage : null,
            chipset: filters.chipset.isNotEmpty ? filters.chipset : null,
            collectionId: filters.collectionId.isNotEmpty ? filters.collectionId : null,
          );
        }
      } else {
        results = await dao.getAll();
      }

      if (mounted) {
        setState(() {
          _sessions = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(historyFiltersProvider.notifier).state =
          ref.read(historyFiltersProvider).copyWith(search: value);
      _loadSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final filters = ref.watch(historyFiltersProvider);

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        backgroundColor: colors.bgSidebar,
        title: Text(
          _multiSelectMode
              ? '${_selectedIds.length} selected'
              : 'Session History',
          style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.md),
        ),
        actions: [
          if (_hasServerConfig)
            _multiSelectMode
                ? TextButton.icon(
                    onPressed: _selectedIds.isEmpty ? null : _uploadSelected,
                    icon: Icon(Icons.cloud_upload, size: 16, color: colors.accentBlue),
                    label: Text(
                      'Upload Selected (${_selectedIds.length})',
                      style: TextStyle(color: colors.accentBlue, fontSize: TextTokens.sm),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.cloud_upload_outlined, color: colors.textSecondary),
                    tooltip: 'Upload to Server',
                    onPressed: _toggleMultiSelect,
                  ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced filter bar (v1.5)
          _EnhancedFilterBar(
            colors: colors,
            filters: filters,
            searchController: _searchController,
            onSearchChanged: _onSearchChanged,
            onFiltersChanged: () => _loadSessions(),
          ),
          // Active filter chips
          if (filters.activeFilters.isNotEmpty) _ActiveFilterChips(
            colors: colors,
            filters: filters,
            onDismiss: (key) {
              ref.read(historyFiltersProvider.notifier).state =
                  filters.clearFilter(key);
              _loadSessions();
            },
          ),
          // Session count
          _SessionCountBar(colors: colors, count: _sessions.length, loading: _loading),
          const Divider(height: 1),
          // Table header
          _TableHeader(colors: colors),
          const Divider(height: 1),
          // Session list
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: colors.accentBlue))
                : _sessions.isEmpty
                    ? _EmptyState(colors: colors)
                    : _SessionListView(
                        colors: colors,
                        sessions: _sessions,
                        multiSelectMode: _multiSelectMode,
                        selectedIds: _selectedIds,
                        onToggleSelection: _toggleSelection,
                      ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Enhanced Filter Bar (V15-05)
// =============================================================================

class _EnhancedFilterBar extends StatefulWidget {
  final AppColors colors;
  final HistoryFilters filters;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFiltersChanged;

  const _EnhancedFilterBar({
    required this.colors,
    required this.filters,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFiltersChanged,
  });

  @override
  State<_EnhancedFilterBar> createState() => _EnhancedFilterBarState();
}

class _EnhancedFilterBarState extends State<_EnhancedFilterBar> {
  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Container(
      color: colors.bgElevated,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // Search input
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 28,
              child: TextField(
                controller: widget.searchController,
                style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm),
                decoration: InputDecoration(
                  hintText: 'Filter sessions...',
                  hintStyle: TextStyle(fontSize: TextTokens.sm),
                  prefixIcon: Icon(Icons.search, size: 14, color: colors.textDisabled),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onChanged: widget.onSearchChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Tag filter
          _CompactDropdown(
            label: 'Tag',
            value: widget.filters.tag,
            colors: colors,
            onChanged: (v) {
              final ref = context as dynamic;
              // We use the callback pattern instead of direct ref access
              widget.onFiltersChanged();
            },
          ),
          const SizedBox(width: 6),
          // Device filter
          _CompactDropdown(
            label: 'Device',
            value: widget.filters.deviceModel,
            colors: colors,
            onChanged: (v) {},
          ),
          const SizedBox(width: 6),
          // App filter
          _CompactDropdown(
            label: 'App',
            value: widget.filters.appPackage,
            colors: colors,
            onChanged: (v) {},
          ),
          const SizedBox(width: 6),
          // Chipset filter
          _CompactDropdown(
            label: 'Chipset',
            value: widget.filters.chipset,
            colors: colors,
            onChanged: (v) {},
          ),
        ],
      ),
    );
  }
}

/// Compact dropdown for filter bar (placeholder — values populated from DB/devices).
class _CompactDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final AppColors colors;
  final ValueChanged<String?> onChanged;

  const _CompactDropdown({
    required this.label,
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: colors.bgInput,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: (value?.isNotEmpty == true) ? value : null,
          hint: Text(label, style: TextStyle(fontSize: TextTokens.xs, color: colors.textDisabled)),
          style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.xs),
          dropdownColor: colors.bgElevated,
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'android', child: Text('Android', style: TextStyle(fontSize: 11))),
            DropdownMenuItem(value: 'ios', child: Text('iOS', style: TextStyle(fontSize: 11))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// =============================================================================
// Active Filter Chips (dismissible per §9.6 spec)
// =============================================================================

class _ActiveFilterChips extends StatelessWidget {
  final AppColors colors;
  final HistoryFilters filters;
  final void Function(String key) onDismiss;

  const _ActiveFilterChips({
    required this.colors,
    required this.filters,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.bgElevated,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: filters.activeFilters.map((f) {
          return Chip(
            label: Text(
              '${f.label}: ${f.value}',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: TextTokens.xs,
              ),
            ),
            deleteIcon: Icon(Icons.close, size: 12, color: colors.textSecondary),
            onDeleted: () => onDismiss(f.key),
            backgroundColor: colors.bgInput,
            side: BorderSide.none,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        }).toList(),
      ),
    );
  }
}

// =============================================================================
// Session Count Bar
// =============================================================================

class _SessionCountBar extends StatelessWidget {
  final AppColors colors;
  final int count;
  final bool loading;

  const _SessionCountBar({required this.colors, required this.count, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.bgSidebar,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            '$count session${count == 1 ? '' : 's'}',
            style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.xs),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () {},
            icon: Icon(Icons.refresh, size: 12, color: colors.textSecondary),
            label: Text('Refresh', style: TextStyle(fontSize: TextTokens.xs, color: colors.textSecondary)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Table Header
// =============================================================================

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

// =============================================================================
// Session List View
// =============================================================================

class _SessionListView extends StatelessWidget {
  final AppColors colors;
  final List<Session> sessions;
  final bool multiSelectMode;
  final Set<String> selectedIds;
  final void Function(String id) onToggleSelection;

  const _SessionListView({
    required this.colors,
    required this.sessions,
    this.multiSelectMode = false,
    this.selectedIds = const {},
    required this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final isEven = index % 2 == 0;

        return Material(
          color: isEven ? colors.bgBase : colors.bgHover.withAlpha(80),
          child: InkWell(
            onTap: () {
              if (multiSelectMode) {
                onToggleSelection(session.id);
              } else {
                context.push('/session/${session.id}');
              }
            },
            onHover: (hovering) {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Multi-select checkbox
                  if (multiSelectMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Checkbox(
                        value: selectedIds.contains(session.id),
                        activeColor: colors.accentBlue,
                        onChanged: (_) => onToggleSelection(session.id),
                      ),
                    ),
                  // Date
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatDate(session.startedAt),
                      style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm),
                    ),
                  ),
                  // App
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Text(
                          session.appName ?? session.appPackage,
                          style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (session.collectionId != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: colors.bgInput,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              session.collectionId!,
                              style: TextStyle(color: colors.textSecondary, fontSize: 9),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Device
                  Expanded(
                    flex: 2,
                    child: Text(
                      session.deviceId,
                      style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Duration
                  Expanded(
                    flex: 1,
                    child: Text(
                      _formatDuration(session.durationMs),
                      style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm),
                    ),
                  ),
                  // FPS (placeholder — will show actual FPS when stats wired)
                  Expanded(
                    flex: 1,
                    child: Text(
                      '--',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: TextTokens.sm,
                        fontFamily: monoFontFamily(),
                      ),
                    ),
                  ),
                  // Tags
                  Expanded(
                    flex: 1,
                    child: _tagChips(session, colors),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tagChips(Session session, AppColors colors) {
    final tags = <String>[];
    if (session.tags != null && session.tags!.isNotEmpty) {
      // Try JSON array parse; fallback to comma-separated
      try {
        final decoded = session.tags;
        if (decoded!.startsWith('[')) {
          // Simple extraction of quoted strings
          final matches = RegExp(r'"([^"]*)"').allMatches(decoded);
          for (final m in matches) {
            if (m.groupCount >= 1) tags.add(m.group(1)!);
          }
        } else {
          tags.addAll(decoded.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty));
        }
      } catch (_) {}
    }

    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: tags.take(2).map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: colors.bgInput,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            tag,
            style: TextStyle(color: colors.textSecondary, fontSize: 9),
          ),
        );
      }).toList(),
    );
  }

  String _formatDate(int unixMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(unixMs);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'Today ${_pad(dt.hour)}:${_pad(dt.minute)}';
    if (diff.inHours < 24) return '${_pad(dt.hour)}:${_pad(dt.minute)}';
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[dt.weekday - 1]} ${_pad(dt.hour)}:${_pad(dt.minute)}';
    }
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _formatDuration(int? ms) {
    if (ms == null) return '--';
    final minutes = ms ~/ 60000;
    final seconds = (ms % 60000) ~/ 1000;
    return '${minutes}m ${seconds}s';
  }
}

// =============================================================================
// Empty State
// =============================================================================

class _EmptyState extends StatelessWidget {
  final AppColors colors;

  const _EmptyState({required this.colors});

  @override
  Widget build(BuildContext context) {
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
