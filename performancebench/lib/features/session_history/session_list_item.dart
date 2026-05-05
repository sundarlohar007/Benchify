// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';

import '../../shared/theme.dart';
import '../../core/models/session.dart';

/// Session list item widget for the history screen.
/// Shows app name, device, duration, FPS, relative timestamp, and upload status (D-26).
class SessionListItem extends StatelessWidget {
  final Session session;
  final AppColors colors;
  final VoidCallback onTap;
  final bool isUploaded;
  final double uploadProgress;
  final int? queuePosition;
  final int? queueTotal;

  const SessionListItem({
    super.key,
    required this.session,
    required this.colors,
    required this.onTap,
    this.isUploaded = false,
    this.uploadProgress = 0.0,
    this.queuePosition,
    this.queueTotal,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Upload status indicators (D-26)
            if (isUploaded)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.check_circle, size: 14, color: colors.accentSuccess),
              ),
            if (queuePosition != null && queueTotal != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.bgInput,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    '$queuePosition of $queueTotal',
                    style: TextStyle(color: colors.textSecondary, fontSize: 8),
                  ),
                ),
              ),
            Expanded(
              flex: 2,
              child: Text(
                _formatDate(),
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: TextTokens.xs,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                session.appName ?? session.appPackage,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: TextTokens.sm,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _formatDevice(),
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: TextTokens.xs,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                _formatDuration(),
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: TextTokens.xs,
                  fontFamily: monoFontFamily(),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '--',
                style: TextStyle(
                  color: colors.textDisabled,
                  fontSize: TextTokens.xs,
                  fontFamily: monoFontFamily(),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: _buildTagBadge(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate() {
    final dt = DateTime.fromMillisecondsSinceEpoch(session.startedAt);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  String _formatDevice() {
    // Device info from session — will be enriched with join in Wave 5
    return session.platform;
  }

  String _formatDuration() {
    if (session.durationMs == null) return '--:--';
    final totalSec = session.durationMs! ~/ 1000;
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Widget _buildTagBadge() {
    if (session.tags == null || session.tags!.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: colors.bgInput,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        session.tags!.length > 12
            ? '${session.tags!.substring(0, 10)}..'
            : session.tags!,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: TextTokens.xs,
        ),
      ),
    );
  }
}
