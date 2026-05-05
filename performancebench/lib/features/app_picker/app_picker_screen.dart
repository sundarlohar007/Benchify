// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';
import '../../core/services/adb_service.dart';
import '../../core/database/database.dart';
import '../../core/database/collection_dao.dart';
import '../../core/models/collection.dart';
import 'app_list_item.dart';

/// Provider for app list on selected device.
final appListProvider = FutureProvider.family<List<AppInfo>, String>(
  (ref, deviceId) async {
    final adb = await AdbService.create();
    return adb.listApps(deviceId);
  },
);

/// App picker screen — shows list of installed apps on the selected device.
/// Each row: app icon (placeholder), app label, package name, version.
/// "Start Profiling" button at the bottom (UNIFIED-SPEC §9.2 flow).
/// v1.5: Collection/project/tag assignment during session start per D-13.
class AppPickerScreen extends ConsumerStatefulWidget {
  final String deviceId;

  const AppPickerScreen({super.key, required this.deviceId});

  @override
  ConsumerState<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends ConsumerState<AppPickerScreen> {
  String? _selectedCollectionId;
  String _projectId = '';
  String _tags = '';
  List<Collection> _collections = [];
  bool _collectionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    try {
      final db = await initDatabase();
      final dao = CollectionDao(db);
      final list = await dao.getAll();
      if (mounted) {
        setState(() {
          _collections = list;
          _collectionsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _collectionsLoaded = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final appsAsync = ref.watch(appListProvider(widget.deviceId));

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        backgroundColor: colors.bgSidebar,
        title: Text(
          'Select App',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: TextTokens.md,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textSecondary),
          onPressed: () {
            // GoRouter back navigation
          },
        ),
      ),
      body: appsAsync.when(
        data: (apps) {
          if (apps.isEmpty) {
            return Center(
              child: Text(
                'No apps found on device',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: TextTokens.base,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              return AppListItem(
                app: app,
                colors: colors,
                onTap: () {
                  // Navigate to active session — will be wired in Wave 2
                },
              );
            },
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: colors.accentBlue),
        ),
        error: (err, _) => Center(
          child: Text(
            'Failed to load apps: $err',
            style: TextStyle(color: colors.accentDanger),
          ),
        ),
      ),
      // Bottom bar with collection/project/tag assignment + Start Profiling button
      bottomNavigationBar: Container(
        color: colors.bgSidebar,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Collection / Project / Tags row (v1.5 D-13)
            Row(
              children: [
                // Collection dropdown
                Expanded(
                  child: _buildCollectionDropdown(colors),
                ),
                const SizedBox(width: 8),
                // Project tag input
                Expanded(
                  child: _buildTextField(
                    colors,
                    hint: 'Project tag (optional)',
                    value: _projectId,
                    onChanged: (v) => _projectId = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Tags input
            _buildTextField(
              colors,
              hint: 'Tags (comma-separated, e.g., release, boss-fight)',
              value: _tags,
              onChanged: (v) => _tags = v,
            ),
            const SizedBox(height: 10),
            // Start Profiling button
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Select an app to begin profiling',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: TextTokens.sm,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: null, // Wired in Wave 2 with actual selection
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Start Profiling'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accentBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: colors.bgInput,
                    disabledForegroundColor: colors.textDisabled,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionDropdown(AppColors colors) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.bgInput,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _selectedCollectionId,
          hint: Text(
            'Collection (optional)',
            style: TextStyle(fontSize: TextTokens.xs, color: colors.textDisabled),
          ),
          isExpanded: true,
          isDense: true,
          style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.xs),
          dropdownColor: colors.bgElevated,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text('None', style: TextStyle(fontSize: TextTokens.xs, color: colors.textSecondary)),
            ),
            ..._collections.map((c) {
              return DropdownMenuItem<String?>(
                value: c.id,
                child: Text(c.name, style: TextStyle(fontSize: TextTokens.xs)),
              );
            }),
          ],
          onChanged: (v) => setState(() => _selectedCollectionId = v),
        ),
      ),
    );
  }

  Widget _buildTextField(
    AppColors colors, {
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: TextEditingController(text: value),
        style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.xs),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: TextTokens.xs, color: colors.textDisabled),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
