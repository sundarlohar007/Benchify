// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/marker_dao.dart';
import '../database/marker_stats_dao.dart';
import '../database/metric_dao.dart';
import '../database/session_dao.dart';
import '../database/session_stats_dao.dart';
import '../models/marker.dart';
import '../models/marker_stats.dart';
import '../models/metric_sample.dart';
import '../models/session.dart';
import '../models/session_stats.dart';

/// Exports session data as JSON or CSV.
///
/// JSON export includes: session metadata, session_stats, all metric_samples,
/// and markers with their stats. CSV export includes all metric_samples.
///
/// Both exports are manual-only (user chooses save path via file_picker).
/// CSV formula injection mitigated: fields starting with =, +, -, @ are
/// prefixed with single quote.
class ExportService {
  final Database _db;
  final MetricDao _metricDao;
  final SessionDao _sessionDao;
  final SessionStatsDao _sessionStatsDao;
  final MarkerDao _markerDao;
  final MarkerStatsDao _markerStatsDao;

  ExportService({
    required Database db,
    required MetricDao metricDao,
    required SessionDao sessionDao,
    required SessionStatsDao sessionStatsDao,
    required MarkerDao markerDao,
    required MarkerStatsDao markerStatsDao,
  })  : _db = db,
        _metricDao = metricDao,
        _sessionDao = sessionDao,
        _sessionStatsDao = sessionStatsDao,
        _markerDao = markerDao,
        _markerStatsDao = markerStatsDao;

  /// Export session as structured JSON.
  Future<String> exportJson(String sessionId) async {
    final session = await _sessionDao.getById(sessionId);
    final samples = await _metricDao.getBySessionId(sessionId);
    final stats = await _sessionStatsDao.getBySessionId(sessionId);
    final markers = await _markerDao.getBySessionId(sessionId);
    final markerStats = <Map<String, dynamic>>[];

    for (final m in markers) {
      final msList = await _markerStatsDao.getByMarkerId(m.id!);
      for (final ms in msList) {
        markerStats.add({
          'marker': m.toMap(),
          'stats': ms.toMap(),
        });
      }
    }

    final json = {
      'session': session?.toMap() ?? {},
      'stats': stats?.toMap() ?? {},
      'samples': samples.map((s) => s.toMap()).toList(),
      'markers': markerStats,
      'exported_at': _iso8601Now(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }

  /// Export session metric samples as CSV.
  Future<String> exportCsv(String sessionId) async {
    final samples = await _metricDao.getBySessionId(sessionId);

    final header = _csvHeaders();
    final rows = <List<dynamic>>[header];

    for (final sample in samples) {
      rows.add(_sampleToRow(sample));
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// All MetricSample fields in snake_case order matching the model.
  List<String> _csvHeaders() {
    return [
      'session_id', 'timestamp',
      'fps', 'jank_count', 'jank_small_count', 'jank_big_count',
      'jank_ratio_count', 'frametimes_json',
      'cpu_system_pct', 'cpu_app_pct', 'cpu_app_pct_freq_norm',
      'cpu_cores', 'cpu_core_states_json', 'cpu_core_freqs_json',
      'cpu_threads_top_json',
      'memory_pss_kb', 'memory_java_kb', 'memory_native_kb',
      'memory_graphics_kb', 'memory_stack_kb', 'memory_code_kb',
      'memory_system_kb', 'memory_webview_kb',
      'battery_pct', 'battery_ma', 'battery_mv', 'battery_temp_c',
      'charging', 'charging_source', 'wifi_active',
      'net_tx_bytes', 'net_rx_bytes',
      'net_wifi_tx_bytes', 'net_wifi_rx_bytes',
      'net_cellular_tx_bytes', 'net_cellular_rx_bytes',
      'net_other_tx_bytes', 'net_other_rx_bytes',
      'thermal_status', 'gpu_pct', 'gpu_freq_mhz', 'gpu_mem_kb',
      'disk_read_kb', 'disk_write_kb',
      'screen_brightness', 'volume_pct',
    ];
  }

  List<dynamic> _sampleToRow(MetricSample s) {
    return [
      _safeCsv(s.sessionId),
      s.timestamp,
      s.fps ?? '',
      s.jankCount ?? '',
      s.jankSmallCount ?? '',
      s.jankBigCount ?? '',
      s.jankRatioCount ?? '',
      _safeCsv(s.frametimesJson),
      s.cpuSystemPct ?? '',
      s.cpuAppPct ?? '',
      s.cpuAppPctFreqNorm ?? '',
      _safeCsv(s.cpuCores),
      _safeCsv(s.cpuCoreStatesJson),
      _safeCsv(s.cpuCoreFreqsJson),
      _safeCsv(s.cpuThreadsTopJson),
      s.memoryPssKb ?? '',
      s.memoryJavaKb ?? '',
      s.memoryNativeKb ?? '',
      s.memoryGraphicsKb ?? '',
      s.memoryStackKb ?? '',
      s.memoryCodeKb ?? '',
      s.memorySystemKb ?? '',
      s.memoryWebviewKb ?? '',
      s.batteryPct ?? '',
      s.batteryMa ?? '',
      s.batteryMv ?? '',
      s.batteryTempC ?? '',
      s.charging,
      _safeCsv(s.chargingSource),
      s.wifiActive ?? '',
      s.netTxBytes ?? '',
      s.netRxBytes ?? '',
      s.netWifiTxBytes ?? '',
      s.netWifiRxBytes ?? '',
      s.netCellularTxBytes ?? '',
      s.netCellularRxBytes ?? '',
      s.netOtherTxBytes ?? '',
      s.netOtherRxBytes ?? '',
      s.thermalStatus ?? '',
      s.gpuPct ?? '',
      s.gpuFreqMhz ?? '',
      s.gpuMemKb ?? '',
      s.diskReadKb ?? '',
      s.diskWriteKb ?? '',
      s.screenBrightness ?? '',
      s.volumePct ?? '',
    ];
  }

  String _iso8601Now() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${_pad(now.month)}-${_pad(now.day)}T'
        '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}Z';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  /// Mitigate CSV formula injection: prefix =, +, -, @ with single quote.
  String _safeCsv(String? value) {
    if (value == null) return '';
    if (value.startsWith('=') ||
        value.startsWith('+') ||
        value.startsWith('-') ||
        value.startsWith('@')) {
      return "'$value";
    }
    return value;
  }
}
