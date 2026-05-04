// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:performancebench/core/parsers/memory_parser.dart';

/// Helper: build a realistic dumpsys meminfo output for testing.
String _buildMeminfoOutput({
  String? javaLabel = 'Java Heap',
  int javaPss = 12480,
  int nativePss = 45120,
  int egPss = 52224,
  int glPss = 24576,
  int stackPss = 1024,
  int soMmap = 38400,
  int jarMmap = 0,
  int apkMmap = 21504,
  int dexMmap = 18432,
  int oatMmap = 15360,
  int artMmap = 4096,
  int totalPss = 237040,
  List<String> extraLines = const [],
}) {
  return '''
                       Pss  Private  Private  SwapPss     Heap     Heap
                     Total    Dirty    Clean    Dirty     Size    Alloc
                    ------   ------   ------   ------   ------   ------
  Native Heap        $nativePss    44980        0      120    52224    44321
  $javaLabel        $javaPss    12350        0       50    16384    11200
  Dalvik Other        2560     2520        0        0
  Stack               $stackPss     1024        0        0
  Ashmem                 8        0        0        0
  Other dev             64        0        0        0
  .so mmap           $soMmap      512    35200        0
  .jar mmap          $jarMmap        0        0        0
  .apk mmap          $apkMmap        0    20800        0
  .ttf mmap            512        0      256        0
  .dex mmap          $dexMmap       64    16400        0
  .oat mmap          $oatMmap        0    15040        0
  .art mmap          $artMmap     3000        0        0
  Other mmap           400      400        0        0
  EGL mtrack         $egPss    52224        0        0
  GL mtrack          $glPss    24576        0        0
  Unknown             1280      900        0        0
${extraLines.join('\n')}
                  ------   ------   ------
            TOTAL   $totalPss   142540    87696      170
''';
}

void main() {
  group('MemoryParser', () {
    group('PSS total extraction', () {
      test('TOTAL PSS line extracts memory_pss_kb correctly', () {
        final output = _buildMeminfoOutput(totalPss: 524288);
        final result = MemoryParser.parse(output);
        expect(result.memoryPssKb, 524288);
        expect(result.memoryNativeKb, 45120);
      });
    });

    group('subsection extraction', () {
      test('Native Heap PSS extracted correctly', () {
        final output = _buildMeminfoOutput(nativePss: 45120);
        final result = MemoryParser.parse(output);
        expect(result.memoryNativeKb, 45120);
      });

      test('EGL + GL mtrack summed for graphics', () {
        final output = _buildMeminfoOutput(egPss: 52224, glPss: 24576);
        final result = MemoryParser.parse(output);
        expect(result.memoryGraphicsKb, 52224 + 24576); // 76800
      });

      test('Code subsection sums all 6 mmap families', () {
        final output = _buildMeminfoOutput(
          soMmap: 38400,
          jarMmap: 0,
          apkMmap: 21504,
          dexMmap: 18432,
          oatMmap: 15360,
          artMmap: 4096,
        );
        final result = MemoryParser.parse(output);
        // 38400 + 0 + 21504 + 18432 + 15360 + 4096 = 97792
        expect(result.memoryCodeKb, 97792);
      });

      test('Java Heap PSS extracted correctly', () {
        final output = _buildMeminfoOutput(javaPss: 12480);
        final result = MemoryParser.parse(output);
        expect(result.memoryJavaKb, 12480);
      });

      test('Stack PSS extracted correctly', () {
        final output = _buildMeminfoOutput(stackPss: 1024);
        final result = MemoryParser.parse(output);
        expect(result.memoryStackKb, 1024);
      });
    });

    group('null handling', () {
      test('null input returns all fields null', () {
        final result = MemoryParser.parse(null);
        expect(result.memoryPssKb, isNull);
        expect(result.memoryJavaKb, isNull);
        expect(result.memoryNativeKb, isNull);
        expect(result.memoryGraphicsKb, isNull);
        expect(result.memoryStackKb, isNull);
        expect(result.memoryCodeKb, isNull);
        expect(result.memorySystemKb, isNull);
      });

      test('empty output returns all fields null', () {
        final result = MemoryParser.parse('');
        expect(result.memoryPssKb, isNull);
      });
    });

    group('Android 6 format', () {
      test('Dalvik Heap used when Java Heap not present (Android 6-)', () {
        final output = _buildMeminfoOutput(
          javaLabel: 'Dalvik Heap',
          javaPss: 8640,
        );
        final result = MemoryParser.parse(output);
        // Should map Dalvik Heap to memory_java_kb
        expect(result.memoryJavaKb, isNotNull);
        expect(result.memoryJavaKb, 8640);
      });
    });
  });
}
