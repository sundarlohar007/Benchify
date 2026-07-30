// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/detected_issues_service.dart';
import '../../core/database/database.dart';
import '../../core/database/detected_issue_dao.dart';
import '../../core/database/marker_dao.dart';
import '../../core/database/marker_stats_dao.dart';
import '../../core/database/metric_dao.dart';
import '../../core/database/region_stats_dao.dart';
import '../../core/database/screenshot_dao.dart';
import '../../core/database/session_dao.dart';
import '../../core/database/session_stats_dao.dart';
import '../../core/models/metric_sample.dart';
import '../../core/models/session.dart';
import '../../core/services/adb_service.dart';
import '../../core/services/error_handler.dart';
import '../../core/services/metric_collector.dart';
import '../../core/services/screenshot_service.dart';
import '../../core/services/session_service.dart';
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

  final GlobalKey<ScreenshotsTabState> _screenshotsKey =
      GlobalKey<ScreenshotsTabState>();

  Session? _session;
  SessionService? _sessionService;
  MetricCollector? _collector;
  ScreenshotService? _screenshotService;
  Stream<MetricSample> _metricStream = const Stream.empty();
  bool _stopping = false;
  bool _started = false;
  bool _finalized = false;
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

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final db = await initDatabase();
      final sessionDao = SessionDao(db);
      final session = await sessionDao.getById(widget.sessionId);
      if (session == null || !mounted) return;

      final metricDao = MetricDao(db);
      final analytics = AnalyticsService(
        metricDao: metricDao,
        sessionStatsDao: SessionStatsDao(db),
        markerDao: MarkerDao(db),
        markerStatsDao: MarkerStatsDao(db),
        regionStatsDao: RegionStatsDao(db),
      );
      final sessionService = SessionService(
        sessionDao: sessionDao,
        analyticsService: analytics,
        detectedIssuesService: DetectedIssuesService(
          sessionStatsDao: SessionStatsDao(db),
          sessionDao: sessionDao,
          detectedIssueDao: DetectedIssueDao(db),
        ),
      );

      AdbService? adb;
      MetricCollector? collector;
      Stream<MetricSample> stream = const Stream.empty();
      ScreenshotService? screenshots;

      if (session.platform == 'android') {
        try {
          adb = await AdbService.create();
          collector = MetricCollector(
            adbService: adb,
            deviceSerial: session.deviceId,
            packageName: session.appPackage,
            sessionId: session.id,
            metricDao: metricDao,
          );
          stream = collector.start();
          sessionService.setActiveCollector(collector);

          screenshots = ScreenshotService(
            adbService: adb,
            deviceSerial: session.deviceId,
            sessionId: session.id,
            screenshotDao: ScreenshotDao(db),
            onCaptured: (result) {
              _screenshotsKey.currentState?.addScreenshots(
                result.filepaths,
                result.timestamp,
              );
            },
          );
          await screenshots.init();
          if (!screenshots.isWireless) {
            screenshots.startAutoCapture();
          }
        } catch (e, stack) {
          ErrorHandler().logError('ActiveSessionScreen.adb', e, stack);
          unawaited(collector?.stop() ?? Future.value());
          screenshots?.stop();
          collector = null;
          screenshots = null;
          stream = const Stream.empty();
        }
      }

      if (!mounted) {
        collector?.stop();
        screenshots?.stop();
        return;
      }

      // Don't pretend recording works if Android ADB bootstrap failed.
      final adbOk = session.platform != 'android' || collector != null;

      setState(() {
        _session = session;
        _sessionService = sessionService;
        _collector = collector;
        _screenshotService = screenshots;
        _metricStream = stream;
        _started = adbOk;
      });

      if (!adbOk && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to device via ADB — recording not started'),
          ),
        );
      }

      // Forward status stream for SQLite indicator
      collector?.statusStream.listen((status) {
        if (mounted) _sqliteStatus.value = status;
      });
    } catch (e, stack) {
      ErrorHandler().logError('ActiveSessionScreen.bootstrap', e, stack);
    }
  }

  /// Shared finalize path for Stop button and dispose (prevents double stopSession).
  Future<void> _finalizeSession() async {
    if (_finalized) return;
    _finalized = true;

    _stopwatch.stop();
    _elapsedTimer?.cancel();
    _screenshotService?.stop();

    try {
      final session = _session;
      final service = _sessionService;
      if (session != null && service != null) {
        // B-047: flush collector, compute stats, set endedAt/durationMs
        await service.stopSession(session);
      } else {
        await _collector?.stop();
      }
      _collector = null;
      _screenshotService = null;
    } catch (e, stack) {
      ErrorHandler().logError('ActiveSessionScreen.finalize', e, stack);
    }
  }

  @override
  void dispose() {
    _recController.dispose();
    _elapsedTimer?.cancel();
    _elapsedNotifier.dispose();
    _sqliteStatus.dispose();
    // Emergency finalize if user closes window without pressing Stop
    if (!_finalized) {
      _screenshotService?.stop();
      unawaited(_finalizeSession());
    }
    super.dispose();
  }

  Future<void> _handleStop() async {
    if (_stopping) return;
    setState(() => _stopping = true);

    await _finalizeSession();

    if (!mounted) return;
    context.go('/session/${widget.sessionId}');
  }

  Future<void> _handleScreenshot() async {
    final svc = _screenshotService;
    if (svc == null || svc.isWireless) return;
    final result = await svc.capture();
    if (result != null && mounted) {
      _screenshotsKey.currentState?.addScreenshots(
        result.filepaths,
        result.timestamp,
      );
    }
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
              onPressed: _started && !_stopping ? _handleScreenshot : null,
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
              onPressed: _stopping ? null : _handleStop,
              icon: _stopping
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.stop, size: 16),
              label: Text(_stopping ? 'Stopping…' : 'Stop Recording'),
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
            ActiveSessionChartsTab(stream: _metricStream),
            ScreenshotsTab(
              key: _screenshotsKey,
              sessionId: widget.sessionId,
              wirelessDisabled: _screenshotService?.isWireless ?? false,
            ),
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
              const SizedBox(width: 6),
              Text(
                'Recording',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: TextTokens.xs,
                ),
              ),
            ],
          ),
          const Spacer(),
          ValueListenableBuilder(
            valueListenable: _sqliteStatus,
            builder: (_, status, __) => Text(
              status,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: TextTokens.xs,
                fontFamily: monoFontFamily(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
