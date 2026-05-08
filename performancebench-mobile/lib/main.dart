// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  // Two-layer guard mirroring the desktop side (B-002): catch framework
  // errors via FlutterError.onError + async / out-of-zone errors via
  // runZonedGuarded so a single bad await doesn't kill the app silently.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      // ignore: avoid_print
      print('FlutterError: ${details.exceptionAsString()}\n${details.stack}');
    }
  };

  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const BenchifyMobileApp());
  }, (error, stack) {
    // ignore: avoid_print
    print('Uncaught zone error: $error\n$stack');
  });
}
