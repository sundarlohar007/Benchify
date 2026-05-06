// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import 'shared/theme.dart';

// =============================================================================
// Placeholder screen imports — all screens scaffolded per D-02 skeleton-first
// These are minimal ConsumerWidget stubs that will be filled in Task 3.
// =============================================================================
import 'features/device_list/device_list_screen.dart';
import 'features/app_picker/app_picker_screen.dart';
import 'features/active_session/active_session_screen.dart';
import 'features/session_history/history_screen.dart';
import 'features/session_detail/detail_screen.dart';
import 'features/comparison/comparison_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/injection/injection_screen.dart';

// =============================================================================
// Theme Mode Provider
// =============================================================================

enum ThemeModeOption { dark, light, highContrast, system }

final themeModeProvider =
    StateProvider<ThemeModeOption>((ref) => ThemeModeOption.dark);

// =============================================================================
// GoRouter Configuration
// =============================================================================

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'deviceList',
        builder: (context, state) => const DeviceListScreen(),
      ),
      GoRoute(
        path: '/app-picker/:deviceId',
        name: 'appPicker',
        builder: (context, state) {
          final deviceId = state.pathParameters['deviceId']!;
          return AppPickerScreen(deviceId: deviceId);
        },
      ),
      GoRoute(
        path: '/session/active/:sessionId',
        name: 'activeSession',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return ActiveSessionScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/session/:sessionId',
        name: 'sessionDetail',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return SessionDetailScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/compare',
        name: 'comparison',
        builder: (context, state) => const ComparisonScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/injection',
        name: 'injection',
        builder: (context, state) => const InjectionScreen(),
      ),
    ],
  );
});

// =============================================================================
// App Root
// =============================================================================

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    // Select ThemeData based on user preference (D-14)
    ThemeData theme;
    switch (themeMode) {
      case ThemeModeOption.dark:
        theme = darkTheme();
        break;
      case ThemeModeOption.light:
        theme = lightTheme();
        break;
      case ThemeModeOption.highContrast:
        theme = highContrastTheme();
        break;
      case ThemeModeOption.system:
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        theme = systemTheme(brightness: brightness);
    }

    return MaterialApp.router(
      title: 'PerformanceBench',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme(),
      themeMode: ThemeMode.dark, // Manual control via themeModeProvider
      routerConfig: router,
    );
  }
}

// =============================================================================
// Custom Title Bar Widget
// =============================================================================

/// VS Code-style custom title bar (UNIFIED-SPEC §9.3).
/// Windows: traffic lights on right, app name centered, menu inline.
/// macOS: native traffic lights preserved, app name centered, 28px height.
class CustomTitleBar extends ConsumerWidget {
  const CustomTitleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final isMacOS = Platform.isMacOS;
    final height = isMacOS ? 28.0 : 30.0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: height,
        color: colors.bgSidebar,
        child: Row(
          children: [
            if (isMacOS) const SizedBox(width: 80), // Traffic light space
            const Spacer(),
            Text(
              'PerformanceBench',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontFamily: monoFontFamily(),
              ),
            ),
            const Spacer(),
            if (!isMacOS) ...[
              const Spacer(),
              const Spacer(),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Status Bar Provider (D-17)
// =============================================================================

final statusBarTextProvider = StateProvider<String>((ref) => 'Ready');
final statusBarColorProvider =
    StateProvider<Color>((ref) => const Color(0xFF2D2D30));
