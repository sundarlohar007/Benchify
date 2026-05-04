import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session detail / replay screen with 5 tabs.
/// Filled in during Task 3.
class SessionDetailScreen extends ConsumerWidget {
  final String sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Text(
          'Session Detail — $sessionId',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
