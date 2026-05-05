// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';
import '../../app.dart';

// =============================================================================
// Threshold Alert Providers
// =============================================================================

final fpsAlertEnabledProvider = StateProvider<bool>((ref) => false);
final fpsMinThresholdProvider = StateProvider<double>((ref) => 30.0);

final cpuAlertEnabledProvider = StateProvider<bool>((ref) => false);
final cpuMaxThresholdProvider = StateProvider<double>((ref) => 85.0);

final memoryAlertEnabledProvider = StateProvider<bool>((ref) => false);
final memoryGrowthMbProvider = StateProvider<double>((ref) => 100.0);

final autoStartEnabledProvider = StateProvider<bool>((ref) => false);
final watchPackagesProvider = StateProvider<List<String>>((ref) => []);

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
          _buildProfilingSection(colors, ref),
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

  Widget _buildProfilingSection(AppColors colors, WidgetRef ref) {
    final fpsEnabled = ref.watch(fpsAlertEnabledProvider);
    final fpsMin = ref.watch(fpsMinThresholdProvider);
    final cpuEnabled = ref.watch(cpuAlertEnabledProvider);
    final cpuMax = ref.watch(cpuMaxThresholdProvider);
    final memEnabled = ref.watch(memoryAlertEnabledProvider);
    final memGrowth = ref.watch(memoryGrowthMbProvider);
    final autoStartEnabled = ref.watch(autoStartEnabledProvider);
    final watchPackages = ref.watch(watchPackagesProvider);

    return Column(
      children: [
        _SettingsGroup(children: [
          _DropdownRow('Sample rate', '1s (default)', ['500ms', '1s', '2s'], colors),
          _DropdownRow('Screenshot interval', '10s', ['5s', '10s', '30s', 'Off'], colors),
          _DropdownRow('Chart time window', '60s', ['30s', '60s', '120s'], colors),
          _ToggleRow('Auto-detect layer name', true, colors),
        ]),
        const SizedBox(height: 20),
        _SectionHeader('Threshold Alerts', colors),
        const SizedBox(height: 8),
        _SettingsGroup(children: [
          // FPS Alert — default off (D-05)
          _ToggleRow(
            'FPS Alert (< 30 for 10s)',
            fpsEnabled,
            colors,
            onChanged: (v) => ref.read(fpsAlertEnabledProvider.notifier).state = v,
          ),
          if (fpsEnabled)
            _SliderRow(
              label: 'FPS Minimum',
              value: fpsMin,
              min: 10,
              max: 55,
              divisions: 45,
              displayValue: '${fpsMin.toInt()}',
              onChanged: (v) =>
                  ref.read(fpsMinThresholdProvider.notifier).state = v,
              colors: colors,
            ),
          const _SettingsDivider(),
          // CPU Alert — default off (D-05)
          _ToggleRow(
            'CPU Alert (> 85% for 5s)',
            cpuEnabled,
            colors,
            onChanged: (v) => ref.read(cpuAlertEnabledProvider.notifier).state = v,
          ),
          if (cpuEnabled)
            _SliderRow(
              label: 'CPU Maximum %',
              value: cpuMax,
              min: 50,
              max: 100,
              divisions: 50,
              displayValue: '${cpuMax.toInt()}%',
              onChanged: (v) =>
                  ref.read(cpuMaxThresholdProvider.notifier).state = v,
              colors: colors,
            ),
          const _SettingsDivider(),
          // Memory Alert — default off (D-05)
          _ToggleRow(
            'Memory Alert (> +100MB in 30s)',
            memEnabled,
            colors,
            onChanged: (v) =>
                ref.read(memoryAlertEnabledProvider.notifier).state = v,
          ),
          if (memEnabled)
            _SliderRow(
              label: 'Memory Growth (MB)',
              value: memGrowth,
              min: 50,
              max: 500,
              divisions: 45,
              displayValue: '${memGrowth.toInt()} MB',
              onChanged: (v) =>
                  ref.read(memoryGrowthMbProvider.notifier).state = v,
              colors: colors,
            ),
        ]),
        const SizedBox(height: 20),
        _SectionHeader('Auto Session Start', colors),
        const SizedBox(height: 8),
        _SettingsGroup(children: [
          _ToggleRow(
            'Watch for app launches',
            autoStartEnabled,
            colors,
            onChanged: (v) =>
                ref.read(autoStartEnabledProvider.notifier).state = v,
          ),
          if (autoStartEnabled) ...[
            _WatchPackageList(
              packages: watchPackages,
              onRemove: (pkg) {
                final updated = List<String>.from(watchPackages)..remove(pkg);
                ref.read(watchPackagesProvider.notifier).state = updated;
              },
              onAdd: () => _showAddPackageDialog(
                  context, ref, watchPackages, colors),
              colors: colors,
            ),
          ],
        ]),
      ],
    );
  }

  void _showAddPackageDialog(BuildContext context, WidgetRef ref,
      List<String> currentPackages, AppColors colors) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.bgSidebar,
        title: Text('Add Watch Package',
            style: TextStyle(color: colors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.sm),
          decoration: InputDecoration(
            hintText: 'com.example.app',
            hintStyle: TextStyle(color: colors.textDisabled, fontSize: TextTokens.sm),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final pkg = controller.text.trim();
              if (pkg.isNotEmpty) {
                final updated = List<String>.from(currentPackages)..add(pkg);
                ref.read(watchPackagesProvider.notifier).state = updated;
              }
              Navigator.pop(ctx);
            },
            child: Text('Add',
                style: TextStyle(color: colors.accentBlue)),
          ),
        ],
      ),
    );
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
  final ValueChanged<bool>? onChanged;
  const _ToggleRow(this.label, this.value, this.colors, {this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      label: label,
      colors: colors,
      trailing: Switch(
        value: value,
        activeColor: colors.accentBlue,
        onChanged: onChanged ?? (_) {},
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;
  final AppColors colors;
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.displayValue,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.borderSubtle.withValues(alpha: 0.3), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.sm)),
                const SizedBox(height: 2),
                Text(displayValue, style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.xs, fontFamily: monoFontFamily())),
              ],
            ),
          ),
          SizedBox(
            width: 140,
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              activeColor: colors.accentBlue,
              inactiveColor: colors.bgInput,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Divider(height: 1, color: colors.borderSubtle);
  }
}

