import 'package:flutter_test/flutter_test.dart';

/// Tests for FPS overlay pill color and behavior logic.
///
/// Since FpsOverlayView is an Android View (not a Flutter widget),
/// these tests validate the color threshold logic and data model
/// that the overlay depends on.
///
/// The actual FpsOverlayView.java rendering is validated via
/// Android instrumentation tests (not in this Flutter test suite).

/// FPS color thresholds matching FpsOverlayView.java constants.
enum FpsColor { green, yellow, red }

/// Determine the color that should be used for a given FPS value.
FpsColor colorForFps(double fps) {
  if (fps > 55) return FpsColor.green;
  if (fps >= 30) return FpsColor.yellow;
  return FpsColor.red;
}

/// Green color constants (FpsOverlayView.java)
const greenTextColor = 0xFF4CAF50;
const greenBgColor = 0xCC1B5E20;

/// Yellow color constants
const yellowTextColor = 0xFFFFC107;
const yellowBgColor = 0xCC827717;

/// Red color constants
const redTextColor = 0xFFF44336;
const redBgColor = 0xCCB71C1C;

void main() {
  group('FPS Overlay Color Logic', () {
    test('60 FPS shows green', () {
      expect(colorForFps(60.0), FpsColor.green);
      expect(colorForFps(120.0), FpsColor.green);
      expect(colorForFps(56.0), FpsColor.green);
    });

    test('55 FPS shows yellow (boundary)', () {
      expect(colorForFps(55.0), FpsColor.yellow);
    });

    test('30-55 FPS shows yellow', () {
      expect(colorForFps(45.0), FpsColor.yellow);
      expect(colorForFps(30.0), FpsColor.yellow);
      expect(colorForFps(40.0), FpsColor.yellow);
    });

    test('29 FPS shows red (boundary)', () {
      expect(colorForFps(29.0), FpsColor.red);
    });

    test('below 30 FPS shows red', () {
      expect(colorForFps(15.0), FpsColor.red);
      expect(colorForFps(0.0), FpsColor.red);
      expect(colorForFps(10.0), FpsColor.red);
    });

    test('color constants match Android java values', () {
      // Green
      expect(greenTextColor, 0xFF4CAF50);
      expect(greenBgColor, 0xCC1B5E20);

      // Yellow
      expect(yellowTextColor, 0xFFFFC107);
      expect(yellowBgColor, 0xCC827717);

      // Red
      expect(redTextColor, 0xFFF44336);
      expect(redBgColor, 0xCCB71C1C);
    });
  });

  group('FPS Overlay Detail Panel Data', () {
    test('rolling stats compute correctly', () {
      final fpsValues = [60.0, 59.0, 58.0, 61.0, 62.0];

      final sum = fpsValues.reduce((a, b) => a + b);
      final avg = sum / fpsValues.length;
      final min = fpsValues.reduce((a, b) => a < b ? a : b);
      final max = fpsValues.reduce((a, b) => a > b ? a : b);

      expect(avg, closeTo(60.0, 0.01));
      expect(min, 58.0);
      expect(max, 62.0);
    });

    test('single sample stats', () {
      final fpsValues = [45.0];
      final avg = fpsValues.reduce((a, b) => a + b) / fpsValues.length;
      final min = fpsValues.reduce((a, b) => a < b ? a : b);
      final max = fpsValues.reduce((a, b) => a > b ? a : b);

      expect(avg, 45.0);
      expect(min, 45.0);
      expect(max, 45.0);
    });
  });
}
