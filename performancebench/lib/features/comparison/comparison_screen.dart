import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Two-session side-by-side comparison screen.
/// Filled in during Task 3.
class ComparisonScreen extends ConsumerWidget {
  const ComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Comparison',
          style: TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
