// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:performancebench/core/models/keystore_config.dart';
import 'package:performancebench/core/services/injection_service.dart';
import 'package:performancebench/features/injection/injection_method_card.dart';
import 'package:performancebench/features/injection/injection_screen.dart';

/// Test 5: Frida card becomes active (not disabled) and hides keystore form.
void main() {
  testWidgets('Frida card is not disabled and hides keystore form when selected',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: const InjectionScreen(),
        ),
      ),
    );

    // Find the Frida card — it should be tappable (not greyed out)
    final fridaCard = find.text('Frida gadget');
    expect(fridaCard, findsOneWidget);

    // The Frida card should NOT be disabled — tapping it should work
    final fridaCardWidget = tester.widget<InjectionMethodCard>(
      find.ancestor(
        of: fridaCard,
        matching: find.byType(InjectionMethodCard),
      ).first,
    );
    expect(fridaCardWidget.isDisabled, isFalse,
        reason: 'Frida card should be enabled (not greyed out)');

    // Tap the Frida card
    await tester.tap(find.text('Frida gadget'));
    await tester.pumpAndSettle();

    // Keystore configuration section should NOT be visible when Frida is selected
    // (the keystore section only shows for smali method)
    expect(find.text('Keystore Configuration'), findsNothing,
        reason: 'Keystore form should be hidden when Frida method is selected');
  });

  testWidgets('Smali card shows keystore form when selected',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: const InjectionScreen(),
        ),
      ),
    );

    // Tap the Smali card
    await tester.tap(find.text('apktool + Smali'));
    await tester.pumpAndSettle();

    // Expand keystore configuration
    await tester.tap(find.text('Keystore Configuration'));
    await tester.pumpAndSettle();

    // Keystore form should be visible
    expect(find.text('Key Alias'), findsOneWidget);
  });

  group('InjectionService Frida support', () {
    test('buildInjectArgs omits keystore args for frida method', () {
      final service = InjectionService(
        injectorScriptPath: 'injector_cli.py',
      );

      final args = service.buildInjectArgs(
        apkPath: 'test.apk',
        method: 'frida',
        keystore: KeystoreConfig(),
        gadgetSoPath: 'frida-gadget-arm64.so',
      );

      // Should contain --method frida and --gadget-so
      expect(args, containsAll(['--method', 'frida']));
      expect(args, containsAll(['--gadget-so', 'frida-gadget-arm64.so']));

      // Should NOT contain keystore-related args
      expect(args.where((a) => a == '--keystore').length, 0);
      expect(args.where((a) => a == '--keystore-password').length, 0);
      expect(args.where((a) => a == '--key-alias').length, 0);
      expect(args.where((a) => a == '--key-password').length, 0);
    });

    test('buildInjectArgs includes keystore args for smali method', () {
      final service = InjectionService(
        injectorScriptPath: 'injector_cli.py',
      );

      final args = service.buildInjectArgs(
        apkPath: 'test.apk',
        method: 'smali',
        keystore: KeystoreConfig(
          keystorePath: 'my.keystore',
          keystorePassword: 'pass',
          keyAlias: 'mykey',
          keyPassword: 'keypass',
        ),
      );

      expect(args, containsAll(['--method', 'smali']));
      expect(args, containsAll(['--keystore', 'my.keystore']));
      expect(args, containsAll(['--keystore-passwords-via-stdin']));
      expect(args, containsAll(['--key-alias', 'mykey']));
    });
  });
}
