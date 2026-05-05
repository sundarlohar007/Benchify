// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// DetectedIssue model — matches `detected_issues` table in Appendix C exactly.
/// Auto-detected performance issues during a session (e.g., low FPS, memory pressure).
class DetectedIssue {
  final int? id; // autoincrement, null on insert
  final String sessionId;
  final String ruleId; // e.g., 'LOW_FPS', 'MEMORY_TRENDING_UP'
  final String severity; // 'informational' | 'medium' | 'high' | 'critical'
  final String? metric; // e.g., 'fps_median', 'memory_pss_kb'
  final double? observedValue;
  final double? thresholdValue;
  final String message;
  final int createdAt;

  const DetectedIssue({
    this.id,
    required this.sessionId,
    required this.ruleId,
    required this.severity,
    this.metric,
    this.observedValue,
    this.thresholdValue,
    required this.message,
    this.createdAt = 0,
  });

  factory DetectedIssue.fromMap(Map<String, dynamic> map) {
    return DetectedIssue(
      id: map['id'] as int?,
      sessionId: map['session_id'] as String,
      ruleId: map['rule_id'] as String,
      severity: map['severity'] as String,
      metric: map['metric'] as String?,
      observedValue: (map['observed_value'] as num?)?.toDouble(),
      thresholdValue: (map['threshold_value'] as num?)?.toDouble(),
      message: map['message'] as String,
      createdAt: (map['created_at'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'session_id': sessionId,
      'rule_id': ruleId,
      'severity': severity,
      'message': message,
      'created_at': createdAt,
    };
    if (id != null) map['id'] = id;
    if (metric != null) map['metric'] = metric;
    if (observedValue != null) map['observed_value'] = observedValue;
    if (thresholdValue != null) map['threshold_value'] = thresholdValue;
    return map;
  }
}
