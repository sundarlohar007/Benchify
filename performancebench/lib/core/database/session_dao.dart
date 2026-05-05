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

  // =========================================================================
  // v1.5 — Search, Filter, Collections (V15-04, V15-05)
  // =========================================================================

  /// Search sessions by text across app_package, app_name, and title.
  /// Uses parameterized LIKE queries — no string interpolation.
  Future<List<Session>> searchSessions(String query) async {
    if (query.trim().isEmpty) return getAll();
    final pattern = '%$query%';
    final rows = await _db.rawQuery('''
      SELECT s.*
      FROM sessions s
      WHERE s.app_package LIKE ? OR s.app_name LIKE ? OR s.title LIKE ?
      ORDER BY s.started_at DESC
    ''', [pattern, pattern, pattern]);
    return rows.map(Session.fromMap).toList();
  }

  /// Filter sessions by tag, device, app, chipset, project, collection — all optional.
  /// All filters combined with AND for intersection semantics.
  /// Uses parameterized queries per T-02-06 (injection mitigation).
  Future<List<Session>> filterSessions({
    String? tag,
    String? deviceModel,
    String? appPackage,
    String? chipset,
    String? projectId,
    String? collectionId,
    int limit = 100,
  }) async {
    final conditions = <String>[];
    final params = <dynamic>[];

    if (tag != null && tag.isNotEmpty) {
      conditions.add('(s.tags LIKE ? OR s.tags_kv_json LIKE ? OR '
          'EXISTS (SELECT 1 FROM session_tags st WHERE st.session_id = s.id AND st.tag = ?))');
      params.addAll(['%$tag%', '%$tag%', tag]);
    }
    if (deviceModel != null && deviceModel.isNotEmpty) {
      conditions.add('(d.model LIKE ? OR d.name LIKE ?)');
      params.addAll(['%$deviceModel%', '%$deviceModel%']);
    }
    if (appPackage != null && appPackage.isNotEmpty) {
      conditions.add('s.app_package LIKE ?');
      params.add('%$appPackage%');
    }
    if (chipset != null && chipset.isNotEmpty) {
      conditions.add('d.chipset LIKE ?');
      params.add('%$chipset%');
    }
    if (projectId != null && projectId.isNotEmpty) {
      conditions.add('s.project_id = ?');
      params.add(projectId);
    }
    if (collectionId != null && collectionId.isNotEmpty) {
      conditions.add('s.collection_id = ?');
      params.add(collectionId);
    }

    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final rows = await _db.rawQuery('''
      SELECT s.*
      FROM sessions s
      JOIN devices d ON s.device_id = d.id
      $where
      ORDER BY s.started_at DESC
      LIMIT ?
    ''', [...params, limit]);
    return rows.map(Session.fromMap).toList();
  }

  /// Mark session as having a video recording.
  Future<int> setHasVideo(String sessionId, bool hasVideo) async {
    return _db.update('sessions', {'has_video': hasVideo ? 1 : 0},
        where: 'id = ?', whereArgs: [sessionId]);
  }

  /// Assign session to a collection (post-hoc per D-13).
  Future<int> setCollection(String sessionId, String collectionId) async {
    return _db.update('sessions', {'collection_id': collectionId},
        where: 'id = ?', whereArgs: [sessionId]);
  }

  /// Assign project to a session.
  Future<int> setProject(String sessionId, String projectId) async {
    return _db.update('sessions', {'project_id': projectId},
        where: 'id = ?', whereArgs: [sessionId]);
  }

  /// Update tags on a session (post-hoc per D-13).
  Future<int> setTags(String sessionId, String tags) async {
    return _db.update('sessions', {'tags': tags},
        where: 'id = ?', whereArgs: [sessionId]);
  }

  /// Get recent sessions for same app_package + device_id combo (for baseline computation).
  /// Used by DetectedIssuesService for FPS_REGRESSION and LAUNCH_TIME_INCREASE rules.
  Future<List<Session>> getRecentSessionsByAppDevice(
    String appPackage,
    String deviceId, {
    int limit = 5,
  }) async {
    final rows = await _db.query(
      'sessions',
      where: 'app_package = ? AND device_id = ?',
      whereArgs: [appPackage, deviceId],
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(Session.fromMap).toList();
  }
}
