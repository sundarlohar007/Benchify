// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../widgets/session_card.dart';

class SessionListScreen extends StatefulWidget {
  final ApiService api;
  const SessionListScreen({super.key, required this.api});

  @override
  State<SessionListScreen> createState() => _SessionListScreenState();
}

class _SessionListScreenState extends State<SessionListScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await widget.api.get('/api/v1/sessions?offset=0&limit=100');
      _sessions = List<Map<String, dynamic>>.from(res['data'] ?? []);
    } catch (e) {
      _error = e.toString();
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.trending_up),
            onPressed: () => context.push('/trends'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSessions,
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Failed to load sessions',
                          style: TextStyle(color: Color(0xFFF44747))),
                      TextButton(
                        onPressed: _loadSessions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
                : _sessions.isEmpty
                ? const Center(
                  child: Text(
                    'No sessions found.\nUpload from the desktop app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF858585)),
                  ),
                )
                : ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final s = _sessions[index];
                    return SessionCard(
                      session: s,
                      onTap:
                          () => context.push('/sessions/${s['id']}'),
                    );
                  },
                ),
      ),
    );
  }
}
