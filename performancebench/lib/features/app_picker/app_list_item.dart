import 'package:flutter/material.dart';

import '../../core/services/adb_service.dart';
import '../../shared/theme.dart';

/// App list item widget — shows app label, package name, and version
/// in the app picker screen.
class AppListItem extends StatelessWidget {
  final AppInfo app;
  final AppColors colors;
  final VoidCallback onTap;

  const AppListItem({
    super.key,
    required this.app,
    required this.colors,
    required this.onTap,
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
