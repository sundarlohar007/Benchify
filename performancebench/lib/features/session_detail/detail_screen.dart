// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';
import 'scorecard_tab.dart';
import 'replay_charts_tab.dart';
import 'fps_analysis_tab.dart';
import 'markers_detail_tab.dart';
import 'region_tab.dart';
import 'screenshots_tab.dart';

/// Session detail / replay screen with 5 tabs and header info.
class SessionDetailScreen extends ConsumerWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: colors.bgBase,
        appBar: AppBar(
          backgroundColor: colors.bgSidebar,
          title: Text(
            'Session — $sessionId',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: TextTokens.md,
              fontFamily: monoFontFamily(),
            ),
          ),
          actions: [
            // Export buttons
            TextButton.icon(
              onPressed: () {
                // Export JSON — wired via ExportService
              },
              icon: Icon(Icons.code, size: 14, color: colors.textSecondary),
              label: Text('JSON', style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm)),
            ),
            TextButton.icon(
              onPressed: () {
                // Export CSV — wired via ExportService
              },
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
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ScorecardTab(sessionId: sessionId),
            ReplayChartsTab(sessionId: sessionId),
            FpsAnalysisTab(sessionId: sessionId),
            MarkersDetailTab(sessionId: sessionId),
            RegionTab(sessionId: sessionId),
            ScreenshotsTab(sessionId: sessionId),
          ],
        ),
      ),
    );
  }
}
