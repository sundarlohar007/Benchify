import 'package:flutter/material.dart';

import '../../core/models/device.dart';
import '../../shared/theme.dart';

/// Device card widget — shows platform icon, device name, OS version,
/// connection status dot, and a Start button (UNIFIED-SPEC §9.2 sidebar).
class DeviceCard extends StatelessWidget {
  final Device device;
  final AppColors colors;
  final VoidCallback onStart;
  final bool enabled;

  const DeviceCard({
    super.key,
    required this.device,
    required this.colors,
    required this.onStart,
    this.enabled = true,
  });

  /// Status dot color: green=connected, grey=offline, red=unauthorized.
  Color get _statusColor {
    final name = device.name.toLowerCase();
    if (name.contains('unauthorized')) return colors.accentDanger;
    if (name.contains('offline')) return colors.textDisabled;
    return colors.accentSuccess;
  }

  IconData get _platformIcon {
    final name = device.name.toLowerCase();
    if (name.contains('iphone') || name.contains('ios')) {
      return Icons.phone_iphone;
    }
    return Icons.android;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onStart : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _statusColor,
                shape: BoxShape.circle,
              ),
            ),
            // Platform icon
            Icon(_platformIcon, size: 16, color: colors.textSecondary),
            const SizedBox(width: 8),
            // Device info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: TextStyle(
                      color: enabled
                          ? colors.textPrimary
                          : colors.textDisabled,
                      fontSize: TextTokens.sm,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (device.osVersion != null || device.model != null)
                    Text(
                      [
                        if (device.model != null) device.model,
                        if (device.osVersion != null)
                          'Android ${device.osVersion}',
                      ].join(' · '),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: TextTokens.xs,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Start button
            if (enabled)
              SizedBox(
                height: 24,
                child: TextButton(
                  onPressed: onStart,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Start',
                    style: TextStyle(
                      color: colors.accentBlue,
                      fontSize: TextTokens.xs,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
