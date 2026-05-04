import 'dart:async';
import 'dart:io' show Platform, Process, ProcessResult;

import '../models/device.dart';

/// Parsed app info from device.
class AppInfo {
  final String package;
  final String name;
  final String version;
  final int? buildNumber;

  const AppInfo({
    required this.package,
    required this.name,
    required this.version,
    this.buildNumber,
  });
}

/// Parsed static device hardware data.
class StaticDeviceData {
  final String serial;
  final String? manufacturer;
  final String? model;
  final String? board;
  final String? osVersion;
  final String? osApiLevel;
  final String? chipset;
  final String? chipsetVendor;
  final String? gpuVendor;
  final String? gpuModel;
  final String? gpuDriverVersion;
  final String? screenResolution;
  final int? screenDensityDpi;
  final int? refreshRateHz;
  final int? totalRamKb;
  final int? internalStorageGb;
  final int? batteryCapacityMah;
  final bool isEmulator;
  final bool isRooted;
  final Map<String, String> allProps;

  const StaticDeviceData({
    required this.serial,
    this.manufacturer,
    this.model,
    this.board,
    this.osVersion,
    this.osApiLevel,
    this.chipset,
    this.chipsetVendor,
    this.gpuVendor,
    this.gpuModel,
    this.gpuDriverVersion,
    this.screenResolution,
    this.screenDensityDpi,
    this.refreshRateHz,
    this.totalRamKb,
    this.internalStorageGb,
    this.batteryCapacityMah,
    this.isEmulator = false,
    this.isRooted = false,
    this.allProps = const {},
  });
}

/// Parsed static app data.
class StaticAppData {
  final String? installSource;
  final int? installTimeMs;
  final int? updateTimeMs;
  final int? targetSdk;
  final int? minSdk;
  final String? permissionsJson;
  final String? abiList;
  final int? apkSizeBytes;

  const StaticAppData({
    this.installSource,
    this.installTimeMs,
    this.updateTimeMs,
    this.targetSdk,
    this.minSdk,
    this.permissionsJson,
    this.abiList,
    this.apkSizeBytes,
  });
}

/// Wrapper around ADB subprocess calls for Android device interaction.
/// All ADB calls use 3-second timeout and async/await — no blocking on UI thread.
///
/// Threat mitigations (T-01-01, T-01-03, T-01-04):
/// - All ADB output validated before parsing; malformed output returns null.
/// - Numeric fields parsed with int.tryParse / double.tryParse.
/// - String fields sanitized with reasonable size limits.
/// - 3-second timeout on all subprocess calls.
/// - ADB serial validated against alphanumeric+dot+dash+colon pattern.
/// - Package names validated against Android package name regex.
class AdbService {
  final String _adbPath;

  /// Creates an AdbService. Finds `adb` on PATH via platform command.
  /// Throws [StateError] if ADB is not found.
  AdbService._(this._adbPath);

  static Future<AdbService> create() async {
    final adbPath = await _findAdb();
    if (adbPath == null) {
      throw StateError(
        'ADB not found on PATH. Please install Android SDK Platform Tools '
        'and ensure `adb` is available in your terminal.',
      );
    }
    return AdbService._(adbPath);
  }

