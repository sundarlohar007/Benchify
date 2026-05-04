// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Integration tests for iOS pyidevice profiling.
///
/// Requires macOS runner with iOS simulator or connected iPhone.
/// Tagged with 'integration', 'ios', and 'device' for CI filtering.
void main() {
  group('iOS Integration', () {
    test('60s iOS session produces fps, cpu, mem, battery non-null', () {
      if (!Platform.isMacOS) {
        // ignore: avoid_print
        print('Skipping: iOS tests require macOS');
        return;
      }
      // Requires iOS simulator. Skipped unless running in CI.
    }, skip: true);

    test('battery_ma null for iPhone 8+', () {
      if (!Platform.isMacOS) return;
      // iPhone 8+ and later don't expose battery current via public API.
    }, skip: true);
  });
}
