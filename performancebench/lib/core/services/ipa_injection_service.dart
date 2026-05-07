// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/ipa_signing_config.dart';

/// Steps in the IPA injection pipeline.
///
/// Mirrors the JSON step names emitted by the Python CLI ipa-inject command.
enum IpaInjectionStep {
  unpack,
  encryptionCheck,
  injectSdk,
  patchPlist,
  loadCommand,
  signing,
  repack,
  verify,
  done,
  error;

  static IpaInjectionStep? fromString(String value) {
    switch (value) {
      case 'unpack':
        return IpaInjectionStep.unpack;
      case 'encryption_check':
        return IpaInjectionStep.encryptionCheck;
      case 'inject_sdk':
        return IpaInjectionStep.injectSdk;
      case 'patch_plist':
        return IpaInjectionStep.patchPlist;
      case 'load_command':
        return IpaInjectionStep.loadCommand;
      case 'signing':
        return IpaInjectionStep.signing;
      case 'repack':
        return IpaInjectionStep.repack;
      case 'verify':
        return IpaInjectionStep.verify;
      case 'done':
        return IpaInjectionStep.done;
      case 'error':
        return IpaInjectionStep.error;
      default:
        return null;
    }
  }
}

/// A single step status event from the Python IPA injector CLI.
class IpaStepEvent {
  final IpaInjectionStep step;
  final String status; // running, pass, fail, warning
  final String detail;

  const IpaStepEvent({
    required this.step,
    required this.status,
    required this.detail,
  });

  factory IpaStepEvent.fromJson(Map<String, dynamic> json) {
    final stepStr = json['step'] as String? ?? '';
    final step = IpaInjectionStep.fromString(stepStr) ?? IpaInjectionStep.error;
    return IpaStepEvent(
      step: step,
      status: json['status'] as String? ?? 'running',
      detail: json['detail'] as String? ?? '',
    );
  }
}

/// Manages Python IPA injector CLI subprocess lifecycle for iOS IPA injection.
///
/// Per 05-02-PLAN Task 1 (D-07):
///   Spawns injector_cli.py ipa-inject/ipa-verify/signing-detect as a Process,
///   parses newline-delimited JSON from stdout, and returns typed Dart objects.
///
/// Follows same Process.start() pattern as InjectionService and IosService.
///
/// Threat mitigations:
///   - T-05-02: Apple ID app-specific password passed via CLI args (not env vars).
///     Keychain storage handled by Python side via security add-generic-password.
class IpaInjectionService {
  final String pythonPath;
  final String injectorScriptPath;

  Process? _process;
  StreamController<IpaStepEvent>? _controller;
  bool _stopped = false;

  IpaInjectionService({
    this.pythonPath = 'python3',
    required this.injectorScriptPath,
  });

  /// Whether the current platform supports IPA injection (macOS only).
  static bool get isSupported => Platform.isMacOS;

