/// Result from GPU utilization parsing — all fields nullable per §5.7.
class GpuResult {
  /// GPU utilization percentage (0-100). null on failure.
  final double? gpuPct;

  const GpuResult({this.gpuPct});
}

/// Parses GPU utilization from Adreno or Mali sysfs paths per §5.7.
///
/// Three parsing paths, auto-detected by `parseAny`:
/// 1. Adreno: `cat /sys/class/kgsl/kgsl-3d0/gpubusy` → "busy total" → (busy/total)*100
/// 2. Mali: `cat /sys/class/misc/mali0/device/utilization` → integer 0-100
/// All parsing is pure synchronous string processing, never throws.
/// Never fabricates GPU values — returns null if all paths fail.
class GpuParser {
  GpuParser._();

  /// Parse Adreno GPU busy output.
  ///
  /// Format: two integers "busy total" separated by whitespace.
  /// Returns `gpu_pct = (busy / total) * 100.0`, clamped to [0, 100].
  static GpuResult parseAdreno(String? output) {
    if (output == null || output.trim().isEmpty) {
      return const GpuResult();
    }

    try {
      final parts = output.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) return const GpuResult();

      final busy = int.tryParse(parts[0]);
      final total = int.tryParse(parts[1]);
      if (busy == null || total == null || total <= 0) {
        return const GpuResult();
      }

      final pct = ((busy / total) * 100.0).clamp(0.0, 100.0);
      return GpuResult(gpuPct: pct);
    } catch (_) {
      return const GpuResult();
    }
  }

  /// Parse Mali GPU utilization output.
  ///
  /// Format: single integer 0-100 representing utilization percentage.
  /// Values outside [0, 100] are considered invalid and return null.
  static GpuResult parseMaliUtil(String? output) {
    if (output == null || output.trim().isEmpty) {
      return const GpuResult();
    }

    try {
      final value = int.tryParse(output.trim());
      if (value == null || value < 0 || value > 100) {
        return const GpuResult();
      }
      return GpuResult(gpuPct: value.toDouble());
    } catch (_) {
      return const GpuResult();
    }
  }

  /// Auto-detect GPU output format and parse.
  ///
  /// Tries Adreno format first (two integers separated by whitespace),
  /// then Mali format (single integer). Returns the first successful parse.
  /// Returns null if all paths fail — never fabricates a GPU value.
  static GpuResult parseAny(String? output) {
    if (output == null || output.trim().isEmpty) {
      return const GpuResult();
    }

    // Try Adreno format first (two integers)
    final parts = output.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final adrenoResult = parseAdreno(output);
      if (adrenoResult.gpuPct != null) return adrenoResult;
    }

    // Try Mali format (single integer)
    final maliResult = parseMaliUtil(output);
    if (maliResult.gpuPct != null) return maliResult;

    return const GpuResult();
  }
}
