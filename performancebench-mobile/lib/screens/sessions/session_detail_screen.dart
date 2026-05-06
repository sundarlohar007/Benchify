// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

class SessionDetailScreen extends StatefulWidget {
  final ApiService api;
  final String sessionId;
  const SessionDetailScreen({
    super.key,
    required this.api,
    required this.sessionId,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  Map<String, dynamic>? _session;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      _session = await widget.api.get(
        '/api/v1/sessions/${widget.sessionId}',
      );
    } catch (e) {
      _error = e.toString();
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final appName =
        _session?['app_name'] as String? ?? 'Unknown';
    final deviceId = _session?['device_id'] as String? ?? '—';
    final startedAt = _session?['started_at'];
    final durationMs = _session?['duration_ms'] as int?;

    final dateStr = _formatDate(startedAt);
    final durationStr =
        durationMs != null ? _formatDuration(durationMs) : '—';

    return Scaffold(
      appBar: AppBar(title: Text(appName)),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Failed to load session',
                        style: const TextStyle(color: Color(0xFFF44747))),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              )
              : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _StatCard('App', appName),
                  _StatCard('Device', deviceId),
                  _StatCard('Date', dateStr),
                  _StatCard('Duration', durationStr),
                  const SizedBox(height: 16),
                  Text(
                    'Session ID: ${widget.sessionId}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5A5A5A),
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Full details available on the web dashboard.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
    );
  }

  String _formatDate(dynamic val) {
    if (val == null) return '—';
    try {
      final dt = DateTime.parse(val.toString());
      return DateFormat('MMM d, yyyy HH:mm').format(dt);
    } catch (_) {
      return val.toString();
    }
  }

  String _formatDuration(int ms) {
    final sec = ms ~/ 1000;
    final min = sec ~/ 60;
    final hr = min ~/ 60;
    if (hr > 0) return '${hr}h ${min % 60}m ${sec % 60}s';
    if (min > 0) return '${min}m ${sec % 60}s';
    return '${sec}s';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF858585),
                fontSize: 12)),
            Text(value, style: const TextStyle(fontSize: 14,
                fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
