// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:performancebench/core/database/session_dao.dart';
import 'package:performancebench/core/database/collection_dao.dart';
import 'package:performancebench/core/models/session.dart';
import 'package:performancebench/core/models/collection.dart';

/// Integration-style tests for session search, filter, and collection operations.
/// Uses in-memory SQLite with minimal test schema.
void main() {
  late Database db;
  late SessionDao sessionDao;
  late CollectionDao collectionDao;

  /// Helper to create a session row directly for test data setup.
  Future<void> insertSession(Session s) async {
    // Insert device record first (sessions reference devices)
    await db.insert('devices', {
      'id': s.deviceId,
      'name': 'Test Device ${s.deviceId}',
      'model': 'TestModel',
      'chipset': 'TestChipset',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Resolve device info for insertion
    final devRows = await db.query('devices', where: 'id = ?', whereArgs: [s.deviceId]);
    final deviceName = devRows.isNotEmpty ? devRows.first['name'] as String? : null;
    final deviceModel = devRows.isNotEmpty ? devRows.first['model'] as String? : null;
    final deviceChipset = devRows.isNotEmpty ? devRows.first['chipset'] as String? : null;

    // Insert into sessions — use only toMap() columns
    await db.insert('sessions', s.toMap());
  }

  setUp(() async {
    // Initialize FFI for in-memory database
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    sessionDao = SessionDao(db);
    collectionDao = CollectionDao(db);

    // Create minimal test schema
    await db.execute('''
      CREATE TABLE devices (
        id TEXT PRIMARY KEY,
        name TEXT,
        model TEXT,
        chipset TEXT,
        manufacturer TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        device_id TEXT NOT NULL,
        platform TEXT NOT NULL,
        target_kind TEXT DEFAULT 'mobile',
        app_package TEXT NOT NULL,
        app_name TEXT,
        app_version TEXT,
        app_version_code INTEGER,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        duration_ms INTEGER,
        title TEXT,
        notes TEXT,
        tags TEXT,
        tags_kv_json TEXT,
        target_fps INTEGER DEFAULT 60,
        production_mode INTEGER DEFAULT 0,
        strict_mode INTEGER DEFAULT 0,
        injected INTEGER DEFAULT 0,
        collection_id TEXT,
        project_id TEXT,
        user_id TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE collections (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        color TEXT,
        created_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS session_tags (
        session_id TEXT NOT NULL,
        tag TEXT NOT NULL,
        PRIMARY KEY (session_id, tag)
      )
    ''');
  });

  tearDown(() async {
    await db.close();
  });

  // ──── Test 1: Text search across app_package, app_name, title ────
  test('searchSessions returns sessions matching app_package, app_name, or title', () async {
    await insertSession(Session(
      id: 's1', deviceId: 'd1', platform: 'android',
      appPackage: 'com.example.game', appName: 'Example Game',
      title: 'Release Test', startedAt: 1000,
    ));
    await insertSession(Session(
      id: 's2', deviceId: 'd1', platform: 'android',
      appPackage: 'com.other.app', appName: 'Other App',
      title: 'Debug Run', startedAt: 2000,
    ));
    await insertSession(Session(
      id: 's3', deviceId: 'd1', platform: 'android',
      appPackage: 'com.demo.app', appName: 'Demo App',
      title: 'Profile', startedAt: 3000,
    ));

    // Search by substring in app_package
    final results1 = await sessionDao.searchSessions('example');
    expect(results1.length, 2);
    expect(results1.any((s) => s.id == 's1'), isTrue);
    expect(results1.any((s) => s.id == 's3'), isTrue);

    // Search by app_name
    final results2 = await sessionDao.searchSessions('Other');
    expect(results2.length, 1);
    expect(results2.first.id, 's2');

    // Search by title
    final results3 = await sessionDao.searchSessions('Profile');
    expect(results3.length, 1);
    expect(results3.first.id, 's3');
  });

  // ──── Test 2: Empty search returns all sessions ────
  test('searchSessions with empty string returns all sessions', () async {
    await insertSession(Session(
      id: 's1', deviceId: 'd1', platform: 'android',
      appPackage: 'com.a', startedAt: 1000,
    ));
    await insertSession(Session(
      id: 's2', deviceId: 'd1', platform: 'android',
      appPackage: 'com.b', startedAt: 2000,
    ));

    final results = await sessionDao.searchSessions('');
    expect(results.length, 2);
  });

  // ──── Test 3: Filter by tag ────
  test('filterByTag returns sessions where tags field contains tag', () async {
    await insertSession(Session(
      id: 's1', deviceId: 'd1', platform: 'android',
      appPackage: 'com.a', startedAt: 1000,
      tags: '["release", "boss-fight"]',
    ));
    await insertSession(Session(
      id: 's2', deviceId: 'd1', platform: 'android',
      appPackage: 'com.b', startedAt: 2000,
      tags: '["debug"]',
    ));
    // Also add session_tags entries for tag-based filter path
    await db.insert('session_tags', {'session_id': 's1', 'tag': 'release'});
    await db.insert('session_tags', {'session_id': 's1', 'tag': 'boss-fight'});

    final results = await sessionDao.filterSessions(tag: 'release');
    expect(results.length, 1);
    expect(results.first.id, 's1');
  });

  // ──── Test 4: Filter by device model ────
  test('filterByDevice returns sessions where device name matches', () async {
    // Override the standard device with a specific model
    await db.delete('devices', where: 'id = ?', whereArgs: ['d1']);
    await db.insert('devices', {
      'id': 'd1', 'name': 'Pixel 8 Pro', 'model': 'Pixel 8 Pro', 'chipset': 'snapdragon',
    });
    await insertSession(Session(
      id: 's1', deviceId: 'd1', platform: 'android',
      appPackage: 'com.a', startedAt: 1000,
    ));

    await db.delete('devices', where: 'id = ?', whereArgs: ['d2']);
    await db.insert('devices', {
      'id': 'd2', 'name': 'Pixel 8', 'model': 'Pixel 8', 'chipset': 'snapdragon',
    });
    await insertSession(Session(
      id: 's2', deviceId: 'd2', platform: 'android',
      appPackage: 'com.b', startedAt: 2000,
    ));

    final results = await sessionDao.filterSessions(deviceModel: 'Pixel 8 Pro');
    expect(results.length, 1);
    expect(results.first.id, 's1');
  });

  // ──── Test 5: Filter by chipset ────
  test('filterByChipset returns sessions where device chipset matches', () async {
    // Override devices with specific chipsets
    await db.delete('devices', where: 'id = ?', whereArgs: ['d1']);
    await db.insert('devices', {
      'id': 'd1', 'name': 'Device A', 'model': 'ModelA', 'chipset': 'snapdragon',
    });
    await insertSession(Session(
      id: 's1', deviceId: 'd1', platform: 'android',
      appPackage: 'com.a', startedAt: 1000,
    ));

    await db.delete('devices', where: 'id = ?', whereArgs: ['d2']);
    await db.insert('devices', {
      'id': 'd2', 'name': 'Device B', 'model': 'ModelB', 'chipset': 'exynos',
    });
    await insertSession(Session(
      id: 's2', deviceId: 'd2', platform: 'android',
      appPackage: 'com.b', startedAt: 2000,
    ));

    final results = await sessionDao.filterSessions(chipset: 'snapdragon');
    expect(results.length, 1);
    expect(results.first.id, 's1');
  });

  // ──── Test 6: Filter by project_id ────
  test('filterByProject returns sessions with matching project_id', () async {
    await insertSession(Session(
      id: 's1', deviceId: 'd1', platform: 'android',
      appPackage: 'com.a', startedAt: 1000, projectId: 'proj-123',
    ));
    await insertSession(Session(
      id: 's2', deviceId: 'd1', platform: 'android',
      appPackage: 'com.b', startedAt: 2000, projectId: 'proj-456',
    ));

    final results = await sessionDao.filterSessions(projectId: 'proj-123');
    expect(results.length, 1);
    expect(results.first.id, 's1');
  });

  // ──── Test 7: Combined filter (intersection) ────
  test('Combined filter: tag + device + app returns intersection', () async {
    await insertSession(Session(
      id: 's1', deviceId: 'd1', platform: 'android',
      appPackage: 'com.example.game', startedAt: 1000,
      tags: '["release"]',
    ));
    await insertSession(Session(
      id: 's2', deviceId: 'd1', platform: 'android',
      appPackage: 'com.other.app', startedAt: 2000,
      tags: '["release"]',
    ));
    await insertSession(Session(
      id: 's3', deviceId: 'd2', platform: 'android',
      appPackage: 'com.example.game', startedAt: 3000,
      tags: '["debug"]',
    ));
    // Session tags for tag filter
    await db.insert('session_tags', {'session_id': 's1', 'tag': 'release'});
    await db.insert('session_tags', {'session_id': 's2', 'tag': 'release'});
    await db.insert('session_tags', {'session_id': 's3', 'tag': 'debug'});

    // Override device models
    await db.delete('devices', where: 'id = ?', whereArgs: ['d1']);
    await db.insert('devices', {
      'id': 'd1', 'name': 'Pixel 8 Pro', 'model': 'Pixel 8 Pro', 'chipset': 'snapdragon',
    });
    await db.delete('devices', where: 'id = ?', whereArgs: ['d2']);
    await db.insert('devices', {
      'id': 'd2', 'name': 'iPhone 15', 'model': 'iPhone 15', 'chipset': 'a17',
    });

    // Combined: tag=release + deviceModel=Pixel + appPackage=example
    final results = await sessionDao.filterSessions(
      tag: 'release',
      deviceModel: 'Pixel 8 Pro',
      appPackage: 'example',
    );
    expect(results.length, 1);
    expect(results.first.id, 's1');
  });

  // ──── Test 8: Collection CRUD and session assignment ────
  test('Collection CRUD: insert, getById, update, delete', () async {
    // Insert
    final c = Collection(
      id: 'col1',
      name: 'Release Tests',
      description: 'Test sessions for v1.0',
      createdAt: 1000,
    );
    await collectionDao.insert(c);

    // Get by ID
    final fetched = await collectionDao.getById('col1');
    expect(fetched, isNotNull);
    expect(fetched!.name, 'Release Tests');
    expect(fetched.description, 'Test sessions for v1.0');

    // Get all
    final all = await collectionDao.getAll();
    expect(all.length, 1);

    // Update
    final updated = Collection(
      id: 'col1',
      name: 'Updated Release Tests',
      description: 'Updated description',
      color: '#FF0000',
      createdAt: 1000,
    );
    await collectionDao.update(updated);

    final reFetched = await collectionDao.getById('col1');
    expect(reFetched!.name, 'Updated Release Tests');
    expect(reFetched.color, '#FF0000');

    // Delete
    await collectionDao.delete('col1');
    final afterDelete = await collectionDao.getById('col1');
    expect(afterDelete, isNull);
  });

  // ──── Test 9: Assign session to collection ────
  test('Assign session to collection and query by collection', () async {
    // Create collection
    final c = Collection(id: 'col1', name: 'Test Collection', createdAt: 1000);
    await collectionDao.insert(c);

    // Create sessions
    await insertSession(Session(
      id: 's1', deviceId: 'd1', platform: 'android',
      appPackage: 'com.a', startedAt: 1000,
    ));
    await insertSession(Session(
      id: 's2', deviceId: 'd1', platform: 'android',
      appPackage: 'com.b', startedAt: 2000,
    ));

    // Assign s1 to collection
    await sessionDao.setCollection('s1', 'col1');

    // Query by collection
    final results = await sessionDao.filterSessions(collectionId: 'col1');
    expect(results.length, 1);
    expect(results.first.id, 's1');
  });
}
