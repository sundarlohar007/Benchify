// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Benchify
//
// PluginInstallService — File copy + config patching for engine plugin installation.
// Per D-04: Installs Benchify plugins to Unity/Unreal/Godot project directories.
// Threat mitigation (T-05-02): Backs up manifest.json/project.godot before editing.

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

import '../../features/plugins/engine_detector.dart';

/// Result of a plugin install/remove operation.
class PluginOperationResult {
  final bool success;
  final String message;
  final String? backupPath;

  const PluginOperationResult({
    required this.success,
    required this.message,
    this.backupPath,
  });
}

/// Service for installing and removing Benchify plugins in detected engine projects.
///
/// Per D-04:
/// - Unity: Adds git URL to manifest.json dependencies
/// - Unreal: Copies plugin files to Plugins/Benchify/
/// - Godot: Copies addons and edits project.godot config
///
/// All config edits are backed up before modification (T-05-02).
class PluginInstallService {
  /// The bundled plugin source directory (relative to app path).
  static const String _pluginSourceDir = 'plugins';

  /// Install the Benchify plugin for the detected engine project.
  static Future<PluginOperationResult> installPlugin(
      DetectedEngine engine) async {
    switch (engine.engineType) {
      case EngineType.unity:
        return _installUnityPlugin(engine);
      case EngineType.unreal:
        return _installUnrealPlugin(engine);
      case EngineType.godot:
        return _installGodotPlugin(engine);
    }
  }

  /// Remove the Benchify plugin from the detected engine project.
  static Future<PluginOperationResult> removePlugin(
      DetectedEngine engine) async {
    if (!engine.hasPluginInstalled) {
      return const PluginOperationResult(
          success: false, message: 'Plugin is not installed.');
    }

    switch (engine.engineType) {
      case EngineType.unity:
        return _removeUnityPlugin(engine);
      case EngineType.unreal:
        return _removeUnrealPlugin(engine);
      case EngineType.godot:
        return _removeGodotPlugin(engine);
    }
  }

  /// Get the installed plugin version (or null if not installed).
  static Future<String?> getInstalledVersion(DetectedEngine engine) async {
    return engine.pluginVersion;
  }

  // ── Unity ──────────────────────────────────────────

  /// Install Unity UPM plugin: add git URL to manifest.json.
  static Future<PluginOperationResult> _installUnityPlugin(
      DetectedEngine engine) async {
    try {
      final manifestPath =
          p.join(engine.path, 'Packages', 'manifest.json');
      final manifestFile = File(manifestPath);

      if (!await manifestFile.exists()) {
        return const PluginOperationResult(
            success: false, message: 'manifest.json not found.');
      }

      // Backup before modification (T-05-02)
      final backupPath = '$manifestPath.bak';
      await manifestFile.copy(backupPath);

      // Read and parse manifest
      final content = await manifestFile.readAsString();
      final Map<String, dynamic> manifest;
      try {
        manifest = jsonDecode(content) as Map<String, dynamic>;
      } catch (e) {
        return const PluginOperationResult(
            success: false, message: 'Invalid manifest.json format.');
      }

      // Add Benchify dependency
      manifest['dependencies'] ??= <String, String>{};
      final deps = manifest['dependencies'] as Map<String, dynamic>;
      const benchifyUrl =
          'https://github.com/sundarlohar007/Benchify.git?path=/benchify-unity-plugin';
      deps['dev.benchify.unity-plugin'] = benchifyUrl;

      // Write back
      final encoder = const JsonEncoder.withIndent('  ');
      await manifestFile.writeAsString(encoder.convert(manifest));

      return PluginOperationResult(
        success: true,
        message: 'Benchify Unity plugin installed. Restart Unity Editor.',
        backupPath: backupPath,
      );
    } catch (e) {
      return PluginOperationResult(
          success: false, message: 'Install failed: $e');
    }
  }

  /// Remove Unity UPM plugin: remove from manifest.json, delete package folder.
  static Future<PluginOperationResult> _removeUnityPlugin(
      DetectedEngine engine) async {
    try {
      final manifestPath =
          p.join(engine.path, 'Packages', 'manifest.json');
      final manifestFile = File(manifestPath);

      if (!await manifestFile.exists()) {
        return const PluginOperationResult(
            success: false, message: 'manifest.json not found.');
      }

      // Backup
      final backupPath = '$manifestPath.bak';
      await manifestFile.copy(backupPath);

      // Read, parse, remove
      final content = await manifestFile.readAsString();
      final manifest = jsonDecode(content) as Map<String, dynamic>;
      final deps = manifest['dependencies'] as Map<String, dynamic>?;
      deps?.removeWhere((key, value) =>
          key.toString().contains('benchify'));

      // Write back
      final encoder = const JsonEncoder.withIndent('  ');
      await manifestFile.writeAsString(encoder.convert(manifest));

      // Remove package cache folder
      final packageDir = Directory(
          p.join(engine.path, 'Library', 'PackageCache', 'dev.benchify.unity-plugin'));
      if (await packageDir.exists()) {
        await packageDir.delete(recursive: true);
      }

      return PluginOperationResult(
        success: true,
        message: 'Benchify Unity plugin removed.',
        backupPath: backupPath,
      );
    } catch (e) {
      return PluginOperationResult(
          success: false, message: 'Remove failed: $e');
    }
  }

  // ── Unreal ─────────────────────────────────────────

