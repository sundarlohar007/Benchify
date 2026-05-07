// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/keystore_config.dart';

/// Steps in the APK injection pipeline.
///
/// Mirrors the JSON step names emitted by injector_cli.py.
enum InjectionStep {
  decompile,
  smali,
  manifest,
  rebuild,
  resign,
  verify,
  frida,
  done,
  error;

  /// Parse from JSON step key string.
  static InjectionStep? fromString(String value) {
    switch (value) {
      case 'decompile':
        return InjectionStep.decompile;
      case 'smali':
        return InjectionStep.smali;
      case 'manifest':
        return InjectionStep.manifest;
      case 'rebuild':
        return InjectionStep.rebuild;
      case 'resign':
        return InjectionStep.resign;
      case 'verify':
        return InjectionStep.verify;
      case 'frida':
        return InjectionStep.frida;
      case 'done':
        return InjectionStep.done;
      case 'error':
        return InjectionStep.error;
      default:
        return null;
    }
  }
}

/// Represents a single step status event from the Python CLI.
class StepEvent {
  final InjectionStep step;
  final String status; // running, pass, fail, warning, skipped
  final String detail;

  const StepEvent({
    required this.step,
    required this.status,
    required this.detail,
  });

  /// Parse from JSON line emitted by injector_cli.py.
  factory StepEvent.fromJson(Map<String, dynamic> json) {
    final stepStr = json['step'] as String? ?? '';
    final step = InjectionStep.fromString(stepStr) ?? InjectionStep.error;
    return StepEvent(
      step: step,
      status: json['status'] as String? ?? 'running',
      detail: json['detail'] as String? ?? '',
    );
  }
}

/// Manages Python injector CLI subprocess lifecycle.
///
/// Per D-01: Desktop app wraps injection logic.
/// Uses Process.start() pattern identical to IosService._spawnCollector().
///
/// Threat mitigations:
/// - T-04-02: Keystore passwords passed via stdin, not CLI args visible in process list.
/// - T-04-05: Subprocess timeout at 5 minutes. SIGTERM -> SIGKILL.
class InjectionService {
  final String pythonPath;
  final String injectorScriptPath;

  Process? _process;
  StreamController<StepEvent>? _controller;
  bool _stopped = false;

  /// Creates an InjectionService instance.
  ///
  /// [pythonPath] — path to Python executable (default: 'python3').
  /// [injectorScriptPath] — path to injector_cli.py in performancebench-injector/.
  InjectionService({
    this.pythonPath = 'python3',
    required this.injectorScriptPath,
  });

  /// Build CLI argument list for the inject subcommand.
  List<String> buildInjectArgs({
    required String apkPath,
    required String method,
    required KeystoreConfig keystore,
    String sdkSoDir = '',
    String outputPath = 'injected.apk',
    String proguardMapping = '',
    String gadgetSoPath = '',
    String gadgetConfigPath = '',
    bool isAab = false,
  }) {
    final args = <String>[
      pythonPath,
      injectorScriptPath,
      'inject',
      '--apk', apkPath,
      '--method', method,
    ];

    // Frida-specific args (no keystore required)
    if (method == 'frida') {
      if (gadgetSoPath.isNotEmpty) {
        args.addAll(['--gadget-so', gadgetSoPath]);
      }
      if (gadgetConfigPath.isNotEmpty) {
        args.addAll(['--gadget-config', gadgetConfigPath]);
      }
    } else {
      // Smali-specific: keystore args
      if (keystore.keystorePath.isNotEmpty) {
        args.addAll([
          '--keystore', keystore.keystorePath,
          '--key-alias', keystore.keyAlias,
        ]);
        // Passwords passed via stdin, not CLI args (T-04-02)
        args.addAll(['--keystore-passwords-via-stdin']);
      }

      if (sdkSoDir.isNotEmpty) {
        args.addAll(['--sdk-so-dir', sdkSoDir]);
      }

      if (proguardMapping.isNotEmpty) {
        args.addAll(['--proguard-mapping', proguardMapping]);
      }
    }

    args.addAll(['--output', outputPath]);

    if (isAab) {
      args.add('--aab');
    }

    return args;
  }

