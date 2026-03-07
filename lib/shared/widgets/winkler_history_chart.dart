import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/utils/calibration_math.dart';

class WinklerHistoryChart extends StatelessWidget {
  final List<WinklerPoint> points;
  final bool expand;
  final void Function(int questionId)? onPointTap;
  final VoidCallback? onBackgroundTap;
  final double? visibleMinX;
  final double? visibleMaxX;

  const WinklerHistoryChart({
    super.key,
    required this.points,
    this.expand = false,
    this.onPointTap,
    this.onBackgroundTap,
    this.visibleMinX,
    this.visibleMaxX,
  });

  // --- log10 helpers ---

  static double _toLog(double v) => log(max(v, 1e-10)) / ln10;
  static double _fromLog(double logV) => pow(10, logV).toDouble();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final xMin = points.first.index.toDouble();
    final xMax = points.last.index.toDouble();
    final effectiveMinX = visibleMinX ?? xMin;
    final effectiveMaxX = visibleMaxX ?? xMax;

    // Transform scores to log10 space for plotting.
    final logValues = [for (final p in points) _toLog(p.score)];
    final logMin = logValues.reduce(min);
    final logMax = logValues.reduce(max);

    // Ensure at least one full decade of visible range.
    final yMinLog = min(logMin - 0.3, logMax - 1.0).floorToDouble();
    final yMaxLog = max(logMax + 0.3, logMin + 1.0).ceilToDouble();

    final logSpots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(points[i].index.toDouble(), logValues[i]),
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

    final hitColor = Colors.green.shade600;
    final missColor = cs.error;

    final chart = Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 4),
      child: LineChart(
        LineChartData(
          minX: effectiveMinX,
          maxX: effectiveMaxX,
          minY: yMinLog,
          maxY: yMaxLog,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1.0, // one grid line per decade
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
                interval: 1.0,
                getTitlesWidget: (v, _) {
                  // Only label at integer decade positions.
                  if ((v - v.roundToDouble()).abs() > 0.01) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _formatScore(_fromLog(v)),
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                },
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
          lineTouchData: LineTouchData(
            handleBuiltInTouches: false,
            touchCallback: (event, response) {
              if (event is! FlTapUpEvent) return;
              final spots = response?.lineBarSpots;
              if (spots != null && spots.isNotEmpty) {
                onPointTap?.call(points[spots.first.spotIndex].questionId);
              } else {
                onBackgroundTap?.call();
              }
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: logSpots,
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

  String _formatScore(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}k';
    if (v >= 100) return v.toStringAsFixed(0);
    if (v >= 10) return v.toStringAsFixed(0);
    if (v >= 1) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }
}
