import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live profiling session screen with charts, screenshots, markers tabs.
/// Filled in during Task 3.
class ActiveSessionScreen extends ConsumerWidget {
  final String sessionId;
  const ActiveSessionScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Text(
          'Active Session — $sessionId',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
