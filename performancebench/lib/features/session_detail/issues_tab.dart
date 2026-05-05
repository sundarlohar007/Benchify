// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';
import '../../core/database/database.dart';
import '../../core/database/detected_issue_dao.dart';
import '../../core/models/detected_issue.dart';

/// IssuesTab — lists auto-detected issues for a session in a DataTable.
///
/// Columns: Rule ID | Severity (color-coded pill) | Metric | Observed |
/// Threshold | Message. Empty state: "No issues detected" with green checkmark.
class IssuesTab extends StatefulWidget {
  final String sessionId;

  const IssuesTab({super.key, required this.sessionId});

  @override
  State<IssuesTab> createState() => _IssuesTabState();
}

class _IssuesTabState extends State<IssuesTab> {
  List<DetectedIssue>? _issues;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    try {
      final db = await initDatabase();
      final dao = DetectedIssueDao(db);
      final issues = await dao.getBySessionId(widget.sessionId);
      if (mounted) {
        setState(() {
          _issues = issues;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: colors.accentBlue));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 32, color: colors.accentDanger),
            const SizedBox(height: 8),
            Text(
              'Failed to load issues: $_error',
              style: TextStyle(color: colors.accentDanger, fontSize: TextTokens.sm),
            ),
          ],
        ),
      );
    }

    final issues = _issues ?? [];

    // Empty state — no issues detected
    if (issues.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: colors.accentSuccess),
            const SizedBox(height: 12),
            Text(
              'No issues detected',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: TextTokens.base,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All performance metrics are within expected ranges',
              style: TextStyle(color: colors.textDisabled, fontSize: TextTokens.sm),
            ),
          ],
        ),
      );
    }

    // Issues table
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: DataTable(
          columnSpacing: 16,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 48,
          headingRowHeight: 28,
          headingTextStyle: TextStyle(
            color: colors.textSecondary,
            fontSize: TextTokens.xs,
            fontWeight: FontWeight.w600,
          ),
          dataTextStyle: TextStyle(
            color: colors.textPrimary,
            fontSize: TextTokens.sm,
            fontFamily: monoFontFamily(),
          ),
          columns: const [
            DataColumn(label: Text('Rule ID')),
            DataColumn(label: Text('Severity')),
            DataColumn(label: Text('Metric')),
            DataColumn(label: Text('Observed')),
            DataColumn(label: Text('Threshold')),
            DataColumn(label: Text('Message')),
          ],
          rows: issues.map((issue) {
            return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.hovered)) {
                  return colors.bgHover;
                }
                return null;
              }),
              cells: [
                DataCell(Text(issue.ruleId)),
                DataCell(_SeverityPill(severity: issue.severity, colors: colors)),
                DataCell(Text(issue.metric ?? '—',
                    style: TextStyle(color: colors.textSecondary))),
                DataCell(Text(_formatObserved(issue.observedValue, issue.metric))),
                DataCell(Text(_formatThreshold(issue.thresholdValue, issue.severity),
                    style: TextStyle(color: colors.textSecondary))),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      issue.message,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: TextStyle(fontSize: TextTokens.sm),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatObserved(double? value, String? metric) {
    if (value == null) return '—';
    if (metric == 'launch_complete_ms') return '${value.toInt()} ms';
    if (metric == 'mem_trend_slope_kb_per_min') return '${value.toStringAsFixed(0)} KB/min';
    if (metric == 'battery_drain_per_hour') return '${value.toStringAsFixed(1)} %/hr';
    if (metric == 'net_cellular_total') return '${(value / 1024).toStringAsFixed(1)} MB';
    if (metric == 'jank_big_total') return '${value.toStringAsFixed(1)} /min';
    return value.toStringAsFixed(1);
  }

  String _formatThreshold(double? value, String severity) {
    if (value == null) return '—';
    return value.toStringAsFixed(0);
  }
}

/// Color-coded severity pill per UNIFIED-SPEC §9.7:
/// informational = blue, medium = orange/yellow, high = red, critical = dark red
class _SeverityPill extends StatelessWidget {
  final String severity;
  final AppColors colors;

  const _SeverityPill({required this.severity, required this.colors});

  Color _pillColor() {
    switch (severity) {
      case 'informational':
        return colors.accentBlue;
      case 'medium':
        return colors.accentWarning;
      case 'high':
        return colors.accentDanger;
      case 'critical':
        return const Color(0xFF8B0000); // dark red
      default:
        return colors.textDisabled;
    }
  }

  Color _textColor() {
    switch (severity) {
      case 'medium':
        // warning/orange needs darker text for readability
        return const Color(0xFF1E1E1E);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _pillColor(),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        severity,
        style: TextStyle(
          color: _textColor(),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
