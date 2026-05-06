// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/theme.dart';

// =============================================================================
// iOS Video Quality Providers
// =============================================================================

/// Resolution: 480p, 720p, 1080p. Default: 1080p (per D-20).
final iosVideoResolutionProvider = StateProvider<String>((ref) => '1080p');

/// FPS: 15, 30, 60. Default: 30 (per D-20).
final iosVideoFpsProvider = StateProvider<int>((ref) => 30);

// =============================================================================
// Persistent preferences keys for iOS video settings
// =============================================================================

const _prefKeyResolution = 'ios_video_resolution';
const _prefKeyFps = 'ios_video_fps';

/// Load saved iOS video preferences from shared_preferences.
Future<void> loadIosVideoPreferences(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final resolution = prefs.getString(_prefKeyResolution);
  final fps = prefs.getInt(_prefKeyFps);

  if (resolution != null && ['480p', '720p', '1080p'].contains(resolution)) {
    ref.read(iosVideoResolutionProvider.notifier).state = resolution;
  }
  if (fps != null && [15, 30, 60].contains(fps)) {
    ref.read(iosVideoFpsProvider.notifier).state = fps;
  }
}

/// Save iOS video preferences to shared_preferences.
Future<void> _saveResolution(String resolution) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefKeyResolution, resolution);
}

Future<void> _saveFps(int fps) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_prefKeyFps, fps);
}

// =============================================================================
// Settings Widget
// =============================================================================

/// iOS Video Quality settings section.
///
/// Per D-20: Dropdown for resolution (480p/720p/1080p) and FPS (15/30/60).
/// Values stored in shared_preferences.
///
/// Per D-18: Entire section is only visible on macOS. Windows/Linux users
/// see a disabled card with tooltip: "iOS video requires macOS".
class VideoQualitySettings extends ConsumerWidget {
  const VideoQualitySettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);

    if (!Platform.isMacOS) {
      return _buildDisabledCard(colors);
    }

    return _buildEnabledSettings(context, colors, ref);
  }

  /// Disabled card shown on non-macOS with tooltip (per D-18).
  Widget _buildDisabledCard(AppColors colors) {
    return Tooltip(
      message: 'iOS video recording requires macOS',
      child: Opacity(
        opacity: 0.4,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colors.borderSubtle, width: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.videocam_off, size: 16, color: Color(0xFF5A5A5A)),
              const SizedBox(width: 8),
              Text(
                'iOS Video',
                style: TextStyle(
                  color: colors.textDisabled,
                  fontSize: TextTokens.sm,
                ),
              ),
              const Spacer(),
              Text(
                'Unavailable',
                style: TextStyle(
                  color: colors.textDisabled,
                  fontSize: TextTokens.xs,
                  fontFamily: monoFontFamily(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full settings widget shown on macOS.
  Widget _buildEnabledSettings(BuildContext context, AppColors colors, WidgetRef ref) {
    final resolution = ref.watch(iosVideoResolutionProvider);
    final fps = ref.watch(iosVideoFpsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'IOS VIDEO'.toUpperCase(),
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colors.borderSubtle, width: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              // Resolution dropdown
              _DropdownRow(
                label: 'Resolution',
                value: resolution,
                items: const ['480p', '720p', '1080p'],
                colors: colors,
                onChanged: (v) {
                  ref.read(iosVideoResolutionProvider.notifier).state = v;
                  _saveResolution(v);
                },
              ),
              const Divider(height: 1),
              // FPS dropdown
              _DropdownRow(
                label: 'Frame Rate',
                value: '$fps fps',
                items: const ['15 fps', '30 fps', '60 fps'],
                colors: colors,
                onChanged: (v) {
                  final fpsVal = int.tryParse(v.split(' ').first) ?? 30;
                  ref.read(iosVideoFpsProvider.notifier).state = fpsVal;
                  _saveFps(fpsVal);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dropdown row widget matching settings_screen.dart _DropdownRow pattern.
class _DropdownRow extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final AppColors colors;
  final ValueChanged<String>? onChanged;

  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.colors,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: TextTokens.sm,
                fontFamily: monoFontFamily(),
              ),
              dropdownColor: colors.bgElevated,
              items: items
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: (v) => onChanged?.call(v ?? value),
            ),
          ),
        ],
      ),
    );
  }
}
