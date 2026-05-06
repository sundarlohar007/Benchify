// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/models/metric_sample.dart';

/// Ring buffer size for PC metric charts (300 samples per §5.8).
const int kPcChartRingBufferSize = 300;

/// Base widget for PC real-time metric charts.
///
/// Provides a rolling ring buffer of MetricSample data and common chart
/// configuration (dark theme colors, jetBrainsMono labels).
abstract class PcRealTimeChart extends StatefulWidget {
  final Stream<MetricSample> samples;
  final double height;

  const PcRealTimeChart({
    super.key,
    required this.samples,
    this.height = 180,
  });
}

/// FPS line chart with jank overlay.
class PcFpsChart extends StatelessWidget {
  final List<MetricSample> samples;

  const PcFpsChart({super.key, required this.samples});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spots = <FlSpot>[];
    final jankSpots = <FlSpot>[];

    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      if (s.fps != null) {
        spots.add(FlSpot(i.toDouble(), s.fps!));
      }
      if (s.jankCount != null && s.jankCount! > 0) {
        jankSpots.add(FlSpot(i.toDouble(), s.jankCount!.toDouble()));
      }
    }

    if (spots.isEmpty) {
      return _emptyChart('FPS — No Data');
    }

    return _chartCard(
      title: 'FPS',
      subtitle: '${spots.isNotEmpty ? spots.last.y.toStringAsFixed(1) : '--'} fps',
      child: LineChart(
        LineChartData(
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colors.outline.withOpacity(0.3),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(color: colors.onSurface.withOpacity(0.5), fontSize: 10),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: colors.primary,
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: colors.primary.withOpacity(0.1),
              ),
            ),
            if (jankSpots.isNotEmpty)
              LineChartBarData(
                spots: jankSpots,
                isCurved: false,
                color: Colors.red.withOpacity(0.7),
                barWidth: 2,
                dotData: const FlDotData(
                  show: true,
                  dotColor: Colors.red,
                  dotSize: 4,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// CPU % line chart + per-core heatmap.
class PcCpuChart extends StatelessWidget {
  final List<MetricSample> samples;

  const PcCpuChart({super.key, required this.samples});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spots = <FlSpot>[];

    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      if (s.cpuAppPct != null) {
        spots.add(FlSpot(i.toDouble(), s.cpuAppPct!));
      }
    }

    if (spots.isEmpty) {
      return _emptyChart('CPU — No Data');
    }

    return _chartCard(
      title: 'CPU %',
      subtitle: '${spots.isNotEmpty ? spots.last.y.toStringAsFixed(1) : '--'}%',
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colors.outline.withOpacity(0.3),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}%',
                  style: TextStyle(color: colors.onSurface.withOpacity(0.5), fontSize: 10),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.cyanAccent,
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.cyanAccent.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Memory chart — stacked area: working set / private bytes / GPU VRAM.
class PcMemoryChart extends StatelessWidget {
  final List<MetricSample> samples;

  const PcMemoryChart({super.key, required this.samples});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final workingSetSpots = <FlSpot>[];
    final privateBytesSpots = <FlSpot>[];
    final gpuMemSpots = <FlSpot>[];

    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      if (s.memoryPssKb != null) {
        workingSetSpots.add(FlSpot(i.toDouble(), s.memoryPssKb!.toDouble() / 1024.0));
      }
      if (s.memoryNativeKb != null) {
        privateBytesSpots.add(FlSpot(i.toDouble(), s.memoryNativeKb!.toDouble() / 1024.0));
      }
      if (s.pcGpuDedicatedMemKb != null) {
        gpuMemSpots.add(FlSpot(i.toDouble(), s.pcGpuDedicatedMemKb!.toDouble() / 1024.0));
      }
    }

    if (workingSetSpots.isEmpty && gpuMemSpots.isEmpty) {
      return _emptyChart('Memory — No Data');
    }

    return _chartCard(
      title: 'Memory (MB)',
      subtitle: 'WS: ${_lastMb(workingSetSpots)} MB / GPU: ${_lastMb(gpuMemSpots)} MB',
      child: LineChart(
        LineChartData(
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colors.outline.withOpacity(0.3),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}',
                  style: TextStyle(color: colors.onSurface.withOpacity(0.5), fontSize: 10),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            if (workingSetSpots.isNotEmpty)
              LineChartBarData(
                spots: workingSetSpots,
                isCurved: true,
                color: Colors.orangeAccent,
                barWidth: 1.5,
                dotData: const FlDotData(show: false),
              ),
            if (privateBytesSpots.isNotEmpty)
              LineChartBarData(
                spots: privateBytesSpots,
                isCurved: true,
                color: Colors.yellowAccent.withOpacity(0.7),
                barWidth: 1,
                dotData: const FlDotData(show: false),
              ),
            if (gpuMemSpots.isNotEmpty)
              LineChartBarData(
                spots: gpuMemSpots,
                isCurved: true,
                color: Colors.purpleAccent,
                barWidth: 1.5,
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
    );
  }

  String _lastMb(List<FlSpot> spots) {
    if (spots.isEmpty) return '--';
    return spots.last.y.toStringAsFixed(0);
  }
}

/// GPU utilization line chart.
class PcGpuChart extends StatelessWidget {
  final List<MetricSample> samples;

  const PcGpuChart({super.key, required this.samples});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spots = <FlSpot>[];

    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      if (s.gpuPct != null) {
        spots.add(FlSpot(i.toDouble(), s.gpuPct!));
      }
    }

    if (spots.isEmpty) {
      return _emptyChart('GPU — No Data');
    }

    return _chartCard(
      title: 'GPU %',
      subtitle: '${spots.isNotEmpty ? spots.last.y.toStringAsFixed(1) : '--'}%',
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colors.outline.withOpacity(0.3),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}%',
                  style: TextStyle(color: colors.onSurface.withOpacity(0.5), fontSize: 10),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.purpleAccent,
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.purpleAccent.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Disk I/O bar chart (Read/Write).
class PcDiskIoChart extends StatelessWidget {
  final List<MetricSample> samples;

  const PcDiskIoChart({super.key, required this.samples});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (samples.isEmpty) return _emptyChart('Disk I/O — No Data');

    // Show last ~20 samples as bar chart groups
    final window = samples.length > 20 ? samples.sublist(samples.length - 20) : samples;
    final readBars = <BarChartGroupData>[];
    final writeBars = <BarChartGroupData>[];

    for (var i = 0; i < window.length; i++) {
      final s = window[i];
      readBars.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: s.diskReadKb ?? 0,
            color: Colors.greenAccent,
            width: 6,
          ),
        ],
      ));
      writeBars.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: s.diskWriteKb ?? 0,
            color: Colors.redAccent,
            width: 6,
          ),
        ],
      ));
    }

    return _chartCard(
      title: 'Disk I/O (KB/s)',
      subtitle: 'R: ${window.last.diskReadKb?.toStringAsFixed(0) ?? '--'} / W: ${window.last.diskWriteKb?.toStringAsFixed(0) ?? '--'}',
      child: BarChart(
        BarChartData(
          barGroups: readBars,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colors.outline.withOpacity(0.3),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(color: colors.onSurface.withOpacity(0.5), fontSize: 10),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

/// Network RX/TX line chart.
class PcNetworkChart extends StatelessWidget {
  final List<MetricSample> samples;

  const PcNetworkChart({super.key, required this.samples});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final rxSpots = <FlSpot>[];
    final txSpots = <FlSpot>[];

    for (var i = 0; i < samples.length; i++) {
      final s = samples[i];
      if (s.netRxBytes != null) {
        rxSpots.add(FlSpot(i.toDouble(), (s.netRxBytes! / 1024.0).toDouble()));
      }
      if (s.netTxBytes != null) {
        txSpots.add(FlSpot(i.toDouble(), (s.netTxBytes! / 1024.0).toDouble()));
      }
    }

    if (rxSpots.isEmpty && txSpots.isEmpty) {
      return _emptyChart('Network — No Data');
    }

    return _chartCard(
      title: 'Network (KB/s)',
      subtitle: 'RX: ${_lastKb(rxSpots)} / TX: ${_lastKb(txSpots)}',
      child: LineChart(
        LineChartData(
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: colors.outline.withOpacity(0.3),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(color: colors.onSurface.withOpacity(0.5), fontSize: 10),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            if (rxSpots.isNotEmpty)
              LineChartBarData(
                spots: rxSpots,
                isCurved: true,
                color: Colors.greenAccent,
                barWidth: 1.5,
                dotData: const FlDotData(show: false),
              ),
            if (txSpots.isNotEmpty)
              LineChartBarData(
                spots: txSpots,
                isCurved: true,
                color: Colors.amberAccent,
                barWidth: 1.5,
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
    );
  }

  String _lastKb(List<FlSpot> spots) {
    if (spots.isEmpty) return '--';
    return spots.last.y.toStringAsFixed(1);
  }
}

// ---------------------------------------------------------------------------
// Shared chart helpers
// ---------------------------------------------------------------------------

/// Empty chart placeholder widget.
Widget _emptyChart(String message) {
  return Card(
    child: SizedBox(
      height: 180,
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ),
    ),
  );
}

/// Wrapper card for a chart with title and subtitle.
Widget _chartCard({
  required String title,
  required String subtitle,
  required Widget child,
}) {
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(height: 160, child: child),
        ],
      ),
    ),
  );
}
