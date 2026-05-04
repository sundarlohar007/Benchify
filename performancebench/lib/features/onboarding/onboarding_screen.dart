import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme.dart';

/// 3-step onboarding wizard shown on first launch.
///
/// Step 1: Connect Device
/// Step 2: Select App
/// Step 3: Start Profiling
///
/// "Skip" is always available — sets flag and navigates to DeviceList.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentStep = 0;

  void _next() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  void _skip() {
    _finish();
  }

  void _finish() {
    // Set onboarding_completed flag (SharedPreferences) and navigate to DeviceList
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: Column(
        children: [
          // Skip button
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: _skip,
                child: Text('Skip', style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm)),
              ),
            ),
          ),
          Expanded(
            child: _buildStep(colors),
          ),
          // Step indicators + navigation
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_currentStep > 0)
                  OutlinedButton(
                    onPressed: _back,
                    style: OutlinedButton.styleFrom(foregroundColor: colors.textSecondary),
                    child: const Text('Back'),
                  ),
                const Spacer(),
                _StepDots(current: _currentStep, colors: colors),
                const Spacer(),
                FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(backgroundColor: colors.accentBlue),
                  child: Text(_currentStep == 2 ? 'Start Profiling' : 'Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(AppColors colors) {
    switch (_currentStep) {
      case 0:
        return _StepContent(
          icon: Icons.usb,
          title: 'Connect Your Device',
          body: 'Connect your Android or iOS device via USB.\n\n'
              'Enable USB Debugging (Android) or\n'
              'Developer Mode (iOS).\n\n'
              'For iOS: macOS host required.',
          colors: colors,
        );
      case 1:
        return _StepContent(
          icon: Icons.apps,
          title: 'Select an App',
          body: 'Choose the app you want to profile.\n\n'
              'PerformanceBench will collect real-time\n'
              'FPS, CPU, memory, battery, and more.\n\n'
              'All data stays on your machine —\n'
              'never transmitted.',
          colors: colors,
        );
      case 2:
        return _StepContent(
          icon: Icons.play_circle,
          title: 'Start Profiling',
          body: 'Your first session awaits.\n\n'
              'Metrics stream at 1Hz.\n'
              'All data local only.\n\n'
              'Press Start to begin profiling\n'
              'your first session!',
          colors: colors,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _StepContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final AppColors colors;

  const _StepContent({
    required this.icon,
    required this.title,
    required this.body,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: colors.accentBlue),
          const SizedBox(height: 24),
          Text(title, style: TextStyle(
            color: colors.textPrimary, fontSize: TextTokens.lg, fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 16),
          Text(body, textAlign: TextAlign.center, style: TextStyle(
            color: colors.textSecondary, fontSize: TextTokens.base, height: 1.6,
          )),
        ],
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int current;
  final AppColors colors;

  const _StepDots({required this.current, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final isActive = i == current;
        final isDone = i < current;
        return Container(
          width: isActive ? 12 : 8,
          height: isActive ? 12 : 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? colors.accentBlue
                : isDone
                    ? colors.accentSuccess
                    : colors.textDisabled,
          ),
        );
      }),
    );
  }
}
