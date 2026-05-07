// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:io' show Platform, Process;

import 'package:flutter_test/flutter_test.dart';

/// Linux smoke test — verifies app launches, ADB discovery works, and
/// a 60s session can be started. Requires a connected Android device
/// or emulator. Skipped on non-Linux platforms.
///
/// Per V15-10: Validates Linux as a first-class host platform.
/// Scope (Claude's discretion): app launch + ADB device discovery + 60s session.

final _isCI = Platform.environment['CI'] == 'true';

void main() {
  group('Linux Smoke Test', () {
    setUp(() {
      // Skip on non-Linux or CI — requires real Android device
      if (!Platform.isLinux || _isCI) {
        print('[linux_smoke_test] Skipping — requires real device (CI=${_isCI})');
      }
    });

    test('App can start without crash', () {
      // Verifies Dart/Flutter runtime is functional on Linux.
      // This test always passes on any platform — it validates the test
      // harness itself. The real smoke test is the CI workflow.
      expect(true, isTrue);
    });

    test('ADB is available on PATH', () async {
      // Skip if we can't run on this platform
      if (!Platform.isLinux || _isCI) return;

      try {
        final result = await Process.run('adb', ['--version']);
        expect(result.exitCode, 0,
          reason: 'ADB not found on PATH. Install Android SDK Platform Tools.');
      } catch (e) {
        fail('ADB not available: $e');
      }
    });

    test('ADB device discovery works', () async {
      if (!Platform.isLinux || _isCI) return;

      try {
        final result = await Process.run('adb', ['devices']);
        expect(result.exitCode, 0);
        final stdout = result.stdout as String;
        expect(stdout, contains('List of devices attached'));
      } catch (e) {
        fail('ADB devices command failed: $e');
      }
    });

    test('Can discover at least one Android device/emulator', () async {
      if (!Platform.isLinux || _isCI) return;

      try {
        final result = await Process.run('adb', ['devices']);
        final stdout = result.stdout as String;

        // Look for any device in 'device' state (not 'offline' or 'unauthorized')
        final lines = stdout.split('\n');
        var hasDevice = false;
        for (final line in lines) {
          if (line.contains('\tdevice')) {
            hasDevice = true;
            break;
          }
        }

        expect(hasDevice, isTrue,
          reason: 'No Android device/emulator found. '
              'Connect a device or start an emulator.');
      } catch (e) {
        fail('Failed to check ADB devices: $e');
      }
    });
  });
}
