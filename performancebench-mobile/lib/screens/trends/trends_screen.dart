// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class TrendsScreen extends StatefulWidget {
  final ApiService api;
  const TrendsScreen({super.key, required this.api});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  String _metric = 'fps';
  bool _isLoading = false;
  List<Map<String, dynamic>> _data = [];
  String? _error;

  static const _metrics = [
    {'id': 'fps', 'label': 'FPS'},
    {'id': 'cpu', 'label': 'CPU'},
    {'id': 'memory', 'label': 'Memory'},
    {'id': 'battery', 'label': 'Battery'},
    {'id': 'network', 'label': 'Network'},
  ];

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 30));
      final res = await widget.api.get(
        '/api/v1/trends/$_metric?start_date=${start.toIso8601String().split('T')[0]}&end_date=${end.toIso8601String().split('T')[0]}',
      );
      _data = List<Map<String, dynamic>>.from(res['data'] ?? []);
    } catch (e) {
      _error = e.toString();
    }
    setState(() => _isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      body: Column(
        children: [
          // Metric selector
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 6,
              children:
                  _metrics.map((m) {
                    final selected = _metric == m['id'];
                    return ChoiceChip(
                      label: Text(m['label']!),
                      selected: selected,
                      onSelected: (v) {
                        if (v) {
                          setState(() => _metric = m['id']!);
                          _load();
                        }
                      },
                    );
                  }).toList(),
            ),
          ),
          // Data
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Failed to load',
                              style: const TextStyle(color: Color(0xFFF44747))),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                    : _data.isEmpty
                    ? const Center(
                      child: Text(
                        'No trend data available.',
                        style: TextStyle(color: Color(0xFF858585)),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _data.length,
                      itemBuilder: (context, index) {
                        final pt = _data[index];
                        final appName = pt['appName'] as String? ?? '—';
                        final value = pt['value'];
                        final date = pt['timestamp'] as String? ?? '—';
                        return ListTile(
                          title: Text(appName),
                          subtitle: Text(date),
                          trailing: Text(
                            value != null
                                ? value.toString()
                                : '—',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
