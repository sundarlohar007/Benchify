// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/screenshot_dao.dart';
import 'adb_service.dart';

/// Configuration for one screenshot size level (SS0-SS4).
class ScreenshotConfig {
  final String sizeId;
  final double scale;
  final int intervalSeconds;

  const ScreenshotConfig({
    required this.sizeId,
    required this.scale,
    required this.intervalSeconds,
  });

  /// Default 5-size config per UNIFIED-SPEC §5.12.
  static const defaults = [
    ScreenshotConfig(sizeId: 'SS0', scale: 1.0, intervalSeconds: 5),
    ScreenshotConfig(sizeId: 'SS1', scale: 0.5, intervalSeconds: 5),
    ScreenshotConfig(sizeId: 'SS2', scale: 0.25, intervalSeconds: 10),
    ScreenshotConfig(sizeId: 'SS3', scale: 0.125, intervalSeconds: 15),
    ScreenshotConfig(sizeId: 'SS4', scale: 0.0675, intervalSeconds: 30),
  ];
}

/// Result of a single screenshot capture.
class ScreenshotResult {
  final int timestamp;
  final List<String> filepaths;

  const ScreenshotResult({required this.timestamp, required this.filepaths});
}

/// Captures device screenshots via ADB, resizes them with the `image` package,
/// and saves as JPEG (B-016 real implementation).
///
/// Wirelessly-connected devices (WiFi ADB) auto-disable screenshots.
class ScreenshotService {
  final AdbService _adbService;
  final String _deviceSerial;
  final String _sessionId;
  final ScreenshotDao _screenshotDao;
  final List<ScreenshotConfig> _configs;
  final void Function(ScreenshotResult result)? onCaptured;

  String? _outputDir;
  bool _isWireless = false;
  final List<Timer> _timers = [];

  ScreenshotService({
    required AdbService adbService,
    required String deviceSerial,
    required String sessionId,
    required ScreenshotDao screenshotDao,
    List<ScreenshotConfig> configs = ScreenshotConfig.defaults,
    this.onCaptured,
  })  : _adbService = adbService,
        _deviceSerial = deviceSerial,
        _sessionId = sessionId,
        _screenshotDao = screenshotDao,
        _configs = configs;

  bool get isWireless => _isWireless;

  /// Initialize output directory. Call before [startAutoCapture].
  Future<void> init() async {
    final dataDir = await getApplicationDocumentsDirectory();
    _outputDir = p.join(dataDir.path, 'screenshots', _sessionId);
    await Directory(_outputDir!).create(recursive: true);

    // Detect wireless connection: serial contains colon = IP:port = WiFi ADB
    _isWireless = _deviceSerial.contains(':');
  }

  /// Start automatic screenshot capture at configured intervals.
  ///
  /// Fires one shared initial capture of all sizes, then each size's timer
  /// only fires that size at its own interval (avoids capture storms).
  void startAutoCapture() {
    if (_isWireless) return; // Auto-disabled over WiFi

    // One initial capture of all sizes (not once per config).
    unawaited(_capture());

    for (final config in _configs) {
      final timer = Timer.periodic(
        Duration(seconds: config.intervalSeconds),
        (_) => _capture(config: config),
      );
      _timers.add(timer);
    }
  }

  /// Stop all screenshot timers.
  void stop() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  /// Capture a single screenshot, resize to all enabled sizes, save to disk.
  Future<ScreenshotResult?> capture() async {
    if (_isWireless || _outputDir == null) return null;
    return _capture();
  }

  /// Capture screenshot(s). When [config] is null, capture all sizes once;
  /// when set, only that size.
  Future<ScreenshotResult?> _capture({ScreenshotConfig? config}) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filepaths = <String>[];
    final configsToCapture = config != null ? [config] : _configs;

    try {
      // Step 1: Get raw PNG from device (B-017 — uses resolved ADB path)
      final pngBytes = await _adbService.runShellCommandRaw(
        _deviceSerial,
        'exec-out screencap -p',
        timeout: const Duration(milliseconds: 3000),
      );
      if (pngBytes == null || pngBytes.isEmpty) return null;

      // Step 2: Decode PNG via `image` package (B-016)
      final decoded = img.decodePng(pngBytes);
      if (decoded == null) return null;
      final srcWidth = decoded.width;
      final srcHeight = decoded.height;
      if (srcWidth <= 0 || srcHeight <= 0) return null;

      // Step 3: For each selected size config, resize and save as JPEG
      final screenshots = <Screenshot>[];
      for (final cfg in configsToCapture) {
        final scaledW = (srcWidth * cfg.scale).round().clamp(1, srcWidth);
        final scaledH = (srcHeight * cfg.scale).round().clamp(1, srcHeight);

        final resized = (scaledW == srcWidth && scaledH == srcHeight)
            ? decoded
            : img.copyResize(
                decoded,
                width: scaledW,
                height: scaledH,
                interpolation: img.Interpolation.average,
              );
        final jpegBytes = Uint8List.fromList(
          img.encodeJpg(resized, quality: 50),
        );

        final filename = '${timestamp}_${cfg.sizeId}.jpg';
        final filepath = p.join(_outputDir!, filename);
        await File(filepath).writeAsBytes(jpegBytes);

        filepaths.add(filepath);
        screenshots.add(Screenshot(
          sessionId: _sessionId,
          timestamp: timestamp,
          filepath: filepath,
          sizeId: cfg.sizeId,
          widthPx: scaledW,
          heightPx: scaledH,
          fileSizeBytes: jpegBytes.length,
        ));
      }

      // Step 4: Batch insert to DB
      await _screenshotDao.batchInsert(screenshots);

      final result =
          ScreenshotResult(timestamp: timestamp, filepaths: filepaths);
      onCaptured?.call(result);
      return result;
    } catch (_) {
      // Silently skip failed captures — don't interrupt the session
      return null;
    }
  }
}