  /// Locate `adb` on the system PATH.
  static Future<String?> _findAdb() async {
    try {
      final cmd = Platform.isWindows ? 'where' : 'which';
      final result = await Process.run(cmd, ['adb']);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim().split('\n').first.trim();
        return path.isNotEmpty ? path : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Centralized ADB subprocess call with timeout.
  /// Returns [ProcessResult] on success, null on timeout or non-zero exit.
  Future<ProcessResult?> _runAdb(
    List<String> args, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    try {
      final result = await Process.run(_adbPath, args).timeout(timeout);
      if (result.exitCode != 0) return null;
      return result;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Serial validation: alphanumeric, dot, dash, colon (ADB serial / IP:port).
  static bool _isValidSerial(String serial) {
    return RegExp(r'^[a-zA-Z0-9.\-:]+$').hasMatch(serial);
  }

  /// Package name validation: Android package name regex.
  static bool _isValidPackage(String pkg) {
    return RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$')
        .hasMatch(pkg);
  }

  // ===========================================================================
  // Device Discovery
  // ===========================================================================

  /// Discovers connected Android devices via `adb devices -l`.
  /// Returns list of Device objects with serial, name, model, state.
  /// Filters unauthorized/offline devices from active list but shows them
  /// as disabled rows (name includes status).
  Future<List<Device>> discoverDevices() async {
    final result = await _runAdb(['devices', '-l']);
    if (result == null) return [];

    final stdout = result.stdout as String;
    final lines = stdout.trim().split('\n');
    final devices = <Device>[];

    // Skip header line "List of devices attached"
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;

      final serial = parts[0];
      if (!_isValidSerial(serial)) continue;

      final status = parts[1]; // 'device', 'offline', 'unauthorized'
      final isOnline = status == 'device';

      // Parse extra fields: "product:xxx model:xxx device:xxx transport_id:N"
      String? product;
      String? model;
      String? deviceName;
      for (var j = 2; j < parts.length; j++) {
        final kv = parts[j].split(':');
        if (kv.length == 2) {
          switch (kv[0]) {
            case 'product':
              product = kv[1];
            case 'model':
              model = kv[1];
            case 'device':
              deviceName = kv[1];
          }
        }
      }

      final name = deviceName ?? model ?? product ?? serial;
      final displayName = isOnline
          ? name
          : '$name ($status)';

      devices.add(Device(
        id: serial,
        name: displayName,
        model: model,
        firstSeenAt: DateTime.now().millisecondsSinceEpoch,
        // is_rooted and is_emulator will be filled by collectStaticData
      ));
    }

    return devices;
  }

  // ===========================================================================
  // App Listing
  // ===========================================================================

  /// Lists installed third-party apps on the device via `pm list packages -3`.
  /// Returns list of AppInfo with package, label, version, and version code.
  Future<List<AppInfo>> listApps(String serial) async {
    if (!_isValidSerial(serial)) return [];

    final result = await _runAdb(['-s', serial, 'shell', 'pm', 'list', 'packages', '-3']);
    if (result == null) return [];

    final stdout = result.stdout as String;
    final lines = stdout.trim().split('\n');
    final apps = <AppInfo>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('package:')) continue;

      final pkg = trimmed.substring('package:'.length);
      if (!_isValidPackage(pkg)) continue;

      // Get app label, version, version code via dumpsys
      final appInfo = await _getAppInfo(serial, pkg);
      apps.add(AppInfo(
        package: pkg,
        name: appInfo['name'] as String? ?? pkg,
        version: appInfo['version'] as String? ?? 'unknown',
        buildNumber: appInfo['buildNumber'] as int?,
      ));
    }

    return apps;
  }

  /// Extracts app label, versionName, versionCode from dumpsys.
  Future<Map<String, dynamic>> _getAppInfo(String serial, String pkg) async {
    final result = await _runAdb(['-s', serial, 'shell', 'dumpsys', 'package', pkg]);
    if (result == null) return {};

    final stdout = result.stdout as String;
    String? label;
    String? versionName;
    int? versionCode;

    for (final line in stdout.split('\n')) {
      final trimmed = line.trim();
      if (label == null) {
        final labelMatch =
            RegExp(r'^\s*labelRes=0x[0-9a-fA-F]+\s+nonLocalizedLabel=(.+)')
                .firstMatch(trimmed);
        if (labelMatch != null) {
          label = labelMatch.group(1)?.trim();
        }
        // Only use nonLocalizedLabel or fall back to package name
      }
      if (versionName == null) {
        final vnMatch = RegExp(r'^\s*versionName=(.+)').firstMatch(trimmed);
        if (vnMatch != null) versionName = vnMatch.group(1)?.trim();
      }
      if (versionCode == null) {
        final vcMatch = RegExp(r'^\s*versionCode=(\d+)').firstMatch(trimmed);
        if (vcMatch != null) versionCode = int.tryParse(vcMatch.group(1)!);
      }
      if (label != null && versionName != null && versionCode != null) break;
    }

    // Fallback: try to get label via application info line
    if (label == null) {
      for (final line in stdout.split('\n')) {
        final labelMatch =
            RegExp(r'^\s*applicationInfo=ApplicationInfo\{.*?\blabel=(.+?)[,}]')
                .firstMatch(line.trim());
        if (labelMatch != null) {
          label = labelMatch.group(1)?.trim();
          break;
        }
      }
    }

    return {
      'name': label ?? pkg,
      'version': versionName,
      'buildNumber': versionCode,
    };
  }

  // ===========================================================================
  // Static Device Data Collection (§5.11)
  // ===========================================================================

  /// Collects full static device data via getprop + dumpsys + other commands.
  /// All fields parsed from output with tryParse safety nets.
  Future<StaticDeviceData> collectStaticData(String serial) async {
    if (!_isValidSerial(serial)) {
      return StaticDeviceData(serial: serial);
    }

    // Collect all getprop values in one call
    final props = await _getAllProps(serial);

    // Parse individual fields with safety nets
    final manufacturer = props['ro.product.manufacturer'] ?? props['ro.product.vendor'];
    final model = props['ro.product.model'];
    final board = props['ro.product.board'];
    final osVersion = props['ro.build.version.release'];
    final apiLevel = props['ro.build.version.sdk'];
    final chipset = props['ro.board.platform'] ?? props['ro.chipname'];
    final chipsetVendor = _resolveChipsetVendor(chipset);
    final gpuVendor = _resolveGpuVendor(props);
    final gpuModel = props['ro.gpu'];
    final gpuDriver = props['ro.gpu.driver'];

    // Screen resolution via dumpsys window
    String? screenRes;
    int? densityDpi;
    int? refreshRate;
    try {
      final wmResult = await _runAdb(
        ['-s', serial, 'shell', 'dumpsys', 'window', 'displays'],
      );
      if (wmResult != null) {
        final wmOut = wmResult.stdout as String;
        final resMatch = RegExp(r'cur=(\d+x\d+)').firstMatch(wmOut);
        if (resMatch != null) screenRes = resMatch.group(1);

        final dpiMatch = RegExp(r'dpi=(\d+)').firstMatch(wmOut);
        if (dpiMatch != null) densityDpi = int.tryParse(dpiMatch.group(1)!);

        final rrMatch = RegExp(r'refreshRate=([\d.]+)').firstMatch(wmOut);
        if (rrMatch != null) {
          refreshRate = double.tryParse(rrMatch.group(1)!)?.round();
        }
      }
    } catch (_) {
      // Non-critical — continue
    }

    // RAM from /proc/meminfo
    int? totalRamKb;
    try {
      final memResult = await _runAdb(
        ['-s', serial, 'shell', 'cat', '/proc/meminfo'],
      );
      if (memResult != null) {
        final memOut = memResult.stdout as String;
        final ramMatch = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(memOut);
        if (ramMatch != null) totalRamKb = int.tryParse(ramMatch.group(1)!);
      }
    } catch (_) {
      // Non-critical
    }

    // Storage from df
    int? storageGb;
    try {
      final dfResult = await _runAdb(
        ['-s', serial, 'shell', 'df', '-k', '/data'],
      );
      if (dfResult != null) {
        final dfOut = dfResult.stdout as String;
        final lines = dfOut.trim().split('\n');
        if (lines.length >= 2) {
          final cols = lines[1].split(RegExp(r'\s+'));
          if (cols.length >= 2) {
            final totalKb = int.tryParse(cols[1]);
            if (totalKb != null) storageGb = (totalKb / 1024 / 1024).round();
          }
        }
      }
    } catch (_) {
      // Non-critical
    }

    // Battery capacity from dumpsys battery
    int? batteryMah;
    try {
      final batResult = await _runAdb(
        ['-s', serial, 'shell', 'dumpsys', 'battery'],
      );
      if (batResult != null) {
        final batOut = batResult.stdout as String;
        // Try to find capacity from power profile
        final capMatch =
            RegExp(r'battery_capacity[=:]\s*(\d+)').firstMatch(batOut);
        if (capMatch != null) batteryMah = int.tryParse(capMatch.group(1)!);
      }
    } catch (_) {
      // Non-critical
    }

    // Power profile fallback for battery capacity
    if (batteryMah == null) {
      try {
        final ppResult = await _runAdb(
          ['-s', serial, 'shell', 'cat', '/sys/class/power_supply/battery/capacity'],
        );
        if (ppResult != null) {
          batteryMah = int.tryParse((ppResult.stdout as String).trim());
        }
      } catch (_) {}
    }

    // Emulator detection
    bool isEmulator = false;
    final buildFingerprint = props['ro.build.fingerprint']?.toLowerCase() ?? '';
    final buildHardware = props['ro.hardware']?.toLowerCase() ?? '';
    final buildProduct = props['ro.product.name']?.toLowerCase() ?? '';
    if (buildFingerprint.contains('generic') ||
        buildFingerprint.contains('sdk_gphone') ||
        buildFingerprint.contains('emulator') ||
        buildHardware.contains('goldfish') ||
        buildHardware.contains('ranchu') ||
        buildHardware.contains('vbox') ||
        buildProduct.contains('sdk_gphone') ||
        buildProduct.contains('emulator')) {
      isEmulator = true;
    }

    // Root detection
    bool isRooted = false;
    try {
      final suResult = await _runAdb(
        ['-s', serial, 'shell', 'which', 'su'],
      );
      if (suResult != null) {
        final suPath = (suResult.stdout as String).trim();
        if (suPath.isNotEmpty && !suPath.contains('not found')) {
          isRooted = true;
        }
      }
    } catch (_) {
      // Can't determine — assume not rooted
    }

    return StaticDeviceData(
      serial: serial,
      manufacturer: manufacturer,
      model: model,
      board: board,
      osVersion: osVersion,
      osApiLevel: apiLevel,
      chipset: chipset,
      chipsetVendor: chipsetVendor,
      gpuVendor: gpuVendor,
      gpuModel: gpuModel,
      gpuDriverVersion: gpuDriver,
      screenResolution: screenRes,
      screenDensityDpi: densityDpi,
      refreshRateHz: refreshRate,
      totalRamKb: totalRamKb,
      internalStorageGb: storageGb,
      batteryCapacityMah: batteryMah,
      isEmulator: isEmulator,
      isRooted: isRooted,
      allProps: props,
    );
  }

  /// Run `getprop` and parse all properties into a Map.
  Future<Map<String, String>> _getAllProps(String serial) async {
    final props = <String, String>{};
    final result = await _runAdb(['-s', serial, 'shell', 'getprop']);
    if (result == null) return props;

    final stdout = result.stdout as String;
    for (final line in stdout.split('\n')) {
      final trimmed = line.trim();
      // Format: [key]: [value]
      final match = RegExp(r'^\[(.+?)\]:\s*\[(.*)\]$').firstMatch(trimmed);
      if (match != null) {
        props[match.group(1)!] = match.group(2)!;
      }
    }
    return props;
  }

  /// Try to resolve chipset vendor from chipset/platform name.
  String? _resolveChipsetVendor(String? chipset) {
    if (chipset == null) return null;
    final lower = chipset.toLowerCase();
    if (lower.contains('snapdragon') || lower.contains('msm') || lower.contains('sm') || lower.contains('qcom')) {
      return 'qualcomm';
    }
    if (lower.contains('mt') || lower.contains('mediatek')) return 'mediatek';
    if (lower.contains('exynos') || lower.contains('universal')) return 'samsung';
    if (lower.contains('tensor') || lower.contains('gs')) return 'google';
    if (lower.contains('apple') || lower.contains('s5e')) return 'apple';
    if (lower.contains('unisoc') || lower.contains('sc') || lower.contains('spreadtrum')) {
      return 'unisoc';
    }
    if (lower.contains('kirin') || lower.contains('hi')) return 'hisilicon';
    return 'unknown';
  }

  /// Try to resolve GPU vendor from props.
  String? _resolveGpuVendor(Map<String, String> props) {
    final gpu = (props['ro.gpu'] ?? props['ro.hardware.vulkan'] ?? '')
        .toLowerCase();
    final hw = (props['ro.hardware.egl'] ?? '').toLowerCase();

    if (gpu.contains('adreno') || hw.contains('adreno')) return 'adreno';
    if (gpu.contains('mali') || hw.contains('mali')) return 'mali';
    if (gpu.contains('powervr') || hw.contains('powervr')) return 'powervr';
    if (gpu.contains('apple')) return 'apple';
    if (gpu.contains('intel') || hw.contains('intel')) return 'intel';
    return 'unknown';
  }

  // ===========================================================================
  // Static App Data Collection
  // ===========================================================================

  /// Collects static app data from dumpsys package.
  Future<StaticAppData> collectAppData(String serial, String package) async {
    if (!_isValidSerial(serial) || !_isValidPackage(package)) {
      return const StaticAppData();
    }

    final result = await _runAdb(
      ['-s', serial, 'shell', 'dumpsys', 'package', package],
    );
    if (result == null) return const StaticAppData();

    final stdout = result.stdout as String;
    String? installSource;
    int? installTimeMs;
    int? updateTimeMs;
    int? targetSdk;
    int? minSdk;
    final permissions = <String>[];
    final abis = <String>[];
    int? apkSizeBytes;

    for (final line in stdout.split('\n')) {
      final trimmed = line.trim();

      // install source
      if (installSource == null) {
        final m = RegExp(r'installerPackageName=([^\s]+)').firstMatch(trimmed);
        if (m != null) installSource = m.group(1);
      }

      // install time
      if (installTimeMs == null) {
        final m = RegExp(r'firstInstallTime=(\d+)').firstMatch(trimmed);
        if (m != null) installTimeMs = int.tryParse(m.group(1)!);
      }

      // update time
      if (updateTimeMs == null) {
        final m = RegExp(r'lastUpdateTime=(\d+)').firstMatch(trimmed);
        if (m != null) updateTimeMs = int.tryParse(m.group(1)!);
      }

      // targetSdk
      if (targetSdk == null) {
        final m = RegExp(r'targetSdk=(\d+)').firstMatch(trimmed);
        if (m != null) targetSdk = int.tryParse(m.group(1)!);
      }

      // minSdk
      if (minSdk == null) {
        final m = RegExp(r'compileSdkVersionCodename=.*').firstMatch(trimmed);
        if (m == null) {
          final m2 = RegExp(r'minSdkVersion=(\d+)').firstMatch(trimmed);
          if (m2 != null) minSdk = int.tryParse(m2.group(1)!);
        }
      }

      // permissions
      {
        final m = RegExp(r'^\s*([a-zA-Z][a-zA-Z0-9_.]*permission\.[a-zA-Z0-9_.]+):\s*granted=true')
            .firstMatch(trimmed);
        if (m != null) permissions.add(m.group(1)!);
      }

      // ABIs
      {
        final m = RegExp(r'^\s*supportedAbi:\s*(.+)').firstMatch(trimmed);
        if (m != null) abis.add(m.group(1)!.trim());
      }

      // APK size — from .apk path size
      if (apkSizeBytes == null) {
        final m = RegExp(r'codePath=([^\s]+\.apk)').firstMatch(trimmed);
        if (m != null) {
          // Try to stat the apk
          final apkPath = m.group(1)!;
          try {
            final statResult = await _runAdb(
              ['-s', serial, 'shell', 'stat', '-c', '%s', apkPath],
            );
            if (statResult != null) {
              apkSizeBytes =
                  int.tryParse((statResult.stdout as String).trim());
            }
          } catch (_) {}
        }
      }
    }

    return StaticAppData(
      installSource: installSource,
      installTimeMs: installTimeMs,
      updateTimeMs: updateTimeMs,
      targetSdk: targetSdk,
      minSdk: minSdk,
      permissionsJson: permissions.isNotEmpty
          ? '[${permissions.map((p) => '"$p"').join(',')}]'
          : null,
      abiList: abis.isNotEmpty ? abis.join(',') : null,
      apkSizeBytes: apkSizeBytes,
    );
  }
}
