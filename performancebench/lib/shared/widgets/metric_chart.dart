// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/models/metric_sample.dart';
import '../theme.dart';

/// A stat pill shown below the chart (e.g., "Med 58.3").
class StatPill {
  final String label;
  final String value;

  const StatPill({required this.label, required this.value});
}

/// Reusable real-time metric chart card with fl_chart LineChart.
///
/// Listens to a [stream] of [MetricSample] values, maintains up to 300 data
/// points, and renders a VS Code Dark+ styled chart with label, current value,
/// stat pills, and optional second line (for Network dual-line mode).
///
/// Per UNIFIED-SPEC section 9.4.
class MetricChart extends StatefulWidget {
  /// Chart label displayed in the card header (e.g., "FPS", "CPU (App)").
  final String label;

  /// Primary line color.
  final Color lineColor;

  /// Stream of MetricSample values from [MetricCollector].
  final Stream<MetricSample> stream;

  /// Extracts the Y-axis value from a [MetricSample].
  /// Returns null if no data for this metric.
  final double? Function(MetricSample) extractValue;

  /// Formats the current value for display (e.g., "58.3", "512 MB").
  final String Function(double? value) valueFormatter;

  /// Computes stat pills from the full list of ring-buffer samples.
  final List<StatPill> Function(List<MetricSample> samples) statCalculator;

  /// Optional target line on the Y-axis (used for FPS 60fps guideline).
  final double? targetLineY;

  /// Whether to show the jank indicator row (FPS only).
  final bool showJankRow;

  /// Y-axis unit string for tooltips.
  final String unit;

  // ---- Second line support (Network dual-line) ----

  /// Secondary line color. If non-null, a second line is drawn.
  final Color? secondLineColor;

  /// Extracts the Y-axis value for the second line from a [MetricSample].
  final double? Function(MetricSample)? extractSecondValue;

  /// Formats the second value for display.
  final String Function(double? value)? secondValueFormatter;

  /// Label for the second line in tooltips.
  final String? secondLineLabel;

  const MetricChart({
    super.key,
    required this.label,
    required this.lineColor,
    required this.stream,
    required this.extractValue,
    required this.valueFormatter,
    required this.statCalculator,
    this.targetLineY,
    this.showJankRow = false,
    this.unit = '',
    this.secondLineColor,
    this.extractSecondValue,
    this.secondValueFormatter,
    this.secondLineLabel,
  });

  @override
  State<MetricChart> createState() => _MetricChartState();
}

class _MetricChartState extends State<MetricChart> {
  /// Primary line data points (max 300 — 60s at 1Hz + buffer).
  final List<FlSpot> _spots = [];

  /// Secondary line data points (Network only — also max 300).
  final List<FlSpot> _secondSpots = [];

  /// Full sample history for stat calculation (last 300).
  final List<MetricSample> _samples = [];

  /// Current value for display.
  double? _currentValue;

  /// Cached stat pills (recomputed on each sample).
  List<StatPill> _statPills = [];

  /// Pending setState flag (batched via post-frame callback).
  bool _pendingUpdate = false;

  StreamSubscription<MetricSample>? _subscription;

  static const int _maxPoints = 300;

  @override
  void initState() {
    super.initState();
    _subscription = widget.stream.listen(_onSample);
  }

