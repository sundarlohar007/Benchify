/// Unified result from battery parsing — all fields nullable per §5.4.
class BatteryResult {
  /// Battery percentage (0-100).
  final int? batteryPct;

  /// Current draw in mA (absolute value).
  final double? batteryMa;

  /// Voltage in mV.
  final double? batteryMv;

  /// Temperature in degrees Celsius.
  final double? batteryTempC;

  /// Whether device is currently charging.
  final bool? charging;

  /// Charging source: "ac", "usb", "wireless", "dock", "none", or null.
  final String? chargingSource;

  /// Whether WiFi is active.
  final bool? wifiActive;

  const BatteryResult({
    this.batteryPct,
    this.batteryMa,
    this.batteryMv,
    this.batteryTempC,
    this.charging,
    this.chargingSource,
    this.wifiActive,
  });
}

/// Parses Android battery-related ADB/sysfs outputs per §5.4.
///
/// Multiple parse methods handle different ADB command outputs. The caller
/// (MetricCollector) runs the commands separately and combines results.
/// All parsing is pure synchronous string processing — no I/O, no blocking.
/// Returns null fields on malformed/missing input, never throws.
class BatteryParser {
  BatteryParser._();

  /// Parse `dumpsys battery` output.
  ///
  /// Extracts level (battery_pct), temperature (÷10 → °C), voltage (mV),
  /// AC/USB/Wireless/Dock powered flags, and charging status.
  /// Composite charging = any power source true OR status 2/5.
  static BatteryResult parseDumpsysBattery(String? output) {
    if (output == null || output.trim().isEmpty) {
      return const BatteryResult();
    }

    try {
      final int? level = _extractInt(output, 'level');
      final int? tempRaw = _extractInt(output, 'temperature');
      final double? tempC = tempRaw != null ? tempRaw / 10.0 : null;
      final int? voltageRaw = _extractInt(output, 'voltage');
      final double? mv = voltageRaw?.toDouble();

      final bool acPowered = _extractBool(output, 'AC powered');
      final bool usbPowered = _extractBool(output, 'USB powered');
      final bool wirelessPowered = _extractBool(output, 'Wireless powered');
      final bool dockPowered = _extractBool(output, 'Dock powered');
      final int? status = _extractInt(output, 'status');

      // Composite charging detection
      final anyPowered = acPowered || usbPowered || wirelessPowered || dockPowered;
      final bool charging = (anyPowered || status == 2 || status == 5) ? true : false;

      // Charging source: first true source
      String chargingSource;
      if (!charging) {
        chargingSource = 'none';
      } else if (acPowered) {
        chargingSource = 'ac';
      } else if (usbPowered) {
        chargingSource = 'usb';
      } else if (wirelessPowered) {
        chargingSource = 'wireless';
      } else if (dockPowered) {
        chargingSource = 'dock';
      } else {
        chargingSource = 'none'; // status 2/5 but no source detected
      }

      return BatteryResult(
        batteryPct: level,
        batteryTempC: tempC,
        batteryMv: mv,
        charging: charging,
        chargingSource: chargingSource,
      );
    } catch (_) {
      return const BatteryResult();
    }
  }

  /// Parse `cat /sys/class/power_supply/battery/current_now` output.
  ///
  /// Value in microamps (µA) → divided by 1000 → mA.
  /// Negative = discharging, stored as absolute value.
  /// Returns null field if file missing or parse fails.
  static BatteryResult parseCurrentNow(String? output) {
    if (output == null || output.trim().isEmpty) {
      return const BatteryResult();
    }

    try {
      final value = int.tryParse(output.trim());
      if (value == null) return const BatteryResult();
      return BatteryResult(batteryMa: value.abs() / 1000.0);
    } catch (_) {
      return const BatteryResult();
    }
  }

  /// Parse `cat /sys/class/power_supply/battery/voltage_now` output.
  ///
  /// Value in microvolts (µV) → divided by 1000 → mV.
  /// Prefer this over dumpsys battery voltage when available.
  static BatteryResult parseVoltageNow(String? output) {
    if (output == null || output.trim().isEmpty) {
      return const BatteryResult();
    }

    try {
      final value = int.tryParse(output.trim());
      if (value == null) return const BatteryResult();
      return BatteryResult(batteryMv: value / 1000.0);
    } catch (_) {
      return const BatteryResult();
    }
  }

  /// Parse WiFi state from connectivity or wifi dumpsys output.
  ///
  /// Tries: "NetworkInfo: type: WIFI" → true
  /// Fallback: "Wi-Fi is enabled" → true, "Wi-Fi is disabled" → false
  /// Returns null if neither parses.
  static BatteryResult parseWifiState(String? output) {
    if (output == null || output.trim().isEmpty) {
      return const BatteryResult();
    }

    try {
      // Primary: dumpsys connectivity output
      if (output.contains('NetworkInfo: type: WIFI')) {
        return const BatteryResult(wifiActive: true);
      }
      if (output.contains('NetworkInfo: type: MOBILE') ||
          output.contains('NetworkInfo: type: ETHERNET')) {
        return const BatteryResult(wifiActive: false);
      }

      // Fallback: dumpsys wifi output
      final lowered = output.toLowerCase();
      if (lowered.contains('wi-fi is enabled')) {
        return const BatteryResult(wifiActive: true);
      }
      if (lowered.contains('wi-fi is disabled')) {
        return const BatteryResult(wifiActive: false);
      }

      // Neither parsed successfully
      return const BatteryResult();
    } catch (_) {
      return const BatteryResult();
    }
  }

  /// Extract an integer field value from dumpsys output.
  /// Looks for pattern: "fieldName: <value>" with word boundary to avoid
  /// partial matches (e.g., "Max charging voltage:" vs "voltage:").
  static int? _extractInt(String output, String fieldName) {
    // Anchor at line start to avoid partial matches like "Max charging voltage:"
    // when looking for "voltage:".
    final escaped = RegExp.escape(fieldName);
    final match = RegExp('^\\s*$escaped:\\s*(\\d+)', multiLine: true)
        .firstMatch(output);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Extract a boolean field value from dumpsys output.
  /// Looks for pattern: "fieldName: true/false"
  static bool _extractBool(String output, String fieldName) {
    final match = RegExp('$fieldName:\\s*(true|false)', caseSensitive: false)
        .firstMatch(output);
    if (match == null) return false;
    return match.group(1)!.toLowerCase() == 'true';
  }
}
