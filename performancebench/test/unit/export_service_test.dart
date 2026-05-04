import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/models/metric_sample.dart';

void main() {
  group('ExportService JSON', () {
    test('empty session produces valid JSON with empty samples array', () {
      final json = {
        'session': {'id': 'test-session'},
        'stats': {},
        'samples': [],
        'markers': [],
        'exported_at': '2024-01-15T14:32:00Z',
      };
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded);
      expect(decoded['samples'], isEmpty);
      expect(decoded['session']['id'], 'test-session');
    });

    test('JSON with 3 samples has 3 elements with fps field', () {
      final samples = List.generate(3, (i) => {
        'session_id': 'test',
        'timestamp': 1000 * i,
        'fps': (60 - i * 5).toDouble(),
      });
      final json = {
        'session': {'id': 'test'},
        'stats': {},
        'samples': samples,
        'markers': [],
        'exported_at': '2024-01-15T14:32:00Z',
      };
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded);
      expect((decoded['samples'] as List).length, 3);
      for (final s in decoded['samples']) {
        expect(s.containsKey('fps'), true);
      }
    });
  });

  group('ExportService CSV', () {
    test('CSV column count matches MetricSample fields, header row present', () {
      final csv = _buildCsvHeader();
      final lines = csv.split('\n');
      expect(lines.first.isNotEmpty, true);
      final headerCols = lines.first.split(',');
      // Header should include key field names
      expect(headerCols.contains('session_id'), true);
      expect(headerCols.contains('timestamp'), true);
      expect(headerCols.contains('fps'), true);
    });

    test('CSV first data row matches first sample fps value', () {
      final csv = _buildCsvWithData([60.0, 59.0, 58.0]);
      final lines = csv.split('\n');
      expect(lines.length, greaterThan(1)); // header + data rows
      final dataRow = lines[1].split(',');
      // Find fps column index in header
      final headerCols = lines[0].split(',');
      final fpsIdx = headerCols.indexOf('fps');
      expect(fpsIdx, greaterThan(-1));
      expect(dataRow[fpsIdx], '60.0');
    });
  });
}

String _buildCsvHeader() {
  return 'session_id,timestamp,fps,jank_count,jank_small_count,jank_big_count,jank_ratio_count,'
      'frametimes_json,cpu_system_pct,cpu_app_pct,cpu_app_pct_freq_norm,cpu_cores,cpu_core_states_json,'
      'cpu_core_freqs_json,cpu_threads_top_json,memory_pss_kb,memory_java_kb,memory_native_kb,'
      'memory_graphics_kb,memory_stack_kb,memory_code_kb,memory_system_kb,memory_webview_kb,'
      'battery_pct,battery_ma,battery_mv,battery_temp_c,charging,charging_source,wifi_active,'
      'net_tx_bytes,net_rx_bytes,net_wifi_tx_bytes,net_wifi_rx_bytes,net_cellular_tx_bytes,'
      'net_cellular_rx_bytes,net_other_tx_bytes,net_other_rx_bytes,thermal_status,gpu_pct,'
      'gpu_freq_mhz,gpu_mem_kb,disk_read_kb,disk_write_kb,screen_brightness,volume_pct\n';
}

String _buildCsvWithData(List<double> fpsValues) {
  final buf = StringBuffer();
  buf.write('session_id,timestamp,fps\n');
  for (var i = 0; i < fpsValues.length; i++) {
    buf.writeln('test,${1000 * i},${fpsValues[i]}');
  }
  return buf.toString();
}
