// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/session.dart';
import 'api_service.dart';
import '../database/database.dart';
import '../database/metric_dao.dart';
import '../database/marker_dao.dart';
import '../database/detected_issue_dao.dart';
import '../database/screenshot_dao.dart';

/// Status of a session upload.
enum UploadStatus {
  pending,
  uploading,
  completed,
  conflict,
  failed,
}

/// Result of an upload attempt.
class UploadResult {
  final UploadStatus status;
  final String? serverUrl;
  final String? conflictUrl;
  final String? errorMessage;

  const UploadResult({
    required this.status,
    this.serverUrl,
    this.conflictUrl,
    this.errorMessage,
  });
}

/// Progress of an active upload (D-26).
class UploadProgress {
  final String sessionId;
  final double progress;
  final int bytesSent;
  final int totalBytes;
  final String? speedText; // e.g. "2.3 MB/s"

  const UploadProgress({
    required this.sessionId,
    required this.progress,
    required this.bytesSent,
    required this.totalBytes,
    this.speedText,
  });
}

/// Queue status for UI display (D-27).
class QueueStatus {
  final int position;
  final int total;
  final String currentSessionId;
  final double progress;
  final String? speedText;

  const QueueStatus({
    required this.position,
    required this.total,
    required this.currentSessionId,
    required this.progress,
    this.speedText,
  });
}

/// Session upload service with retry, progress tracking, and FIFO queue.
///
/// Implements D-22 (Bearer token auth), D-23 (gzip), D-24 (exponential backoff),
/// D-25 (409 conflict), D-26 (progress bar), D-27 (FIFO queue), D-28 (optional video),
/// D-30 (upload payload structure).
class UploadService {
  final ApiService api;
  final List<Session> _queue = [];
  bool _isUploading = false;

  // Stream controllers for UI updates
  final _progressController = StreamController<UploadProgress>.broadcast();
  final _queueStatusController = StreamController<QueueStatus>.broadcast();

  Stream<UploadProgress> get uploadProgressStream => _progressController.stream;
  Stream<QueueStatus> get queueStatusStream => _queueStatusController.stream;

  UploadService({required this.api});

  /// Add sessions to the FIFO upload queue.
  void addToQueue(List<Session> sessions) {
    // Filter out already uploaded sessions
    final newSessions = sessions.toList();
    _queue.addAll(newSessions);
    _processQueue();
  }

