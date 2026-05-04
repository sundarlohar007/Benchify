/// Device model — matches `devices` table in Appendix C exactly.
/// 22 columns: id, name, manufacturer, model, os_version, os_api_level,
/// kernel_version, chipset, chipset_vendor, gpu_vendor, gpu_model,
/// cpu_cores_count, cpu_max_freq_khz, screen_resolution, screen_density_dpi,
/// refresh_rate_hz, battery_capacity_mah, total_ram_kb, internal_storage_gb,
/// is_rooted, is_emulator, first_seen_at.
class Device {
  final String id; // ADB serial or iOS UDID
  final String name;
  final String? manufacturer;
  final String? model;
  final String? osVersion;
  final int? osApiLevel;
  final String? kernelVersion;
  final String? chipset;
  final String? chipsetVendor;
  final String? gpuVendor;
  final String? gpuModel;
  final int? cpuCoresCount;
  final int? cpuMaxFreqKhz;
  final String? screenResolution;
  final int? screenDensityDpi;
  final int? refreshRateHz;
  final int? batteryCapacityMah;
  final int? totalRamKb;
  final int? internalStorageGb;
  final int isRooted;
  final int isEmulator;
  final int firstSeenAt;

  const Device({
    required this.id,
    required this.name,
    this.manufacturer,
    this.model,
    this.osVersion,
    this.osApiLevel,
    this.kernelVersion,
    this.chipset,
    this.chipsetVendor,
    this.gpuVendor,
    this.gpuModel,
    this.cpuCoresCount,
    this.cpuMaxFreqKhz,
    this.screenResolution,
    this.screenDensityDpi,
    this.refreshRateHz,
    this.batteryCapacityMah,
    this.totalRamKb,
    this.internalStorageGb,
    this.isRooted = 0,
    this.isEmulator = 0,
    required this.firstSeenAt,
  });

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'] as String,
      name: map['name'] as String,
      manufacturer: map['manufacturer'] as String?,
      model: map['model'] as String?,
      osVersion: map['os_version'] as String?,
      osApiLevel: map['os_api_level'] as int?,
      kernelVersion: map['kernel_version'] as String?,
      chipset: map['chipset'] as String?,
      chipsetVendor: map['chipset_vendor'] as String?,
      gpuVendor: map['gpu_vendor'] as String?,
      gpuModel: map['gpu_model'] as String?,
      cpuCoresCount: map['cpu_cores_count'] as int?,
      cpuMaxFreqKhz: map['cpu_max_freq_khz'] as int?,
      screenResolution: map['screen_resolution'] as String?,
      screenDensityDpi: map['screen_density_dpi'] as int?,
      refreshRateHz: map['refresh_rate_hz'] as int?,
      batteryCapacityMah: map['battery_capacity_mah'] as int?,
      totalRamKb: map['total_ram_kb'] as int?,
      internalStorageGb: map['internal_storage_gb'] as int?,
      isRooted: (map['is_rooted'] as int?) ?? 0,
      isEmulator: (map['is_emulator'] as int?) ?? 0,
      firstSeenAt: map['first_seen_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'manufacturer': manufacturer,
      'model': model,
      'os_version': osVersion,
      'os_api_level': osApiLevel,
      'kernel_version': kernelVersion,
      'chipset': chipset,
      'chipset_vendor': chipsetVendor,
      'gpu_vendor': gpuVendor,
      'gpu_model': gpuModel,
      'cpu_cores_count': cpuCoresCount,
      'cpu_max_freq_khz': cpuMaxFreqKhz,
      'screen_resolution': screenResolution,
      'screen_density_dpi': screenDensityDpi,
      'refresh_rate_hz': refreshRateHz,
      'battery_capacity_mah': batteryCapacityMah,
      'total_ram_kb': totalRamKb,
      'internal_storage_gb': internalStorageGb,
      'is_rooted': isRooted,
      'is_emulator': isEmulator,
      'first_seen_at': firstSeenAt,
    };
  }
}
