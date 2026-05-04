/// Result from CPU parsing — all fields nullable.
class CpuResult {
  /// App CPU percentage (0-100). null on first sample or parse failure.
  final double? cpuAppPct;

  /// System CPU percentage (0-100). null on first sample or parse failure.
  final double? cpuSystemPct;

  /// Frequency-normalized app CPU percentage. null if sysfs unavailable.
  final double? cpuAppPctFreqNorm;

  /// JSON array of core count (string for backward compat).
  final String? cpuCores;

  /// JSON array of per-core online states.
  final String? cpuCoreStatesJson;

  /// JSON array of per-core current frequencies (kHz).
  final String? cpuCoreFreqsJson;

  const CpuResult({
    this.cpuAppPct,
    this.cpuSystemPct,
    this.cpuAppPctFreqNorm,
    this.cpuCores,
    this.cpuCoreStatesJson,
    this.cpuCoreFreqsJson,
  });
}

/// Result from core frequency parsing.
class CpuFreqResult {
  /// JSON array of per-core online states (1=on, 0=off).
  final String? cpuCoreStatesJson;

  /// JSON array of per-core current frequencies in kHz.
  final String? cpuCoreFreqsJson;

  /// Total max cycles across all cores (kHz). Cached after first read.
  final int? totalMaxCycles;

  /// Total available cycles from online cores (kHz).
  final int? totalAvailCycles;

  const CpuFreqResult({
    this.cpuCoreStatesJson,
    this.cpuCoreFreqsJson,
    this.totalMaxCycles,
    this.totalAvailCycles,
  });
}

/// Parses /proc/pid/stat, /proc/stat, and sysfs CPU frequency data per §5.2.
///
/// Maintains internal state (snapshots) to compute delta-based CPU percentages.
/// First sample stores snapshots and returns null for pct fields.
/// All parsing is pure synchronous string processing — no I/O, no blocking.
class CpuParser {
  int? _prevPidTicks;
  int? _prevTotalTicks;
  int? _prevIdleTicks;

  // Cached max cycles from first sysfs read (constant per boot).
  int? _cachedTotalMaxCycles;
  int? _cachedTotalAvailCycles;

  /// Parse combined process and system CPU stats.
  ///
  /// [pidStat] is the output of `cat /proc/<pid>/stat`.
  /// [procStat] is the output of `cat /proc/stat` (first line starting "cpu ").
  ///
  /// On first call, stores snapshots and returns null for pct fields.
  /// On subsequent calls, computes delta-based percentages.
  CpuResult parse(String? pidStat, String? procStat) {
    if (pidStat == null || procStat == null) {
      // Store snapshots as null so next call also returns null
      _storeSnapshots(null, null, null);
      return const CpuResult();
    }

    final pidTicks = _extractPidTicks(pidStat);
    final systemTicks = _extractSystemTicks(procStat);

    if (pidTicks == null || systemTicks == null) {
      _storeSnapshots(null, null, null);
      return const CpuResult();
    }

    final totalTicks = systemTicks.totalTicks;
    final idleTicks = systemTicks.idleTicks;

    double? cpuAppPct;
    double? cpuSystemPct;

    // Compute deltas if we have previous snapshots
    if (_prevPidTicks != null && _prevTotalTicks != null) {
      final deltaPid = pidTicks - _prevPidTicks!;
      final deltaTotal = totalTicks - _prevTotalTicks!;
      if (deltaTotal > 0) {
        cpuAppPct = ((deltaPid / deltaTotal) * 100.0).clamp(0.0, 100.0);
      }
    }

    if (_prevTotalTicks != null && _prevIdleTicks != null) {
      final deltaTotal = totalTicks - _prevTotalTicks!;
      final deltaIdle = idleTicks - _prevIdleTicks!;
      if (deltaTotal > 0) {
        cpuSystemPct =
            (((deltaTotal - deltaIdle) / deltaTotal) * 100.0).clamp(0.0, 100.0);
      }
    }

    // Store current snapshots for next call
    _storeSnapshots(pidTicks, totalTicks, idleTicks);

    return CpuResult(
      cpuAppPct: cpuAppPct,
      cpuSystemPct: cpuSystemPct,
    );
  }

