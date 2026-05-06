// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// PluginInstallCard — Per-engine install/remove widget.
// Per D-04: Shows engine icon, project info, status badge, install/remove actions.

import 'package:flutter/material.dart';
import 'engine_detector.dart';
import '../../core/services/plugin_install_service.dart';

/// A card widget representing a detected game engine project.
/// Shows install status, version info, and install/remove actions.
class PluginInstallCard extends StatefulWidget {
  final DetectedEngine engine;
  final VoidCallback onChanged;

  const PluginInstallCard({
    super.key,
    required this.engine,
    required this.onChanged,
  });

  @override
  State<PluginInstallCard> createState() => _PluginInstallCardState();
}

class _PluginInstallCardState extends State<PluginInstallCard> {
  bool _isInstalling = false;
  bool _isRemoving = false;
  String? _statusMessage;

  @override
  Widget build(BuildContext context) {
    final engine = widget.engine;
    final status = _getStatus();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Engine icon
            _buildEngineIcon(engine.engineType),
            const SizedBox(width: 12),

            // Project info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    engine.projectName,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${engine.engineDisplayName} project',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    engine.path,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withOpacity(0.6),
                        ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusMessage!.contains('failed')
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Status badge
            _buildStatusBadge(status),
            const SizedBox(width: 8),

            // Action button
            _buildActionButton(status),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineIcon(EngineType type) {
    IconData icon;
    Color color;

    switch (type) {
      case EngineType.unity:
        icon = Icons.view_in_ar;
        color = Colors.grey.shade700;
      case EngineType.unreal:
        icon = Icons.sports_esports;
        color = Colors.blue.shade700;
      case EngineType.godot:
        icon = Icons.science;
        color = Colors.teal.shade600;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _buildStatusBadge(_Status status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case _Status.installed:
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        label = 'Installed v${widget.engine.pluginVersion ?? "3.0.0"}';
      case _Status.updateAvailable:
        bgColor = Colors.amber.shade100;
        textColor = Colors.amber.shade900;
        label = 'Update Available';
      case _Status.notInstalled:
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        label = 'Not Installed';
      case _Status.installing:
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        label = 'Installing...';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildActionButton(_Status status) {
    if (_isInstalling || _isRemoving) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    switch (status) {
      case _Status.notInstalled:
        return IconButton(
          icon: const Icon(Icons.download, size: 20),
          tooltip: 'Install Benchify Plugin',
          onPressed: _install,
        );
      case _Status.installed:
      case _Status.updateAvailable:
        return IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: 'Remove Benchify Plugin',
          onPressed: _confirmRemove,
        );
      case _Status.installing:
        return const SizedBox.shrink();
    }
  }

  _Status _getStatus() {
    if (_isInstalling) return _Status.installing;
    if (!widget.engine.hasPluginInstalled) return _Status.notInstalled;
    // TODO: Compare versions for update detection
    return _Status.installed;
  }

  Future<void> _install() async {
    setState(() {
      _isInstalling = true;
      _statusMessage = null;
    });

    final result = await PluginInstallService.installPlugin(widget.engine);

    setState(() {
      _isInstalling = false;
      _statusMessage = result.message;
    });

    widget.onChanged();
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Benchify Plugin?'),
        content: Text(
            'Remove Benchify from ${widget.engine.projectName}?\n\n'
            'This deletes plugin files. Marker instrumentation in your '
            'code will break until reinstalled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _remove();
    }
  }

  Future<void> _remove() async {
    setState(() {
      _isRemoving = true;
      _statusMessage = null;
    });

    final result = await PluginInstallService.removePlugin(widget.engine);

    setState(() {
      _isRemoving = false;
      _statusMessage = result.message;
    });

    widget.onChanged();
  }
}

enum _Status { notInstalled, installed, updateAvailable, installing }
