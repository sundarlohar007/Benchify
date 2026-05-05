// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/collection.dart';

/// Data access object for the `collections` table.
/// All queries are parameterized.
class CollectionDao {
  final Database _db;

  CollectionDao(this._db);

  /// Insert a collection row. Returns the row id.
  Future<void> insert(Collection collection) async {
    await _db.insert('collections', collection.toMap());
  }

  /// Query all collections.
  Future<List<Collection>> getAll() async {
    final rows = await _db.query('collections', orderBy: 'created_at DESC');
    return rows.map(Collection.fromMap).toList();
  }

  /// Query a collection by id.
  Future<Collection?> getById(String id) async {
    final rows = await _db.query(
      'collections',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Collection.fromMap(rows.first);
  }

  /// Update a collection.
  Future<int> update(Collection collection) async {
    return _db.update(
      'collections',
      collection.toMap(),
      where: 'id = ?',
      whereArgs: [collection.id],
    );
  }

  /// Delete a collection.
  Future<int> delete(String id) async {
    return _db.delete(
      'collections',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
