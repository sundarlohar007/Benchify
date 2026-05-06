// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';

import '../../core/models/metric_sample.dart';
import '../../core/services/ios_service.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/metric_chart.dart';

/// 2-column auto-adaptive grid of real-time metric chart cards.
///
/// Renders MetricChart widgets for all metrics, conditionally hiding
/// battery/cellular charts when targetKind is tvos (per D-08).
///
/// Per 05-02-PLAN Task 2: tvOS hides battery and cellular charts
/// (mains-powered, WiFi-only). Shows "Power: Mains" label.
class ActiveSessionChartsTab extends StatelessWidget {
  final Stream<MetricSample> stream;
  final TargetKind? targetKind;

  const ActiveSessionChartsTab({
    super.key,
    required this.stream,
    this.targetKind,
  });

  /// Whether battery charts should be shown.
  bool get _showBattery =>
      targetKind == null ||
      IosService.shouldShowField('battery_pct', targetKind!);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1400
            ? 3
            : constraints.maxWidth >= 900
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.5,
          padding: const EdgeInsets.all(8),
          children: [
            MetricChart(
              label: 'FPS',
              lineColor: ChartColors.fps,
              stream: stream,
              extractValue: (s) => s.fps,
              valueFormatter: (v) => v?.toStringAsFixed(1) ?? '--',
              statCalculator: _fpsStats,
              targetLineY: 60,
              showJankRow: true,
              unit: 'fps',
            ),
            MetricChart(
              label: 'CPU (App)',
              lineColor: ChartColors.cpuApp,
              stream: stream,
              extractValue: (s) => s.cpuAppPct,
              valueFormatter: (v) =>
                  v != null ? '${v.toStringAsFixed(1)}%' : '--',
              statCalculator: _cpuStats,
              unit: '%',
            ),
            MetricChart(
              label: 'Memory',
              lineColor: ChartColors.memory,
              stream: stream,
              extractValue: (s) => s.memoryPssKb?.toDouble(),
              valueFormatter: (v) =>
                  v != null ? '${(v / 1024).toStringAsFixed(0)} MB' : '--',
              statCalculator: _memoryStats,
              unit: 'MB',
            ),
            // Battery charts — hidden for tvOS (mains-powered, D-08)
            if (_showBattery) ...[
              MetricChart(
                label: 'Battery %',
                lineColor: ChartColors.batteryPct,
                stream: stream,
                extractValue: (s) => s.batteryPct?.toDouble(),
                valueFormatter: (v) =>
                    v != null ? '${v.toInt()}%' : '--',
                statCalculator: _batteryPctStats,
                unit: '%',
              ),
              MetricChart(
                label: 'Battery mA',
                lineColor: ChartColors.batteryMa,
                stream: stream,
                extractValue: (s) => s.batteryMa,
                valueFormatter: (v) =>
                    v != null ? '${v.toStringAsFixed(0)} mA' : '--',
                statCalculator: _batteryMaStats,
                unit: 'mA',
              ),
              MetricChart(
                label: 'Battery mV',
                lineColor: ChartColors.batteryMv,
                stream: stream,
                extractValue: (s) => s.batteryMv,
                valueFormatter: (v) =>
                    v != null ? '${v.toStringAsFixed(0)} mV' : '--',
                statCalculator: _batteryMvStats,
                unit: 'mV',
              ),
              MetricChart(
                label: 'Battery Temp',
                lineColor: ChartColors.batteryTemp,
                stream: stream,
                extractValue: (s) => s.batteryTempC,
                valueFormatter: (v) =>
                    v != null ? '${v.toStringAsFixed(1)}°C' : '--',
                statCalculator: _batteryTempStats,
                unit: '°C',
              ),
            ] else ...[
              // tvOS: show Power: Mains label
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Card(
                  color: Colors.transparent,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.power, size: 24, color: ChartColors.batteryPct),
                        const SizedBox(height: 8),
                        Text(
                          'Power: Mains',
                          style: TextStyle(
                            color: ChartColors.batteryPct,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'tvOS — battery unavailable (mains-powered)',
                          style: TextStyle(
                            color: ChartColors.batteryPct.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            MetricChart(
              label: 'Network',
              lineColor: ChartColors.networkTx,
              stream: stream,
              extractValue: (s) {
                final txKb = (s.netTxBytes ?? 0) / 1024;
                return txKb;
              },
              valueFormatter: (v) =>
                  v != null ? '${v.toStringAsFixed(1)} KB' : '--',
              statCalculator: _networkStats,
              secondLineColor: ChartColors.networkRx,
              extractSecondValue: (s) {
                final rxKb = (s.netRxBytes ?? 0) / 1024;
                return rxKb;
              },
              secondValueFormatter: (v) =>
                  v != null ? '${v.toStringAsFixed(1)} KB' : '--',
              secondLineLabel: 'RX',
              unit: 'KB',
            ),
            MetricChart(
              label: 'GPU',
              lineColor: ChartColors.gpu,
              stream: stream,
              extractValue: (s) => s.gpuPct,
              valueFormatter: (v) =>
                  v != null ? '${v.toStringAsFixed(1)}%' : '--',
              statCalculator: _gpuStats,
              unit: '%',
            ),
          ],
        );
      },
    );
  }

  // ---- Stat calculators ----

