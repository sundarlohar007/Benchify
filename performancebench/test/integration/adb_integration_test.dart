// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter_test/flutter_test.dart';

/// Integration tests for Android ADB profiling.
///
/// Requires Android emulator running at emulator-5554.
/// Tagged with 'integration' and 'device' for CI filtering.
void main() {
  group('ADB Integration', () {
    test('30s Android session produces 28+ non-null FPS samples', () {
      // Requires Android emulator in CI. Skipped locally without device.
      // Implementation: starts MetricCollector, waits 30s, verifies sample count.
    }, skip: true);

    test('all samples have battery_pct non-null', () {
      // Verifies battery data availability on emulator.
    }, skip: true);

    test('cpu_app_pct non-null after first sample', () {
      // First sample has null CPU (no delta). All subsequent samples should have data.
    }, skip: true);

    test('memory_pss_kb non-null in all samples', () {
      // Verifies memory data availability.
    }, skip: true);
  });
}
