// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/marker.dart';

/// Data access object for the `markers` table.
/// All queries are parameterized.
class MarkerDao {
  final Database _db;

  MarkerDao(this._db);

  /// Insert a marker. Returns the auto-generated id.
  Future<int> insert(Marker marker) async {
    return _db.insert('markers', marker.toMap());
  }

  /// Query all markers for a session, ordered by started_at ASC.
  Future<List<Marker>> getBySessionId(String sessionId) async {
    final rows = await _db.query(
      'markers',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'started_at ASC',
    );
    return rows.map(Marker.fromMap).toList();
  }

  /// Query markers for a session by label.
  Future<List<Marker>> getBySessionIdAndLabel(
    String sessionId,
    String label,
  ) async {
    final rows = await _db.query(
      'markers',
      where: 'session_id = ? AND label = ?',
      whereArgs: [sessionId, label],
      orderBy: 'started_at ASC',
    );
    return rows.map(Marker.fromMap).toList();
  }

  /// Find the launch_complete marker for a session.
  Future<Marker?> getLaunchComplete(String sessionId) async {
    final rows = await _db.query(
      'markers',
      where: "session_id = ? AND label = '__launch_complete__'",
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Marker.fromMap(rows.first);
  }

  /// Update the ended_at timestamp for a point→range marker transition.
  Future<int> updateEndedAt(int markerId, int endedAt) async {
    return _db.update(
      'markers',
      {'ended_at': endedAt},
      where: 'id = ?',
      whereArgs: [markerId],
    );
  }

  /// Update marker notes and auto_screenshot flag.
  Future<int> updateMarker(int markerId, {
    String? notes,
    int? autoScreenshot,
    int? endedAt,
  }) async {
    final values = <String, dynamic>{};
    if (notes != null) values['notes'] = notes;
    if (autoScreenshot != null) values['auto_screenshot'] = autoScreenshot;
    if (endedAt != null) values['ended_at'] = endedAt;
    if (values.isEmpty) return 0;
    return _db.update(
      'markers',
      values,
      where: 'id = ?',
      whereArgs: [markerId],
    );
  }

  /// Delete a marker by id.
  Future<int> deleteById(int markerId) async {
    return _db.delete(
      'markers',
      where: 'id = ?',
      whereArgs: [markerId],
    );
  }

  /// Count markers for a session.
  Future<int> countBySessionId(String sessionId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM markers WHERE session_id = ?',
      [sessionId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }
}
