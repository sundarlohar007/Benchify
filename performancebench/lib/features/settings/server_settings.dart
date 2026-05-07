// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/theme.dart';
import '../../core/services/api_service.dart';

/// Server settings widget — Server URL, API Token, and Test Connection (D-29, D-34).
/// Used as a section inside the main SettingsScreen.
class ServerSettingsWidget extends StatefulWidget {
  final AppColors colors;

  const ServerSettingsWidget({super.key, required this.colors});

  @override
  State<ServerSettingsWidget> createState() => _ServerSettingsWidgetState();
}

class _ServerSettingsWidgetState extends State<ServerSettingsWidget> {
  final _urlController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _obscureToken = true;
  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _urlController.text = prefs.getString('server_url') ?? '';
    _tokenController.text = prefs.getString('api_token') ?? '';
  }

  Future<void> _saveUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', value.trim());
  }

  Future<void> _saveToken(String value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value.isNotEmpty) {
      await prefs.setString('api_token', value.trim());
    } else {
      await prefs.remove('api_token');
    }
  }

  /// Test connection to server (GET /health).
  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });

    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testing = false;
        _testResult = 'Enter a server URL first';
        _testSuccess = false;
      });
      return;
    }

    try {
      final api = ApiService(baseUrl: url, apiToken: _tokenController.text.trim());
      final response = await api.get('/health');

      if (response.isSuccess) {
        setState(() {
          _testing = false;
          _testResult = 'Connected — server is healthy';
          _testSuccess = true;
        });
        await _saveUrl(url);
        await _saveToken(_tokenController.text.trim());
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        setState(() {
          _testing = false;
          _testResult = 'Connected but authentication failed — check your API token';
          _testSuccess = false;
        });
      } else {
        setState(() {
          _testing = false;
          _testResult = 'Server returned status ${response.statusCode}';
          _testSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _testing = false;
        _testResult = 'Connection failed: $e';
        _testSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          'SERVER',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colors.borderSubtle, width: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              // Server URL field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colors.borderSubtle.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Server URL',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: TextTokens.sm,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _urlController,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: TextTokens.sm,
                              fontFamily: monoFontFamily(),
                            ),
                            decoration: InputDecoration(
                              hintText: 'https://192.168.1.100:3000',
                              hintStyle: TextStyle(
                                color: colors.textDisabled,
                                fontSize: TextTokens.sm,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            onChanged: _saveUrl,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // API Token field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colors.borderSubtle.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'API Token',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: TextTokens.sm,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _tokenController,
                            obscureText: _obscureToken,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: TextTokens.sm,
                              fontFamily: monoFontFamily(),
                            ),
                            decoration: InputDecoration(
                              hintText: 'pb_...',
                              hintStyle: TextStyle(
                                color: colors.textDisabled,
                                fontSize: TextTokens.sm,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureToken ? Icons.visibility_off : Icons.visibility,
                                  size: 16,
                                  color: colors.textDisabled,
                                ),
                                onPressed: () {
                                  setState(() => _obscureToken = !_obscureToken);
                                },
                              ),
                            ),
                            onChanged: _saveToken,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Test connection button + result
              Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _testing ? null : _testConnection,
                        icon: _testing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                _testSuccess ? Icons.check_circle : Icons.wifi_tethering,
                                size: 16,
                              ),
                        label: Text(
                          _testing ? 'Testing...' : 'Test Connection',
                          style: TextStyle(fontSize: TextTokens.sm),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accentBlue,
                          foregroundColor: colors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    if (_testResult != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _testSuccess ? Icons.check_circle : Icons.error,
                            size: 14,
                            color: _testSuccess ? colors.accentSuccess : colors.accentDanger,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _testResult!,
                              style: TextStyle(
                                color: _testSuccess ? colors.accentSuccess : colors.accentDanger,
                                fontSize: TextTokens.xs,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
