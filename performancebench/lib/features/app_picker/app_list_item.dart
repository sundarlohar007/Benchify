// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';

import '../../core/services/adb_service.dart';
import '../../shared/theme.dart';

/// App list item widget — shows app label, package name, and version
/// in the app picker screen. v1.5: adds watch-list toggle for auto-start.
class AppListItem extends StatelessWidget {
  final AppInfo app;
  final AppColors colors;
  final VoidCallback onTap;
  final bool isWatched;
  final VoidCallback? onWatchToggle;

  const AppListItem({
    super.key,
    required this.app,
    required this.colors,
    required this.onTap,
    this.isWatched = false,
    this.onWatchToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Placeholder app icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.bgInput,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.android,
                size: 20,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            // App info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: TextTokens.sm,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${app.package}  ·  v${app.version}',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: TextTokens.xs,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Watch-list toggle (v1.5 — D-10, D-11)
            if (onWatchToggle != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  icon: Icon(
                    isWatched ? Icons.visibility : Icons.visibility_off,
                    size: 16,
                    color: isWatched ? colors.accentBlue : colors.textDisabled,
                  ),
                  tooltip: isWatched
                      ? 'Watching for auto-start'
                      : 'Add to watch list',
                  onPressed: onWatchToggle,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ),
            // Build number badge
            if (app.buildNumber != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.bgInput,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '${app.buildNumber}',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: TextTokens.xs,
                    fontFamily: monoFontFamily(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
