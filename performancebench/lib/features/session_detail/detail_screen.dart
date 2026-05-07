// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show Database;

import '../../shared/theme.dart';
import '../../core/database/database.dart';
import '../../core/database/session_dao.dart';
import '../../core/database/collection_dao.dart';
import '../../core/database/metric_dao.dart';
import '../../core/database/session_stats_dao.dart';
import '../../core/database/marker_dao.dart';
import '../../core/database/marker_stats_dao.dart';
import '../../core/database/region_stats_dao.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/models/collection.dart';
import '../../core/models/session.dart';
import 'scorecard_tab.dart';
import 'replay_charts_tab.dart';
import 'fps_analysis_tab.dart';
import 'markers_detail_tab.dart';
import 'region_tab.dart';
import 'screenshots_tab.dart';
import 'video_tab.dart';
import 'issues_tab.dart';

/// Session detail / replay screen with 7 tabs, post-hoc editing (v1.5 D-13),
/// and header info.
class SessionDetailScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  Database? _db;
  Session? _session;
  List<Collection> _collections = [];

  // Editable fields
  String? _editTags;
  String? _editCollectionId;
  String? _editProjectId;
  bool _showEditor = false;
  bool _loading = true;
  bool _saving = false;
  final _regionTabKey = GlobalKey<RegionTabState>();

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    _db = await initDatabase();
    await _loadData();
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final db = _db;
      if (db == null) return;
      final sessionDao = SessionDao(db);
      final collectionDao = CollectionDao(db);

      final session = await sessionDao.getById(widget.sessionId);
      final collections = await collectionDao.getAll();

      if (mounted) {
        setState(() {
          _session = session;
          _collections = collections;
          _editTags = session?.tags;
          _editCollectionId = session?.collectionId;
          _editProjectId = session?.projectId;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveEdits() async {
    if (_session == null) return;
    setState(() => _saving = true);

    try {
      final db = _db;
      if (db == null) return;
      final sessionDao = SessionDao(db);

      if (_editTags != null) {
        await sessionDao.setTags(widget.sessionId, _editTags!);
      }
      if (_editCollectionId != null) {
        await sessionDao.setCollection(widget.sessionId, _editCollectionId!);
      }
      if (_editProjectId != null) {
        await sessionDao.setProject(widget.sessionId, _editProjectId!);
      }

      // Reload session to get updated values
      final updated = await sessionDao.getById(widget.sessionId);
      if (mounted) {
        setState(() {
          _session = updated;
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Session metadata saved'),
            backgroundColor: AppColors.of(context).accentSuccess,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.of(context).accentDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DefaultTabController(
      length: 8,
      child: Scaffold(
        backgroundColor: colors.bgBase,
        appBar: AppBar(
          backgroundColor: colors.bgSidebar,
          title: Text(
            'Session — ${widget.sessionId}',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: TextTokens.md,
              fontFamily: monoFontFamily(),
            ),
          ),
          actions: [
            // Edit metadata toggle
            TextButton.icon(
              onPressed: () => setState(() => _showEditor = !_showEditor),
              icon: Icon(
                _showEditor ? Icons.edit_off : Icons.edit,
                size: 14,
                color: colors.textSecondary,
              ),
              label: Text(
                _showEditor ? 'Done' : 'Edit',
                style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm),
              ),
            ),
            // Export buttons
            TextButton.icon(
              onPressed: () {},
              icon: Icon(Icons.code, size: 14, color: colors.textSecondary),
              label: Text('JSON', style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm)),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: Icon(Icons.table_chart, size: 14, color: colors.textSecondary),
              label: Text('CSV', style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm)),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: colors.textPrimary,
            unselectedLabelColor: colors.textSecondary,
            indicatorColor: colors.accentBlue,
            dividerColor: colors.borderSubtle,
            tabs: const [
              Tab(text: 'Scorecard'),
              Tab(text: 'Charts'),
              Tab(text: 'FPS Analysis'),
              Tab(text: 'Markers'),
              Tab(text: 'Regions'),
              Tab(text: 'Screenshots'),
              Tab(text: 'Issues'),
              Tab(text: 'Video'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Post-hoc metadata editor (v1.5 D-13)
            if (_showEditor) _MetadataEditor(
              colors: colors,
              editTags: _editTags,
              editCollectionId: _editCollectionId,
              editProjectId: _editProjectId,
              collections: _collections,
              saving: _saving,
              onTagsChanged: (v) => _editTags = v,
              onCollectionChanged: (v) => _editCollectionId = v,
              onProjectChanged: (v) => _editProjectId = v,
              onSave: _saveEdits,
            ),
            // Tabs
            Expanded(
              child: TabBarView(
                children: [
                  ScorecardTab(sessionId: widget.sessionId),
                  ReplayChartsTab(
                    sessionId: widget.sessionId,
                    onRegionSelected: (startMs, endMs) async {
                      final db = _db;
                      if (db == null) return;
                      final metricDao = MetricDao(db);
                      final sessionStatsDao = SessionStatsDao(db);
                      final markerDao = MarkerDao(db);
                      final markerStatsDao = MarkerStatsDao(db);
                      final regionStatsDao = RegionStatsDao(db);
                      final analyticsService = AnalyticsService(
                        metricDao: metricDao,
                        sessionStatsDao: sessionStatsDao,
                        markerDao: markerDao,
                        markerStatsDao: markerStatsDao,
                        regionStatsDao: regionStatsDao,
                      );
                      await analyticsService.computeRegionStats(
                        widget.sessionId,
                        startMs,
                        endMs,
                        label: 'Region ${DateTime.now().millisecondsSinceEpoch}',
                      );
                      _regionTabKey.currentState?.refresh();
                    },
                  ),
                  FpsAnalysisTab(sessionId: widget.sessionId),
                  MarkersDetailTab(sessionId: widget.sessionId),
                  RegionTab(key: _regionTabKey, sessionId: widget.sessionId),
                  ScreenshotsTab(sessionId: widget.sessionId),
                  IssuesTab(sessionId: widget.sessionId),
                  VideoTab(sessionId: widget.sessionId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Post-hoc metadata editor panel for session detail (v1.5 D-13).
class _MetadataEditor extends StatelessWidget {
  final AppColors colors;
  final String? editTags;
  final String? editCollectionId;
  final String? editProjectId;
  final List<Collection> collections;
  final bool saving;
  final ValueChanged<String> onTagsChanged;
  final ValueChanged<String?> onCollectionChanged;
  final ValueChanged<String> onProjectChanged;
  final VoidCallback onSave;

  const _MetadataEditor({
    required this.colors,
    required this.editTags,
    required this.editCollectionId,
    required this.editProjectId,
    required this.collections,
    required this.saving,
    required this.onTagsChanged,
    required this.onCollectionChanged,
    required this.onProjectChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.bgElevated,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Tags field
          Expanded(
            flex: 2,
            child: _InlineField(
              label: 'Tags',
              value: editTags ?? '',
              hint: 'comma-separated',
              colors: colors,
              onChanged: onTagsChanged,
            ),
          ),
          const SizedBox(width: 8),
          // Collection dropdown
          Expanded(
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: colors.bgInput,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: editCollectionId,
                  hint: Text('Collection',
                      style: TextStyle(fontSize: TextTokens.xs, color: colors.textDisabled)),
                  isExpanded: true,
                  isDense: true,
                  style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.xs),
                  dropdownColor: colors.bgElevated,
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None',
                          style: TextStyle(fontSize: TextTokens.xs, color: colors.textSecondary)),
                    ),
                    ...collections.map((c) => DropdownMenuItem<String?>(
                          value: c.id,
                          child: Text(c.name, style: TextStyle(fontSize: TextTokens.xs)),
                        )),
                  ],
                  onChanged: onCollectionChanged,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Project field
          Expanded(
            child: _InlineField(
              label: 'Project',
              value: editProjectId ?? '',
              hint: 'e.g., v1.4.2',
              colors: colors,
              onChanged: onProjectChanged,
            ),
          ),
          const SizedBox(width: 8),
          // Save button
          SizedBox(
            height: 28,
            child: ElevatedButton(
              onPressed: saving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: colors.bgInput,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
              ),
              child: saving
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.textPrimary,
                      ),
                    )
                  : Text('Save', style: TextStyle(fontSize: TextTokens.xs)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline text field with label for metadata editing.
class _InlineField extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final AppColors colors;
  final ValueChanged<String> onChanged;

  const _InlineField({
    required this.label,
    required this.value,
    required this.hint,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: TextField(
        controller: TextEditingController(text: value),
        style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.xs),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: TextTokens.xs, color: colors.textDisabled),
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
