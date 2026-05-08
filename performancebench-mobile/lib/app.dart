// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

import 'routes/app_router.dart';
import 'services/api_service.dart';

class BenchifyMobileApp extends StatefulWidget {
  const BenchifyMobileApp({super.key});

  @override
  State<BenchifyMobileApp> createState() => _BenchifyMobileAppState();
}

class _BenchifyMobileAppState extends State<BenchifyMobileApp> {
  bool _loaded = false;
  GoRouterHandle? _routerHandle;

  @override
  void initState() {
    super.initState();
    _loadApiService();
  }

  Future<void> _loadApiService() async {
    final api = await ApiService.fromPreferences();
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _routerHandle = AppRouter.create(api: api, onConnected: _setApi);
    });
  }

  /// Called by `ServerSettingsScreen` after a successful health-check.
  ///
  /// Pre-fix (B-052): the old `onConnected` handler only called
  /// `GoRouter.of(context).go('/sessions')`, but the routes for
  /// `/sessions` and `/trends` had captured the *original* (null)
  /// `ApiService` via closure when the router was first built. So the
  /// user got a crash on `api!` the moment the navigation completed.
  /// Now we rebuild the router with the new api before navigating, so
  /// the route closures see the connected service.
  void _setApi(ApiService api) {
    setState(() {
      _routerHandle = AppRouter.create(api: api, onConnected: _setApi);
    });
    _routerHandle?.router.go('/sessions');
  }

  @override
  Widget build(BuildContext context) {
    // While the prefs read is in flight (or the router hasn't been
    // built yet), show a small splash. Pre-fix (B-051): the router was
    // recreated on every build call, throwing away the in-memory nav
    // stack — a tap on a list row could navigate "forward" but back
    // gestures landed somewhere unexpected.
    if (!_loaded || _routerHandle == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF1E1E1E),
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Benchify Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF007ACC),
          secondary: Color(0xFF4EC9B0),
          surface: Color(0xFF2D2D30),
          error: Color(0xFFF44747),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF252526),
          foregroundColor: Color(0xFFD4D4D4),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF2D2D30),
          surfaceTintColor: Color(0xFF2D2D30),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF3C3C3C),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF3C3C3C)),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF3C3C3C)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF007ACC)),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFFD4D4D4)),
          bodySmall: TextStyle(color: Color(0xFF858585)),
        ),
      ),
      routerConfig: _routerHandle!.router,
    );
  }
}
