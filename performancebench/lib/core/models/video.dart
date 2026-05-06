// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// Video model — matches `videos` table in Appendix C / §32.8 exactly.
/// Synced screen recording associated with a session.
class Video {
  final String sessionId; // PK, FK to sessions
  final String filepath;
  final String codec;
  final String container;
  final int widthPx;
  final int heightPx;
  final int? targetFps;
  final double? actualAvgFps;
  final int? bitrateKbps;
  final int durationMs;
  final int fileSizeBytes;
  final String? chunksJson;
  final String? gapsJson;
  final int hasAudio;
  final String targetKind; // 'android', 'ios', 'tvos', 'windows_pc', 'macos_pc', 'linux_pc'
  final double? recordingOverheadEstimatePct;
  final int startedAt;
  final int endedAt;
  final int createdAt;

  const Video({
    required this.sessionId,
    required this.filepath,
    this.codec = 'h264',
    this.container = 'mp4',
    required this.widthPx,
    required this.heightPx,
    this.targetFps,
    this.actualAvgFps,
    this.bitrateKbps,
    required this.durationMs,
    required this.fileSizeBytes,
    this.chunksJson,
    this.gapsJson,
    this.hasAudio = 0,
    this.targetKind = 'android',
    this.recordingOverheadEstimatePct,
    required this.startedAt,
    required this.endedAt,
    this.createdAt = 0,
  });

  factory Video.fromMap(Map<String, dynamic> map) {
    return Video(
      sessionId: map['session_id'] as String,
      filepath: map['filepath'] as String,
      codec: (map['codec'] as String?) ?? 'h264',
      container: (map['container'] as String?) ?? 'mp4',
      widthPx: map['width_px'] as int,
      heightPx: map['height_px'] as int,
      targetFps: map['target_fps'] as int?,
      actualAvgFps: (map['actual_avg_fps'] as num?)?.toDouble(),
      bitrateKbps: map['bitrate_kbps'] as int?,
      durationMs: map['duration_ms'] as int,
      fileSizeBytes: map['file_size_bytes'] as int,
      chunksJson: map['chunks_json'] as String?,
      gapsJson: map['gaps_json'] as String?,
      hasAudio: (map['has_audio'] as int?) ?? 0,
      targetKind: (map['target_kind'] as String?) ?? 'android',
      recordingOverheadEstimatePct:
          (map['recording_overhead_estimate_pct'] as num?)?.toDouble(),
      startedAt: map['started_at'] as int,
      endedAt: map['ended_at'] as int,
      createdAt: (map['created_at'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'filepath': filepath,
      'codec': codec,
      'container': container,
      'width_px': widthPx,
      'height_px': heightPx,
      'target_fps': targetFps,
      'actual_avg_fps': actualAvgFps,
      'bitrate_kbps': bitrateKbps,
      'duration_ms': durationMs,
      'file_size_bytes': fileSizeBytes,
      'chunks_json': chunksJson,
      'gaps_json': gapsJson,
      'has_audio': hasAudio,
      'target_kind': targetKind,
      'recording_overhead_estimate_pct': recordingOverheadEstimatePct,
      'started_at': startedAt,
      'ended_at': endedAt,
      'created_at': createdAt,
    };
  }
}