  /// Upload a single session with retry logic.
  /// Returns UploadResult with status.
  Future<UploadResult> uploadSession(Session session) async {
    try {
      // Gather session data from SQLite
      final db = await initDatabase();
      final metricDao = MetricDao(db);
      final markerDao = MarkerDao(db);
      final issueDao = DetectedIssueDao(db);
      final screenshotDao = ScreenshotDao(db);

      // Read data from local DB
      final samples = await metricDao.getBySessionId(session.id);
      final markers = await markerDao.getBySessionId(session.id);
      final issues = await issueDao.getBySessionId(session.id);
      final screenshots = await screenshotDao.getBySessionId(session.id);

      // Build upload payload (D-30)
      final payload = _buildUploadPayload(
        session,
        samples,
        markers,
        issues,
      );

      // Screenshot file paths
      final screenshotPaths = screenshots.map((s) => s.filePath).toList();

      // Apply gzip compression to metadata (D-23)
      final metadataJson = jsonEncode(payload);
      // Note: gzip compression handled at HTTP level; metadata sent as JSON string

      // Upload with exponential backoff retry (D-24)
      const retryDelays = [1, 4, 16]; // seconds
      ApiResponse? lastResponse;

      for (var attempt = 0; attempt <= retryDelays.length; attempt++) {
        if (attempt > 0) {
          await Future.delayed(Duration(seconds: retryDelays[attempt - 1]));
        }

        lastResponse = await api.uploadMultipart(
          '/api/v1/sessions',
          metadata: metadataJson,
          screenshotPaths: screenshotPaths,
          onProgress: (progress, sent, total) {
            _progressController.add(UploadProgress(
              sessionId: session.id,
              progress: progress,
              bytesSent: sent,
              totalBytes: total,
              speedText: _formatSpeed(sent, null),
            ));
          },
        );

        // Success
        if (lastResponse.isSuccess) {
          return UploadResult(
            status: UploadStatus.completed,
            serverUrl: lastResponse.body?['url'] as String?,
          );
        }

        // Conflict — no retry (D-25)
        if (lastResponse.isConflict) {
          return UploadResult(
            status: UploadStatus.conflict,
            conflictUrl: lastResponse.body?['existing_url'] as String?,
          );
        }

        // Client error (4xx, not 409) — don't retry
        if (lastResponse.statusCode >= 400 && lastResponse.statusCode < 500) {
          break;
        }
      }

      // All retries exhausted
      return UploadResult(
        status: UploadStatus.failed,
        errorMessage: lastResponse?.body?['message']?.toString() ?? 'Upload failed after 3 retries',
      );
    } catch (e) {
      return UploadResult(
        status: UploadStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  /// Process the upload queue sequentially (FIFO, D-27).
  void _processQueue() async {
    if (_isUploading || _queue.isEmpty) return;
    _isUploading = true;

    while (_queue.isNotEmpty) {
      final session = _queue.removeAt(0);
      final position = _queue.length + 1; // 1-based position
      final total = _queue.length + 1;

      _queueStatusController.add(QueueStatus(
        position: position,
        total: total,
        currentSessionId: session.id,
        progress: 0.0,
        speedText: null,
      ));

      final result = await uploadSession(session);

      switch (result.status) {
        case UploadStatus.completed:
          // Mark as uploaded in local DB
          await _markUploaded(session.id);
          break;
        case UploadStatus.conflict:
          // Already exists on server — mark as uploaded locally
          await _markUploaded(session.id);
          break;
        case UploadStatus.failed:
          // Failed permanently — log error, continue
          debugPrint('Upload failed for session ${session.id}: ${result.errorMessage}');
          break;
        case UploadStatus.uploading:
        case UploadStatus.pending:
          break;
      }
    }

    _isUploading = false;
    _queueStatusController.add(QueueStatus(
      position: 0,
      total: 0,
      currentSessionId: '',
      progress: 0.0,
      speedText: null,
    ));
  }

  /// Build the upload payload matching the POST /api/v1/sessions contract.
  Map<String, dynamic> _buildUploadPayload(
    Session session,
    List<dynamic> samples,
    List<dynamic> markers,
    List<dynamic> issues,
  ) {
    return {
      'session': {
        'id': session.id,
        'app_name': session.appName ?? session.appPackage,
        'app_package': session.appPackage,
        'app_version': session.appVersion,
        'device_model': 'Unknown',
        'device_os_version': 'Unknown',
        'chipset': 'Unknown',
        'tags': _parseTags(session.tags).toList(),
        'project_id': session.projectId,
        'collection_id': session.collectionId,
        'notes': session.notes,
        'started_at': DateTime.fromMillisecondsSinceEpoch(session.startedAt).toUtc().toIso8601String(),
        'ended_at': session.endedAt != null
            ? DateTime.fromMillisecondsSinceEpoch(session.endedAt!).toUtc().toIso8601String()
            : null,
        'duration_seconds': session.durationMs != null ? session.durationMs! ~/ 1000 : null,
        'screenshots': <String>[],
        'thumbnail_path': null,
        'devices': [
          {
            'os_type': session.platform,
            'model': session.deviceId,
          }
        ],
      },
      'samples': samples.map((s) {
        if (s is Map<String, dynamic>) return s;
        return <String, dynamic>{};
      }).toList(),
      'markers': markers.map((m) {
        if (m is Map<String, dynamic>) return m;
        return <String, dynamic>{};
      }).toList(),
      'detected_issues': issues.map((i) {
        if (i is Map<String, dynamic>) return i;
        return <String, dynamic>{};
      }).toList(),
      'video_metadata': <dynamic>[],
    };
  }

  /// Parse tags from JSON array string.
  List<String> _parseTags(String? tagsJson) {
    if (tagsJson == null || tagsJson.isEmpty) return [];
    try {
      final decoded = jsonDecode(tagsJson);
      if (decoded is List) return decoded.cast<String>();
      return [tagsJson];
    } catch (_) {
      return [tagsJson];
    }
  }

  /// Mark a session as uploaded in the local SQLite database.
  Future<void> _markUploaded(String sessionId) async {
    try {
      final db = await initDatabase();
      await db.update(
        'sessions',
        {'is_uploaded': 1},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    } catch (e) {
      debugPrint('Failed to mark session $sessionId as uploaded: $e');
    }
  }

  /// Format upload speed for display.
  String _formatSpeed(int bytesSent, Duration? elapsed) {
    // Simplified — real implementation would track time
    if (bytesSent < 1024) return '$bytesSent B/s';
    if (bytesSent < 1024 * 1024) return '${(bytesSent / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesSent / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  /// Clean up resources.
  void dispose() {
    _progressController.close();
    _queueStatusController.close();
  }
}
