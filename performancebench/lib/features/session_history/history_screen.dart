import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session history list — sortable, filterable past sessions.
/// Filled in during Task 3.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(
        child: Text(
          'No sessions recorded yet',
          style: TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
