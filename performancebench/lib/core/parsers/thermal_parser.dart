/// Result from thermal status parsing — all fields nullable per §5.6.
class ThermalResult {
  /// Thermal status (0=normal, 1=fair, 2=serious, 3=critical). null on failure.
  final int? thermalStatus;

  const ThermalResult({this.thermalStatus});
}

/// Parses Android thermal status from dumpsys or getprop per §5.6.
///
/// Two parsing paths, tried in order:
/// 1. `dumpsys thermalservice` — parse "Status:" field
/// 2. `getprop sys.thermal.state` — parse integer 0-3
/// All parsing is pure synchronous string processing, never throws.
class ThermalParser {
  ThermalParser._();

  static const _statusMap = {
    'normal': 0,
    'fair': 1,
    'serious': 2,
    'critical': 3,
  };

  /// Parse `dumpsys thermalservice` output.
  ///
  /// Extracts the "Status:" field and maps to 0-3 integer.
  /// Returns null thermalStatus on failure or unrecognized status.
  static ThermalResult parseThermalService(String? output) {
    if (output == null || output.trim().isEmpty) {
      return const ThermalResult();
    }

    try {
      final match =
          RegExp(r'Status:\s*(\w+)', caseSensitive: false).firstMatch(output);
      if (match == null) return const ThermalResult();

      final statusStr = match.group(1)!.toLowerCase();
      final status = _statusMap[statusStr];
      return ThermalResult(thermalStatus: status);
    } catch (_) {
      return const ThermalResult();
    }
  }

  /// Parse `getprop sys.thermal.state` output as fallback.
  ///
  /// Expects an integer 0-3. Returns null on failure.
  static ThermalResult parseGetprop(String? output) {
    if (output == null || output.trim().isEmpty) {
      return const ThermalResult();
    }

    try {
      final value = int.tryParse(output.trim());
      if (value != null && value >= 0 && value <= 3) {
        return ThermalResult(thermalStatus: value);
      }
      return const ThermalResult();
    } catch (_) {
      return const ThermalResult();
    }
  }
}
