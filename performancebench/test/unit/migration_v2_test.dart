// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Helper: Create the complete v1 schema (matches _migrateV1 in database.dart).
Future<void> _createV1Schema(Database db) async {
  final batch = db.batch();

  batch.execute('''
    CREATE TABLE IF NOT EXISTS schema_version (
        version    INTEGER NOT NULL,
        applied_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS devices (
        id                    TEXT PRIMARY KEY,
        name                  TEXT NOT NULL,
        manufacturer          TEXT,
        model                 TEXT,
        os_version            TEXT,
        os_api_level          INTEGER,
        kernel_version        TEXT,
        chipset               TEXT,
        chipset_vendor        TEXT,
        gpu_vendor            TEXT,
        gpu_model             TEXT,
        cpu_cores_count       INTEGER,
        cpu_max_freq_khz      INTEGER,
        screen_resolution     TEXT,
        screen_density_dpi    INTEGER,
        refresh_rate_hz       INTEGER,
        battery_capacity_mah  INTEGER,
        total_ram_kb          INTEGER,
        internal_storage_gb   INTEGER,
        is_rooted             INTEGER DEFAULT 0,
        is_emulator           INTEGER DEFAULT 0,
        first_seen_at         INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS sessions (
        id                TEXT    PRIMARY KEY,
        device_id         TEXT    NOT NULL REFERENCES devices(id),
        platform          TEXT    NOT NULL,
        target_kind       TEXT    NOT NULL DEFAULT 'mobile',
        app_package       TEXT    NOT NULL,
        app_name          TEXT,
        app_version       TEXT,
        app_version_code  INTEGER,
        started_at        INTEGER NOT NULL,
        ended_at          INTEGER,
        duration_ms       INTEGER,
        title             TEXT,
        notes             TEXT,
        tags              TEXT,
        tags_kv_json      TEXT,
        target_fps        INTEGER DEFAULT 60,
        production_mode   INTEGER DEFAULT 0,
        strict_mode       INTEGER DEFAULT 0,
        injected          INTEGER DEFAULT 0,
        collection_id     TEXT,
        project_id        TEXT,
        user_id           TEXT
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS static_device_data (
        session_id        TEXT PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,
        raw_getprop_json  TEXT,
        sensors_json      TEXT,
        cameras_json      TEXT,
        sim_carriers_json TEXT,
        locale            TEXT,
        timezone          TEXT,
        captured_at       INTEGER NOT NULL
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS static_app_data (
        session_id          TEXT PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,
        install_source      TEXT,
        install_time_ms     INTEGER,
        update_time_ms      INTEGER,
        target_sdk          INTEGER,
        min_sdk             INTEGER,
        permissions_json    TEXT,
        abi_list            TEXT,
        apk_size_bytes      INTEGER,
        captured_at         INTEGER NOT NULL
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS metric_samples (
        id                       INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id               TEXT    NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        timestamp                INTEGER NOT NULL,
        fps                      REAL,
        jank_count               INTEGER,
        jank_small_count         INTEGER,
        jank_big_count           INTEGER,
        jank_ratio_count         INTEGER,
        frametimes_json          TEXT,
        cpu_system_pct           REAL,
        cpu_app_pct              REAL,
        cpu_app_pct_freq_norm    REAL,
        cpu_cores                TEXT,
        cpu_core_states_json     TEXT,
        cpu_core_freqs_json      TEXT,
        cpu_threads_top_json     TEXT,
        memory_pss_kb            INTEGER,
        memory_java_kb           INTEGER,
        memory_native_kb         INTEGER,
        memory_graphics_kb       INTEGER,
        memory_stack_kb          INTEGER,
        memory_code_kb           INTEGER,
        memory_system_kb         INTEGER,
        memory_webview_kb        INTEGER,
        battery_pct              INTEGER,
        battery_ma               REAL,
        battery_mv               REAL,
        battery_temp_c           REAL,
        charging                 INTEGER DEFAULT 0,
        charging_source          TEXT,
        wifi_active              INTEGER,
        net_tx_bytes             INTEGER,
        net_rx_bytes             INTEGER,
        net_wifi_tx_bytes        INTEGER,
        net_wifi_rx_bytes        INTEGER,
        net_cellular_tx_bytes    INTEGER,
        net_cellular_rx_bytes    INTEGER,
        net_other_tx_bytes       INTEGER,
        net_other_rx_bytes       INTEGER,
        thermal_status           INTEGER,
        gpu_pct                  REAL,
        gpu_freq_mhz             REAL,
        gpu_mem_kb               INTEGER,
        disk_read_kb             REAL,
        disk_write_kb            REAL,
        screen_brightness        INTEGER,
        volume_pct               INTEGER
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS marker_groups (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT    NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        name       TEXT    NOT NULL,
        color      TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS markers (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id      TEXT    NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        group_id        INTEGER REFERENCES marker_groups(id) ON DELETE SET NULL,
        label           TEXT    NOT NULL,
        started_at      INTEGER NOT NULL,
        ended_at        INTEGER,
        auto_screenshot INTEGER DEFAULT 0,
        notes           TEXT
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS regions (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id  TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        label       TEXT NOT NULL,
        started_at  INTEGER NOT NULL,
        ended_at    INTEGER NOT NULL,
        color       TEXT
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS marker_stats (
        id                       INTEGER PRIMARY KEY AUTOINCREMENT,
        marker_id                INTEGER NOT NULL REFERENCES markers(id) ON DELETE CASCADE,
        session_id               TEXT    NOT NULL,
        duration_ms              INTEGER,
        fps_median               REAL,
        fps_min                  REAL,
        fps_max                  REAL,
        fps_1pct_low             REAL,
        fps_stability            REAL,
        frame_time_p95           REAL,
        variability_index        REAL,
        cpu_avg_pct              REAL,
        cpu_avg_pct_freq_norm    REAL,
        memory_peak_kb           INTEGER,
        mem_graphics_peak_kb     INTEGER,
        gpu_avg_pct              REAL,
        battery_drain_pct        REAL,
        mah_consumed             REAL,
        jank_total               INTEGER,
        jank_small_total         INTEGER,
        jank_big_total           INTEGER,
        jank_ratio_total         INTEGER,
        jank_per_min             REAL
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS session_stats (
        session_id                  TEXT    PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,
        fps_median                  REAL,
        fps_min                     REAL,
        fps_max                     REAL,
        fps_1pct_low                REAL,
        fps_stability               REAL,
        frame_time_p95              REAL,
        fps_histogram               TEXT,
        variability_index           REAL,
        frame_ratio_jank_total      INTEGER,
        cpu_avg_pct                 REAL,
        cpu_peak_pct                REAL,
        cpu_avg_pct_freq_norm       REAL,
        cpu_peak_pct_freq_norm      REAL,
        memory_avg_kb               INTEGER,
        memory_peak_kb              INTEGER,
        mem_java_avg_kb             INTEGER,
        mem_java_peak_kb            INTEGER,
        mem_native_avg_kb           INTEGER,
        mem_native_peak_kb          INTEGER,
        mem_graphics_avg_kb         INTEGER,
        mem_graphics_peak_kb        INTEGER,
        mem_stack_avg_kb            INTEGER,
        mem_code_avg_kb             INTEGER,
        mem_system_avg_kb           INTEGER,
        mem_webview_avg_kb          INTEGER,
        mem_growth_kb               INTEGER,
        mem_trend_slope_kb_per_min  REAL,
        gpu_avg_pct                 REAL,
        gpu_peak_pct                REAL,
        battery_drain_pct           REAL,
        battery_drain_per_hour      REAL,
        battery_temp_max_c          REAL,
        mah_consumed                REAL,
        avg_power_mw                REAL,
        total_power_mwh             REAL,
        estimated_playtime_h        REAL,
        has_charging_period         INTEGER DEFAULT 0,
        jank_total                  INTEGER,
        jank_small_total            INTEGER,
        jank_big_total              INTEGER,
        jank_ratio_total            INTEGER,
        jank_per_min                REAL,
        net_total_tx_kb             REAL,
        net_total_rx_kb             REAL,
        net_wifi_total_tx_kb        REAL,
        net_wifi_total_rx_kb        REAL,
        net_cellular_total_tx_kb    REAL,
        net_cellular_total_rx_kb    REAL,
        net_other_total_tx_kb       REAL,
        net_other_total_rx_kb       REAL,
        net_wifi_avg_kbps           REAL,
        net_cellular_avg_kbps       REAL,
        thermal_peak                INTEGER,
        launch_complete_ms          INTEGER,
        duration_ms                 INTEGER
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS screenshots (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id      TEXT    NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        marker_id       INTEGER REFERENCES markers(id) ON DELETE SET NULL,
        timestamp       INTEGER NOT NULL,
        filepath        TEXT    NOT NULL,
        size_id         TEXT    NOT NULL,
        width_px        INTEGER,
        height_px       INTEGER,
        file_size_bytes INTEGER
    )
  ''');

  batch.execute('''
    CREATE TABLE IF NOT EXISTS session_tags (
        session_id  TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        tag         TEXT NOT NULL,
        PRIMARY KEY (session_id, tag)
    )
  ''');

  await batch.commit(noResult: true);

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  await db.insert('schema_version', {
    'version': 1,
    'applied_at': nowMs,
  });
}