class _WatchPackageList extends StatelessWidget {
  final List<String> packages;
  final ValueChanged<String> onRemove;
  final VoidCallback onAdd;
  final AppColors colors;
  const _WatchPackageList({
    required this.packages,
    required this.onRemove,
    required this.onAdd,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.borderSubtle.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Watched Packages',
              style: TextStyle(
                  color: colors.textSecondary, fontSize: TextTokens.xs)),
          const SizedBox(height: 4),
          if (packages.isEmpty)
            Text('No packages added',
                style: TextStyle(
                    color: colors.textDisabled,
                    fontSize: TextTokens.xs,
                    fontStyle: FontStyle.italic))
          else
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: packages.map((pkg) {
                return Chip(
                  label: Text(pkg,
                      style: TextStyle(
                          fontSize: 10, fontFamily: monoFontFamily())),
                  backgroundColor: colors.bgInput,
                  labelStyle: TextStyle(color: colors.textPrimary),
                  deleteIcon: Icon(Icons.close, size: 12, color: colors.textSecondary),
                  onDeleted: () => onRemove(pkg),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          const SizedBox(height: 4),
          TextButton.icon(
            icon: Icon(Icons.add, size: 14, color: colors.accentBlue),
            label: Text('Add Package',
                style: TextStyle(
                    color: colors.accentBlue, fontSize: TextTokens.xs)),
            onPressed: onAdd,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
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
