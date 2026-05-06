// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'routes/app_router.dart';
import 'services/api_service.dart';
import 'screens/settings/server_settings_screen.dart';

class BenchifyMobileApp extends StatefulWidget {
  const BenchifyMobileApp({super.key});

  @override
  State<BenchifyMobileApp> createState() => _BenchifyMobileAppState();
}

class _BenchifyMobileAppState extends State<BenchifyMobileApp> {
  ApiService? _apiService;

  @override
  void initState() {
    super.initState();
    _loadApiService();
  }

  Future<void> _loadApiService() async {
    final api = await ApiService.fromPreferences();
    setState(() => _apiService = api);
  }

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.create(_apiService);

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
      routerConfig: router,
    );
  }
}
