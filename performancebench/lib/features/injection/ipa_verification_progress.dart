// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';

import '../../core/services/ipa_injection_service.dart';
import '../../shared/theme.dart';

/// Multi-step verification progress indicator for iOS IPA injection.
///
/// Per 05-02-PLAN Task 1 (D-07):
///   Shows 7-step progress: Unpacking IPA → Checking encryption →
///   Injecting SDK → Patching Info.plist → Signing → Verifying signature → Done.
///
/// Each step shows: spinner (in progress) / checkmark (success) /
/// X (failure with error message).
///
/// Matches Phase 4 Android verification stepper pattern exactly.
class IpaVerificationProgress extends StatelessWidget {
  final Map<IpaInjectionStep, IpaStepEvent> stepStates;
  final bool isRunning;

  static const _stepLabels = <IpaInjectionStep, String>{
    IpaInjectionStep.unpack: 'Unpacking IPA',
    IpaInjectionStep.encryptionCheck: 'Checking encryption',
    IpaInjectionStep.injectSdk: 'Injecting SDK',
    IpaInjectionStep.patchPlist: 'Patching Info.plist',
    IpaInjectionStep.loadCommand: 'Inserting load command',
    IpaInjectionStep.signing: 'Signing',
    IpaInjectionStep.repack: 'Repacking IPA',
    IpaInjectionStep.verify: 'Verifying signature',
    IpaInjectionStep.done: 'Done',
  };

  static const _displayOrder = <IpaInjectionStep>[
    IpaInjectionStep.unpack,
    IpaInjectionStep.encryptionCheck,
    IpaInjectionStep.injectSdk,
    IpaInjectionStep.patchPlist,
    IpaInjectionStep.loadCommand,
    IpaInjectionStep.signing,
    IpaInjectionStep.repack,
    IpaInjectionStep.verify,
    IpaInjectionStep.done,
  ];

  const IpaVerificationProgress({
    super.key,
    required this.stepStates,
    required this.isRunning,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (stepStates.isEmpty && !isRunning) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final step in _displayOrder)
          _buildStep(colors, step),
      ],
    );
  }

  Widget _buildStep(AppColors colors, IpaInjectionStep step) {
    final label = _stepLabels[step] ?? 'Unknown';
    final event = stepStates[step];

    IconData icon;
    Color iconColor;
    Widget? trailing;

    if (event == null) {
      // Not yet reached
      icon = Icons.circle_outlined;
      iconColor = colors.textDisabled;
    } else if (event.status == 'running') {
      // In progress
      icon = Icons.circle;
      iconColor = colors.accentBlue;
      trailing = SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: colors.accentBlue,
        ),
      );
    } else if (event.status == 'pass') {
      // Completed successfully
      icon = Icons.check_circle;
      iconColor = colors.accentSuccess;
    } else if (event.status == 'fail') {
      // Failed
      icon = Icons.cancel;
      iconColor = colors.accentDanger;
      trailing = Expanded(
        child: Text(
          event.detail,
          style: TextStyle(
            color: colors.accentDanger,
            fontSize: TextTokens.xs,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else if (event.status == 'warning') {
      // Warning
      icon = Icons.warning_amber_rounded;
      iconColor = colors.accentWarning;
      trailing = Expanded(
        child: Text(
          event.detail,
          style: TextStyle(
            color: colors.accentWarning,
            fontSize: TextTokens.xs,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else {
      icon = Icons.circle_outlined;
      iconColor = colors.textDisabled;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: event != null ? colors.textPrimary : colors.textDisabled,
              fontSize: TextTokens.sm,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }
}
