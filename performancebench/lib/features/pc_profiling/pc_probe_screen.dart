// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/metric_sample.dart';
import '../../core/services/pcprobe_service.dart';
import 'pc_metric_charts.dart';
import 'pc_video_settings.dart';

/// Provider for the PcprobeService singleton.
final pcprobeServiceProvider = Provider<PcprobeService>((ref) {
  return PcprobeService();
});

/// Provider for the list of received MetricSamples (ring buffer).
final pcSamplesProvider = StateProvider<List<MetricSample>>((ref) => []);

/// Provider for probe connection status.
final pcProbeStatusProvider = StateProvider<PcProbeStatus?>((ref) => null);

/// Provider for video recording state.
final pcIsRecordingProvider = StateProvider<bool>((ref) => false);
final pcRecordingDurationProvider = StateProvider<Duration>( (ref) => Duration.zero);

/// Main PC profiling screen.
///
/// Top section: Probe connection status + manual connect fields.
/// Middle section: PC metric charts (FPS, CPU, Memory, GPU, Disk, Network).
/// Bottom section: Video recording controls, marker controls.
class PcProbeScreen extends ConsumerStatefulWidget {
  const PcProbeScreen({super.key});

  @override
  ConsumerState<PcProbeScreen> createState() => _PcProbeScreenState();
}

class _PcProbeScreenState extends ConsumerState<PcProbeScreen> {
  final TextEditingController _hostController = TextEditingController(text: '127.0.0.1');
  final TextEditingController _portController = TextEditingController(text: '27184');
  final TextEditingController _processNameController = TextEditingController();
  final TextEditingController _markerNameController = TextEditingController();
  final TextEditingController _markerNoteController = TextEditingController();

