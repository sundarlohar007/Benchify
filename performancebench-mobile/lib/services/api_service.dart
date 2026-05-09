// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl;
  final String? apiToken;
  final http.Client _client = http.Client();

  /// Per-request timeout. Mobile networks stall silently when on flaky
  /// connections; without this the UI hangs forever on `Connect` (B-053).
  static const Duration _requestTimeout = Duration(seconds: 15);

  ApiService({required this.baseUrl, this.apiToken});

  static Future<ApiService?> fromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('server_url');
    if (serverUrl == null || serverUrl.isEmpty) return null;
    final apiToken = prefs.getString('api_token');
    return ApiService(baseUrl: serverUrl, apiToken: apiToken);
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (apiToken != null && apiToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $apiToken';
    }
    return headers;
  }

  Future<Map<String, dynamic>> get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final response =
        await _client.get(uri, headers: _headers).timeout(_requestTimeout);
    if (response.statusCode >= 400) {
      throw HttpException(
        'HTTP ${response.statusCode}: ${response.body}',
        uri: uri,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client
        .post(
          uri,
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
    if (response.statusCode >= 400) {
      throw HttpException(
        'HTTP ${response.statusCode}: ${response.body}',
        uri: uri,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Release the underlying http client. Call from any owner that
  /// supersedes this instance (the app shell does this implicitly when
  /// it rebuilds the router with a fresh `ApiService`, but a future
  /// long-running tab — e.g. a live-trends stream — should call this on
  /// dispose).
  void close() => _client.close();
}
