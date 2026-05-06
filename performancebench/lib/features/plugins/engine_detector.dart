// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// EngineDetector — Scans filesystem for Unity/Unreal/Godot projects.
// Per D-04: Detection heuristics based on project directory structure.
// Per §F: No network calls during scan — fully offline file detection.

import 'dart:io';
import 'package:path/path.dart' as p;

/// The type of game engine detected.
enum EngineType { unity, unreal, godot }

/// A detected game engine project on the local filesystem.
class DetectedEngine {
  final String path;
  final EngineType engineType;
  final String projectName;
  final bool hasPluginInstalled;
  final String? pluginVersion;

  const DetectedEngine({
    required this.path,
    required this.engineType,
    required this.projectName,
    required this.hasPluginInstalled,
    this.pluginVersion,
  });

  /// Display-friendly engine type name.
  String get engineDisplayName {
    switch (engineType) {
      case EngineType.unity:
        return 'Unity';
      case EngineType.unreal:
        return 'Unreal Engine';
      case EngineType.godot:
        return 'Godot';
    }
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'engineType': engineType.name,
        'projectName': projectName,
        'hasPluginInstalled': hasPluginInstalled,
        'pluginVersion': pluginVersion,
      };
}

/// Scans common project directories for game engine projects.
///
/// Detection heuristics (per D-04):
/// - Unity: Directory contains `Assets/`, `ProjectSettings/`, `Packages/manifest.json`
/// - Unreal: Directory contains `*.uproject` file, `Source/` directory
/// - Godot: Directory contains `project.godot` file
///
/// Runs in an Isolate to avoid blocking UI during filesystem scan.
class EngineDetector {
  /// Common base directories to scan for game engine projects.
  static List<String> _defaultSearchPaths() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
    return [
      p.join(home, 'Documents'),
      p.join(home, 'projects'),
      p.join(home, 'dev'),
      p.join(home, 'src'),
      p.join(home, 'Desktop'),
    ];
  }

  /// Scan for detected engines. Optionally provide custom search paths.
  /// Returns list of [DetectedEngine] sorted by engine type then project name.
  static Future<List<DetectedEngine>> scan({
    List<String>? searchPaths,
    int maxDepth = 3,
  }) async {
    final paths = searchPaths ?? _defaultSearchPaths();
    final results = <DetectedEngine>[];

    for (final searchPath in paths) {
      if (!Directory(searchPath).existsSync()) continue;
      final found = await _scanDirectory(searchPath, maxDepth);
      results.addAll(found);
    }

    // Sort: Unity first, then Unreal, then Godot, alphabetical within each
    results.sort((a, b) {
      final typeCmp = a.engineType.index.compareTo(b.engineType.index);
      if (typeCmp != 0) return typeCmp;
      return a.projectName.compareTo(b.projectName);
    });

    return results;
  }

  /// Scan a single directory and its immediate children.
  static Future<List<DetectedEngine>> _scanDirectory(
    String dirPath,
    int remainingDepth,
  ) async {
    final results = <DetectedEngine>[];

    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return results;

      // Check if this directory is a project root
      final project = await _detectProject(dir);
      if (project != null) {
        results.add(project);
        return results; // Don't recurse into project directories
      }

      // Recurse into subdirectories (depth-limited)
      if (remainingDepth > 0) {
        await for (final entity in dir.list()) {
          if (entity is Directory) {
            // Skip hidden directories and common non-project dirs
            final name = p.basename(entity.path);
            if (name.startsWith('.') ||
                name == 'node_modules' ||
                name == 'Library' ||
                name == 'Temp' ||
                name == 'Build' ||
                name == 'Binaries' ||
                name == 'Intermediate') {
              continue;
            }
            final subResults =
                await _scanDirectory(entity.path, remainingDepth - 1);
            results.addAll(subResults);
          }
        }
      }
    } catch (e) {
      // Permission errors or inaccessible directories — skip silently.
    }

    return results;
  }

  /// Try to detect a game engine project in the given directory.
  static Future<DetectedEngine?> _detectProject(Directory dir) async {
    try {
      final dirPath = dir.path;

      // ── Unity Detection ──────────────────────────
      if (await _hasDir(dirPath, 'Assets') &&
          await _hasDir(dirPath, 'ProjectSettings') &&
          await _hasFile(dirPath, 'Packages', 'manifest.json')) {
        final projectName = await _readUnityProjectName(dirPath);
        final hasPlugin = await _hasUnityPlugin(dirPath);
        final version = hasPlugin ? await _readUnityPluginVersion(dirPath) : null;
        return DetectedEngine(
          path: dirPath,
          engineType: EngineType.unity,
          projectName: projectName,
          hasPluginInstalled: hasPlugin,
          pluginVersion: version,
        );
      }

      // ── Unreal Detection ─────────────────────────
      final uprojectFile = await _findUprojectFile(dirPath);
      if (uprojectFile != null && await _hasDir(dirPath, 'Source')) {
        final projectName = p.basenameWithoutExtension(uprojectFile);
        final hasPlugin = await _hasFile(
            dirPath, p.join('Plugins', 'Benchify', 'Benchify.uplugin'));
        final version = hasPlugin ? await _readUpluginVersion(dirPath) : null;
        return DetectedEngine(
          path: dirPath,
          engineType: EngineType.unreal,
          projectName: projectName,
          hasPluginInstalled: hasPlugin,
          pluginVersion: version,
        );
      }

      // ── Godot Detection ─────────────────────────
      if (await _hasFile(dirPath, 'project.godot')) {
        final projectName = await _readGodotProjectName(dirPath);
        final hasPlugin = await _hasFile(
            dirPath, p.join('addons', 'benchify', 'plugin.cfg'));
        final version = hasPlugin ? '3.0.0' : null;
        return DetectedEngine(
          path: dirPath,
          engineType: EngineType.godot,
          projectName: projectName,
          hasPluginInstalled: hasPlugin,
          pluginVersion: version,
        );
      }
    } catch (e) {
      // Skip on I/O errors.
    }

    return null;
  }

  // ── File/Directory Helpers ───────────────────────

  static Future<bool> _hasDir(String base, String child) async {
    return Directory(p.join(base, child)).exists();
  }

  static Future<bool> _hasFile(
      String base, String child1, [String? child2]) async {
    final path = child2 != null
        ? p.join(base, child1, child2)
        : p.join(base, child1);
    return File(path).exists();
  }

  /// Find a .uproject file in the given directory.
  static Future<String?> _findUprojectFile(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.uproject')) {
          return entity.path;
        }
      }
    } catch (e) {
      // Skip on I/O errors.
    }
    return null;
  }

  /// Read Unity project name from ProjectSettings/ProjectSettings.asset
  static Future<String> _readUnityProjectName(String dirPath) async {
    try {
      final file = File(p.join(dirPath, 'ProjectSettings', 'ProjectSettings.asset'));
      final content = await file.readAsString();
      final match = RegExp(r'productName:\s*(.+)').firstMatch(content);
      if (match != null) return match.group(1)!.trim();
    } catch (e) {
      // Fallback to directory name.
    }
    return p.basename(dirPath);
  }

  /// Read Godot project name from project.godot
  static Future<String> _readGodotProjectName(String dirPath) async {
    try {
      final file = File(p.join(dirPath, 'project.godot'));
      final content = await file.readAsString();
      final match = RegExp(r'config/name="([^"]+)"').firstMatch(content);
      if (match != null) return match.group(1)!;
    } catch (e) {
      // Fallback to directory name.
    }
    return p.basename(dirPath);
  }

  /// Check if Benchify Unity plugin is installed via manifest.json dependencies.
  static Future<bool> _hasUnityPlugin(String dirPath) async {
    try {
      final file = File(p.join(dirPath, 'Packages', 'manifest.json'));
      final content = await file.readAsString();
      return content.contains('dev.benchify.unity-plugin') ||
          content.contains('dev.benchify');
    } catch (e) {
      return false;
    }
  }

  /// Read Unity plugin version from manifest.json.
  static Future<String?> _readUnityPluginVersion(String dirPath) async {
    try {
      final file = File(p.join(dirPath, 'Packages', 'manifest.json'));
      final content = await file.readAsString();
      final match =
          RegExp(r'"dev\.benchify.*?"\s*:\s*"[^"]*#(v?[\d.]+)"').firstMatch(content);
      return match?.group(1) ?? 'unknown';
    } catch (e) {
      return null;
    }
  }

  /// Read Unreal plugin version from .uplugin file.
  static Future<String?> _readUpluginVersion(String dirPath) async {
    try {
      final file = File(
          p.join(dirPath, 'Plugins', 'Benchify', 'Benchify.uplugin'));
      final content = await file.readAsString();
      final match = RegExp(r'"VersionName"\s*:\s*"([\d.]+)"').firstMatch(content);
      return match?.group(1);
    } catch (e) {
      return null;
    }
  }
}