/// Helper: Create the v2 schema additions (matches _migrateV2 in database.dart).
Future<void> _createV2Schema(Database db) async {
  // collections table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS collections (
        id          TEXT    PRIMARY KEY,
        name        TEXT    NOT NULL,
        description TEXT,
        color       TEXT,
        created_at  INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
    )
  ''');

  // detected_issues table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS detected_issues (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id      TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        rule_id         TEXT NOT NULL,
        severity        TEXT NOT NULL,
        metric          TEXT,
        observed_value  REAL,
        threshold_value REAL,
        message         TEXT NOT NULL,
        created_at      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
    )
  ''');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_issues_session  ON detected_issues(session_id)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_issues_severity ON detected_issues(severity)');

  // videos table
  await db.execute('''
    CREATE TABLE IF NOT EXISTS videos (
        session_id          TEXT    PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,
        filepath            TEXT    NOT NULL,
        codec               TEXT    NOT NULL DEFAULT 'h264',
        container           TEXT    NOT NULL DEFAULT 'mp4',
        width_px            INTEGER NOT NULL,
        height_px           INTEGER NOT NULL,
        target_fps          INTEGER,
        actual_avg_fps      REAL,
        bitrate_kbps        INTEGER,
        duration_ms         INTEGER NOT NULL,
        file_size_bytes     INTEGER NOT NULL,
        chunks_json         TEXT,
        gaps_json           TEXT,
        has_audio           INTEGER DEFAULT 0,
        recording_overhead_estimate_pct REAL,
        started_at          INTEGER NOT NULL,
        ended_at            INTEGER NOT NULL,
        created_at          INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
    )
  ''');

  // sessions table addition
  await db.execute('ALTER TABLE sessions ADD COLUMN has_video INTEGER DEFAULT 0');

  // region_stats table for per-region computed analytics
  await db.execute('''
    CREATE TABLE IF NOT EXISTS region_stats (
        id                       INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id               TEXT    NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        label                    TEXT    NOT NULL,
        start_ms                 INTEGER NOT NULL,
        end_ms                   INTEGER NOT NULL,
        color                    TEXT,
        duration_ms              INTEGER,
        fps_median               REAL,
        fps_min                  REAL,
        fps_max                  REAL,
        fps_1pct_low             REAL,
        fps_stability            REAL,
        frame_time_p95           REAL,
        variability_index        REAL,
        cpu_avg_pct              REAL,
        cpu_avg_pct_freq_norm    REAL,
        memory_peak_kb           INTEGER,
        mem_graphics_peak_kb     INTEGER,
        gpu_avg_pct              REAL,
        battery_drain_pct        REAL,
        mah_consumed             REAL,
        jank_total               INTEGER,
        jank_small_total         INTEGER,
        jank_big_total           INTEGER,
        jank_ratio_total         INTEGER,
        jank_per_min             REAL
    )
  ''');

  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_videos_session ON videos(session_id)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_region_stats_session ON region_stats(session_id)');

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  await db.insert('schema_version', {
    'version': 2,
    'applied_at': nowMs,
  });
}

