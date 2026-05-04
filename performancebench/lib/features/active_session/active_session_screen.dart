// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme.dart';
import 'charts_tab.dart';
import 'screenshots_tab.dart';
import 'markers_tab.dart';

/// Live profiling session screen with REC indicator, stop button,
/// and 3-tab layout: Charts, Screenshots, Markers.
class ActiveSessionScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const ActiveSessionScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _recController;
  late final Animation<double> _recScale;
  late final Stopwatch _stopwatch;
  Timer? _elapsedTimer;
  final ValueNotifier<String> _elapsedNotifier = ValueNotifier('00:00:00');
  final ValueNotifier<String> _sqliteStatus = ValueNotifier('SQLite ✓');

  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _recController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _recScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _recController, curve: Curves.easeInOut),
    );

    _stopwatch = Stopwatch()..start();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds = _stopwatch.elapsed.inSeconds;
      final h = (_elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
      final m = ((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
      _elapsedNotifier.value = '$h:$m:$s';
    });
  }

  @override
  void dispose() {
    _recController.dispose();
    _elapsedTimer?.cancel();
    _elapsedNotifier.dispose();
    _sqliteStatus.dispose();
    super.dispose();
  }

  void _handleStop() {
    _stopwatch.stop();
    _elapsedTimer?.cancel();
    context.go('/');
  }

  void _handleScreenshot() {
    // Wired in Task 3
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: colors.bgBase,
        appBar: AppBar(
          backgroundColor: colors.bgSidebar,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _recScale,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF44747),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder(
                valueListenable: _elapsedNotifier,
                builder: (_, elapsed, __) => Text(
                  'REC $elapsed',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: TextTokens.sm,
                    fontFamily: monoFontFamily(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: _handleScreenshot,
              icon: Icon(Icons.camera_alt, size: 16, color: colors.textSecondary),
              label: Text(
                'Screenshot',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: TextTokens.sm,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                // Add marker — wired in Wave 4
              },
              icon: Icon(Icons.flag, size: 16, color: colors.textSecondary),
              label: Text(
                'Marker',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: TextTokens.sm,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _handleStop,
              icon: const Icon(Icons.stop, size: 16),
              label: const Text('Stop Recording'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.accentRecording,
                side: BorderSide(color: colors.accentRecording),
              ),
            ),
            const SizedBox(width: 12),
          ],
          bottom: TabBar(
            labelColor: colors.textPrimary,
            unselectedLabelColor: colors.textSecondary,
            indicatorColor: colors.accentBlue,
            dividerColor: colors.borderSubtle,
            tabs: const [
              Tab(text: 'Charts'),
              Tab(text: 'Screenshots'),
              Tab(text: 'Markers'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const ActiveSessionChartsTab(stream: Stream.empty()),
            ScreenshotsTab(sessionId: widget.sessionId),
            MarkersTab(sessionId: widget.sessionId),
          ],
        ),
        bottomNavigationBar: _buildStatusBar(colors),
      ),
    );
  }

  Widget _buildStatusBar(AppColors colors) {
    return Container(
      height: 22,
      color: colors.bgSidebar,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _recScale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF44747),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder(
                valueListenable: _elapsedNotifier,
                builder: (_, elapsed, __) => Text(
                  elapsed,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 10,
                    fontFamily: monoFontFamily(),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '1 Hz',
            style: TextStyle(
              color: colors.textDisabled,
              fontSize: 10,
              fontFamily: monoFontFamily(),
            ),
          ),
          const Spacer(),
          ValueListenableBuilder(
            valueListenable: _sqliteStatus,
            builder: (_, status, __) => Text(
              status,
              style: TextStyle(
                color: status.contains('✓')
                    ? colors.accentSuccess
                    : colors.accentWarning,
                fontSize: 10,
                fontFamily: monoFontFamily(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