  /// Parse sysfs CPU frequency output per §5.2.1.
  ///
  /// [sysfsOutput] is the combined output of the sysfs glob command.
  /// Caches total_max_cycles after first successful read.
  CpuFreqResult parseCoreFreqs(String? sysfsOutput) {
    if (sysfsOutput == null || sysfsOutput.trim().isEmpty) {
      return const CpuFreqResult();
    }

    final blocks = sysfsOutput.split('---');
    final coreStates = <int>[];
    final coreFreqs = <int>[];
    final maxFreqs = <int>[];

    var i = 0;
    while (i < blocks.length) {
      final block = blocks[i].trim();
      if (block.isEmpty) {
        i++;
        continue;
      }

      final lines = block.split('\n').map((l) => l.trim()).toList();
      if (lines.length < 3) {
        i++;
        continue;
      }

      // lines[0]: core path (e.g., /sys/devices/system/cpu/cpu0)
      // lines[1]: online (1/0)
      // lines[2]: scaling_cur_freq (kHz)
      // lines[3]: cpuinfo_max_freq (kHz) — optional
      final online = int.tryParse(lines[1]);
      final curFreq = int.tryParse(lines[2]);
      final maxFreq = lines.length > 3 ? int.tryParse(lines[3]) : null;

      if (online == null || curFreq == null) {
        i++;
        continue;
      }

      coreStates.add(online);
      coreFreqs.add(online == 1 ? curFreq : 0);
      if (maxFreq != null) {
        maxFreqs.add(maxFreq);
      }

      i++;
    }

    if (coreStates.isEmpty) {
      return const CpuFreqResult();
    }

    // Compute totals
    final totalAvail = <int>[];
    for (var j = 0; j < coreStates.length; j++) {
      if (coreStates[j] == 1) {
        totalAvail.add(coreFreqs[j] > 0 ? coreFreqs[j] : 0);
      }
    }

    final totalAvailCycles =
        totalAvail.fold<int>(0, (sum, f) => sum + f);
    final totalMaxCycles =
        maxFreqs.fold<int>(0, (sum, f) => sum + f);

    if (totalMaxCycles > 0) {
      _cachedTotalMaxCycles = totalMaxCycles;
      _cachedTotalAvailCycles = totalAvailCycles;
    }

    return CpuFreqResult(
      cpuCoreStatesJson:
          '[${coreStates.join(',')}]',
      cpuCoreFreqsJson:
          '[${coreFreqs.join(',')}]',
      totalMaxCycles: totalMaxCycles > 0 ? totalMaxCycles : null,
      totalAvailCycles: totalAvailCycles,
    );
  }

  /// Compute frequency-normalized CPU percentage.
  ///
  /// [cpuAppPct] is the raw app CPU percentage from [parse].
  /// Returns null if sysfs data hasn't been successfully parsed yet.
  double? computeNormalizedCpu(double cpuAppPct) {
    if (_cachedTotalMaxCycles == null ||
        _cachedTotalMaxCycles == 0 ||
        _cachedTotalAvailCycles == null) {
      return null;
    }
    final normFactor = _cachedTotalAvailCycles! / _cachedTotalMaxCycles!;
    return cpuAppPct * normFactor;
  }

  /// Extract utime + stime ticks from /proc/pid/stat.
  ///
  /// Format: `pid (comm) state ppid ... utime stime ...`
  /// utime = field index 11 after state, stime = field index 12 after state.
  int? _extractPidTicks(String pidStat) {
    try {
      final closeParen = pidStat.indexOf(')');
      if (closeParen < 0) return null;

      final afterComm = pidStat.substring(closeParen + 1).trim();
      final fields = afterComm.split(RegExp(r'\s+'));
      if (fields.length < 13) return null;

      // fields[0] = state, fields[1]=ppid, ..., fields[11]=utime, fields[12]=stime
      final utime = int.tryParse(fields[11]);
      final stime = int.tryParse(fields[12]);
      if (utime == null || stime == null) return null;
      return utime + stime;
    } catch (_) {
      return null;
    }
  }

  /// Extract total_ticks and idle_ticks from /proc/stat first line.
  _SystemTicks? _extractSystemTicks(String procStat) {
    try {
      final firstLine = procStat.split('\n').first.trim();
      if (!firstLine.startsWith('cpu ')) return null;

      final fields = firstLine.split(RegExp(r'\s+'));
      // fields[0]="cpu", fields[1]=user, [2]=nice, [3]=system, [4]=idle,
      // [5]=iowait, [6]=irq, [7]=softirq, [8]=steal, ...
      if (fields.length < 8) return null;

      final user = int.tryParse(fields[1]);
      final nice = int.tryParse(fields[2]);
      final system = int.tryParse(fields[3]);
      final idle = int.tryParse(fields[4]);
      final iowait = int.tryParse(fields[5]);
      final irq = int.tryParse(fields[6]);
      final softirq = int.tryParse(fields[7]);

      if (user == null ||
          nice == null ||
          system == null ||
          idle == null ||
          iowait == null ||
          irq == null ||
          softirq == null) {
        return null;
      }

      final total = user + nice + system + idle + iowait + irq + softirq;
      final idleTotal = idle + iowait;

      return _SystemTicks(totalTicks: total, idleTicks: idleTotal);
    } catch (_) {
      return null;
    }
  }

  void _storeSnapshots(int? pidTicks, int? totalTicks, int? idleTicks) {
    _prevPidTicks = pidTicks;
    _prevTotalTicks = totalTicks;
    _prevIdleTicks = idleTicks;
  }
}

class _SystemTicks {
  final int totalTicks;
  final int idleTicks;
  const _SystemTicks({required this.totalTicks, required this.idleTicks});
}