  /// Detect available signing methods from the host system.
  ///
  /// Runs `python injector_cli.py signing-detect` and parses JSON output.
  Future<List<SigningMethod>> detectSigningMethods() async {
    if (!isSupported) return [];

    try {
      final result = await Process.run(
        pythonPath,
        [injectorScriptPath, 'signing-detect'],
      );
      if (result.exitCode != 0) return [];

      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final methods = json['available_methods'] as List<dynamic>? ?? [];
      return methods
          .map((m) => SigningMethod.fromString(m.toString()))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Read IPA metadata (app name, bundle ID, version, encryption status).
  ///
  /// Runs `python injector_cli.py ipa-metadata --input {ipaPath}`.
  Future<IpaMetadata> getIpaMetadata(String ipaPath) async {
    if (!isSupported) {
      return IpaMetadata(error: 'IPA injection requires macOS host');
    }

    try {
      final result = await Process.run(
        pythonPath,
        [injectorScriptPath, 'ipa-metadata', '--input', ipaPath],
      );
      if (result.exitCode != 0) {
        return IpaMetadata(error: 'Failed to read IPA metadata');
      }

      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      return IpaMetadata.fromJson(json);
    } catch (e) {
      return IpaMetadata(error: e.toString());
    }
  }

  /// Build CLI argument list for the ipa-inject subcommand.
  List<String> _buildInjectArgs({
    required String ipaPath,
    required String outputPath,
    required IpaSigningConfig config,
    String? frameworkDir,
    String? appSpecificPassword,
  }) {
    final args = <String>[
      pythonPath,
      injectorScriptPath,
      'ipa-inject',
      '--input', ipaPath,
      '--output', outputPath,
      '--signing', _signingMethodArg(config.method),
    ];

    if (config.appleId != null && config.appleId!.isNotEmpty) {
      args.addAll(['--apple-id', config.appleId!]);
    }
    if (config.teamId != null && config.teamId!.isNotEmpty) {
      args.addAll(['--team-id', config.teamId!]);
    }
    if (config.provisioningProfilePath != null &&
        config.provisioningProfilePath!.isNotEmpty) {
      args.addAll(['--profile-path', config.provisioningProfilePath!]);
    }
    if (config.certIdentity != null && config.certIdentity!.isNotEmpty) {
      args.addAll(['--cert-identity', config.certIdentity!]);
    }
    if (frameworkDir != null && frameworkDir.isNotEmpty) {
      args.addAll(['--framework-dir', frameworkDir]);
    }
    if (appSpecificPassword != null && appSpecificPassword.isNotEmpty) {
      // Password passed via stdin, not CLI args
      args.add('--password-via-stdin');
    }

    return args;
  }

  /// Map Dart SigningMethod enum to Python CLI argument value.
  String _signingMethodArg(SigningMethod method) {
    switch (method) {
      case SigningMethod.freeAppleId:
        return 'free';
      case SigningMethod.paidDeveloper:
        return 'paid';
      case SigningMethod.userCertificate:
        return 'cert';
    }
  }

  /// Start the IPA injection pipeline.
  ///
  /// Returns a [Stream<IpaStepEvent>] emitting one event per step.
  /// Call [stop] to abort injection.
  Stream<IpaStepEvent> injectIpa({
    required String ipaPath,
    required String outputPath,
    required IpaSigningConfig config,
    String? frameworkDir,
    String? appSpecificPassword,
  }) {
    _controller = StreamController<IpaStepEvent>.broadcast();
    _stopped = false;

    final args = _buildInjectArgs(
      ipaPath: ipaPath,
      outputPath: outputPath,
      config: config,
      frameworkDir: frameworkDir,
      appSpecificPassword: appSpecificPassword,
    );

    _spawnProcess(args, appSpecificPassword: appSpecificPassword);

    return _controller!.stream;
  }

  /// Verify an already-injected IPA.
  Stream<IpaStepEvent> verifyIpa(String ipaPath) {
    _controller = StreamController<IpaStepEvent>.broadcast();
    _stopped = false;

    _spawnProcess([
      pythonPath,
      injectorScriptPath,
      'ipa-verify',
      '--input', ipaPath,
    ]);

    return _controller!.stream;
  }

  Future<void> _spawnProcess(List<String> args, {String? appSpecificPassword}) async {
    try {
      _process = await Process.start(args.first, args.sublist(1));

      if (appSpecificPassword != null && args.contains('--password-via-stdin')) {
        final passwordJson = jsonEncode({
          'app_specific_password': appSpecificPassword,
        });
        _process!.stdin.write(passwordJson);
        await _process!.stdin.close();
      }

      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            final event = IpaStepEvent.fromJson(json);
            _controller?.add(event);
            if (event.step == IpaInjectionStep.done ||
                event.step == IpaInjectionStep.error) {
              _controller?.close();
            }
          } catch (_) {
            // Skip non-JSON lines
          }
        },
        onDone: () {
          _controller?.close();
        },
      );

      _process!.stderr.transform(utf8.decoder).listen((line) {
        // ignore: avoid_print
        print('[ipa_injection_service stderr] $line');
      });

      _process!.exitCode.then((code) {
        if (code != 0 && !_stopped) {
          _controller?.add(
            IpaStepEvent(
              step: IpaInjectionStep.error,
              status: 'fail',
              detail: 'IPA injector exited with code $code',
            ),
          );
        }
        _controller?.close();
      });
    } catch (e) {
      _controller?.add(
        IpaStepEvent(
          step: IpaInjectionStep.error,
          status: 'fail',
          detail: e.toString(),
        ),
      );
      _controller?.close();
    }
  }

  /// Abort the injection subprocess.
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
}
