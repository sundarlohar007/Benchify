// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/detected_issue.dart';

/// Data access object for the `detected_issues` table.
/// All queries are parameterized. Severity values are validated per T-02-05.
class DetectedIssueDao {
  final Database _db;

  DetectedIssueDao(this._db);

  static const _validSeverities = {'informational', 'medium', 'high', 'critical'};

  /// Insert a single detected_issue row. Severity is validated before insert.
  Future<int> insert(DetectedIssue issue) async {
    final sev = issue.severity.toLowerCase();
    if (!_validSeverities.contains(sev)) {
      throw ArgumentError('Invalid severity: "${issue.severity}". Must be one of: $_validSeverities');
    }
    final map = issue.toMap();
    map['severity'] = sev;
    return _db.insert('detected_issues', map);
  }

  /// Batch insert detected_issue rows in a transaction.
  Future<void> batchInsert(List<DetectedIssue> issues) async {
    if (issues.isEmpty) return;
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final issue in issues) {
        final sev = issue.severity.toLowerCase();
        if (!_validSeverities.contains(sev)) {
          throw ArgumentError('Invalid severity: "${issue.severity}". Must be one of: $_validSeverities');
        }
        final map = issue.toMap();
        map['severity'] = sev;
        batch.insert('detected_issues', map);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Query all detected issues for a session.
  Future<List<DetectedIssue>> getBySessionId(String sessionId) async {
    final rows = await _db.query(
      'detected_issues',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return rows.map(DetectedIssue.fromMap).toList();
  }

  /// Query detected issues for a session by rule_id.
  Future<List<DetectedIssue>> getByRuleId(String sessionId, String ruleId) async {
    final rows = await _db.query(
      'detected_issues',
      where: 'session_id = ? AND rule_id = ?',
      whereArgs: [sessionId, ruleId],
      orderBy: 'created_at ASC',
    );
    return rows.map(DetectedIssue.fromMap).toList();
  }

  /// Delete all detected issues for a session.
  Future<int> deleteBySessionId(String sessionId) async {
    return _db.delete(
      'detected_issues',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }
}
