import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';
import 'scorecard_tab.dart';
import 'replay_charts_tab.dart';
import 'fps_analysis_tab.dart';
import 'markers_detail_tab.dart';
import 'screenshots_tab.dart';

/// Session detail / replay screen with 5 tabs:
/// Scorecard, Charts, FPS Analysis, Markers, Screenshots.
class SessionDetailScreen extends ConsumerWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);

    return DefaultTabController(
      length: 5,
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
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Scorecard'),
              Tab(text: 'Charts'),
              Tab(text: 'FPS Analysis'),
              Tab(text: 'Markers'),
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
            ScreenshotsTab(sessionId: sessionId),
          ],
        ),
      ),
    );
  }
}
