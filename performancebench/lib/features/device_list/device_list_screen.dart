// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';
import '../../core/models/device.dart';
import '../../core/services/adb_service.dart';
import 'device_card.dart';

/// Provider for the list of discovered devices.
final deviceListProvider = FutureProvider<List<Device>>((ref) async {
  final adb = await AdbService.create();
  return adb.discoverDevices();
});

/// Native navigation section identifier (VS Code-style activity bar).
enum NavSection { devices, history, compare, settings }

/// VS Code-style device list screen — activity bar, collapsible sidebar,
/// and main content area (UNIFIED-SPEC §9.2).
class DeviceListScreen extends ConsumerStatefulWidget {
  const DeviceListScreen({super.key});

  @override
  ConsumerState<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends ConsumerState<DeviceListScreen> {
  NavSection _activeSection = NavSection.devices;

  void _onSectionTap(NavSection section) {
    setState(() => _activeSection = section);
    // Navigation is handled by GoRouter for major views;
    // activity bar switches sidebar content within this shell.
    switch (section) {
      case NavSection.history:
        // Navigate via GoRouter
        break;
      case NavSection.compare:
        break;
      case NavSection.settings:
        break;
      case NavSection.devices:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final devicesAsync = ref.watch(deviceListProvider);

    return Scaffold(
      body: Row(
        children: [
          // Activity bar (48px, leftmost strip)
          _buildActivityBar(colors),
          // Sidebar (280px — collapsible via Ctrl+B in Wave 2)
          _buildSidebar(colors, devicesAsync),
          // Main content area
          Expanded(child: _buildMainContent(colors)),
        ],
      ),
    );
  }

  Widget _buildActivityBar(AppColors colors) {
    return Container(
      width: 48,
      color: colors.bgSidebar,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _ActivityIcon(
            icon: Icons.devices,
            label: 'Devices',
            isActive: _activeSection == NavSection.devices,
            colors: colors,
            onTap: () => _onSectionTap(NavSection.devices),
          ),
          _ActivityIcon(
            icon: Icons.history,
            label: 'History',
            isActive: _activeSection == NavSection.history,
            colors: colors,
            onTap: () => _onSectionTap(NavSection.history),
          ),
          _ActivityIcon(
            icon: Icons.compare_arrows,
            label: 'Compare',
            isActive: _activeSection == NavSection.compare,
            colors: colors,
            onTap: () => _onSectionTap(NavSection.compare),
          ),
          _ActivityIcon(
            icon: Icons.settings,
            label: 'Settings',
            isActive: _activeSection == NavSection.settings,
            colors: colors,
            onTap: () => _onSectionTap(NavSection.settings),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(
    AppColors colors,
    AsyncValue<List<Device>> devicesAsync,
  ) {
    return Container(
      width: 280,
      color: colors.bgSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Explorer header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text(
                  'EXPLORER',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: TextTokens.xs,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                _sidebarButton(Icons.refresh, colors, () => ref.refresh(deviceListProvider)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Devices section
          _SidebarSection(
            title: 'DEVICES',
            colors: colors,
            initiallyExpanded: true,
            children: devicesAsync.when(
              data: (devices) => devices
                  .map((d) => DeviceCard(
                        device: d,
                        colors: colors,
                        onStart: () {
                          // Navigate to app picker
                        },
                      ))
                  .toList(),
              loading: () => [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Scanning for devices...',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: TextTokens.sm,
                    ),
                  ),
                ),
              ],
              error: (err, _) => [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'ADB not available',
                    style: TextStyle(
                      color: colors.accentDanger,
                      fontSize: TextTokens.sm,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Recent sessions section
          _SidebarSection(
            title: 'RECENT SESSIONS',
            colors: colors,
            initiallyExpanded: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'No sessions recorded yet',
                  style: TextStyle(
                    color: colors.textDisabled,
                    fontSize: TextTokens.sm,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(AppColors colors) {
    return Container(
      color: colors.bgBase,
      child: const Center(
        child: Text(
          'Select a device to start profiling',
          style: TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _sidebarButton(IconData icon, AppColors colors, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 14, color: colors.textSecondary),
      ),
    );
  }
}

// =============================================================================
// Activity Icon
// =============================================================================

class _ActivityIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final AppColors colors;
  final VoidCallback onTap;

  const _ActivityIcon({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isActive ? colors.accentBlue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Icon(
            icon,
            color: isActive ? colors.textPrimary : colors.textSecondary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Collapsible Sidebar Section
// =============================================================================

class _SidebarSection extends StatefulWidget {
  final String title;
  final AppColors colors;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _SidebarSection({
    required this.title,
    required this.colors,
    required this.initiallyExpanded,
    required this.children,
  });

  @override
  State<_SidebarSection> createState() => _SidebarSectionState();
}

class _SidebarSectionState extends State<_SidebarSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 16,
                  color: widget.colors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.title,
                  style: TextStyle(
                    color: widget.colors.textSecondary,
                    fontSize: TextTokens.xs,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...widget.children,
      ],
    );
  }
}
