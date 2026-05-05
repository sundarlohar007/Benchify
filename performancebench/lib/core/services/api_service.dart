// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Base HTTP client for the PerformanceBench team server REST API.
///
/// Reads server URL and API token from SharedPreferences (D-29, D-34).
/// All requests include `Authorization: Bearer <apiToken>` header (D-22).
class ApiService {
  final String baseUrl;
  final String? apiToken;

  ApiService({required this.baseUrl, this.apiToken});

  /// Create an ApiService from SharedPreferences settings.
  /// Returns null if server URL is not configured.
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

  /// Send a GET request to [path] (relative to baseUrl).
  Future<ApiResponse> get(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final client = HttpClient();
      try {
        final request = await client.getUrl(uri);
        _headers.forEach((k, v) => request.headers.set(k, v));
        final response = await request.close().timeout(const Duration(seconds: 30));
        final body = await response.transform(utf8.decoder).join();
        return ApiResponse(
          statusCode: response.statusCode,
          body: jsonDecode(body),
        );
      } finally {
        client.close();
      }
    } on SocketException catch (e) {
      return ApiResponse(statusCode: -1, body: {'error': 'Connection failed: $e'});
    } on TimeoutException {
      return ApiResponse(statusCode: -1, body: {'error': 'Request timed out'});
    } on HttpException catch (e) {
      return ApiResponse(statusCode: -1, body: {'error': 'HTTP error: $e'});
    }
  }

  /// Send a POST request with JSON body.
  Future<ApiResponse> post(String path, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final client = HttpClient();
      try {
        final request = await client.postUrl(uri);
        _headers.forEach((k, v) => request.headers.set(k, v));
        final jsonBody = utf8.encode(jsonEncode(body));
        request.add(jsonBody);
        final response = await request.close().timeout(const Duration(seconds: 30));
        final respBody = await response.transform(utf8.decoder).join();
        return ApiResponse(
          statusCode: response.statusCode,
          body: jsonDecode(respBody),
        );
      } finally {
        client.close();
      }
    } on SocketException catch (e) {
      return ApiResponse(statusCode: -1, body: {'error': 'Connection failed: $e'});
    } on TimeoutException {
      return ApiResponse(statusCode: -1, body: {'error': 'Request timed out'});
    } on HttpException catch (e) {
      return ApiResponse(statusCode: -1, body: {'error': 'HTTP error: $e'});
    }
  }

  /// Send a DELETE request.
  Future<ApiResponse> delete(String path) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final client = HttpClient();
      try {
        final request = await client.deleteUrl(uri);
        _headers.forEach((k, v) => request.headers.set(k, v));
        final response = await request.close().timeout(const Duration(seconds: 30));
        final body = await response.transform(utf8.decoder).join();
        return ApiResponse(
          statusCode: response.statusCode,
          body: body.isNotEmpty ? jsonDecode(body) : {},
        );
      } finally {
        client.close();
      }
    } on SocketException catch (e) {
      return ApiResponse(statusCode: -1, body: {'error': 'Connection failed: $e'});
    } on TimeoutException {
      return ApiResponse(statusCode: -1, body: {'error': 'Request timed out'});
    } on HttpException catch (e) {
      return ApiResponse(statusCode: -1, body: {'error': 'HTTP error: $e'});
    }
  }

  /// Send a multipart POST request for session upload (D-20, D-21).
  /// [metadata] — JSON string of the upload payload.
  /// [screenshotPaths] — list of file paths for screenshots.
  /// [onProgress] — progress callback (bytes sent / total bytes).
  Future<ApiResponse> uploadMultipart(
    String path, {
    required String metadata,
    required List<String> screenshotPaths,
    void Function(double progress, int bytesSent, int totalBytes)? onProgress,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final client = HttpClient();
      try {
        final request = await client.postUrl(uri);

        // Headers (Authorization only — Content-Type set by multipart boundary)
        if (apiToken != null && apiToken!.isNotEmpty) {
          request.headers.set('Authorization', 'Bearer $apiToken');
        }

        // Build multipart body
        final boundary = 'boundary-${DateTime.now().millisecondsSinceEpoch}';
        request.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');

        // Calculate total size for progress
        var totalBytes = utf8.encode(metadata).length + 512; // metadata + overhead
        final screenshotBytesList = <List<int>>[];
        for (final p in screenshotPaths) {
          try {
            final file = File(p);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              totalBytes += bytes.length + 512;
              screenshotBytesList.add(bytes);
            }
          } catch (_) {
            // Skip missing files
          }
        }

        // Write multipart body
        final sink = await request as dynamic; // HttpClientRequest
        final buffer = <int>[];

        // Metadata part
        void add(String s) => buffer.addAll(utf8.encode(s));

        add('--$boundary\r\n');
        add('Content-Disposition: form-data; name="metadata"\r\n');
        add('Content-Type: application/json\r\n\r\n');
        buffer.addAll(utf8.encode(metadata));
        add('\r\n');

        var bytesSent = buffer.length;
        onProgress?.call(bytesSent / totalBytes, bytesSent, totalBytes);

        // Screenshot parts
        for (var i = 0; i < screenshotPaths.length; i++) {
          final path = screenshotPaths[i];
          final filename = path.split(Platform.pathSeparator).last;
          add('--$boundary\r\n');
          add('Content-Disposition: form-data; name="screenshots"; filename="$filename"\r\n');
          add('Content-Type: image/png\r\n\r\n');

          // Write header to request first
          request.add(buffer);
          buffer.clear();

          // Write file bytes
          if (i < screenshotBytesList.length) {
            request.add(screenshotBytesList[i]);
          }
          add('\r\n');
        }

        // Final boundary
        add('--$boundary--\r\n');
        request.add(buffer);

        final response = await request.close().timeout(const Duration(minutes: 10));
        final body = await response.transform(utf8.decoder).join();
        return ApiResponse(
          statusCode: response.statusCode,
          body: jsonDecode(body),
        );
      } finally {
        client.close();
      }
    } on SocketException catch (e) {
      return ApiResponse(statusCode: -1, body: {'error': 'Connection failed: $e'});
    } on TimeoutException {
      return ApiResponse(statusCode: -1, body: {'error': 'Request timed out'});
    } on HttpException catch (e) {
      return ApiResponse(statusCode: -1, body: {'error': 'HTTP error: $e'});
    }
  }
}

/// Response from an API call.
class ApiResponse {
  final int statusCode;
  final dynamic body;

  const ApiResponse({required this.statusCode, required this.body});

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isConflict => statusCode == 409;
  bool get isError => statusCode < 0 || statusCode >= 400;
}
