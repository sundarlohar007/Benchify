// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// UnifiedInstallerScreen — Main "Plugins" screen in desktop app.
// Per D-04: Scans for game engine projects, shows detected engines,
// offers one-click install/remove, per-engine standalone distribution links.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'engine_detector.dart';
import 'plugin_install_card.dart';
import '../../core/services/plugin_install_service.dart';

/// Main screen for the Benchify Plugins section of the desktop app.
/// Allows users to scan for Unity/Unreal/Godot projects and install
/// the Benchify profiling plugin into each.
class UnifiedInstallerScreen extends StatefulWidget {
  const UnifiedInstallerScreen({super.key});

  @override
  State<UnifiedInstallerScreen> createState() => _UnifiedInstallerScreenState();
}

class _UnifiedInstallerScreenState extends State<UnifiedInstallerScreen> {
  List<DetectedEngine> _detectedEngines = [];
  bool _isScanning = false;
  String? _scanError;
  String _customPath = '';
  EngineType? _filterType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugins'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-scan',
            onPressed: _isScanning ? null : _scan,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Scan Section ──────────────────────────
          _buildScanSection(),

          // ── Filter Tabs ───────────────────────────
          _buildFilterTabs(),

          // ── Results List ───────────────────────────
          Expanded(child: _buildResultsList()),

          // ── Standalone Distribution ────────────────
          if (_detectedEngines.isEmpty && !_isScanning)
            _buildStandaloneSection(),
        ],
      ),
    );
  }

  // ── Scan Section ───────────────────────────────────

  Widget _buildScanSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Scan button + custom path
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: _isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_isScanning ? 'Scanning...' : 'Scan for Game Engines'),
                  onPressed: _isScanning ? null : _scan,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Custom path input
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Custom directory path...',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.folder, size: 18),
                  ),
                  onChanged: (v) => _customPath = v,
                  onSubmitted: (_) => _scan(),
                ),
              ),
            ],
          ),

          // Error message
          if (_scanError != null) ...[
            const SizedBox(height: 8),
            Text(
              _scanError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  // ── Filter Tabs ────────────────────────────────────

  Widget _buildFilterTabs() {
    if (_detectedEngines.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildFilterChip('All', null),
          const SizedBox(width: 6),
          _buildFilterChip('Unity', EngineType.unity),
          const SizedBox(width: 6),
          _buildFilterChip('Unreal', EngineType.unreal),
          const SizedBox(width: 6),
          _buildFilterChip('Godot', EngineType.godot),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, EngineType? type) {
    final isSelected = _filterType == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = selected ? type : null;
        });
      },
      visualDensity: VisualDensity.compact,
    );
  }

  // ── Results List ───────────────────────────────────

  Widget _buildResultsList() {
    final filtered = _filterType == null
        ? _detectedEngines
        : _detectedEngines
            .where((e) => e.engineType == _filterType)
            .toList();

    if (_isScanning) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning for game engine projects...'),
          ],
        ),
      );
    }

    if (_detectedEngines.isEmpty && !_isScanning) {
      return const SizedBox.shrink(); // Empty state handled by standalone section
    }

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No ${_filterType?.name ?? ""} projects detected.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filtered.length} project${filtered.length == 1 ? '' : 's'} found',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (filtered.any((e) => !e.hasPluginInstalled))
                TextButton.icon(
                  icon: const Icon(Icons.download_for_offline, size: 16),
                  label: const Text('Install All'),
                  onPressed: () => _installAll(filtered),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) => PluginInstallCard(
              engine: filtered[index],
              onChanged: _scan,
            ),
          ),
        ),
      ],
    );
  }

  // ── Standalone Distribution ────────────────────────

  Widget _buildStandaloneSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Standalone Distribution',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'If the one-click installer doesn\'t work, install plugins manually:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),

          // Unity
          _buildDistroCard(
            'Unity (UPM)',
            'Add via Unity Package Manager git URL:',
            'https://github.com/sundarlohar007/Benchify.git?path=/benchify-unity-plugin',
            Icons.view_in_ar,
          ),
          const SizedBox(height: 8),

          // Unreal
          _buildDistroCard(
            'Unreal Engine',
            'Clone into your project\'s Plugins/Benchify/ folder:',
            'git clone https://github.com/sundarlohar007/Benchify.git',
            Icons.sports_esports,
          ),
          const SizedBox(height: 8),

          // Godot
          _buildDistroCard(
            'Godot Engine',
            'Copy addons to your project and enable in Project Settings:',
            'https://github.com/sundarlohar007/Benchify/tree/main/benchify-godot-plugin',
            Icons.science,
          ),
        ],
      ),
    );
  }

  Widget _buildDistroCard(
    String engine,
    String description,
    String url,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(engine,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(description,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            url,
                            style: const TextStyle(
                                fontSize: 11, fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          tooltip: 'Copy to clipboard',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: url));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied to clipboard'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────

  Future<void> _scan() async {
    setState(() {
      _isScanning = true;
      _scanError = null;
    });

    try {
      final paths = _customPath.isNotEmpty ? [_customPath] : null;
      final engines = await EngineDetector.scan(searchPaths: paths);

      setState(() {
        _detectedEngines = engines;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _scanError = 'Scan failed: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _installAll(List<DetectedEngine> engines) async {
    final notInstalled = engines.where((e) => !e.hasPluginInstalled).toList();

    if (notInstalled.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All plugins already installed.')),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Install All Plugins?'),
        content: Text(
          'Install Benchify plugins into ${notInstalled.length} '
          'project${notInstalled.length == 1 ? '' : 's'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Install All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final engine in notInstalled) {
      await PluginInstallService.installPlugin(engine);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Installed Benchify into ${notInstalled.length} project${notInstalled.length == 1 ? '' : 's'}.'),
        ),
      );
    }

    _scan(); // Refresh status
  }
}

