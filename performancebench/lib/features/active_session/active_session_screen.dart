import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';
import 'charts_tab.dart';
import 'screenshots_tab.dart';
import 'markers_tab.dart';

/// Live profiling session screen with REC indicator, stop button,
/// and 3-tab layout: Charts, Screenshots, Markers.
class ActiveSessionScreen extends ConsumerWidget {
  final String sessionId;

  const ActiveSessionScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: colors.bgBase,
        appBar: AppBar(
          backgroundColor: colors.bgSidebar,
          title: Row(
            children: [
              // REC indicator
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFF44747),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'RECORDING — $sessionId',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: TextTokens.sm,
                  fontFamily: monoFontFamily(),
                ),
              ),
            ],
          ),
          actions: [
            // Stop button
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton.icon(
                onPressed: () {
                  // Stop recording — wired in Wave 2
                },
                icon: const Icon(Icons.stop, size: 16),
                label: const Text('Stop'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.accentRecording,
                  side: BorderSide(color: colors.accentRecording),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Charts'),
              Tab(text: 'Screenshots'),
              Tab(text: 'Markers'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ChartsTab(sessionId: sessionId),
            ScreenshotsTab(sessionId: sessionId),
            MarkersTab(sessionId: sessionId),
          ],
        ),
      ),
    );
  }
}
