// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Data model for the `screenshots` table.
class Screenshot {
  final int? id;
  final String sessionId;
  final int? markerId;
  final int timestamp;
  final String filepath;
  final String sizeId;
  final int? widthPx;
  final int? heightPx;
  final int? fileSizeBytes;

  const Screenshot({
    this.id,
    required this.sessionId,
    this.markerId,
    required this.timestamp,
    required this.filepath,
    required this.sizeId,
    this.widthPx,
    this.heightPx,
    this.fileSizeBytes,
  });

  factory Screenshot.fromMap(Map<String, dynamic> map) {
    return Screenshot(
      id: map['id'] as int?,
      sessionId: map['session_id'] as String,
      markerId: map['marker_id'] as int?,
      timestamp: map['timestamp'] as int,
      filepath: map['filepath'] as String,
      sizeId: map['size_id'] as String,
      widthPx: map['width_px'] as int?,
      heightPx: map['height_px'] as int?,
      fileSizeBytes: map['file_size_bytes'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'session_id': sessionId,
      'marker_id': markerId,
      'timestamp': timestamp,
      'filepath': filepath,
      'size_id': sizeId,
      'width_px': widthPx,
      'height_px': heightPx,
      'file_size_bytes': fileSizeBytes,
    };
    if (id != null) map['id'] = id;
    return map;
  }
}

/// Data access object for the `screenshots` table.
class ScreenshotDao {
  final Database _db;

  ScreenshotDao(this._db);

  /// Batch insert multiple screenshot rows in a single transaction.
  Future<void> batchInsert(List<Screenshot> screenshots) async {
    if (screenshots.isEmpty) return;
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final s in screenshots) {
        batch.insert('screenshots', s.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  /// Insert a single screenshot row. Returns the auto-generated id.
  Future<int> insert(Screenshot screenshot) async {
    return _db.insert('screenshots', screenshot.toMap());
  }

  /// Query all screenshots for a session, ordered by timestamp ASC.
  Future<List<Screenshot>> getBySessionId(String sessionId) async {
    final rows = await _db.query(
      'screenshots',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(Screenshot.fromMap).toList();
  }

  /// Query screenshots for a session filtered by size_id.
  Future<List<Screenshot>> getBySessionIdAndSize(
    String sessionId,
    String sizeId,
  ) async {
    final rows = await _db.query(
      'screenshots',
      where: 'session_id = ? AND size_id = ?',
      whereArgs: [sessionId, sizeId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(Screenshot.fromMap).toList();
  }

  /// Query screenshots associated with a specific marker.
  Future<List<Screenshot>> getByMarkerId(int markerId) async {
    final rows = await _db.query(
      'screenshots',
      where: 'marker_id = ?',
      whereArgs: [markerId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(Screenshot.fromMap).toList();
  }

  /// Delete all screenshots for a session.
  Future<int> deleteBySessionId(String sessionId) async {
    return _db.delete(
      'screenshots',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Count screenshots for a session.
  Future<int> countBySessionId(String sessionId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM screenshots WHERE session_id = ?',
      [sessionId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }
}
