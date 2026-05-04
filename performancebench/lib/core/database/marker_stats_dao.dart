// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/marker_stats.dart';

/// Data access object for the `marker_stats` table.
/// All queries are parameterized.
class MarkerStatsDao {
  final Database _db;

  MarkerStatsDao(this._db);

  /// Insert a marker_stats row. Returns the auto-generated id.
  Future<int> insert(MarkerStats stats) async {
    return _db.insert('marker_stats', stats.toMap());
  }

  /// Query marker_stats by marker_id.
  Future<List<MarkerStats>> getByMarkerId(int markerId) async {
    final rows = await _db.query(
      'marker_stats',
      where: 'marker_id = ?',
      whereArgs: [markerId],
    );
    return rows.map(MarkerStats.fromMap).toList();
  }

  /// Query all marker_stats for a session.
  Future<List<MarkerStats>> getBySessionId(String sessionId) async {
    final rows = await _db.query(
      'marker_stats',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return rows.map(MarkerStats.fromMap).toList();
  }

  /// Query marker_stats for a session joined with markers for labels.
  Future<List<Map<String, dynamic>>> getBySessionIdWithMarkerLabel(
    String sessionId,
  ) async {
    return _db.rawQuery(
      '''SELECT ms.*, m.label as marker_label
         FROM marker_stats ms
         JOIN markers m ON ms.marker_id = m.id
         WHERE ms.session_id = ?
         ORDER BY m.started_at ASC''',
      [sessionId],
    );
  }

  /// Delete all marker_stats for a session.
  Future<int> deleteBySessionId(String sessionId) async {
    return _db.delete(
      'marker_stats',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }
}