  /// Install Unreal plugin: copy Benchify/ to Plugins/.
  static Future<PluginOperationResult> _installUnrealPlugin(
      DetectedEngine engine) async {
    try {
      final targetDir =
          Directory(p.join(engine.path, 'Plugins', 'Benchify'));

      if (await targetDir.exists()) {
        return const PluginOperationResult(
            success: false,
            message: 'Benchify plugin already exists in Plugins/.');
      }

      // Copy plugin files from bundled source
      final sourceDir = Directory(p.join(_pluginSourceDir, 'benchify-unreal-plugin'));
      if (!await sourceDir.exists()) {
        // Fallback: create from bundled app resources (shipped with desktop app)
        // For development, plugin files are embedded in the app bundle.
        return const PluginOperationResult(
            success: false,
            message: 'Plugin source files not bundled with this build.\n'
                'Please use standalone install:\n'
                'git clone https://github.com/sundarlohar007/Benchify.git\n'
                'cp -r Benchify/benchify-unreal-plugin [project]/Plugins/Benchify/');
      }

      await _copyDirectory(sourceDir, targetDir);

      return PluginOperationResult(
        success: true,
        message: 'Benchify Unreal plugin installed to Plugins/Benchify/. '
            'Regenerate project files and rebuild.',
      );
    } catch (e) {
      return PluginOperationResult(
          success: false, message: 'Install failed: $e');
    }
  }

  /// Remove Unreal plugin: delete Plugins/Benchify/.
  static Future<PluginOperationResult> _removeUnrealPlugin(
      DetectedEngine engine) async {
    try {
      final targetDir =
          Directory(p.join(engine.path, 'Plugins', 'Benchify'));

      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }

      return const PluginOperationResult(
        success: true,
        message: 'Benchify Unreal plugin removed.',
      );
    } catch (e) {
      return PluginOperationResult(
          success: false, message: 'Remove failed: $e');
    }
  }

  // ── Godot ─────────────────────────────────────────

  /// Install Godot addon: copy addons/benchify/ and patch project.godot.
  static Future<PluginOperationResult> _installGodotPlugin(
      DetectedEngine engine) async {
    try {
      final addonsDir =
          Directory(p.join(engine.path, 'addons', 'benchify'));

      if (await addonsDir.exists()) {
        return const PluginOperationResult(
            success: false,
            message: 'Benchify addon already exists in addons/benchify/.');
      }

      // Copy plugin files from bundled source
      final sourceDir = Directory(p.join(_pluginSourceDir, 'benchify-godot-plugin', 'addons', 'benchify'));
      if (!await sourceDir.exists()) {
        return const PluginOperationResult(
            success: false,
            message: 'Plugin source files not bundled with this build.\n'
                'Please use standalone install:\n'
                'git clone https://github.com/sundarlohar007/Benchify.git\n'
                'cp -r Benchify/benchify-godot-plugin/addons/benchify [project]/addons/');
      }

      await _copyDirectory(sourceDir, addonsDir);

      // Patch project.godot to enable autoload (T-05-02: backup first)
      final projectPath = p.join(engine.path, 'project.godot');
      final projectFile = File(projectPath);
      final backupPath = '$projectPath.bak';
      await projectFile.copy(backupPath);

      var content = await projectFile.readAsString();

      // Add autoload section if not present
      if (!content.contains('[autoload]')) {
        content += '\n\n[autoload]\n';
      }

      // Add Benchify autoload if not present
      if (!content.contains('Benchify="*res://addons/benchify/benchify_autoload.gd"')) {
        // Find [autoload] section and append
        final autoloadIndex = content.indexOf('[autoload]');
        if (autoloadIndex >= 0) {
          final nextSection = RegExp(r'\n\[[a-z]').firstMatch(
              content.substring(autoloadIndex + 9));
          final insertIndex = nextSection != null
              ? autoloadIndex + 9 + nextSection.start
              : content.length;
          content =
              '${content.substring(0, insertIndex)}'
              'Benchify="*res://addons/benchify/benchify_autoload.gd"\n'
              '${content.substring(insertIndex)}';
        }
      }

      await projectFile.writeAsString(content);

      return const PluginOperationResult(
        success: true,
        message: 'Benchify Godot addon installed. '
            'Enable in Project > Project Settings > Plugins.',
      );
    } catch (e) {
      return PluginOperationResult(
          success: false, message: 'Install failed: $e');
    }
  }

  /// Remove Godot addon: delete addons/benchify/, remove autoload.
  static Future<PluginOperationResult> _removeGodotPlugin(
      DetectedEngine engine) async {
    try {
      final addonsDir =
          Directory(p.join(engine.path, 'addons', 'benchify'));

      if (await addonsDir.exists()) {
        await addonsDir.delete(recursive: true);
      }

      // Remove autoload entry from project.godot
      final projectPath = p.join(engine.path, 'project.godot');
      final projectFile = File(projectPath);
      if (await projectFile.exists()) {
        final backupPath = '$projectPath.bak';
        await projectFile.copy(backupPath);

        var content = await projectFile.readAsString();
        content = content.replaceAll(
          RegExp(r'Benchify="\*?res://addons/benchify/benchify_autoload\.gd"\n?'),
          '',
        );
        await projectFile.writeAsString(content);
      }

      return const PluginOperationResult(
        success: true,
        message: 'Benchify Godot addon removed.',
      );
    } catch (e) {
      return PluginOperationResult(
          success: false, message: 'Remove failed: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────

  /// Recursively copy a directory.
  static Future<void> _copyDirectory(
      Directory source, Directory target) async {
    if (!await source.exists()) return;

    await target.create(recursive: true);

    await for (final entity in source.list()) {
      final targetPath = p.join(target.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      } else if (entity is File) {
        await entity.copy(targetPath);
      }
    }
  }
}
