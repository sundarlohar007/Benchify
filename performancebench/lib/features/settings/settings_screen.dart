import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App settings screen — theme, data directory, debug mode, etc.
/// Filled in during Task 3.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Settings',
          style: TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