  static List<StatPill> _fpsStats(List<MetricSample> samples) {
    final fpsVals =
        samples.map((s) => s.fps).where((v) => v != null).toList();
    if (fpsVals.isEmpty) return [];
    fpsVals.sort();
    return [
      StatPill(label: 'Med', value: fpsVals[fpsVals.length ~/ 2]!.toStringAsFixed(1)),
      StatPill(
          label: '1%Low',
          value: fpsVals[(fpsVals.length * 0.01).round().clamp(0, fpsVals.length - 1)]!
              .toStringAsFixed(1)),
      StatPill(label: 'Min', value: fpsVals.first!.toStringAsFixed(0)),
      StatPill(label: 'Max', value: fpsVals.last!.toStringAsFixed(0)),
    ];
  }

  static List<StatPill> _cpuStats(List<MetricSample> samples) {
    final vals = samples.map((s) => s.cpuAppPct).where((v) => v != null).toList();
    if (vals.isEmpty) return [];
    final avg = vals.reduce((a, b) => a! + b!)! / vals.length;
    final peak = vals.reduce((a, b) => a! > b! ? a : b)!;
    return [
      StatPill(label: 'Avg', value: '${avg.toStringAsFixed(1)}%'),
      StatPill(label: 'Peak', value: '${peak.toStringAsFixed(1)}%'),
    ];
  }

  static List<StatPill> _memoryStats(List<MetricSample> samples) {
    final vals = samples
        .map((s) => s.memoryPssKb?.toDouble())
        .where((v) => v != null)
        .toList();
    if (vals.isEmpty) return [];
    final avgMb = vals.reduce((a, b) => a! + b!)! / vals.length / 1024;
    final peakMb = vals.reduce((a, b) => a! > b! ? a : b)! / 1024;
    return [
      StatPill(label: 'Avg', value: '${avgMb.toStringAsFixed(0)} MB'),
      StatPill(label: 'Peak', value: '${peakMb.toStringAsFixed(0)} MB'),
    ];
  }

  static List<StatPill> _batteryPctStats(List<MetricSample> samples) {
    final vals = samples
        .map((s) => s.batteryPct?.toDouble())
        .where((v) => v != null)
        .toList();
    if (vals.isEmpty) return [];
    final current = vals.last!;
    final drain = vals.first! - vals.last!;
    final seconds = samples.length.toDouble();
    final hourly = seconds > 0 ? drain / seconds * 3600 : 0;
    return [
      StatPill(label: 'Now', value: '${current.toInt()}%'),
      StatPill(label: 'Drain', value: '${drain.abs().toStringAsFixed(1)}%'),
      StatPill(label: 'Rate', value: '${hourly.toStringAsFixed(1)}%/h'),
    ];
  }

  static List<StatPill> _batteryMaStats(List<MetricSample> samples) {
    final vals = samples.map((s) => s.batteryMa).where((v) => v != null).toList();
    if (vals.isEmpty) return [];
    final avg = vals.reduce((a, b) => a! + b!)! / vals.length;
    return [
      StatPill(label: 'Avg', value: '${avg.toStringAsFixed(0)} mA'),
      StatPill(label: 'Peak', value: '${vals.reduce((a, b) => a! > b! ? a : b)!} mA'),
    ];
  }

  static List<StatPill> _batteryMvStats(List<MetricSample> samples) {
    final vals = samples.map((s) => s.batteryMv).where((v) => v != null).toList();
    if (vals.isEmpty) return [];
    final avg = vals.reduce((a, b) => a! + b!)! / vals.length;
    return [StatPill(label: 'Avg', value: '${avg.toStringAsFixed(0)} mV')];
  }

  static List<StatPill> _batteryTempStats(List<MetricSample> samples) {
    final vals = samples.map((s) => s.batteryTempC).where((v) => v != null).toList();
    if (vals.isEmpty) return [];
    final max = vals.reduce((a, b) => a! > b! ? a : b)!;
    return [
      StatPill(label: 'Now', value: '${vals.last!.toStringAsFixed(1)}°C'),
      StatPill(label: 'Max', value: '${max.toStringAsFixed(1)}°C'),
    ];
  }

  static List<StatPill> _networkStats(List<MetricSample> samples) {
    if (samples.length < 2) return [];
    final first = samples.first;
    final last = samples.last;
    final txDeltaKb =
        ((last.netTxBytes ?? 0) - (first.netTxBytes ?? 0)) / 1024;
    final rxDeltaKb =
        ((last.netRxBytes ?? 0) - (first.netRxBytes ?? 0)) / 1024;
    final seconds = (last.timestamp - first.timestamp) / 1000;
    final txRate = seconds > 0 ? txDeltaKb / seconds : 0;
    final rxRate = seconds > 0 ? rxDeltaKb / seconds : 0;
    return [
      StatPill(label: 'TX', value: '${txRate.toStringAsFixed(1)} KB/s'),
      StatPill(label: 'RX', value: '${rxRate.toStringAsFixed(1)} KB/s'),
    ];
  }

  static List<StatPill> _gpuStats(List<MetricSample> samples) {
    final vals = samples.map((s) => s.gpuPct).where((v) => v != null).toList();
    if (vals.isEmpty) return [];
    final avg = vals.reduce((a, b) => a! + b!)! / vals.length;
    return [StatPill(label: 'Avg', value: '${avg.toStringAsFixed(1)}%')];
  }
}
