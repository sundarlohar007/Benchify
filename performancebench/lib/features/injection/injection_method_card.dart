// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import '../../shared/theme.dart';

/// Reusable card widget for injection method selection.
///
/// Per D-02: User selects apktool+Smali or Frida gadget.
/// Shows highlighted border when selected, greyed out when disabled.
class InjectionMethodCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDisabled;

  const InjectionMethodCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final borderColor = isSelected ? colors.accentBlue : colors.borderSubtle;
    final bgColor = isSelected
        ? colors.accentBlue.withValues(alpha: 0.1)
        : colors.bgElevated;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDisabled
              ? colors.bgElevated.withValues(alpha: 0.5)
              : bgColor,
          border: Border.all(
            color: isDisabled
                ? colors.borderSubtle.withValues(alpha: 0.5)
                : borderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isDisabled
                      ? colors.textSecondary.withValues(alpha: 0.5)
                      : isSelected
                          ? colors.accentBlue
                          : colors.textSecondary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isDisabled
                          ? colors.textSecondary.withValues(alpha: 0.5)
                          : colors.textPrimary,
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: colors.accentBlue,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(
                subtitle,
                style: TextStyle(
                  color: isDisabled
                      ? colors.textSecondary.withValues(alpha: 0.3)
                      : colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
