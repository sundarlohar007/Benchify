// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

/// Debug mode flag — set via `--debug` command-line argument.
/// Stored as a Riverpod provider so all widgets can access it (D-16).
final debugModeProvider = StateProvider<bool>((ref) => false);

/// Whether the host platform is macOS. Used to conditionally enable
/// iOS video recording features (per D-18).
/// On non-macOS, iOS video UI is shown disabled with tooltip.
final isMacOSProvider = StateProvider<bool>((ref) => Platform.isMacOS);

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Parse --debug flag (D-16)
  final debugMode = args.contains('--debug');

  // Initialize window manager for custom title bar (D-11, §9.3)
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
}
