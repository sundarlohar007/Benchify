import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App picker screen for selecting target app on connected device.
/// Filled in during Task 3.
class AppPickerScreen extends ConsumerWidget {
  final String deviceId;
  const AppPickerScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Text(
          'App Picker — Device: $deviceId',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
