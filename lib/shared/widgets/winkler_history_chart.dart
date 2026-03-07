import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/utils/calibration_math.dart';

class WinklerHistoryChart extends StatelessWidget {
  final List<WinklerPoint> points;
  final bool expand;

  const WinklerHistoryChart({
    super.key,
    required this.points,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final xMin = points.first.index.toDouble();
    final xMax = points.last.index.toDouble();
    final values = points.map((p) => p.score).toList();
    final maxVal = values.reduce(max);
    final yMax = maxVal * 1.2;

    final spots = [
      for (final p in points) FlSpot(p.index.toDouble(), p.score),
    ];

    final xRange = max(xMax - xMin, 1.0);
    final xInterval = xRange <= 10
        ? 2.0
        : xRange <= 25
            ? 5.0
            : xRange <= 50
                ? 10.0
                : xRange <= 100
                    ? 20.0
                    : 50.0;

    final yInterval = _yInterval(yMax);

    final hitColor = Colors.green.shade600;
    final missColor = cs.error;

    final chart = Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 4),
      child: LineChart(
        LineChartData(
          minX: xMin,
          maxX: xMax,
          minY: 0,
          maxY: yMax,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: cs.outline.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: cs.outline.withOpacity(0.4)),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                interval: yInterval,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    _formatScore(v),
                    style: const TextStyle(fontSize: 9),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 18,
                interval: xInterval,
                getTitlesWidget: (v, meta) {
                  if (v == meta.min || v == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    v.toInt().toString(),
                    style: const TextStyle(fontSize: 9),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: cs.outline.withOpacity(0.25),
              barWidth: 1,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isHit = points[index].isHit;
                  return FlDotCirclePainter(
                    radius: 4,
                    color: isHit ? hitColor : missColor,
                    strokeWidth: 0,
                    strokeColor: Colors.transparent,
                  );
                },
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );

    return expand ? chart : AspectRatio(aspectRatio: 2.5, child: chart);
  }

  double _yInterval(double yMax) {
    if (yMax <= 0) return 1;
    final magnitude =
        pow(10, (log(yMax) / ln10).floor()).toDouble();
    final normalized = yMax / magnitude;
    if (normalized <= 2) return magnitude * 0.5;
    if (normalized <= 5) return magnitude;
    return magnitude * 2;
  }

  String _formatScore(double v) {
    if (v == 0) return '0';
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}k';
    if (v >= 100) return v.toStringAsFixed(0);
    if (v >= 10) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }
}
