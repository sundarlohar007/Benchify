/// Result from /proc/net/dev parsing — all fields nullable per §5.5.
class NetworkResult {
  /// Total received bytes (all interfaces except loopback).
  final int? netRxBytes;

  /// Total transmitted bytes (all interfaces except loopback).
  final int? netTxBytes;

  /// WiFi received bytes.
  final int? netWifiRxBytes;

  /// WiFi transmitted bytes.
  final int? netWifiTxBytes;

  /// Cellular received bytes.
  final int? netCellularRxBytes;

  /// Cellular transmitted bytes.
  final int? netCellularTxBytes;

  /// Other interface received bytes.
  final int? netOtherRxBytes;

  /// Other interface transmitted bytes.
  final int? netOtherTxBytes;

  const NetworkResult({
    this.netRxBytes,
    this.netTxBytes,
    this.netWifiRxBytes,
    this.netWifiTxBytes,
    this.netCellularRxBytes,
    this.netCellularTxBytes,
    this.netOtherRxBytes,
    this.netOtherTxBytes,
  });
}

/// Parses `cat /proc/net/dev` output per §5.5.
///
/// Classifies interfaces into WiFi/Cellular/Other by name prefix.
/// Excludes loopback (lo) from all totals.
/// Returns cumulative byte counters — delta computation is handled
/// at the analytics/display layer.
/// All parsing is pure synchronous string processing, never throws.
class NetworkParser {
  NetworkParser._();

  /// WiFi interface name prefixes.
  static const _wifiPrefixes = ['wlan', 'wifi', 'nan'];

  /// Cellular interface name prefixes.
  static const _cellularPrefixes = ['rmnet', 'ccmni', 'pdp', 'ppp'];

  /// Parse /proc/net/dev output into classified cumulative byte counters.
  ///
  /// Returns [NetworkResult] with all fields null on null/empty/malformed input.
  static NetworkResult parse(String? procNetDev) {
    if (procNetDev == null || procNetDev.trim().isEmpty) {
      return const NetworkResult();
    }

    try {
      final lines = procNetDev.split('\n');

      int totalRx = 0;
      int totalTx = 0;
      int wifiRx = 0;
      int wifiTx = 0;
      int cellularRx = 0;
      int cellularTx = 0;
      int otherRx = 0;
      int otherTx = 0;
      bool hasData = false;

      // Skip first 2 header lines
      for (var i = 2; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        // Split on ':' to separate interface name from counters
        final colonIdx = line.indexOf(':');
        if (colonIdx < 0) continue;

        final ifaceName = line.substring(0, colonIdx).trim();
        final counters = line.substring(colonIdx + 1).trim();

        // Skip loopback
        if (ifaceName == 'lo') continue;

        // Parse RX bytes (first field) and TX bytes (field index 8 after rx bytes)
        final fields = counters.split(RegExp(r'\s+'));
        if (fields.length < 9) continue;

        final rxBytes = int.tryParse(fields[0]);
        final txBytes = int.tryParse(fields[8]);
        if (rxBytes == null || txBytes == null) continue;

        hasData = true;

        // Classify by prefix
        if (_matchesPrefix(ifaceName, _wifiPrefixes)) {
          wifiRx += rxBytes;
          wifiTx += txBytes;
        } else if (_matchesPrefix(ifaceName, _cellularPrefixes)) {
          cellularRx += rxBytes;
          cellularTx += txBytes;
        } else {
          otherRx += rxBytes;
          otherTx += txBytes;
        }

        totalRx += rxBytes;
        totalTx += txBytes;
      }

      if (!hasData) {
        return const NetworkResult();
      }

      return NetworkResult(
        netRxBytes: totalRx,
        netTxBytes: totalTx,
        netWifiRxBytes: wifiRx,
        netWifiTxBytes: wifiTx,
        netCellularRxBytes: cellularRx,
        netCellularTxBytes: cellularTx,
        netOtherRxBytes: otherRx,
        netOtherTxBytes: otherTx,
      );
    } catch (_) {
      return const NetworkResult();
    }
  }

  /// Check if [ifaceName] starts with any of the given [prefixes].
  static bool _matchesPrefix(String ifaceName, List<String> prefixes) {
    for (final prefix in prefixes) {
      if (ifaceName.startsWith(prefix)) return true;
    }
    return false;
  }
}
