// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:io' show Platform;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Initialises the SQLite database and returns the instance.
/// Uses sqflite_common_ffi for desktop (Windows, macOS, Linux).
/// The database file is created at `<data_dir>/performancebench.db`.
Future<Database> initDatabase() async {
  // Must be called before any sqflite_common_ffi usage on desktop.
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final appDir = await getApplicationSupportDirectory();
  final dbPath = p.join(appDir.path, 'performancebench.db');

  final db = await databaseFactory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 2,
      onCreate: (db, version) async {
        await runMigrations(db, fromVersion: 0, toVersion: version);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await runMigrations(db, fromVersion: oldVersion, toVersion: newVersion);
      },
    ),
  );

  return db;
}

/// Additive migration runner. Reads the current `schema_version` and applies
/// migrations from [fromVersion]+1 up to [toVersion].
///
/// Migration v1: Creates all 13 v1.0 core tables exactly as specified in
/// UNIFIED-SPEC.md Appendix C. No deviations.
Future<void> runMigrations(
  Database db, {
  required int fromVersion,
  required int toVersion,
}) async {
  for (var v = fromVersion + 1; v <= toVersion; v++) {
    switch (v) {
      case 1:
        await _migrateV1(db);
      case 2:
        await _migrateV2(db);
    }
  }
}

/// v1 migration — create all 13 core tables per Appendix C DDL verbatim.
Future<void> _migrateV1(Database db) async {
  final batch = db.batch();

  // Schema version tracking
  batch.execute('''
    CREATE TABLE IF NOT EXISTS schema_version (
        version    INTEGER NOT NULL,
        applied_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
    )
  ''');

  // Devices (snapshot at session time, denormalized intentionally)
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

  // Sessions
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
        user_id           TEXT,
        has_video         INTEGER DEFAULT 0,
        is_uploaded       INTEGER DEFAULT 0,
        uploaded_at       INTEGER
    )
  ''');

  // Static device data — full hardware snapshot per session
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

  // Static app data — app-level snapshot per session
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

  // Metric samples — one row per second per session
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

  // Marker groups
  batch.execute('''
    CREATE TABLE IF NOT EXISTS marker_groups (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT    NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        name       TEXT    NOT NULL,
        color      TEXT,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
    )
  ''');

  // Markers
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

  // Sub-marker time regions
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

  // Per-marker analytics (computed post-session)
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

  // Session-level analytics summary (computed post-session)
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

  // Screenshots (5 sizes)
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

  // Session tags (many-to-many join for future use)
  batch.execute('''
    CREATE TABLE IF NOT EXISTS session_tags (
        session_id  TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        tag         TEXT NOT NULL,
        PRIMARY KEY (session_id, tag)
    )
  ''');

  await batch.commit(noResult: true);

  // Record schema version
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  await db.insert('schema_version', {
    'version': 1,
    'applied_at': nowMs,
  });
}

/// v2 migration — add collections, detected_issues, videos, and region_stats
/// tables per Appendix C DDL verbatim. Also adds `has_video` column to sessions.
Future<void> _migrateV2(Database db) async {
  // 1. collections table (v1.5)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS collections (
        id          TEXT    PRIMARY KEY,
        name        TEXT    NOT NULL,
        description TEXT,
        color       TEXT,
        created_at  INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
    )
  ''');

  // 2. detected_issues table (6.9)
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

  // 3. videos table (32.8)
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
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_videos_session ON videos(session_id)');

  // 4. sessions table addition
  await db.execute('ALTER TABLE sessions ADD COLUMN has_video INTEGER DEFAULT 0');

  // 5. region_stats table for per-region computed analytics
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
      'CREATE INDEX IF NOT EXISTS idx_region_stats_session ON region_stats(session_id)');

  // Record schema version
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  await db.insert('schema_version', {
    'version': 2,
    'applied_at': nowMs,
  });
}
