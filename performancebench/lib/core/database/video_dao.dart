// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/video.dart';

/// Data access object for the `videos` table.
/// All queries are parameterized.
class VideoDao {
  final Database _db;

  VideoDao(this._db);

  /// Insert a video row.
  Future<int> insert(Video video) async {
    return _db.insert('videos', video.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Query the video for a session (one per session max).
  Future<Video?> getBySessionId(String sessionId) async {
    final rows = await _db.query(
      'videos',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Video.fromMap(rows.first);
  }

  /// Update a video row.
  Future<int> update(Video video) async {
    return _db.update(
      'videos',
      video.toMap(),
      where: 'session_id = ?',
      whereArgs: [video.sessionId],
    );
  }

  /// Delete the video for a session.
  Future<int> deleteBySessionId(String sessionId) async {
    return _db.delete(
      'videos',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }
}
