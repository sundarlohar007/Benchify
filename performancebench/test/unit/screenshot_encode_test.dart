// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Unit coverage for B-016 screenshot encode path (no ADB / no device).
void main() {
  test('PNG decode + JPEG encode round-trip produces real image bytes', () {
    // 8×8 red PNG
    final src = img.Image(width: 8, height: 8);
    for (final p in src) {
      p.r = 255;
      p.g = 0;
      p.b = 0;
      p.a = 255;
    }
    final pngBytes = Uint8List.fromList(img.encodePng(src));

    final decoded = img.decodePng(pngBytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 8);
    expect(decoded.height, 8);

    final resized = img.copyResize(
      decoded,
      width: 4,
      height: 4,
      interpolation: img.Interpolation.average,
    );
    final jpeg = img.encodeJpg(resized, quality: 50);

    expect(jpeg.length, greaterThan(32));
    // JPEG SOI marker
    expect(jpeg[0], 0xFF);
    expect(jpeg[1], 0xD8);

    final roundTrip = img.decodeJpg(Uint8List.fromList(jpeg));
    expect(roundTrip, isNotNull);
    expect(roundTrip!.width, 4);
    expect(roundTrip.height, 4);
  });
}
