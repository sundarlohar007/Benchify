// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';
import '../../app.dart';

/// Full settings screen with 6 categories: Profiling, Paths, Appearance,
/// Charts, Keyboard Shortcuts, About.
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
        title: Text('Settings', style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.md)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Profiling', colors),
          const SizedBox(height: 8),
          _buildProfilingSection(colors),
          const SizedBox(height: 24),
          _SectionHeader('Paths', colors),
          const SizedBox(height: 8),
          _buildPathsSection(colors),
          const SizedBox(height: 24),
          _SectionHeader('Appearance', colors),
          const SizedBox(height: 8),
          _buildAppearanceSection(colors, currentTheme, ref),
          const SizedBox(height: 24),
          _SectionHeader('Charts', colors),
          const SizedBox(height: 8),
          _buildChartsSection(colors),
          const SizedBox(height: 24),
          _SectionHeader('Keyboard Shortcuts', colors),
          const SizedBox(height: 8),
          _buildKeyboardShortcuts(colors),
          const SizedBox(height: 24),
          _SectionHeader('About', colors),
          const SizedBox(height: 8),
          _buildAboutSection(colors),
        ],
      ),
    );
  }

  Widget _buildProfilingSection(AppColors colors) {
    return _SettingsGroup(children: [
      _DropdownRow('Sample rate', '1s (default)', ['500ms', '1s', '2s'], colors),
      _DropdownRow('Screenshot interval', '10s', ['5s', '10s', '30s', 'Off'], colors),
      _DropdownRow('Chart time window', '60s', ['30s', '60s', '120s'], colors),
      _ToggleRow('Auto-detect layer name', true, colors),
    ]);
  }

  Widget _buildPathsSection(AppColors colors) {
    return _SettingsGroup(children: [
      _PathRow('ADB executable', 'Auto (PATH)', colors),
      _PathRow('Python executable', 'Auto (PATH)', colors),
      _PathRow('Data directory', '~/PerformanceBench', colors),
    ]);
  }

  Widget _buildAppearanceSection(AppColors colors, ThemeModeOption current, WidgetRef ref) {
    return _SettingsGroup(children: [
      _DropdownRow('Theme', current.name, ['Dark', 'Light', 'High Contrast', 'System'], colors, onChanged: (v) {
        final mode = switch (v) {
          'Dark' => ThemeModeOption.dark,
          'Light' => ThemeModeOption.light,
          'High Contrast' => ThemeModeOption.highContrast,
          _ => ThemeModeOption.system,
        };
        ref.read(themeModeProvider.notifier).state = mode;
      }),
      _DropdownRow('Monospace font', 'Auto', ['Auto', 'Cascadia Code', 'SF Mono', 'JetBrains Mono'], colors),
    ]);
  }

  Widget _buildChartsSection(AppColors colors) {
    return _SettingsGroup(children: [
      _RadioRow('FPS histogram bucket', ['5fps', '10fps'], '5fps', colors),
      _RadioRow('Chart grid columns', ['Auto', '1', '2', '3'], 'Auto', colors),
      _ToggleRow('Show null gaps', true, colors),
      _ToggleRow('Animate chart scroll', true, colors),
    ]);
  }

  Widget _buildKeyboardShortcuts(AppColors colors) {
    final shortcuts = [
      ('Start / Stop Recording', 'Ctrl+Shift+R', '⌘⇧R'),
      ('Add Marker', 'Ctrl+Shift+M', '⌘⇧M'),
      ('Launch Complete', 'Ctrl+Shift+L', '⌘⇧L'),
      ('Screenshot', 'Ctrl+Shift+S', '⌘⇧S'),
      ('Toggle Sidebar', 'Ctrl+B', '⌘B'),
      ('Expand Chart', 'Double-click', 'Double-click'),
      ('Close Tab', 'Ctrl+W', '⌘W'),
    ];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.borderSubtle, width: 0.5),
      ),
      child: Column(
        children: [
          _ShortcutHeader(colors),
          for (final s in shortcuts) _ShortcutRow(s.$1, s.$2, s.$3, colors),
        ],
      ),
    );
  }

  Widget _buildAboutSection(AppColors colors) {
    return _SettingsGroup(children: [
      _InfoRow('Version', '1.0.0', colors),
      _InfoRow('License', 'MIT', colors),
      _InfoRow('GitHub', 'github.com/sundarlohar007/Benchify', colors),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () {
          // Reset onboarding flag
        },
        child: Text('Reset Onboarding', style: TextStyle(color: colors.accentBlue, fontSize: TextTokens.sm)),
      ),
    ]);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final AppColors colors;
  const _SectionHeader(this.title, this.colors);

  @override
  Widget build(BuildContext context) {
    return Text(title.toUpperCase(), style: TextStyle(
      color: colors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2,
    ));
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.borderSubtle, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(children: children),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final AppColors colors;
  final ValueChanged<String>? onChanged;
  const _DropdownRow(this.label, this.value, this.items, this.colors, {this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      label: label,
      colors: colors,
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm, fontFamily: monoFontFamily()),
          dropdownColor: colors.bgElevated,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged: (v) => onChanged?.call(v ?? value),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final AppColors colors;
  const _ToggleRow(this.label, this.value, this.colors);

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      label: label,
      colors: colors,
      trailing: Switch(
        value: value,
        activeColor: colors.accentBlue,
        onChanged: (_) {},
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final AppColors colors;
  const _RadioRow(this.label, this.options, this.selected, this.colors);

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      label: label,
      colors: colors,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((o) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Radio<String>(
              value: o,
              groupValue: selected,
              activeColor: colors.accentBlue,
              onChanged: (_) {},
              visualDensity: VisualDensity.compact,
            ),
            Text(o, style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.xs)),
          ]),
        )).toList(),
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  final String label;
  final String value;
  final AppColors colors;
  const _PathRow(this.label, this.value, this.colors);

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      label: label,
      colors: colors,
      trailing: Text(value, style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm, fontFamily: monoFontFamily())),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final AppColors colors;
  const _InfoRow(this.label, this.value, this.colors);

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      label: label,
      colors: colors,
      trailing: Text(value, style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm, fontFamily: monoFontFamily())),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  final AppColors colors;
  const _SettingRow({required this.label, required this.trailing, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderSubtle.withValues(alpha: 0.3), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm))),
          trailing,
        ],
      ),
    );
  }
}

class _ShortcutHeader extends StatelessWidget {
  final AppColors colors;
  const _ShortcutHeader(this.colors);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderSubtle, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Action', style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.xs, fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('Windows', style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.xs, fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text('macOS', style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.xs, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String action;
  final String win;
  final String mac;
  final AppColors colors;
  const _ShortcutRow(this.action, this.win, this.mac, this.colors);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderSubtle.withValues(alpha: 0.3), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(action, style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.xs))),
          Expanded(flex: 2, child: Text(win, style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.xs, fontFamily: monoFontFamily()))),
          Expanded(flex: 2, child: Text(mac, style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.xs, fontFamily: monoFontFamily()))),
        ],
      ),
    );
  }
}