  PcVideoSettings _videoSettings = const PcVideoSettings();
  bool _isConnecting = false;
  String? _errorText;
  Timer? _recordingTimer;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _processNameController.dispose();
    _markerNameController.dispose();
    _markerNoteController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _errorText = null;
    });

    try {
      final service = ref.read(pcprobeServiceProvider);
      final connection = await service.connect(
        host: _hostController.text,
        port: int.tryParse(_portController.text) ?? 27184,
      );

      // Listen for samples
      connection.metricStream.listen((sample) {
        ref.read(pcSamplesProvider.notifier).update((samples) {
          final updated = List<MetricSample>.from(samples);
          updated.add(sample);
          if (updated.length > kPcChartRingBufferSize) {
            updated.removeAt(0);
          }
          return updated;
        });
      });

      // Listen for status
      connection.statusStream.listen((status) {
        ref.read(pcProbeStatusProvider.notifier).state = status;
      });

      // Request initial status
      await connection.requestStatus();

      setState(() {
        _isConnecting = false;
        _errorText = null;
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _errorText = 'Connection failed: $e';
      });
    }
  }

  Future<void> _disconnect() async {
    final service = ref.read(pcprobeServiceProvider);
    await service.disconnect();
    ref.read(pcProbeStatusProvider.notifier).state = null;
  }

  Future<void> _startSession() async {
    final service = ref.read(pcprobeServiceProvider);
    final sessionId = 'pc_${DateTime.now().millisecondsSinceEpoch}';
    await service.startSession(sessionId);
  }

  Future<void> _stopSession() async {
    final service = ref.read(pcprobeServiceProvider);
    await service.stopSession();
  }

  Future<void> _startRecording() async {
    final service = ref.read(pcprobeServiceProvider);
    final config = PcVideoConfig(
      width: _videoSettings.width,
      height: _videoSettings.height,
      fps: _videoSettings.fps,
      bitrateKbps: _videoSettings.bitrateKbps,
      captureTarget: _videoSettings.captureTarget,
    );
    await service.startVideo(config);
    ref.read(pcIsRecordingProvider.notifier).state = true;

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(pcRecordingDurationProvider.notifier).update((state) => state + const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording() async {
    final service = ref.read(pcprobeServiceProvider);
    await service.stopVideo();
    ref.read(pcIsRecordingProvider.notifier).state = false;
    _recordingTimer?.cancel();
    ref.read(pcRecordingDurationProvider.notifier).state = Duration.zero;
  }

  Future<void> _addMarker() async {
    final name = _markerNameController.text.trim();
    if (name.isEmpty) return;
    final service = ref.read(pcprobeServiceProvider);
    await service.addMarker(name, note: _markerNoteController.text.trim());
    _markerNameController.clear();
    _markerNoteController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(pcprobeServiceProvider);
    final samples = ref.watch(pcSamplesProvider);
    final status = ref.watch(pcProbeStatusProvider);
    final isRecording = ref.watch(pcIsRecordingProvider);
    final recordingDuration = ref.watch(pcRecordingDurationProvider);
    final isConnected = service.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PC Profiling'),
        actions: [
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: 'Disconnect',
              onPressed: _disconnect,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ================================================================
            // Section 1: Probe Connection
            // ================================================================
            _buildConnectionSection(isConnected, status),

            const Divider(),

            // ================================================================
            // Section 2: Session Control
            // ================================================================
            if (isConnected) _buildSessionControl(status),

            // ================================================================
            // Section 3: Metric Charts
            // ================================================================
            if (isConnected && samples.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Live Metrics',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              PcFpsChart(samples: samples),
              PcCpuChart(samples: samples),
              PcMemoryChart(samples: samples),
              PcGpuChart(samples: samples),
              PcNetworkChart(samples: samples),
              PcDiskIoChart(samples: samples),
            ],

            // ================================================================
            // Section 4: Video Recording Controls
            // ================================================================
            if (isConnected) ...[
              const SizedBox(height: 8),
              _buildVideoControls(isRecording, recordingDuration),
            ],

            // ================================================================
            // Section 5: Marker Controls
            // ================================================================
            if (isConnected) ...[
              const SizedBox(height: 8),
              _buildMarkerControls(),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionSection(bool isConnected, PcProbeStatus? status) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected && status != null
                      ? 'Connected to ${status.processName ?? "probe"} (PID ${status.processId ?? "?"})'
                      : 'Disconnected',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (isConnected && status != null) ...[
              const SizedBox(height: 8),
              Text(
                'Host: ${service.hostLabel} | Uptime: ${_formatUptime(status.uptimeS)}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              Text(
                'Status: ${status.isRunning ? "Profiling" : "Idle"}${status.paused ? " (Paused)" : ""}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
            if (!isConnected) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Host',
                  hintText: '127.0.0.1',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: '27184',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _processNameController,
                decoration: const InputDecoration(
                  labelText: 'Process Name (for local launch)',
                  hintText: 'game.exe',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isConnecting ? null : _connect,
                    icon: _isConnecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow, size: 18),
                    label: Text(_isConnecting ? 'Connecting...' : 'Connect'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isConnecting ? null : _connect,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Auto-discover'),
                  ),
                ],
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Or launch locally: pb-pcprobe --process-name {name}',
                style: TextStyle(color: Colors.grey[600], fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionControl(PcProbeStatus? status) {
    final isRunning = status?.isRunning ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: isRunning ? null : _startSession,
            icon: const Icon(Icons.fiber_manual_record, size: 16, color: Colors.red),
            label: const Text('Start Session'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: isRunning ? _stopSession : null,
            icon: const Icon(Icons.stop, size: 16),
            label: const Text('Stop Session'),
          ),
          const SizedBox(width: 8),
          if (isRunning) ...[
            IconButton(
              onPressed: () {
                final service = ref.read(pcprobeServiceProvider);
                if (status?.paused ?? false) {
                  service.resume();
                } else {
                  service.pause();
                }
              },
              icon: Icon(status?.paused ?? false ? Icons.play_arrow : Icons.pause),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoControls(bool isRecording, Duration duration) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Video Recording',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const Spacer(),
                if (isRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fiber_manual_record, size: 10, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(duration),
                          style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: isRecording ? null : _startRecording,
                  icon: const Icon(Icons.videocam, size: 18, color: Colors.red),
                  label: const Text('Start Recording'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: isRecording ? _stopRecording : null,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Stop Recording'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkerControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Markers',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _markerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Marker Name',
                        hintText: 'boss_fight_start',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _markerNoteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _addMarker,
                    icon: const Icon(Icons.flag, size: 16),
                    label: const Text('Add Marker'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatUptime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h > 0 ? '${h}h ' : ''}${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Extension on PcprobeService for the host label display.
extension on PcprobeService {
  String get hostLabel {
    final conn = connection;
    if (conn == null) return '--';
    return '${conn.host}:${conn.port}';
  }
}