  /// Start the APK injection pipeline.
  ///
  /// Returns a [Stream<StepEvent>] emitting one event per step.
  /// Call [stop] to abort injection.
  Stream<StepEvent> inject({
    required String apkPath,
    required String method,
    required KeystoreConfig keystore,
    String sdkSoDir = '',
    String outputPath = 'injected.apk',
    String proguardMapping = '',
    String gadgetSoPath = '',
    String gadgetConfigPath = '',
    bool isAab = false,
  }) {
    _controller = StreamController<StepEvent>.broadcast();
    _stopped = false;

    final args = buildInjectArgs(
      apkPath: apkPath,
      method: method,
      keystore: keystore,
      sdkSoDir: sdkSoDir,
      outputPath: outputPath,
      proguardMapping: proguardMapping,
      gadgetSoPath: gadgetSoPath,
      gadgetConfigPath: gadgetConfigPath,
      isAab: isAab,
    );

    _spawnProcess(args);

    return _controller!.stream;
  }

  /// Start the APK verification pipeline.
  Stream<StepEvent> verify({
    required String apkPath,
    String keystorePath = '',
    String deviceSerial = '',
    String package = '',
  }) {
    _controller = StreamController<StepEvent>.broadcast();
    _stopped = false;

    final args = <String>[
      pythonPath,
      injectorScriptPath,
      'verify',
      '--apk', apkPath,
    ];

    if (keystorePath.isNotEmpty) {
      args.addAll(['--keystore', keystorePath]);
    }
    if (deviceSerial.isNotEmpty) {
      args.addAll(['--device-serial', deviceSerial]);
    }
    if (package.isNotEmpty) {
      args.addAll(['--package', package]);
    }

    _spawnProcess(args);

    return _controller!.stream;
  }

  /// Parse a JSON status line from the Python CLI stdout.
  StepEvent? parseStepLine(String line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      return StepEvent.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _spawnProcess(List<String> args, {KeystoreConfig? keystore}) async {
    try {
      _process = await Process.start(
        args.first,
        args.sublist(1),
      );

      // Write keystore passwords via stdin (not CLI args — T-04-02)
      if (keystore != null && args.contains('--keystore-passwords-via-stdin')) {
        final passwordJson = jsonEncode({
          'keystore_password': keystore.keystorePassword,
          'key_password': keystore.keyPassword,
        });
        _process!.stdin.write(passwordJson);
        await _process!.stdin.close();
      }

      // Read stdout line by line
      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          final event = parseStepLine(line);
          if (event != null) {
            _controller?.add(event);
            if (event.step == InjectionStep.done || event.step == InjectionStep.error) {
              _controller?.close();
            }
          }
        },
        onDone: () {
          _controller?.close();
        },
      );

      // Capture stderr for diagnostics
      _process!.stderr.transform(utf8.decoder).listen((line) {
        // Log stderr but don't surface to UI directly
        // ignore: avoid_print
        print('[injection_service stderr] $line');
      });

      // Handle process exit
      _process!.exitCode.then((code) {
        if (code != 0 && !_stopped) {
          _controller?.add(
            StepEvent(
              step: InjectionStep.error,
              status: 'fail',
              detail: 'Injector exited with code $code',
            ),
          );
        }
        _controller?.close();
      });
    } catch (e) {
      _controller?.add(
        StepEvent(
          step: InjectionStep.error,
          status: 'fail',
          detail: e.toString(),
        ),
      );
      _controller?.close();
    }
  }

  /// Abort the injection subprocess. SIGTERM, then SIGKILL after 3s.
  /// Pattern identical to IosService.stop().
  void stop() {
    _stopped = true;
    if (_process != null) {
      _process!.kill(ProcessSignal.sigterm);
      Future.delayed(const Duration(seconds: 3), () {
        if (_process != null) {
          _process!.kill(ProcessSignal.sigkill);
        }
      });
      _process = null;
    }
    _controller?.close();
    _controller = null;
  }

  // --------------------------------------------------------------------------
  // Shared Preferences — keystore path persistence (D-03)
  // --------------------------------------------------------------------------

  static const _keystorePathKey = 'injection_keystore_path';

  /// Save the last-used keystore path to shared preferences.
  /// Per D-03: Desktop remembers last-used keystore path in settings.
  static Future<void> saveKeystorePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keystorePathKey, path);
  }

  /// Load the last-used keystore path from shared preferences.
  static Future<String> loadKeystorePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keystorePathKey) ?? '';
  }

  /// Clear the saved keystore path.
  static Future<void> clearKeystorePath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keystorePathKey);
  }
}
