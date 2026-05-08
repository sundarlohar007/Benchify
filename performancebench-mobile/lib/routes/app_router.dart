// SPDX-License-Identifier: MIT

import 'package:go_router/go_router.dart';

import '../screens/settings/server_settings_screen.dart';
import '../screens/sessions/session_detail_screen.dart';
import '../screens/sessions/session_list_screen.dart';
import '../screens/trends/trends_screen.dart';
import '../services/api_service.dart';

/// Bundle of the configured `GoRouter` plus a stable handle the app shell
/// can call into. The shell rebuilds this whenever the `ApiService`
/// reference changes (i.e. user just connected); routes capture the new
/// `api` via closure on construction. Re-export from the same file so
/// callers don't have to import `go_router` directly.
class GoRouterHandle {
  final GoRouter router;
  const GoRouterHandle(this.router);
}

class AppRouter {
  /// Build a `GoRouter` for the mobile shell.
  ///
  /// `api` is the currently-resolved service (or null pre-connect).
  /// `onConnected` is invoked by `ServerSettingsScreen` after a
  /// successful health-check; the shell propagates the new `api` back
  /// in by rebuilding the router (B-052).
  static GoRouterHandle create({
    required ApiService? api,
    required void Function(ApiService) onConnected,
  }) {
    final hasApi = api != null;

    final router = GoRouter(
      initialLocation: hasApi ? '/sessions' : '/settings',
      // Soft-redirect any post-connect navigation that lacks a live api
      // back to the settings screen instead of crashing on `api!`.
      redirect: (context, state) {
        final loc = state.uri.path;
        if (api == null && loc != '/settings') return '/settings';
        return null;
      },
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) =>
              ServerSettingsScreen(onConnected: onConnected),
        ),
        GoRoute(
          path: '/sessions',
          builder: (context, state) => SessionListScreen(api: api!),
        ),
        GoRoute(
          path: '/sessions/:id',
          builder: (context, state) => SessionDetailScreen(
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

    return GoRouterHandle(router);
  }
}
