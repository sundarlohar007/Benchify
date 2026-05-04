// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// Result from dumpsys meminfo parsing — all fields nullable per §5.3.
class MemoryResult {
  /// Total PSS in KB (primary metric).
  final int? memoryPssKb;

  /// Java/Dalvik Heap PSS in KB.
  final int? memoryJavaKb;

  /// Native Heap PSS in KB.
  final int? memoryNativeKb;

  /// Graphics PSS in KB (EGL mtrack + GL mtrack sum).
  final int? memoryGraphicsKb;

  /// Stack PSS in KB.
  final int? memoryStackKb;

  /// Code PSS in KB (sum of .so/.jar/.apk/.dex/.oat/.art mmap).
  final int? memoryCodeKb;

  /// System PSS in KB (all other categories combined).
  final int? memorySystemKb;

  const MemoryResult({
    this.memoryPssKb,
    this.memoryJavaKb,
    this.memoryNativeKb,
    this.memoryGraphicsKb,
    this.memoryStackKb,
    this.memoryCodeKb,
    this.memorySystemKb,
  });
}

/// Parses `dumpsys meminfo <package>` output per §5.3.
///
/// Extracts PSS Total plus 7 subsections from the meminfo table.
/// All parsing is pure synchronous string processing — no I/O, no blocking.
/// Returns null fields on malformed/missing input, never throws.
class MemoryParser {
  MemoryParser._();

  /// Labels that map to the code subsection (summed).
  static const _codeLabels = {
    '.so mmap',
    '.jar mmap',
    '.apk mmap',
    '.dex mmap',
    '.oat mmap',
    '.art mmap',
  };

  /// Parse dumpsys meminfo output into structured memory data.
  ///
  /// Returns [MemoryResult] with all fields null on failure/empty input.
  static MemoryResult parse(String? meminfoOutput) {
    if (meminfoOutput == null || meminfoOutput.trim().isEmpty) {
      return const MemoryResult();
    }

    try {
      final lines = meminfoOutput.split('\n');
      final parsed = <String, int>{};

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty || line.startsWith('------')) continue;

        // Check for TOTAL PSS line
        if (line.startsWith('TOTAL')) {
          final match = RegExp(r'TOTAL\s+(\d+)').firstMatch(line);
          if (match != null) {
            parsed['_total'] = int.parse(match.group(1)!);
          }
          continue;
        }

        // Skip header lines
        if (line.contains('Pss') && line.contains('Private')) continue;

        // Try to parse a label + PSS value line
        // Format: label (multi-word) followed by numbers
        final numberMatch = RegExp(r'(\d+)').firstMatch(line);
        if (numberMatch == null) continue;

        // Extract the label (everything before the first number)
        final numberStart = numberMatch.start;
        var label = line.substring(0, numberStart).trim();

        // Normalize label: collapse multiple spaces, trim
        label = label.replaceAll(RegExp(r'\s+'), ' ');

        if (label.isEmpty) continue;

        final pssValue = int.parse(numberMatch.group(1)!);
        parsed[label] = pssValue;
      }

      if (parsed.isEmpty) {
        return const MemoryResult();
      }

      // Map parsed labels to schema columns
      int? total = parsed.remove('_total');

      // Java Heap (modern Android 7+) or Dalvik Heap (Android 6-)
      int? javaKb = parsed['Java Heap'] ?? parsed['Dalvik Heap'];

      // Native Heap
      int? nativeKb = parsed['Native Heap'];

      // Graphics = EGL mtrack + GL mtrack
      int? graphicsKb;
      final egl = parsed['EGL mtrack'];
      final gl = parsed['GL mtrack'];
      if (egl != null || gl != null) {
        graphicsKb = (egl ?? 0) + (gl ?? 0);
      }

      // Stack
      int? stackKb = parsed['Stack'];

      // Code = sum of all mmap families
      int codeKb = 0;
      bool hasCode = false;
      for (final label in _codeLabels) {
        if (parsed.containsKey(label)) {
          codeKb += parsed[label]!;
          hasCode = true;
        }
      }
      final codeResult = hasCode ? codeKb : null;

      // System = sum of all remaining labels
      int systemKb = 0;
      bool hasSystem = false;
      for (final entry in parsed.entries) {
        final label = entry.key;
        // Skip labels we've already mapped
        if (label == 'Java Heap' ||
            label == 'Dalvik Heap' ||
            label == 'Native Heap' ||
            label == 'EGL mtrack' ||
            label == 'GL mtrack' ||
            label == 'Stack' ||
            _codeLabels.contains(label)) {
          continue;
        }
        systemKb += entry.value;
        hasSystem = true;
      }
      final systemResult = hasSystem ? systemKb : null;

      return MemoryResult(
        memoryPssKb: total,
        memoryJavaKb: javaKb,
        memoryNativeKb: nativeKb,
        memoryGraphicsKb: graphicsKb,
        memoryStackKb: stackKb,
        memoryCodeKb: codeResult,
        memorySystemKb: systemResult,
      );
    } catch (_) {
      return const MemoryResult();
    }
  }
}
