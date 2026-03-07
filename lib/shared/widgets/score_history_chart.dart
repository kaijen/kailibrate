import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/utils/calibration_math.dart';

class ScoreHistoryChart extends StatelessWidget {
  final List<ScorePoint> points;

  /// true = Brier Score, false = Log Loss
  final bool isBrier;
  final bool expand;
  final double? visibleMinX;
  final double? visibleMaxX;

  const ScoreHistoryChart({
    super.key,
    required this.points,
    required this.isBrier,
    this.expand = false,
    this.visibleMinX,
    this.visibleMaxX,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final xMin = points.first.index.toDouble();
    final xMax = points.last.index.toDouble();
    final effectiveMinX = visibleMinX ?? xMin;
    final effectiveMaxX = visibleMaxX ?? xMax;

    final values = isBrier
        ? points.map((p) => p.brierScore).toList()
        : points.map((p) => p.logLoss).toList();

    final maxVal = values.reduce(max);

    // Referenzlinie: Münzwurf (immer 50 % schätzen)
    final refLine = isBrier ? 0.25 : log(2); // 0.25 bzw. ~0.693

    final yMax = max(maxVal * 1.2, refLine * 1.15);

    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(points[i].index.toDouble(), values[i]),
    ];

    final xRange = max(effectiveMaxX - effectiveMinX, 1.0);
    final xInterval = xRange <= 10
        ? 2.0
        : xRange <= 25
            ? 5.0
            : xRange <= 50
                ? 10.0
                : xRange <= 100
                    ? 20.0
                    : 50.0;

    final yInterval = yMax <= 0.4
        ? 0.1
        : yMax <= 0.8
            ? 0.2
            : 0.5;

    final lineColor = isBrier ? cs.primary : cs.secondary;

    final chart = Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 4),
      child: LineChart(
          LineChartData(
            minX: effectiveMinX,
            maxX: effectiveMaxX,
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
                  reservedSize: 36,
                  interval: yInterval,
                  getTitlesWidget: (v, _) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      v.toStringAsFixed(2),
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
              // Referenzlinie: Münzwurf
              LineChartBarData(
                spots: [FlSpot(effectiveMinX, refLine), FlSpot(effectiveMaxX, refLine)],
                isCurved: false,
                color: cs.error.withOpacity(0.45),
                barWidth: 1,
                dashArray: [6, 4],
                dotData: const FlDotData(show: false),
              ),
              // Verlaufslinie
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.15,
                color: lineColor,
                barWidth: 2,
                dotData: FlDotData(
                  show: points.length <= 25,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 3,
                    color: lineColor,
                    strokeWidth: 0,
                    strokeColor: Colors.transparent,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: lineColor.withOpacity(0.08),
                ),
              ),
            ],
          ),
        ),
    );
    return expand ? chart : AspectRatio(aspectRatio: 2.5, child: chart);
  }
}