void main() {
  group('Schema migration v2', () {
    late String dbPath;

    setUp(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      dbPath =
          '${Directory.systemTemp.path}/migration_v2_test_${DateTime.now().millisecondsSinceEpoch}.db';
    });

    tearDown(() async {
      try {
        await File(dbPath).delete();
      } catch (_) {}
    });

    // ---------------------------------------------------------------------------
    // Test 1: 4 new tables exist after upgrade
    // ---------------------------------------------------------------------------
    test('v2 upgrade creates 4 new tables (collections, detected_issues, videos, region_stats)',
        () async {
      // Create DB at version 1
      var db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await _createV1Schema(db);
          },
        ),
      );

      // Insert a sample device and session so FK references work
      await db.insert('devices', {
        'id': 'dev-1',
        'name': 'Test Device',
      });
      await db.insert('sessions', {
        'id': 'sess-1',
        'device_id': 'dev-1',
        'platform': 'android',
        'app_package': 'com.test.app',
        'started_at': DateTime.now().millisecondsSinceEpoch,
      });
      await db.close();

      // Reopen at version 2, triggering onUpgrade
      db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await _createV1Schema(db);
            await _createV2Schema(db);
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            if (oldVersion < 2) {
              await _createV2Schema(db);
            }
          },
        ),
      );

      // Verify all 4 new tables exist
      final tables = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
      final tableNames = tables.map((r) => r['name'] as String).toSet();

      expect(tableNames.contains('collections'), isTrue,
          reason: 'collections table should exist after v2 migration');
      expect(tableNames.contains('detected_issues'), isTrue,
          reason: 'detected_issues table should exist after v2 migration');
      expect(tableNames.contains('videos'), isTrue,
          reason: 'videos table should exist after v2 migration');
      expect(tableNames.contains('region_stats'), isTrue,
          reason: 'region_stats table should exist after v2 migration');

      // Existing v1 data still intact
      expect(tableNames.contains('sessions'), isTrue,
          reason: 'sessions table should still exist after v2 migration');
      final sessionRows = await db.query('sessions', where: 'id = ?', whereArgs: ['sess-1']);
      expect(sessionRows, isNotEmpty);

      await db.close();
    });

    // ---------------------------------------------------------------------------
    // Test 2: collections table has correct columns
    // ---------------------------------------------------------------------------
    test('collections table has correct columns', () async {
      var db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(version: 2, onCreate: (db, version) async {
          await _createV1Schema(db);
          await _createV2Schema(db);
        }),
      );

      final columns =
          await db.rawQuery("PRAGMA table_info('collections')");
      final colNames = columns.map((c) => c['name'] as String).toSet();

      expect(colNames.contains('id'), isTrue);
      expect(colNames.contains('name'), isTrue);
      expect(colNames.contains('description'), isTrue);
      expect(colNames.contains('color'), isTrue);
      expect(colNames.contains('created_at'), isTrue);

      // Verify PK and NOT NULL constraints
      final idCol = columns.firstWhere((c) => c['name'] == 'id');
      expect(idCol['pk'], 1); // Primary key
      final nameCol = columns.firstWhere((c) => c['name'] == 'name');
      expect(nameCol['notnull'], 1); // NOT NULL

      await db.close();
    });

    // ---------------------------------------------------------------------------
    // Test 3: detected_issues table has correct columns
    // ---------------------------------------------------------------------------
    test('detected_issues table has correct columns', () async {
      var db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(version: 2, onCreate: (db, version) async {
          await _createV1Schema(db);
          await _createV2Schema(db);
        }),
      );

      final columns =
          await db.rawQuery("PRAGMA table_info('detected_issues')");
      final colNames = columns.map((c) => c['name'] as String).toSet();

      expect(colNames.contains('id'), isTrue);
      expect(colNames.contains('session_id'), isTrue);
      expect(colNames.contains('rule_id'), isTrue);
      expect(colNames.contains('severity'), isTrue);
      expect(colNames.contains('metric'), isTrue);
      expect(colNames.contains('observed_value'), isTrue);
      expect(colNames.contains('threshold_value'), isTrue);
      expect(colNames.contains('message'), isTrue);
      expect(colNames.contains('created_at'), isTrue);

      await db.close();
    });

    // ---------------------------------------------------------------------------
    // Test 4: videos table has correct columns
    // ---------------------------------------------------------------------------
    test('videos table has correct columns per spec', () async {
      var db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(version: 2, onCreate: (db, version) async {
          await _createV1Schema(db);
          await _createV2Schema(db);
        }),
      );

      final columns = await db.rawQuery("PRAGMA table_info('videos')");
      final colNames = columns.map((c) => c['name'] as String).toSet();

      expect(colNames.contains('session_id'), isTrue);
      expect(colNames.contains('filepath'), isTrue);
      expect(colNames.contains('codec'), isTrue);
      expect(colNames.contains('container'), isTrue);
      expect(colNames.contains('width_px'), isTrue);
      expect(colNames.contains('height_px'), isTrue);
      expect(colNames.contains('target_fps'), isTrue);
      expect(colNames.contains('actual_avg_fps'), isTrue);
      expect(colNames.contains('bitrate_kbps'), isTrue);
      expect(colNames.contains('duration_ms'), isTrue);
      expect(colNames.contains('file_size_bytes'), isTrue);
      expect(colNames.contains('chunks_json'), isTrue);
      expect(colNames.contains('gaps_json'), isTrue);
      expect(colNames.contains('has_audio'), isTrue);
      expect(colNames.contains('recording_overhead_estimate_pct'), isTrue);
      expect(colNames.contains('started_at'), isTrue);
      expect(colNames.contains('ended_at'), isTrue);
      expect(colNames.contains('created_at'), isTrue);

      await db.close();
    });

    // ---------------------------------------------------------------------------
    // Test 5: sessions table has has_video column after migration
    // ---------------------------------------------------------------------------
    test('sessions table has has_video column after migration', () async {
      var db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(version: 2, onCreate: (db, version) async {
          await _createV1Schema(db);
          await _createV2Schema(db);
        }),
      );

      final columns =
          await db.rawQuery("PRAGMA table_info('sessions')");
      final hasVideoCol = columns.cast<Map<String, dynamic>>().firstWhere(
            (c) => c['name'] == 'has_video',
            orElse: () => <String, dynamic>{},
          );

      expect(hasVideoCol, isNotEmpty,
          reason: 'has_video column should exist on sessions table');
      expect(hasVideoCol['dflt_value'], contains('0'),
          reason: 'has_video should default to 0');

      await db.close();
    });

    // ---------------------------------------------------------------------------
    // Test 6: indexes exist
    // ---------------------------------------------------------------------------
    test('required indexes exist after v2 migration', () async {
      var db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(version: 2, onCreate: (db, version) async {
          await _createV1Schema(db);
          await _createV2Schema(db);
        }),
      );

      final indexes = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type='index' ORDER BY name");
      final indexNames = indexes.map((r) => r['name'] as String).toSet();

      expect(indexNames.contains('idx_issues_session'), isTrue,
          reason: 'idx_issues_session index should exist');
      expect(indexNames.contains('idx_issues_severity'), isTrue,
          reason: 'idx_issues_severity index should exist');
      expect(indexNames.contains('idx_videos_session'), isTrue,
          reason: 'idx_videos_session index should exist');

      await db.close();
    });

    // ---------------------------------------------------------------------------
    // Test 7: collection row round-trip (insert + query)
    // ---------------------------------------------------------------------------
    test('collection row round-trips correctly', () async {
      var db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(version: 2, onCreate: (db, version) async {
          await _createV1Schema(db);
          await _createV2Schema(db);
        }),
      );

      final id = 'col-1';
      await db.insert('collections', {
        'id': id,
        'name': 'My Collection',
        'description': 'Test description',
        'color': '#FF0000',
        'created_at': 1000000,
      });

      final rows = await db.query('collections', where: 'id = ?', whereArgs: [id]);
      expect(rows, hasLength(1));
      expect(rows.first['id'], id);
      expect(rows.first['name'], 'My Collection');
      expect(rows.first['description'], 'Test description');
      expect(rows.first['color'], '#FF0000');

      await db.close();
    });
  });
}
