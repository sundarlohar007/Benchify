// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/session_stats.dart';

/// Data access object for the `session_stats` table.
/// All queries are parameterized.
class SessionStatsDao {
  final Database _db;

  SessionStatsDao(this._db);

  /// Upsert (INSERT OR REPLACE) a session_stats row.
  /// session_id is the PRIMARY KEY, so this replaces on conflict.
  Future<void> upsert(SessionStats stats) async {
    await _db.insert(
      'session_stats',
      stats.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Query session_stats by session_id.
  Future<SessionStats?> getBySessionId(String sessionId) async {
    final rows = await _db.query(
      'session_stats',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SessionStats.fromMap(rows.first);
  }

  /// Query all session_stats rows (for comparison, lenses).
  Future<List<SessionStats>> getAll() async {
    final rows = await _db.query('session_stats');
    return rows.map(SessionStats.fromMap).toList();
  }

  /// Query session_stats for a specific set of session ids.
  Future<List<SessionStats>> getBySessionIds(List<String> sessionIds) async {
    if (sessionIds.isEmpty) return [];
    final placeholders = sessionIds.map((_) => '?').join(',');
    final rows = await _db.rawQuery(
      'SELECT * FROM session_stats WHERE session_id IN ($placeholders)',
      sessionIds,
    );
    return rows.map(SessionStats.fromMap).toList();
  }

  /// Delete session_stats for a given session.
  Future<int> delete(String sessionId) async {
    return _db.delete(
      'session_stats',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Check if stats exist for a session.
  Future<bool> exists(String sessionId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM session_stats WHERE session_id = ?',
      [sessionId],
    );
    final cnt = (result.first['cnt'] as int?) ?? 0;
    return cnt > 0;
  }
}
