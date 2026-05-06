// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/features/injection/injection_screen.dart';
import 'package:performancebench/features/injection/injection_method_card.dart';
import 'package:performancebench/shared/theme.dart';

/// Wraps a widget in ProviderScope + MaterialApp for testing.
Widget wrapWithProviders(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData(
        extensions: const [
          AppColors.dark,
        ],
      ),
      home: child,
    ),
  );
}

void main() {
  group('InjectionScreen', () {
    testWidgets('renders drag-drop zone', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(const InjectionScreen()));

      // Should show the APK Injection title in the AppBar
      expect(find.text('APK Injection'), findsOneWidget);

      // Should show drag-drop instructions
      expect(
        find.textContaining('Drop APK/AAB here'),
        findsOneWidget,
      );
    });

    testWidgets('renders injection method selector', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(const InjectionScreen()));

      // Should show method selector header text
      expect(find.text('Injection Method'), findsOneWidget);

      // Should show both method options
      expect(find.text('apktool + Smali'), findsOneWidget);
      expect(find.text('Frida gadget'), findsOneWidget);
    });

    testWidgets('renders keystore configuration expandable section', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(const InjectionScreen()));

      // Should show keystore section label (collapsed by default, but label visible)
      expect(find.text('Keystore Configuration'), findsOneWidget);
    });

    testWidgets('renders inject button', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(const InjectionScreen()));

      // Should have an inject button
      expect(find.text('Inject'), findsOneWidget);
    });

    testWidgets('renders verification progress section', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(const InjectionScreen()));

      // Should show verification progress section with 4 step labels
      expect(find.text('Verification Progress'), findsOneWidget);
      expect(find.text('Decompile APK'), findsOneWidget);
      expect(find.text('Patch Smali + Manifest'), findsOneWidget);
      expect(find.text('Rebuild + Re-sign'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
    });
  });

  group('InjectionMethodCard', () {
    testWidgets('renders with title and subtitle', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(
        InjectionMethodCard(
          title: 'Test Method',
          subtitle: 'Test description',
          icon: Icons.android,
          isSelected: false,
          onTap: () {},
        ),
      ));

      expect(find.text('Test Method'), findsOneWidget);
      expect(find.text('Test description'), findsOneWidget);
    });

    testWidgets('shows selected state with check icon', (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithProviders(
        InjectionMethodCard(
          title: 'Selected',
          subtitle: 'Chosen',
          icon: Icons.android,
          isSelected: true,
          onTap: () {},
        ),
      ));

      // Selected card should still show content
      expect(find.text('Selected'), findsOneWidget);

      // Should show a check icon for selected state
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });
}
