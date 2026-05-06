// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/models/keystore_config.dart';
import 'package:performancebench/core/services/injection_service.dart';

void main() {
  group('InjectionService', () {
    late InjectionService service;

    setUp(() {
      service = InjectionService(
        pythonPath: 'python3',
        injectorScriptPath: '/fake/path/injector_cli.py',
      );
    });

    test('constructs correct CLI args from keystore config', () {
      final keystore = KeystoreConfig(
        keystorePath: '/path/to/keystore.jks',
        keystorePassword: 'pass123',
        keyAlias: 'mykey',
        keyPassword: 'keypass',
      );

      final args = service.buildInjectArgs(
        apkPath: '/path/to/app.apk',
        method: 'smali',
        keystore: keystore,
        sdkSoDir: '/path/to/libs',
        outputPath: '/path/to/output.apk',
      );

      // Verify key arguments are present
      final argsString = args.join(' ');
      expect(argsString, contains('python3'));
      expect(argsString, contains('injector_cli.py'));
      expect(argsString, contains('inject'));
      expect(argsString, contains('--apk'));
      expect(argsString, contains('/path/to/app.apk'));
      expect(argsString, contains('--method smali'));
      expect(argsString, contains('--keystore'));
      expect(argsString, contains('/path/to/keystore.jks'));
      expect(argsString, contains('--keystore-password pass123'));
      expect(argsString, contains('--key-alias mykey'));
      expect(argsString, contains('--key-password keypass'));
    });

    test('constructs CLI args without optional fields', () {
      final keystore = KeystoreConfig(
        keystorePath: '',
        keystorePassword: '',
        keyAlias: '',
        keyPassword: '',
      );

      final args = service.buildInjectArgs(
        apkPath: '/path/to/app.apk',
        method: 'smali',
        keystore: keystore,
      );

      // Empty keystore path means no signing arguments
      final argsString = args.join(' ');
      expect(argsString, contains('python3'));
      expect(argsString, contains('inject'));
      expect(argsString, contains('--apk /path/to/app.apk'));
    });

    test('InjectionStep enum has all expected values', () {
      // Verify enum values exist
      expect(InjectionStep.decompile, isA<InjectionStep>());
      expect(InjectionStep.smali, isA<InjectionStep>());
      expect(InjectionStep.manifest, isA<InjectionStep>());
      expect(InjectionStep.rebuild, isA<InjectionStep>());
      expect(InjectionStep.resign, isA<InjectionStep>());
      expect(InjectionStep.verify, isA<InjectionStep>());
      expect(InjectionStep.error, isA<InjectionStep>());
      expect(InjectionStep.done, isA<InjectionStep>());
    });

    test('parses JSON status lines correctly', () {
      final line = '{"step": "decompile", "status": "running", "detail": "Decompiling..."}';
      final result = service.parseStepLine(line);
      expect(result, isNotNull);
      expect(result!.step, InjectionStep.decompile);
      expect(result.status, 'running');
    });

    test('handles malformed JSON gracefully', () {
      final result = service.parseStepLine('not valid json');
      expect(result, isNull);
    });
  });
}
