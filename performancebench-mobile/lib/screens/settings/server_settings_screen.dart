// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

class ServerSettingsScreen extends StatefulWidget {
  final void Function(ApiService api) onConnected;
  const ServerSettingsScreen({super.key, required this.onConnected});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isConnecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _urlController.text = prefs.getString('server_url') ?? '';
    _tokenController.text = prefs.getString('api_token') ?? '';
  }

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _error = null;
    });

    final url = _urlController.text.trim();
    final token = _tokenController.text.trim();

    if (url.isEmpty) {
      setState(() {
        _error = 'Server URL is required';
        _isConnecting = false;
      });
      return;
    }

    try {
      final api = ApiService(baseUrl: url, apiToken: token.isEmpty ? null : token);
      await api.get('/health');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_url', url);
      if (token.isNotEmpty) {
        await prefs.setString('api_token', token);
      }

      widget.onConnected(api);
    } catch (e) {
      setState(() {
        _error = 'Failed to connect: $e';
        _isConnecting = false;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Benchify Mobile')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.speed, size: 64, color: Color(0xFF007ACC)),
              const SizedBox(height: 16),
              const Text(
                'Connect to Server',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'https://192.168.1.100:3000',
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tokenController,
                decoration: const InputDecoration(
                  labelText: 'API Token',
                  hintText: 'pb_...',
                ),
                obscureText: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF44747).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFF44747)),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isConnecting ? null : _connect,
                child: Text(
                  _isConnecting ? 'Connecting...' : 'Connect',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
