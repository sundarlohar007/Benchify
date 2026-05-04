/// Marker model — matches `markers` table in Appendix C exactly.
/// Columns: id, session_id, group_id, label, started_at, ended_at,
/// auto_screenshot, notes.
class Marker {
  final int? id; // autoincrement, null on insert
  final String sessionId;
  final int? groupId;
  final String label; // '__launch_complete__' for special
  final int startedAt;
  final int? endedAt; // null = point marker
  final int autoScreenshot;
  final String? notes;

  const Marker({
    this.id,
    required this.sessionId,
    this.groupId,
    required this.label,
    required this.startedAt,
    this.endedAt,
    this.autoScreenshot = 0,
    this.notes,
  });

  factory Marker.fromMap(Map<String, dynamic> map) {
    return Marker(
      id: map['id'] as int?,
      sessionId: map['session_id'] as String,
      groupId: map['group_id'] as int?,
      label: map['label'] as String,
      startedAt: map['started_at'] as int,
      endedAt: map['ended_at'] as int?,
      autoScreenshot: (map['auto_screenshot'] as int?) ?? 0,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'session_id': sessionId,
      'group_id': groupId,
      'label': label,
      'started_at': startedAt,
      'ended_at': endedAt,
      'auto_screenshot': autoScreenshot,
      'notes': notes,
    };
    if (id != null) map['id'] = id;
    return map;
  }
}
