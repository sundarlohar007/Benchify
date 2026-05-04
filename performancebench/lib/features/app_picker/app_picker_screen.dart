// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';
import '../../core/services/adb_service.dart';
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
class AppPickerScreen extends ConsumerWidget {
  final String deviceId;

  const AppPickerScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final appsAsync = ref.watch(appListProvider(deviceId));

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
      // Bottom bar with Start Profiling button
      bottomNavigationBar: Container(
        color: colors.bgSidebar,
        padding: const EdgeInsets.all(12),
        child: Row(
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
      ),
    );
  }
}
