// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/session.dart';

/// Data access object for the `sessions` table.
/// All queries are parameterized — no string concatenation for SQL values.
class SessionDao {
  final Database _db;

  SessionDao(this._db);

  /// Insert a new session. Returns the row id.
  Future<void> insert(Session session) async {
    await _db.insert('sessions', session.toMap());
  }

  /// Update an existing session by id.
  Future<int> update(Session session) async {
    return _db.update(
      'sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  /// Update ended_at and duration_ms for a completed session.
  Future<int> updateEndedAt(String id, int endedAt, int durationMs) async {
    return _db.update(
      'sessions',
      {'ended_at': endedAt, 'duration_ms': durationMs},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Query a session by its UUID id.
  Future<Session?> getById(String id) async {
    final rows = await _db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Session.fromMap(rows.first);
  }

  /// Query all sessions, ordered by started_at descending.
  Future<List<Session>> getAll() async {
    final rows = await _db.query(
      'sessions',
      orderBy: 'started_at DESC',
    );
    return rows.map(Session.fromMap).toList();
  }

  /// Query sessions for a specific device, ordered by started_at descending.
  Future<List<Session>> getByDeviceId(String deviceId) async {
    final rows = await _db.query(
      'sessions',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'started_at DESC',
    );
    return rows.map(Session.fromMap).toList();
  }

  /// Delete a session by id with confirmation return value.
  Future<int> delete(String id) async {
    return _db.delete(
      'sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Count sessions for a device.
  Future<int> countByDeviceId(String deviceId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM sessions WHERE device_id = ?',
      [deviceId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Query sessions with optional limit and offset (for pagination).
  Future<List<Session>> getPage({int limit = 50, int offset = 0}) async {
    final rows = await _db.query(
      'sessions',
      orderBy: 'started_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Session.fromMap).toList();
  }
}
