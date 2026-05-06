// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import '../../core/services/injection_service.dart';

/// Verification progress widget showing 4-step injection pipeline.
///
/// Per D-08: Multi-step verification with checkmarks per step:
///   1. Decompile APK (apktool)
///   2. Patch Smali + Manifest
///   3. Rebuild + Re-sign (apksigner)
///   4. Verify (apksigner check + Smali + ADB port test)
///
/// Each step shows: grey circle -> blue spinner (running) -> green checkmark
/// (pass) or red X (fail) with detail message.
class VerificationProgress extends StatelessWidget {
  final Map<InjectionStep, StepEvent> stepStates;
  final bool isRunning;
  final List<String> stepLabels;

  const VerificationProgress({
    super.key,
    required this.stepStates,
    required this.isRunning,
    this.stepLabels = const [
      'Decompile APK',
      'Patch Smali + Manifest',
      'Rebuild + Re-sign',
      'Verify',
    ],
  });

  int _stepIndex(InjectionStep step) {
    switch (step) {
      case InjectionStep.decompile:
        return 0;
      case InjectionStep.frida:
        return 0;
      case InjectionStep.smali:
      case InjectionStep.manifest:
        return 1;
      case InjectionStep.rebuild:
      case InjectionStep.resign:
        return 2;
      case InjectionStep.verify:
        return 3;
      default:
        return -1;
    }
  }

  StepEvent? _eventForIndex(int index) {
    final matching = stepStates.entries
        .where((e) => _stepIndex(e.key) == index)
        .toList();
    if (matching.isEmpty) return null;
    return matching.last.value;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verification Progress',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(stepLabels.length, (i) {
          final event = _eventForIndex(i);
          final isCurrentStep = isRunning && event?.status == 'running';
          final isDone = event?.status == 'pass';
          final isFailed = event?.status == 'fail';

          return _buildStepItem(
            colors,
            index: i + 1,
            label: stepLabels[i],
            isCurrent: isCurrentStep,
            isDone: isDone,
            isFailed: isFailed,
            detail: event?.detail,
          );
        }),
      ],
    );
  }

  Widget _buildStepItem(
    AppColors colors, {
    required int index,
    required String label,
    required bool isCurrent,
    required bool isDone,
    required bool isFailed,
    String? detail,
  }) {
    Color iconColor;
    Widget iconWidget;

    if (isDone) {
      iconColor = colors.accentSuccess;
      iconWidget = Icon(Icons.check_circle, color: iconColor, size: 22);
    } else if (isFailed) {
      iconColor = colors.accentDanger;
      iconWidget = Icon(Icons.cancel, color: iconColor, size: 22);
    } else if (isCurrent) {
      iconWidget = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.accentBlue,
        ),
      );
    } else {
      iconWidget = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.borderSubtle, width: 2),
        ),
        child: Center(
          child: Text(
            '$index',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconWidget,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDone
                        ? colors.accentSuccess
                        : isFailed
                            ? colors.accentDanger
                            : colors.textPrimary,
                    fontSize: 13,
                    fontWeight:
                        isCurrent ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      color: isFailed
                          ? colors.accentDanger
                          : colors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
