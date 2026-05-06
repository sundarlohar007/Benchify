// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../core/models/metric_sample.dart';

/// Video recording configuration for PC profiling.
class PcVideoSettings {
  /// Video resolution (native, 1080p, 720p, 480p).
  final PcVideoResolution resolution;

  /// Target FPS (30 or 60).
  final int fps;

  /// Encoding bitrate in Mbps (4, 8, 12, 20).
  final int bitrateMbps;

  /// Capture method: low-overhead or highest compatibility.
  final PcCaptureMethod captureMethod;

  /// Whether to use GPU hardware encoding.
  final bool useGpuEncoding;

  const PcVideoSettings({
    this.resolution = PcVideoResolution.p1080,
    this.fps = 30,
    this.bitrateMbps = 8,
    this.captureMethod = PcCaptureMethod.lowOverhead,
    this.useGpuEncoding = true,
  });

  /// Estimated disk space usage per hour in GB.
  ///
  /// Formula: bitrate (Mbps) / 8 * 3600 / 1000 = GB/hour
  double get estimatedGbPerHour => (bitrateMbps * 3600) / (8 * 1000);

  /// Actual width based on resolution.
  int get width {
    switch (resolution) {
      case PcVideoResolution.native:
        return 0; // Use native
      case PcVideoResolution.p1080:
        return 1920;
      case PcVideoResolution.p720:
        return 1280;
      case PcVideoResolution.p480:
        return 854;
    }
  }

  /// Actual height based on resolution.
  int get height {
    switch (resolution) {
      case PcVideoResolution.native:
        return 0; // Use native
      case PcVideoResolution.p1080:
        return 1080;
      case PcVideoResolution.p720:
        return 720;
      case PcVideoResolution.p480:
        return 480;
    }
  }

  /// Bitrate in Kbps (for IPC commands).
  int get bitrateKbps => bitrateMbps * 1000;

  /// Capture target string for IPC.
  String get captureTarget => captureMethod == PcCaptureMethod.lowOverhead
      ? 'full_screen'
      : 'full_screen';
}

enum PcVideoResolution {
  native,
  p1080,
  p720,
  p480;
}

enum PcCaptureMethod {
  /// Platform-native low-overhead capture (Windows.Graphics.Capture, AVScreenCaptureKit, kmsgrab)
  lowOverhead,

  /// Highest compatibility (desktop duplication, ffmpeg x11grab)
  highCompatibility;
}

/// Video configuration UI widget for PC profiling.
class PcVideoSettingsWidget extends StatefulWidget {
  final PcVideoSettings initialSettings;
  final ValueChanged<PcVideoSettings> onChanged;

  const PcVideoSettingsWidget({
    super.key,
    this.initialSettings = const PcVideoSettings(),
    required this.onChanged,
  });

  @override
  State<PcVideoSettingsWidget> createState() => _PcVideoSettingsWidgetState();
}

class _PcVideoSettingsWidgetState extends State<PcVideoSettingsWidget> {
  late PcVideoSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
  }

  void _update(PcVideoSettings Function(PcVideoSettings) updater) {
    setState(() {
      _settings = updater(_settings);
      widget.onChanged(_settings);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Video Recording Settings',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),

            // Resolution dropdown
            _buildDropdown<PcVideoResolution>(
              label: 'Resolution',
              value: _settings.resolution,
              items: PcVideoResolution.values,
              display: (r) => switch (r) {
                PcVideoResolution.native => 'Native (auto-detect)',
                PcVideoResolution.p1080 => '1080p (1920x1080)',
                PcVideoResolution.p720 => '720p (1280x720)',
                PcVideoResolution.p480 => '480p (854x480)',
              },
              onChanged: (v) => _update((s) => PcVideoSettings(
                    resolution: v,
                    fps: s.fps,
                    bitrateMbps: s.bitrateMbps,
                    captureMethod: s.captureMethod,
                    useGpuEncoding: s.useGpuEncoding,
                  )),
            ),

            // FPS dropdown
            _buildDropdown<int>(
              label: 'Frame Rate',
              value: _settings.fps,
              items: const [30, 60],
              display: (f) => '$f FPS',
              onChanged: (v) => _update((s) => PcVideoSettings(
                    resolution: s.resolution,
                    fps: v,
                    bitrateMbps: s.bitrateMbps,
                    captureMethod: s.captureMethod,
                    useGpuEncoding: s.useGpuEncoding,
                  )),
            ),

            // Bitrate dropdown
            _buildDropdown<int>(
              label: 'Bitrate',
              value: _settings.bitrateMbps,
              items: const [4, 8, 12, 20],
              display: (b) => '$b Mbps',
              onChanged: (v) => _update((s) => PcVideoSettings(
                    resolution: s.resolution,
                    fps: s.fps,
                    bitrateMbps: v,
                    captureMethod: s.captureMethod,
                    useGpuEncoding: s.useGpuEncoding,
                  )),
            ),

            // Capture method
            _buildDropdown<PcCaptureMethod>(
              label: 'Capture Method',
              value: _settings.captureMethod,
              items: PcCaptureMethod.values,
              display: (m) => switch (m) {
                PcCaptureMethod.lowOverhead => '${_platformCaptureName()} (low overhead)',
                PcCaptureMethod.highCompatibility =>
                    'Desktop duplication (highest compat)',
              },
              onChanged: (v) => _update((s) => PcVideoSettings(
                    resolution: s.resolution,
                    fps: s.fps,
                    bitrateMbps: s.bitrateMbps,
                    captureMethod: v,
                    useGpuEncoding: s.useGpuEncoding,
                  )),
            ),

            // GPU encoding toggle
            SwitchListTile(
              title: const Text('GPU Hardware Encoding'),
              subtitle: Text(
                'Use hardware encoder (NVENC / AMF / VideoToolbox) when available',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              value: _settings.useGpuEncoding,
              onChanged: (v) => _update((s) => PcVideoSettings(
                    resolution: s.resolution,
                    fps: s.fps,
                    bitrateMbps: s.bitrateMbps,
                    captureMethod: s.captureMethod,
                    useGpuEncoding: v,
                  )),
              contentPadding: EdgeInsets.zero,
            ),

            const Divider(height: 32),

            // Disk space estimate
            _buildDiskEstimate(),

            // Warning text
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Video will use ~${_settings.estimatedGbPerHour.toStringAsFixed(1)} GB/hour '
                'at ${_resolutionLabel(_settings.resolution)} ${_settings.bitrateMbps} Mbps',
                style: TextStyle(
                  color: Colors.amber[300],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) display,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              underline: const SizedBox(),
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Text(
                    display(item),
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiskEstimate() {
    return Row(
      children: [
        const Icon(Icons.storage, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          'Est. ~${_settings.estimatedGbPerHour.toStringAsFixed(1)} GB/hour',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  String _resolutionLabel(PcVideoResolution res) {
    return switch (res) {
      PcVideoResolution.native => 'Native',
      PcVideoResolution.p1080 => '1080p',
      PcVideoResolution.p720 => '720p',
      PcVideoResolution.p480 => '480p',
    };
  }

  String _platformCaptureName() {
    if (Platform.isWindows) return 'Windows.Graphics.Capture';
    if (Platform.isMacOS) return 'AVScreenCaptureKit';
    if (Platform.isLinux) return 'ffmpeg kmsgrab/x11grab';
    return 'Platform capture';
  }
}
