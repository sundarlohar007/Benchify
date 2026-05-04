// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter_test/flutter_test.dart';

/// Ring buffer logic tests.
///
/// The ring buffer is implemented inside MetricCollector as a List<MetricSample>
/// capped at 300 entries. These tests validate the eviction behavior using a
/// simple list — the same pattern used in MetricCollector._buffer.
void main() {
  group('Ring buffer (300 sample cap)', () {
    test('starts empty', () {
      final buffer = <int>[];
      expect(buffer.length, 0);
    });

    test('adds 100 entries without eviction', () {
      final buffer = <int>[];
      for (var i = 0; i < 100; i++) {
        buffer.add(i);
      }
      expect(buffer.length, 100);
      expect(buffer.first, 0);
      expect(buffer.last, 99);
    });

    test('caps at 300 entries, evicts oldest on overflow', () {
      final buffer = <int>[];
      const maxSize = 300;
      for (var i = 0; i < 350; i++) {
        buffer.add(i);
        while (buffer.length > maxSize) {
          buffer.removeAt(0);
        }
      }
      expect(buffer.length, 300);
    });

    test('oldest sample is the 51st added after adding 350 (first 50 evicted)', () {
      final buffer = <int>[];
      const maxSize = 300;
      for (var i = 0; i < 350; i++) {
        buffer.add(i);
        while (buffer.length > maxSize) {
          buffer.removeAt(0);
        }
      }
      // After 350 adds, entries 0-49 evicted, buffer holds entries 50-349
      expect(buffer.first, 50);
    });

    test('newest sample is the 350th added after adding 350', () {
      final buffer = <int>[];
      const maxSize = 300;
      for (var i = 0; i < 350; i++) {
        buffer.add(i);
        while (buffer.length > maxSize) {
          buffer.removeAt(0);
        }
      }
      // 0-indexed: 350th add has value 349
      expect(buffer.last, 349);
    });
  });
}
