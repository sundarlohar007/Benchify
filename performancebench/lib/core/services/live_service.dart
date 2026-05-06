// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/metric_sample.dart';
import 'api_service.dart';

/// Live streaming service — sends metric samples from desktop to server
/// during active profiling for WebSocket broadcast (V20-17).
///
/// Buffers samples locally and flushes in 5-second batches
/// via POST /api/v1/sessions/:id/live/batch.
/// Best-effort: failures are logged, not surfaced to the user.
class LiveService {
  final ApiService _api;
  Timer? _timer;
  final List<MetricSample> _buffer = [];
  bool _isStreaming = false;

  LiveService(this._api);

  /// Start streaming metric samples to server.
  /// Flushes every 5 seconds.
  void startStreaming(String sessionId) {
    if (_isStreaming) return;
    _isStreaming = true;
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _flush(sessionId),
    );
  }

  /// Buffer a sample. Called by MetricCollector.onSample callback.
  void pushSample(MetricSample sample) {
    if (!_isStreaming) return;
    _buffer.add(sample);
  }

  /// Flush buffered samples to the server.
  Future<void> _flush(String sessionId) async {
    if (_buffer.isEmpty) return;

    final batch = List<MetricSample>.from(_buffer);
    _buffer.clear();

    try {
      final body = jsonEncode({
        'samples': batch.map((s) => s.toMap()).toList(),
      });
      await _api.post(
        '/api/v1/sessions/$sessionId/live/batch',
        jsonDecode(body) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('LiveService: failed to flush batch: $e');
    }
  }

  /// Stop streaming and clear buffered samples.
  void stopStreaming() {
    _timer?.cancel();
    _timer = null;
    _isStreaming = false;
    _buffer.clear();
  }

  bool get isStreaming => _isStreaming;
}
