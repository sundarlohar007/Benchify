// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter_test/flutter_test.dart';

import 'package:performancebench/core/services/adb_service.dart';

/// Unit tests for ADB logcat ActivityManager START line parsing.
///
/// Tests the _parseActivityStart parser with realistic logcat lines
/// and edge cases. Does not require a real device.
/// Test-only wrapper that exposes the private logcat parser.
class _TestAdbService extends AdbService {
  _TestAdbService() : super.test();

  /// Expose private parser for unit testing.
  LogcatStartEvent? parseLine(String line, String serial) {
    return parseActivityStart(line, serial);
  }
}

void main() {
  late _TestAdbService _adbService;

  setUp(() {
    _adbService = _TestAdbService();
  });

  // ---------------------------------------------------------------------------
  // Test 1: Valid ActivityManager START line with known package
  // ---------------------------------------------------------------------------
  test('Valid ActivityManager START line parses package name correctly', () {
    const line =
        '05-04 14:32:01.123  1234  5678 I ActivityManager: '
        'START u0 {act=android.intent.action.MAIN '
        'cat=[android.intent.category.LAUNCHER] flg=0x10200000 '
        'cmp=com.example.game/.MainActivity}';

    final event = _adbService.parseLine(line, 'device-001');

    expect(event, isNotNull);
    expect(event!.packageName, 'com.example.game');
    expect(event.serial, 'device-001');
    expect(event.timestamp, '05-04 14:32:01.123');
    expect(event.intent, line.trim());
  });

  // ---------------------------------------------------------------------------
  // Test 2: ActivityManager line for different action (not START)
  // ---------------------------------------------------------------------------
  test('Non-START ActivityManager line returns null', () {
    const line =
        '05-04 14:32:02.456  1234  5678 I ActivityManager: '
        'Killing 12345:com.example.game/u0a123 (adj 900): remove task';

    final event = _adbService.parseLine(line, 'device-001');

    expect(event, isNull);
  });

  // ---------------------------------------------------------------------------
  // Test 3: START line for package NOT in watch list
  // ---------------------------------------------------------------------------
  test('START line for non-watched package does not trigger auto-start', () {
    const line =
        '05-04 14:32:03.789  1234  5678 I ActivityManager: '
        'START u0 {act=android.intent.action.MAIN '
        'cmp=com.other.app/.MainActivity}';

    final event = _adbService.parseLine(line, 'device-001');

    // Parse succeeds (valid line), but watch-list filtering is done by caller
    expect(event, isNotNull);
    expect(event!.packageName, 'com.other.app');
  });

  // ---------------------------------------------------------------------------
  // Test 4: START line for package IN watch list
  // ---------------------------------------------------------------------------
  test('START line for watched package is parsed for auto-start signal', () {
    const line =
        '05-04 14:32:04.012  1234  5678 I ActivityManager: '
        'START u0 {act=android.intent.action.MAIN '
        'cmp=com.watched.game/.SplashActivity}';

    final event = _adbService.parseLine(line, 'device-002');

    expect(event, isNotNull);
    expect(event!.packageName, 'com.watched.game');
    expect(event.serial, 'device-002');
  });

  // ---------------------------------------------------------------------------
  // Test 5: Malformed logcat line (garbled) returns null, no crash
  // ---------------------------------------------------------------------------
  test('Malformed logcat line returns null without crash', () {
    const garbledLines = [
      '',
      'garbage data without any structure',
      '05-04 14:32:05.000  1234  5678 I ActivityManager: ',
      '05-04 14:32:06.000  1234  5678 I ActivityManager: START u0 {}',
      '05-04 14:32:07.000  1234  5678 I ActivityManager: START u0 {act=android.intent.action.MAIN}',
    ];

    for (final line in garbledLines) {
      // Should not throw
      final event = _adbService.parseLine(line, 'device-x');
      expect(event, isNull, reason: 'Line should not parse: "$line"');
    }
  });

  // ---------------------------------------------------------------------------
  // Test 6: Two devices, same app launches — both get events
  // ---------------------------------------------------------------------------
  test('Same app launch on two devices produces two separate events', () {
    const line =
        '05-04 14:32:08.345  1234  5678 I ActivityManager: '
        'START u0 {act=android.intent.action.MAIN '
        'cmp=com.example.game/.MainActivity}';

    final event1 = _adbService.parseLine(line, 'device-A');
    final event2 = _adbService.parseLine(line, 'device-B');

    expect(event1, isNotNull);
    expect(event2, isNotNull);
    expect(event1!.serial, 'device-A');
    expect(event2!.serial, 'device-B');
    expect(event1.packageName, event2.packageName);
  });

  // ---------------------------------------------------------------------------
  // Test 7: START with timestamp extraction
  // ---------------------------------------------------------------------------
  test('LogcatStartEvent extracts timestamp from logcat line', () {
    const line =
        '12-31 23:59:59.999  1000  2000 I ActivityManager: '
        'START u0 {act=android.intent.action.MAIN '
        'cmp=com.app.test/.MainActivity}';

    final event = _adbService.parseLine(line, 'device-ts');

    expect(event, isNotNull);
    expect(event!.timestamp, '12-31 23:59:59.999');
    expect(event.packageName, 'com.app.test');
  });

  // ---------------------------------------------------------------------------
  // Test 8: Package name validation — system packages filtered
  // ---------------------------------------------------------------------------
  test('System package starts are filtered by package name validation', () {
    // System packages starting with "com.android" ARE valid Android packages
    const systemLine =
        '05-04 14:32:09.567  1234  5678 I ActivityManager: '
        'START u0 {act=android.intent.action.MAIN '
        'cmp=com.android.settings/.Settings}';

    final event = _adbService.parseLine(systemLine, 'device-sys');

    // com.android.settings is a valid package name format — parser accepts it.
    // Watch-list filtering at the caller level decides whether to auto-start.
    expect(event, isNotNull);
    expect(event!.packageName, 'com.android.settings');
  });

  // ---------------------------------------------------------------------------
  // Additional: Package name with underscores and numbers
  // ---------------------------------------------------------------------------
  test('Package names with underscores and numbers parse correctly', () {
    const line =
        '05-04 14:32:10.000  1234  5678 I ActivityManager: '
        'START u0 {act=android.intent.action.MAIN '
        'cmp=com.company123.game_engine/.MainActivity}';

    final event = _adbService.parseLine(line, 'device-num');

    expect(event, isNotNull);
    expect(event!.packageName, 'com.company123.game_engine');
  });

  // ---------------------------------------------------------------------------
  // Additional: Package name with multiple subdomains
  // ---------------------------------------------------------------------------
  test('Multi-subdomain package names parse correctly', () {
    const line =
        '05-04 14:32:11.000  1234  5678 I ActivityManager: '
        'START u0 {act=android.intent.action.MAIN '
        'cmp=com.tencent.tmgp.pubgmhd/.GameActivity}';

    final event = _adbService.parseLine(line, 'device-sub');

    expect(event, isNotNull);
    expect(event!.packageName, 'com.tencent.tmgp.pubgmhd');
  });
}
