// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/settings/server_settings_screen.dart';
import '../screens/sessions/session_list_screen.dart';
import '../screens/sessions/session_detail_screen.dart';
import '../screens/trends/trends_screen.dart';
import '../services/api_service.dart';

class AppRouter {
  static GoRouter create(ApiService? api) {
    final hasApi = api != null;

    return GoRouter(
      initialLocation: hasApi ? '/sessions' : '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder:
              (context, state) => ServerSettingsScreen(
                onConnected: (ApiService api) {
                  // Re-create router with new API service
                  GoRouter.of(context).go('/sessions');
                },
              ),
        ),
        GoRoute(
          path: '/sessions',
          builder: (context, state) => SessionListScreen(api: api!),
        ),
        GoRoute(
          path: '/sessions/:id',
          builder:
              (context, state) => SessionDetailScreen(
                api: api!,
                sessionId: state.pathParameters['id']!,
              ),
        ),
        GoRoute(
          path: '/trends',
          builder: (context, state) => TrendsScreen(api: api!),
        ),
      ],
    );
  }
}
