// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/metric_sample.dart';

/// Data access object for the `metric_samples` table.
/// All queries are parameterized.
class MetricDao {
  final Database _db;

  MetricDao(this._db);

  /// Batch insert a list of MetricSamples in a single transaction.
  /// Uses INSERT OR IGNORE — first write wins on session_id+timestamp collision.
  Future<void> batchInsert(List<MetricSample> samples) async {
    if (samples.isEmpty) return;
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final sample in samples) {
        batch.insert(
          'metric_samples',
          sample.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Query all samples for a session, ordered by timestamp ASC.
  Future<List<MetricSample>> getBySessionId(String sessionId) async {
    final rows = await _db.query(
      'metric_samples',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(MetricSample.fromMap).toList();
  }

  /// Query samples for a session within a timestamp range (for marker stats).
  Future<List<MetricSample>> getBySessionIdAndTimestampRange(
    String sessionId, {
    required int startMs,
    required int endMs,
  }) async {
    final rows = await _db.query(
      'metric_samples',
      where: 'session_id = ? AND timestamp >= ? AND timestamp <= ?',
      whereArgs: [sessionId, startMs, endMs],
      orderBy: 'timestamp ASC',
    );
    return rows.map(MetricSample.fromMap).toList();
  }

  /// Delete all samples for a session (cascade from session deletion).
  Future<int> deleteBySessionId(String sessionId) async {
    return _db.delete(
      'metric_samples',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Count samples for a session.
  Future<int> countBySessionId(String sessionId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM metric_samples WHERE session_id = ?',
      [sessionId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Get the latest sample for a session (by timestamp).
  Future<MetricSample?> getLatest(String sessionId) async {
    final rows = await _db.query(
      'metric_samples',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MetricSample.fromMap(rows.first);
  }
}
