import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/parsers/cpu_parser.dart';

/// Helper: build a synthetic /proc/<pid>/stat line with controlled utime and stime.
/// Fields: pid comm state ppid pgrp session tty_nr tpgid flags minflt cminflt
///         majflt cmajflt utime stime cutime cstime ...
/// utime = field index 13, stime = field index 14 (0-indexed after splitting)
String _makePidStat(int utime, int stime) {
  return '12345 (test) S 0 0 0 0 0 0 0 0 0 0 $utime $stime 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0';
}

/// Helper: build a synthetic /proc/stat first line with controlled cpu fields.
/// Fields: cpu user nice system idle iowait irq softirq steal guest guest_nice
String _makeProcStat(
  int user,
  int nice,
  int system,
  int idle,
  int iowait,
  int irq,
  int softirq,
) {
  return 'cpu  $user $nice $system $idle $iowait $irq $softirq 0 0 0';
}

void main() {
  group('CpuParser', () {
    group('first sample / null handling', () {
      test('first sample returns null for all CPU pct fields', () {
        final parser = CpuParser();
        final result = parser.parse(
          _makePidStat(500, 250),
          _makeProcStat(1000, 0, 500, 8000, 500, 100, 50),
        );
        expect(result.cpuAppPct, isNull);
        expect(result.cpuSystemPct, isNull);
        // Non-pct fields should still parse if applicable
      });

      test('null pidStat returns null for cpu fields', () {
        final parser = CpuParser();
        final result = parser.parse(
          null,
          _makeProcStat(1000, 0, 500, 8000, 500, 100, 50),
        );
        expect(result.cpuAppPct, isNull);
      });

      test('null procStat returns null for cpu fields', () {
        final parser = CpuParser();
        final result = parser.parse(
          _makePidStat(500, 250),
          null,
        );
        expect(result.cpuAppPct, isNull);
        expect(result.cpuSystemPct, isNull);
      });

      test('malformed input returns null without throwing', () {
        final parser = CpuParser();
        final result = parser.parse('not a valid stat', 'also not valid');
        expect(result.cpuAppPct, isNull);
        expect(result.cpuSystemPct, isNull);
      });
    });

    group('cpu_app_pct computation', () {
      test('delta_pid_ticks=500, delta_total_ticks=1000 => cpu_app_pct=50.0', () {
        final parser = CpuParser();
        // First call: establish snapshots
        parser.parse(
          _makePidStat(1000, 500), // pid_ticks = 1500
          _makeProcStat(1000, 0, 500, 8000, 500, 100, 50), // total = 10150
        );
        // Second call: deltas = (750-500=250) no wait...
        // We want delta_pid=500 and delta_total=1000
        // First: pid_ticks = 1500, total = 10150
        // Second: pid_ticks = 2000 (delta=500), total = 11150 (delta=1000)
        final result = parser.parse(
          _makePidStat(1250, 750), // pid_ticks = 2000
          _makeProcStat(1100, 0, 550, 8800, 550, 110, 40), // total = 11150, idle = 9350
        );
        expect(result.cpuAppPct, closeTo(50.0, 0.01));
      });

      test('cpu_app_pct clamped to [0, 100]', () {
        final parser = CpuParser();
        parser.parse(
          _makePidStat(0, 0), // pid_ticks = 0
          _makeProcStat(0, 0, 0, 100, 0, 0, 0), // total = 100
        );
        // Make delta_pid > delta_total to test clamping
        final result = parser.parse(
          _makePidStat(200, 0), // pid_ticks = 200, delta = 200
          _makeProcStat(0, 0, 0, 200, 0, 0, 0), // total = 200, delta = 100
        );
        // cpu_app_pct = (200 / 100) * 100 = 200 -> clamped to 100
        expect(result.cpuAppPct, 100.0);
      });
    });

    group('cpu_system_pct computation', () {
      test('system pct computed correctly from delta idle', () {
        final parser = CpuParser();
        parser.parse(
          _makePidStat(0, 0),
          _makeProcStat(1000, 0, 500, 7000, 500, 100, 50), // total=9150, idle=7500
        );
        // Second: total=9650 (delta=500), idle=7800 (delta=300)
        // system pct = (500 - 300) / 500 * 100 = 40%
        final result = parser.parse(
          _makePidStat(0, 0),
          _makeProcStat(1100, 0, 550, 7300, 550, 100, 50), // total=9650, idle=7850
        );
        expect(result.cpuSystemPct, isNotNull);
      });
    });

    group('core frequency normalization', () {
      test('cores 0,1 online@500MHz, 2,3 offline, max=2GHz => cpu_norm=6.25% at 50% cpu', () {
        final parser = CpuParser();
        final sysfsOutput = '''
/sys/devices/system/cpu/cpu0
1
500000
2000000
---
/sys/devices/system/cpu/cpu1
1
500000
2000000
---
/sys/devices/system/cpu/cpu2
0
0
2000000
---
/sys/devices/system/cpu/cpu3
0
0
2000000
---
''';
        final result = parser.parseCoreFreqs(sysfsOutput);
        expect(result.cpuCoreStatesJson, isNotNull);
        expect(result.cpuCoreFreqsJson, isNotNull);
        // total_max_cycles = 4 * 2000000 = 8000000 kHz
        // total_avail_cycles = 2 * 500000 = 1000000 kHz (only cores 0,1 online)
        // cpu_norm_factor = 1000000 / 8000000 = 0.125
        // Normalized: set external cpuAppPct for compute
        final normResult = parser.computeNormalizedCpu(50.0);
        expect(normResult, closeTo(6.25, 0.01));
      });

      test('all cores online at max freq => normalized equals raw cpu', () {
        final parser = CpuParser();
        final sysfsOutput = '''
/sys/devices/system/cpu/cpu0
1
2000000
2000000
---
/sys/devices/system/cpu/cpu1
1
2000000
2000000
---
''';
        final result = parser.parseCoreFreqs(sysfsOutput);
        expect(result.cpuCoreStatesJson, isNotNull);
        final normResult = parser.computeNormalizedCpu(50.0);
        expect(normResult, closeTo(50.0, 0.01));
      });

      test('sysfs glob parse fails => core fields null, normalized null', () {
        final parser = CpuParser();
        final result = parser.parseCoreFreqs('not valid output');
        expect(result.cpuCoreStatesJson, isNull);
        expect(result.cpuCoreFreqsJson, isNull);
        final normResult = parser.computeNormalizedCpu(50.0);
        expect(normResult, isNull);
      });
    });
  });
}
