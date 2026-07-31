// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onTap;

  const SessionCard({super.key, required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final appName = session['app_name'] as String? ?? 'Unknown';
    final deviceId = session['device_id'] as String? ?? '—';
    final startedAt = session['started_at'];
    // B-055: prefer measured FPS (actual_avg_fps / fps_median), not target_fps.
    final measuredRaw =
        session['actual_avg_fps'] ?? session['fps_median'] ?? session['fps'];
    final targetRaw = session['target_fps'];
    final num? measuredFps = measuredRaw is num ? measuredRaw : null;
    final num? targetFps = targetRaw is num ? targetRaw : null;
    final num? fps = measuredFps ?? targetFps;
    // Defensive substring: most ids are 36-char UUIDs, but a malformed or
    // truncated value would crash `substring(0, 8)` (B-060). Guard the length.
    final fullId = session['id'] as String?;
    final sessionId =
        (fullId != null && fullId.length >= 8) ? fullId.substring(0, 8) : (fullId ?? '—');

    final dateStr = _formatDate(startedAt);
    final Color fpsColor =
        fps != null && fps > 55
            ? const Color(0xFF4EC9B0)
            : fps != null && fps > 30
            ? const Color(0xFFCE9178)
            : const Color(0xFFF44747);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$deviceId — $dateStr',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF858585),
                      ),
                    ),
                    Text(
                      sessionId,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF5A5A5A),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              if (fps != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: fpsColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${measuredFps != null ? (fps! % 1 == 0 ? fps.toInt() : fps.toStringAsFixed(1)) : fps} fps',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: fpsColor,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic val) {
    if (val == null) return '—';
    try {
      final dt = DateTime.parse(val.toString());
      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return val.toString();
    }
  }
}