  @override
  void didUpdateWidget(covariant MetricChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stream != widget.stream) {
      _subscription?.cancel();
      _spots.clear();
      _secondSpots.clear();
      _samples.clear();
      _subscription = widget.stream.listen(_onSample);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// Handle a new sample from the stream.
  ///
  /// Per T-01-12: batched setState via addPostFrameCallback to avoid
  /// unnecessary rebuilds and stay within 33ms frame budget.
  void _onSample(MetricSample sample) {
    _samples.add(sample);
    while (_samples.length > _maxPoints) {
      _samples.removeAt(0);
    }

    final value = widget.extractValue(sample);
    _currentValue = value;

    final secondValue = widget.extractSecondValue?.call(sample);

    // Index for X-axis (keeps growing, chart auto-scrolls last 60s window)
    final x = _spots.length.toDouble();

    if (value != null) {
      _spots.add(FlSpot(x, value));
    } else {
      _spots.add(FlSpot(x, double.nan));
    }
    while (_spots.length > _maxPoints) {
      _spots.removeAt(0);
    }

    if (widget.extractSecondValue != null) {
      if (secondValue != null) {
        _secondSpots.add(FlSpot(x, secondValue));
      } else {
        _secondSpots.add(FlSpot(x, double.nan));
      }
      while (_secondSpots.length > _maxPoints) {
        _secondSpots.removeAt(0);
      }
    }

    _statPills = widget.statCalculator(_samples);

    if (!_pendingUpdate) {
      _pendingUpdate = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _pendingUpdate = false;
        if (mounted) setState(() {});
      });
    }
  }

  /// Count jank from accumulated samples in current window.
  int _countSmallJank(List<MetricSample> samples) {
    return samples.fold(0, (sum, s) => sum + (s.jankSmallCount ?? 0));
  }

  int _countMediumJank(List<MetricSample> samples) {
    return samples.fold(0, (sum, s) => sum + (s.jankCount ?? 0));
  }

  int _countBigJank(List<MetricSample> samples) {
    return samples.fold(0, (sum, s) => sum + (s.jankBigCount ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onDoubleTap: () => _showFullScreen(context, colors),
      child: Container(
        decoration: BoxDecoration(
          color: colors.bgSidebar,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.borderSubtle, width: 0.5),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: label + current value
            _buildHeader(colors),
            const SizedBox(height: 4),
            // Chart area
            Expanded(child: _buildChart(colors)),
            const SizedBox(height: 4),
            // Stat pills row
            _buildStatPills(colors),
            // Jank indicator row (FPS only)
            if (widget.showJankRow) _buildJankRow(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors colors) {
    return Row(
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: TextTokens.xs,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const Spacer(),
        Text(
          widget.valueFormatter(_currentValue),
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: TextTokens.monoValue,
            fontFamily: monoFontFamily(),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildChart(AppColors colors) {
    if (_spots.isEmpty) {
      return Center(
        child: Text(
          'Waiting for data...',
          style: TextStyle(
            color: colors.textDisabled,
            fontSize: TextTokens.xs,
          ),
        ),
      );
    }

    // Computed Y-axis range with 10% padding on top, clamped at 0.
    final allValues = <double>[];
    for (final spot in _spots) {
      if (!spot.y.isNaN && !spot.y.isInfinite) {
        allValues.add(spot.y);
      }
    }
    for (final spot in _secondSpots) {
      if (!spot.y.isNaN && !spot.y.isInfinite) {
        allValues.add(spot.y);
      }
    }
    if (allValues.isEmpty) allValues.add(0);

    double minY = allValues.reduce(math.min);
    double maxY = allValues.reduce(math.max);
    if (minY > 0) minY = 0; // Clamp bottom at 0
    double range = maxY - minY;
    if (range == 0) range = 1; // Avoid zero range
    maxY = maxY + range * 0.1; // 10% top padding
    minY = math.max(0, minY - range * 0.02); // Small bottom padding

    final hasTargetLine = widget.targetLineY != null;
    if (hasTargetLine && maxY < widget.targetLineY!) {
      maxY = widget.targetLineY! + range * 0.1;
    }

    final lineBars = <LineChartBarData>[];

    // Primary line
    lineBars.add(
      LineChartBarData(
        spots: _spots,
        isCurved: true,
        curveSmoothness: 0.3,
        color: widget.lineColor,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.lineColor.withOpacity(0.20),
              widget.lineColor.withOpacity(0.0),
            ],
          ),
        ),
        // Split line on null gaps (NaN values) — separate segments
        preventCurveOverShooting: true,
      ),
    );

    // Second line (Network TX/RX)
    if (widget.secondLineColor != null && _secondSpots.isNotEmpty) {
      lineBars.add(
        LineChartBarData(
          spots: _secondSpots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: widget.secondLineColor!,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                widget.secondLineColor!.withOpacity(0.15),
                widget.secondLineColor!.withOpacity(0.0),
              ],
            ),
          ),
          preventCurveOverShooting: true,
        ),
      );
    }

    // Target line (FPS 60fps guideline) as extra dashed horizontal line
    if (hasTargetLine) {
      // We render target line as a separate LineChartBarData with two points
      final minX = _spots.isNotEmpty ? _spots.first.x : 0.0;
      final maxX = _spots.isNotEmpty ? _spots.last.x : 1.0;
      lineBars.add(
        LineChartBarData(
          spots: [
            FlSpot(minX, widget.targetLineY!),
            FlSpot(maxX, widget.targetLineY!),
          ],
          isCurved: false,
          color: colors.borderSubtle.withOpacity(0.6),
          barWidth: 1,
          dashArray: [6, 4],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    return ClipRect(
      child: LineChart(
        LineChartData(
          lineBarsData: lineBars,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            drawHorizontalLine: true,
            horizontalInterval: _calcInterval(range),
            getDrawingHorizontalLine: (value) => FlLine(
              color: colors.borderSubtle.withOpacity(0.3),
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 15,
                getTitlesWidget: (value, meta) {
                  final x = value.toInt();
                  final maxIdx = _spots.length - 1;
                  if (maxIdx <= 0) return const SizedBox.shrink();

                  // Show labels at relative positions: "now", "-15s", "-30s", "-45s", "-60s"
                  final posFromEnd = maxIdx - x;
                  if (posFromEnd == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'now',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 9,
                          fontFamily: monoFontFamily(),
                        ),
                      ),
                    );
                  } else if (posFromEnd > 0 && posFromEnd % 15 == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '-${posFromEnd}s',
                        style: TextStyle(
                          color: colors.textDisabled,
                          fontSize: 9,
                          fontFamily: monoFontFamily(),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _formatYLabel(value),
                      style: TextStyle(
                        color: colors.textDisabled,
                        fontSize: 9,
                        fontFamily: monoFontFamily(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => colors.bgElevated,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  String label = widget.label;
                  if (widget.secondLineColor != null &&
                      spot.barIndex == 1) {
                    label = widget.secondLineLabel ?? 'RX';
                  }
                  final valueStr = spot.y.isNaN
                      ? 'N/A'
                      : spot.y.toStringAsFixed(1);
                  return LineTooltipItem(
                    '$label: $valueStr ${widget.unit}',
                    TextStyle(
                      color: colors.textPrimary,
                      fontSize: 11,
                      fontFamily: monoFontFamily(),
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Calculate a sensible grid interval from the data range.
  double _calcInterval(double range) {
    if (range <= 0) return 10;
    // Aim for 4-6 horizontal grid lines
    final raw = range / 5;
    final magnitude = math.pow(10, (raw.log10()).floor()).toDouble();
    final normalized = raw / magnitude;
    if (normalized <= 1.5) return magnitude;
    if (normalized <= 3.5) return 2 * magnitude;
    if (normalized <= 7.5) return 5 * magnitude;
    return 10 * magnitude;
  }

  String _formatYLabel(double value) {
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(0);
  }

  Widget _buildStatPills(AppColors colors) {
    if (_statPills.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];
    for (var i = 0; i < _statPills.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '·', // middle dot
              style: TextStyle(
                color: colors.textDisabled,
                fontSize: TextTokens.monoSm,
                fontFamily: monoFontFamily(),
              ),
            ),
          ),
        );
      }
      children.add(
        Text(
          '${_statPills[i].label} ${_statPills[i].value}',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: TextTokens.monoSm,
            fontFamily: monoFontFamily(),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Wrap(children: children),
    );
  }

  Widget _buildJankRow(AppColors colors) {
    final smallCount = _countSmallJank(_samples);
    final medCount = _countMediumJank(_samples);
    final bigCount = _countBigJank(_samples);

    // Rate per minute (samples are 1Hz, so samples.length seconds)
    final seconds = _samples.length.toDouble();
    final rate = seconds > 0 ? 60.0 / seconds : 1.0;
    final smallPerMin = (smallCount * rate).round();
    final medPerMin = (medCount * rate).round();
    final bigPerMin = (bigCount * rate).round();

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Text(
            '◎ Small $smallPerMin/min',
            style: TextStyle(
              color: colors.textDisabled,
              fontSize: TextTokens.monoSm,
              fontFamily: monoFontFamily(),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '◉ Jank $medPerMin/min',
            style: TextStyle(
              color: colors.accentWarning,
              fontSize: TextTokens.monoSm,
              fontFamily: monoFontFamily(),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '⬤ Big $bigPerMin/min',
            style: TextStyle(
              color: colors.accentDanger,
              fontSize: TextTokens.monoSm,
              fontFamily: monoFontFamily(),
            ),
          ),
        ],
      ),
    );
  }

  /// Double-click: expand to full-screen overlay.
  void _showFullScreen(BuildContext context, AppColors colors) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: colors.bgBase,
          appBar: AppBar(
            backgroundColor: colors.bgSidebar,
            title: Text(
              widget.label,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: TextTokens.md,
                fontFamily: monoFontFamily(),
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: MetricChart(
              key: ValueKey('fullscreen-${widget.label}'),
              label: widget.label,
              lineColor: widget.lineColor,
              stream: widget.stream,
              extractValue: widget.extractValue,
              valueFormatter: widget.valueFormatter,
              statCalculator: widget.statCalculator,
              targetLineY: widget.targetLineY,
              showJankRow: widget.showJankRow,
              unit: widget.unit,
              secondLineColor: widget.secondLineColor,
              extractSecondValue: widget.extractSecondValue,
              secondValueFormatter: widget.secondValueFormatter,
              secondLineLabel: widget.secondLineLabel,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Extension for log10 on double
// ---------------------------------------------------------------------------
extension _Log10 on double {
  double log10() => _log10(this);
}

double _log10(double x) {
  if (x <= 0) return 0;
  return math.log(x) / math.ln10;
}
