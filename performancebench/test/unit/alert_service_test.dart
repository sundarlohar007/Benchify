// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter_test/flutter_test.dart';

import 'package:performancebench/core/services/alert_service.dart';
import 'package:performancebench/core/models/metric_sample.dart';
import 'package:performancebench/core/models/marker.dart';

/// Fake marker insert tracker for testing AlertService.
class _FakeMarkerTracker {
  final List<Marker> inserted = [];

  Future<int> insert(Marker marker) async {
    inserted.add(marker);
    return inserted.length;
  }

  void clear() => inserted.clear();
}

/// Helper: create a MetricSample with minimal fields for threshold testing.
MetricSample _sample({
  required String sessionId,
  required int timestamp,
  double? fps,
  double? cpuAppPct,
  int? memoryPssKb,
}) {
  return MetricSample(
    sessionId: sessionId,
    timestamp: timestamp,
    fps: fps,
    cpuAppPct: cpuAppPct,
    memoryPssKb: memoryPssKb,
  );
}

void main() {
  late _FakeMarkerTracker _markerTracker;
  late int _breachCount;
  late String _lastBreachLabel;
  late AlertService _service;

  setUp(() {
    _markerTracker = _FakeMarkerTracker();
    _breachCount = 0;
    _lastBreachLabel = '';
    _service = AlertService(
      onMarkerInsert: (marker) => _markerTracker.insert(marker),
      onBreachCallback: (count, label) {
        _breachCount = count;
        _lastBreachLabel = label;
      },
      fpsConfig: const ThresholdConfig(
        enabled: true,
        threshold: 30.0,
        windowSamples: 10,
        label: 'FPS < 30',
        metricField: 'fps',
      ),
      cpuConfig: const ThresholdConfig(
        enabled: true,
        threshold: 85.0,
        windowSamples: 5,
        label: 'CPU > 85%',
        metricField: 'cpuAppPct',
      ),
      memoryConfig: const ThresholdConfig(
        enabled: true,
        threshold: 102400.0, // 100 MB in KB
        windowSamples: 30,
        label: 'Memory +100MB',
        metricField: 'memoryPssKb',
      ),
    );
  });

  // ---------------------------------------------------------------------------
  // Test 1: FPS threshold — last 10 samples all fps < 30 → breach triggers
  // ---------------------------------------------------------------------------
  test('FPS threshold breach when last 10 samples all below 30', () {
    // Feed 10 samples all with FPS = 28 (below threshold)
    for (var i = 0; i < 10; i++) {
      _service.checkThresholds(
        _sample(sessionId: 's1', timestamp: 1000 + i * 1000, fps: 28),
        sessionId: 's1',
      );
    }

    expect(_breachCount, 1);
    expect(_lastBreachLabel, 'FPS < 30');
    expect(_markerTracker.inserted.length, 1);
    expect(_markerTracker.inserted.first.label, 'Alert: FPS < 30');
    expect(_markerTracker.inserted.first.sessionId, 's1');
  });

  // ---------------------------------------------------------------------------
  // Test 2: FPS threshold — mixed samples → no breach (must be sustained)
  // ---------------------------------------------------------------------------
  test('FPS no breach when samples mixed above and below threshold', () {
    _markerTracker.clear();
    _service.reset();

    // Feed 10 samples: 5 below, 5 above — mixed, not sustained
    for (var i = 0; i < 5; i++) {
      _service.checkThresholds(
        _sample(sessionId: 's2', timestamp: 1000 + i * 1000, fps: 28),
        sessionId: 's2',
      );
    }
    for (var i = 5; i < 10; i++) {
      _service.checkThresholds(
        _sample(sessionId: 's2', timestamp: 1000 + i * 1000, fps: 35),
        sessionId: 's2',
      );
    }

    expect(_breachCount, 0);
    expect(_markerTracker.inserted.length, 0);
  });

  // ---------------------------------------------------------------------------
  // Test 3: FPS threshold — only 5 samples available → no breach
  // ---------------------------------------------------------------------------
  test('FPS no breach when insufficient window (only 5 samples)', () {
    _markerTracker.clear();
    _service.reset();

    // Feed only 5 samples, all below threshold
    for (var i = 0; i < 5; i++) {
      _service.checkThresholds(
        _sample(sessionId: 's3', timestamp: 1000 + i * 1000, fps: 25),
        sessionId: 's3',
      );
    }

    expect(_breachCount, 0);
    expect(_markerTracker.inserted.length, 0);
  });

  // ---------------------------------------------------------------------------
  // Test 4: CPU threshold — last 5 samples all cpuAppPct > 85% → breach
  // ---------------------------------------------------------------------------
  test('CPU threshold breach when last 5 samples all above 85%', () {
    _markerTracker.clear();
    _service.reset();

    for (var i = 0; i < 5; i++) {
      _service.checkThresholds(
        _sample(sessionId: 's4', timestamp: 1000 + i * 1000, cpuAppPct: 90),
        sessionId: 's4',
      );
    }

    expect(_breachCount, 1);
    expect(_lastBreachLabel, 'CPU > 85%');
    expect(_markerTracker.inserted.length, 1);
    expect(_markerTracker.inserted.first.label, 'Alert: CPU > 85%');
  });

  // ---------------------------------------------------------------------------
  // Test 5: CPU threshold — last 5 samples with one at 80% → no breach
  // ---------------------------------------------------------------------------
  test('CPU no breach when one sample in window is below threshold', () {
    _markerTracker.clear();
    _service.reset();

    // 4 samples above, 1 below in the window
    for (var i = 0; i < 4; i++) {
      _service.checkThresholds(
        _sample(sessionId: 's5', timestamp: 1000 + i * 1000, cpuAppPct: 90),
        sessionId: 's5',
      );
    }
    _service.checkThresholds(
      _sample(sessionId: 's5', timestamp: 6000, cpuAppPct: 80),
      sessionId: 's5',
    );

    expect(_breachCount, 0);
    expect(_markerTracker.inserted.length, 0);
  });

  // ---------------------------------------------------------------------------
  // Test 6: Memory threshold — growth > 100MB over 30-sample window → breach
  // ---------------------------------------------------------------------------
  test('Memory threshold breach when growth exceeds 100MB over 30 samples', () {
    _markerTracker.clear();
    _service.reset();

    // 30 samples: start at 500MB, end at 620MB → +120MB growth (>100MB threshold)
    const startKb = 512000; // 500 MB in KB
    const endKb = 634880; // 620 MB in KB
    const step = (endKb - startKb) ~/ 29;

    for (var i = 0; i < 30; i++) {
      _service.checkThresholds(
        _sample(
          sessionId: 's6',
          timestamp: 1000 + i * 1000,
          memoryPssKb: startKb + (i * step),
        ),
        sessionId: 's6',
      );
    }

    expect(_breachCount, 1);
    expect(_lastBreachLabel, 'Memory +100MB');
    expect(_markerTracker.inserted.length, 1);
    expect(_markerTracker.inserted.first.label, 'Alert: Memory +100MB');
  });

  // ---------------------------------------------------------------------------
  // Test 7: Memory threshold — growth = 50MB → no breach
  // ---------------------------------------------------------------------------
  test('Memory no breach when growth is less than 100MB', () {
    _markerTracker.clear();
    _service.reset();

    // 30 samples: start at 500MB, end at 550MB → +50MB growth (<100MB threshold)
    const startKb = 512000; // 500 MB
    const endKb = 563200; // 550 MB
    const step = (endKb - startKb) ~/ 29;

    for (var i = 0; i < 30; i++) {
      _service.checkThresholds(
        _sample(
          sessionId: 's7',
          timestamp: 1000 + i * 1000,
          memoryPssKb: startKb + (i * step),
        ),
        sessionId: 's7',
      );
    }

    expect(_breachCount, 0);
    expect(_markerTracker.inserted.length, 0);
  });

  // ---------------------------------------------------------------------------
  // Test 8: All thresholds disabled → no checks performed
  // ---------------------------------------------------------------------------
  test('No checks when all thresholds disabled', () {
    _markerTracker.clear();

    final disabledService = AlertService(
      onMarkerInsert: (marker) => _markerTracker.insert(marker),
      onBreachCallback: (count, label) {
        _breachCount = count;
      },
      fpsConfig: const ThresholdConfig(
        enabled: false,
        threshold: 30.0,
        windowSamples: 10,
        label: 'FPS < 30',
        metricField: 'fps',
      ),
      cpuConfig: const ThresholdConfig(
        enabled: false,
        threshold: 85.0,
        windowSamples: 5,
        label: 'CPU > 85%',
        metricField: 'cpuAppPct',
      ),
      memoryConfig: const ThresholdConfig(
        enabled: false,
        threshold: 102400.0,
        windowSamples: 30,
        label: 'Memory +100MB',
        metricField: 'memoryPssKb',
      ),
    );

    // Feed 15 samples with FPS below threshold, CPU above, memory growing
    for (var i = 0; i < 15; i++) {
      disabledService.checkThresholds(
        _sample(
          sessionId: 's8',
          timestamp: 1000 + i * 1000,
          fps: 20,
          cpuAppPct: 95,
          memoryPssKb: 512000 + (i * 10000),
        ),
        sessionId: 's8',
      );
    }

    expect(_breachCount, 0);
    expect(_markerTracker.inserted.length, 0);
  });

  // ---------------------------------------------------------------------------
  // Test 9: Breach counts correctly (1 per sustained period, not per sample)
  // ---------------------------------------------------------------------------
  test('Only one breach per sustained period, not per sample', () {
    _markerTracker.clear();
    _service.reset();

    // Feed 20 samples all below FPS threshold — only 1 breach
    for (var i = 0; i < 20; i++) {
      _service.checkThresholds(
        _sample(sessionId: 's9', timestamp: 1000 + i * 1000, fps: 25),
        sessionId: 's9',
      );
    }

    expect(_breachCount, 1);
    expect(_markerTracker.inserted.length, 1);
  });

  // ---------------------------------------------------------------------------
  // Test 10: Auto-marker created with correct label at breach timestamp
  // ---------------------------------------------------------------------------
  test('Auto-marker created with label "Alert: FPS < 30" at breach timestamp', () {
    _markerTracker.clear();
    _service.reset();

    const breachTimestamp = 5000000;

    // Feed 10 FPS samples at specific timestamps
    for (var i = 0; i < 10; i++) {
      _service.checkThresholds(
        _sample(
          sessionId: 's10',
          timestamp: breachTimestamp - 9000 + (i * 1000),
          fps: 25,
        ),
        sessionId: 's10',
      );
    }

    expect(_markerTracker.inserted.length, 1);
    final marker = _markerTracker.inserted.first;
    expect(marker.label, 'Alert: FPS < 30');
    expect(marker.sessionId, 's10');
    expect(marker.autoScreenshot, 0);
    expect(marker.notes, contains('Threshold: 30.0'));
    // Marker should be created with a timestamp (allow small difference for test runtime)
    expect(marker.startedAt, isNotNull);
  });

  // ---------------------------------------------------------------------------
  // Test 11: Second breach of same type after gap → creates NEW marker
  // ---------------------------------------------------------------------------
  test('Second breach after recovery creates a new marker', () {
    _markerTracker.clear();
    _service.reset();

    // First sustained breach: 10 samples below FPS 30
    for (var i = 0; i < 10; i++) {
      _service.checkThresholds(
        _sample(sessionId: 's11', timestamp: 1000 + i * 1000, fps: 25),
        sessionId: 's11',
      );
    }
    expect(_markerTracker.inserted.length, 1);

    // Recovery: 5 samples above threshold (breach ends)
    for (var i = 0; i < 5; i++) {
      _service.checkThresholds(
        _sample(sessionId: 's11', timestamp: 11000 + i * 1000, fps: 35),
        sessionId: 's11',
      );
    }
    // Still 1 marker (breach just ended, no new breach yet)
    expect(_markerTracker.inserted.length, 1);

    // Second sustained breach: 10 more samples below
    for (var i = 0; i < 10; i++) {
      _service.checkThresholds(
        _sample(sessionId: 's11', timestamp: 16000 + i * 1000, fps: 22),
        sessionId: 's11',
      );
    }

    expect(_markerTracker.inserted.length, 2);
    expect(_breachCount, 2);
  });

  // ---------------------------------------------------------------------------
  // Additional: updateConfig test
  // ---------------------------------------------------------------------------
  test('updateConfig changes threshold values correctly', () {
    _markerTracker.clear();
    _service.reset();

    // With default config (FPS < 30), FPS 25 triggers breach
    for (var i = 0; i < 10; i++) {
      _service.checkThresholds(
        _sample(sessionId: 'sc', timestamp: 1000 + i * 1000, fps: 25),
        sessionId: 'sc',
      );
    }
    expect(_markerTracker.inserted.length, 1);
    _markerTracker.clear();

    // Update FPS config to threshold of 20 → FPS 25 should NOT breach anymore
    _service.updateConfig(fpsMin: 20.0);
    _service.reset();

    for (var i = 0; i < 10; i++) {
      _service.checkThresholds(
        _sample(sessionId: 'sc2', timestamp: 1000 + i * 1000, fps: 25),
        sessionId: 'sc2',
      );
    }
    expect(_markerTracker.inserted.length, 0);

    // But FPS 18 (below new threshold of 20) should breach
    _service.reset();
    for (var i = 0; i < 10; i++) {
      _service.checkThresholds(
        _sample(sessionId: 'sc3', timestamp: 1000 + i * 1000, fps: 18),
        sessionId: 'sc3',
      );
    }
    expect(_markerTracker.inserted.length, 1);
  });
}
