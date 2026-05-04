// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// Session model — matches `sessions` table in Appendix C exactly.
/// All columns: id, device_id, platform, target_kind, app_package, app_name,
/// app_version, app_version_code, started_at, ended_at, duration_ms, title,
/// notes, tags, tags_kv_json, target_fps, production_mode, strict_mode,
/// injected, collection_id, project_id, user_id.
class Session {
  final String id; // UUID v4
  final String deviceId;
  final String platform; // 'android'|'ios'|'tvos'|'windows_pc'
  final String targetKind;
  final String appPackage;
  final String? appName;
  final String? appVersion;
  final int? appVersionCode;
  final int startedAt; // Unix ms
  final int? endedAt;
  final int? durationMs;
  final String? title;
  final String? notes;
  final String? tags; // JSON array
  final String? tagsKvJson; // JSON object
  final int targetFps;
  final int productionMode;
  final int strictMode;
  final int injected;
  final String? collectionId;
  final String? projectId;
  final String? userId;

  const Session({
    required this.id,
    required this.deviceId,
    required this.platform,
    this.targetKind = 'mobile',
    required this.appPackage,
    this.appName,
    this.appVersion,
    this.appVersionCode,
    required this.startedAt,
    this.endedAt,
    this.durationMs,
    this.title,
    this.notes,
    this.tags,
    this.tagsKvJson,
    this.targetFps = 60,
    this.productionMode = 0,
    this.strictMode = 0,
    this.injected = 0,
    this.collectionId,
    this.projectId,
    this.userId,
  });

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as String,
      deviceId: map['device_id'] as String,
      platform: map['platform'] as String,
      targetKind: (map['target_kind'] as String?) ?? 'mobile',
      appPackage: map['app_package'] as String,
      appName: map['app_name'] as String?,
      appVersion: map['app_version'] as String?,
      appVersionCode: map['app_version_code'] as int?,
      startedAt: map['started_at'] as int,
      endedAt: map['ended_at'] as int?,
      durationMs: map['duration_ms'] as int?,
      title: map['title'] as String?,
      notes: map['notes'] as String?,
      tags: map['tags'] as String?,
      tagsKvJson: map['tags_kv_json'] as String?,
      targetFps: (map['target_fps'] as int?) ?? 60,
      productionMode: (map['production_mode'] as int?) ?? 0,
      strictMode: (map['strict_mode'] as int?) ?? 0,
      injected: (map['injected'] as int?) ?? 0,
      collectionId: map['collection_id'] as String?,
      projectId: map['project_id'] as String?,
      userId: map['user_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'platform': platform,
      'target_kind': targetKind,
      'app_package': appPackage,
      'app_name': appName,
      'app_version': appVersion,
      'app_version_code': appVersionCode,
      'started_at': startedAt,
      'ended_at': endedAt,
      'duration_ms': durationMs,
      'title': title,
      'notes': notes,
      'tags': tags,
      'tags_kv_json': tagsKvJson,
      'target_fps': targetFps,
      'production_mode': productionMode,
      'strict_mode': strictMode,
      'injected': injected,
      'collection_id': collectionId,
      'project_id': projectId,
      'user_id': userId,
    };
  }
}
