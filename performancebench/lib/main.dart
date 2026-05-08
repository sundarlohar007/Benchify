// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/services/error_handler.dart';

/// Debug mode flag — set via `--debug` command-line argument.
/// Stored as a Riverpod provider so all widgets can access it (D-16).
final debugModeProvider = StateProvider<bool>((ref) => false);

void main(List<String> args) {
  // Framework errors (build/render/layout). Without this, framework errors
  // are swallowed silently in release builds.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      // ignore: avoid_print
      print('FlutterError: ${details.exceptionAsString()}\n${details.stack}');
    }
    // TODO(audit S-19+ logging): also append to a crash log file once a
    // structured logging layer exists.
  };

  // Async / out-of-zone errors (Futures, Timers, isolates).
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Parse --debug flag (D-16) and propagate to the singleton ErrorHandler
    // so its first log obeys the flag. The Riverpod provider is also kept
    // for widget consumption.
    final debugMode = args.contains('--debug');
    ErrorHandler().setDebugMode(debugMode);

    // Initialise window manager for custom title bar (D-11, §9.3).
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(800, 600),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      skipTaskbar: false,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    runApp(
      ProviderScope(
        overrides: [
          debugModeProvider.overrideWith((ref) => debugMode),
        ],
        child: const App(),
      ),
    );
  }, (error, stack) {
    // ignore: avoid_print
    print('Uncaught zone error: $error\n$stack');
  });
}
