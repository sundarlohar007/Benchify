// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';

import '../../core/services/error_handler.dart';
import '../theme.dart';

/// 22px bottom status bar per D-17 + UNIFIED-SPEC §9.2.
///
/// Left: recording state or "Ready"
/// Center: device name + sample rate
/// Right: alert badge (threshold breaches) + error count badge (clickable) + SQLite write status
class StatusBar extends StatelessWidget {
  final bool isRecording;
  final String elapsed;
  final String deviceInfo;
  final String sqliteStatus;
  final int alertCount;
  final VoidCallback? onAlertTap;

  const StatusBar({
    super.key,
    this.isRecording = false,
    this.elapsed = '00:00:00',
    this.deviceInfo = '',
    this.sqliteStatus = 'SQLite ✓',
    this.alertCount = 0,
    this.onAlertTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bgColor = isRecording ? colors.accentRecording : colors.bgElevated;
    final errors = ErrorHandler().errorCount;

    return Container(
      height: 22,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Left: recording state
          if (isRecording) ...[
            Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text('REC $elapsed', style: TextStyle(
              color: Colors.white, fontSize: 10, fontFamily: monoFontFamily(),
            )),
          ] else
            Text('Ready', style: TextStyle(
              color: colors.textSecondary, fontSize: 10, fontFamily: monoFontFamily(),
            )),
          const Spacer(),
          // Center: device info
          if (deviceInfo.isNotEmpty)
            Text(deviceInfo, style: TextStyle(
              color: isRecording ? Colors.white70 : colors.textDisabled,
              fontSize: 10, fontFamily: monoFontFamily(),
            )),
          const Spacer(),
          // Right: alert badge (threshold breaches) + error count + SQLite status
          if (alertCount > 0)
            GestureDetector(
              onTap: onAlertTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: colors.accentWarning,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$alertCount alert',
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ),
          if (errors > 0)
            GestureDetector(
              onTap: () => _showErrorLog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: colors.accentDanger,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$errors errors', style: const TextStyle(color: Colors.white, fontSize: 9)),
              ),
            ),
          Text(sqliteStatus, style: TextStyle(
            color: sqliteStatus.contains('✓') ? colors.accentSuccess : colors.accentWarning,
            fontSize: 10, fontFamily: monoFontFamily(),
          )),
        ],
      ),
    );
  }

  void _showErrorLog(BuildContext context) {
    final colors = AppColors.of(context);
    final errors = ErrorHandler().errors;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.bgSidebar,
      builder: (_) => SizedBox(
        height: 400,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: colors.bgElevated,
              child: Row(
                children: [
                  Text('Error Log (${errors.length})', style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      ErrorHandler().clearErrors();
                      Navigator.pop(context);
                    },
                    child: Text('Clear', style: TextStyle(color: colors.accentBlue, fontSize: TextTokens.sm)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: errors.length,
                itemBuilder: (_, i) {
                  final e = errors[errors.length - 1 - i]; // newest first
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: colors.borderSubtle, width: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(e.timestamp.toString().substring(11, 19), style: TextStyle(color: colors.textDisabled, fontSize: 10, fontFamily: monoFontFamily())),
                          const SizedBox(width: 8),
                          Text(e.source, style: TextStyle(color: colors.textSecondary, fontSize: 10)),
                        ]),
                        const SizedBox(height: 4),
                        Text(e.message, style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm)),
                        if (e.stackTrace != null) ...[
                          const SizedBox(height: 4),
                          Text(e.stackTrace.toString(), style: TextStyle(color: colors.textDisabled, fontSize: 9, fontFamily: monoFontFamily())),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
