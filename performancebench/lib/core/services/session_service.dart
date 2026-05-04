// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';

import '../database/session_dao.dart';
import '../models/session.dart';
import 'error_handler.dart';
import 'metric_collector.dart';
import '../../core/analytics/analytics_service.dart';

/// Manages session lifecycle: start, stop, edge case recovery.
class SessionService {
  final SessionDao _sessionDao;
  final AnalyticsService _analyticsService;
  MetricCollector? _activeCollector;

  SessionService({
    required SessionDao sessionDao,
    required AnalyticsService analyticsService,
  })  : _sessionDao = sessionDao,
        _analyticsService = analyticsService;

  MetricCollector? get activeCollector => _activeCollector;

  /// Stop an active session: flush batch, compute stats, update DB.
  Future<void> stopSession(Session session) async {
    try {
      // Stop the collector and get remaining samples
      List<dynamic>? remainingSamples;
      if (_activeCollector != null) {
        remainingSamples = await _activeCollector!.stop();
        _activeCollector = null;
      }

      // Compute session-level stats
      await _analyticsService.computeSessionStats(session.id);

      // Compute per-marker stats
      await _analyticsService.computeMarkerStats(session.id);

      // Update session end time and duration
      final endedAt = DateTime.now().millisecondsSinceEpoch;
      final durationMs = endedAt - session.startedAt;

      // Minimum duration warning (10s)
      if (durationMs < 10000) {
        ErrorHandler().logError(
          'SessionService',
          'Session too short (${(durationMs / 1000).toStringAsFixed(1)}s). Minimum 10 seconds recommended.',
        );
      }

      // Update session record
      await _sessionDao.updateEndedAt(session.id, endedAt, durationMs);
    } catch (e, stack) {
      ErrorHandler().logError('SessionService', e, stack);
    }
  }

  /// Set the active collector so session service can stop it.
  void setActiveCollector(MetricCollector collector) {
    _activeCollector = collector;
  }
}
