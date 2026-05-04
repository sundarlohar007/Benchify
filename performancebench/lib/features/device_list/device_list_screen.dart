import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// VS Code-style device list screen with activity bar, sidebar, and main content.
/// Filled in during Task 3.
class DeviceListScreen extends ConsumerWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Select a device to start profiling',
          style: TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
