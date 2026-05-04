import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';
import '../../app.dart';
import '../../main.dart';

/// App settings screen — theme selection, data directory path, debug mode, about.
/// Two-column layout: categories on left, settings on right (UNIFIED-SPEC §9.x).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final currentTheme = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        backgroundColor: colors.bgSidebar,
        title: Text(
          'Settings',
          style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.md),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance section
          _SectionHeader(title: 'Appearance', colors: colors),
          const SizedBox(height: 8),
          _buildThemeSelector(colors, currentTheme, ref),

          const SizedBox(height: 24),

          // Data section
          _SectionHeader(title: 'Data', colors: colors),
          const SizedBox(height: 8),
          _buildDataDirRow(colors),

          const SizedBox(height: 24),

          // Debug section
          _SectionHeader(title: 'Developer', colors: colors),
          const SizedBox(height: 8),
          _buildDebugToggle(colors, ref),

          const SizedBox(height: 24),

          // About section
          _SectionHeader(title: 'About', colors: colors),
          const SizedBox(height: 8),
          _infoRow('Version', '1.0.0', colors),
          _infoRow('License', 'MIT', colors),
          _infoRow('Platform', 'Desktop', colors),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(
    AppColors colors,
    ThemeModeOption current,
    WidgetRef ref,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.borderSubtle, width: 0.5),
      ),
      child: Column(
        children: [
          for (final opt in ThemeModeOption.values)
            ListTile(
              title: Text(
                _themeLabel(opt),
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: TextTokens.sm,
                ),
              ),
              leading: Radio<ThemeModeOption>(
                value: opt,
                groupValue: current,
                onChanged: (v) {
                  if (v != null) ref.read(themeModeProvider.notifier).state = v;
                },
                activeColor: colors.accentBlue,
              ),
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8),
              onTap: () {
                ref.read(themeModeProvider.notifier).state = opt;
              },
            ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeModeOption opt) {
    return switch (opt) {
      ThemeModeOption.dark => 'Dark+ (VS Code default)',
      ThemeModeOption.light => 'Light',
      ThemeModeOption.highContrast => 'High Contrast',
      ThemeModeOption.system => 'System default',
    };
  }

  Widget _buildDataDirRow(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.borderSubtle, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.folder, color: colors.textSecondary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Data directory: ~/Library/Application Support/performancebench.db',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: TextTokens.xs,
                fontFamily: monoFontFamily(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugToggle(AppColors colors, WidgetRef ref) {
    final isDebug = ref.watch(debugModeProvider);

    return SwitchListTile(
      value: isDebug,
      onChanged: (v) {
        ref.read(debugModeProvider.notifier).state = v;
      },
      title: Text(
        'Debug mode',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: TextTokens.sm,
        ),
      ),
      subtitle: Text(
        'Show verbose ADB command output and extra logging',
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: TextTokens.xs,
        ),
      ),
      activeColor: colors.accentBlue,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _infoRow(String label, String value, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: TextTokens.sm,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: TextTokens.sm,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final AppColors colors;

  const _SectionHeader({required this.title, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: colors.textSecondary,
        fontSize: TextTokens.xs,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}
