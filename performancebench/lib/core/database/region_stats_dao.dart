// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/region_stats.dart';

/// Data access object for the `region_stats` table.
/// All queries are parameterized. Follows same pattern as MarkerStatsDao.
class RegionStatsDao {
  final Database _db;

  RegionStatsDao(this._db);

  /// Insert a region_stats row. Returns the auto-generated id.
  Future<int> insert(RegionStats stats) async {
    return _db.insert('region_stats', stats.toMap());
  }

  /// Query all region_stats for a session.
  Future<List<RegionStats>> getBySessionId(String sessionId) async {
    final rows = await _db.query(
      'region_stats',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'start_ms ASC',
    );
    return rows.map(RegionStats.fromMap).toList();
  }

  /// Delete all region_stats for a session.
  Future<int> deleteBySessionId(String sessionId) async {
    return _db.delete(
      'region_stats',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }
}
