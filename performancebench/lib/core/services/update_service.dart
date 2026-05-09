// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:convert';
import 'dart:io';

/// Update check result.
class UpdateInfo {
  final String version;
  final String releaseUrl;
  final String? releaseNotes;

  const UpdateInfo({
    required this.version,
    required this.releaseUrl,
    this.releaseNotes,
  });
}

/// Checks GitHub Releases for new versions.
///
/// Only outbound network connection in the app (D-25).
/// Single request per launch, cached for 6 hours.
/// No binary download — links to GitHub Releases page only.
class UpdateService {
  static const _repoUrl =
      'https://api.github.com/repos/sundarlohar007/Benchify/releases/latest';
  // Tracks the published release line. Bump in lockstep with new git tags.
  // TODO(audit S-19 build/CI): replace with `package_info_plus`-derived version
  // so this can't drift from the build number. Until then, stale here means
  // the update banner wrongly says "you're up to date" — exactly the failure
  // mode B-024 documents.
  static const _currentVersion = '0.1.1';
  static const _cacheDuration = Duration(hours: 6);

  DateTime? _lastCheck;
  UpdateInfo? _cachedUpdate;

  /// Check for available updates.
  ///
  /// Returns [UpdateInfo] if a newer version is available, null otherwise.
  /// Never throws — errors return null silently.
  Future<UpdateInfo?> checkForUpdate() async {
    // Use cached result if recent
    if (_lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < _cacheDuration) {
      return _cachedUpdate;
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(_repoUrl));
      request.headers.set('User-Agent', 'PerformanceBench/1.0.0');
      request.headers.set('Accept', 'application/vnd.github.v3+json');

      final response = await request.close().timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tagName = (json['tag_name'] as String?)?.replaceFirst('v', '');

      if (tagName == null) return null;

      // Version comparison
      if (_compareVersions(tagName, _currentVersion) > 0) {
        _cachedUpdate = UpdateInfo(
          version: tagName,
          releaseUrl: json['html_url'] as String? ?? _repoUrl,
          releaseNotes: json['body'] as String?,
        );
        _lastCheck = DateTime.now();
        return _cachedUpdate;
      }

      _lastCheck = DateTime.now();
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Compare semver strings. Returns > 0 if a > b.
  ///
  /// Strips a trailing pre-release tag (`-rc.1`, `-beta`, …) before parsing
  /// so `0.1.1` vs `0.1.1-rc.6` doesn't break on `int.tryParse('1-rc')`.
  /// Pre-release ordering itself is intentionally not honoured — the update
  /// banner exists to flag a newer release line, not to differentiate rc vs
  /// final. Tightening that semantic is queued for S-20.
  int _compareVersions(String a, String b) {
    final aParts = _stripPreRelease(a).split('.').map(int.tryParse).toList();
    final bParts = _stripPreRelease(b).split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final aVal = i < aParts.length ? (aParts[i] ?? 0) : 0;
      final bVal = i < bParts.length ? (bParts[i] ?? 0) : 0;
      if (aVal != bVal) return aVal - bVal;
    }
    return 0;
  }

  static String _stripPreRelease(String v) {
    final dash = v.indexOf('-');
    return dash < 0 ? v : v.substring(0, dash);
  }
}
