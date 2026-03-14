import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:forcegauge/models/tabata/report.dart';
import 'package:forcegauge/bloc/cubit/settings_cubit.dart';

/// Multi-series line chart for multiple [ReportValues] (e.g. sets/reps in a workout).
class ReportGraph2 extends StatelessWidget {
  final List<ReportValues> reports;

  const ReportGraph2(this.reports, {super.key});

  static const List<Color> _seriesColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chartBg = isDark ? const Color(0xFF121212) : Colors.white;
    final axisColor = isDark ? Colors.grey[400]! : const Color(0xFF424242);
    if (reports.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          'No data',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    final primaryColor = context.read<SettingsCubit>().settings.primarySwatch;
    double globalMinY = double.infinity;
    double globalMaxY = double.negativeInfinity;
    double globalMaxX = 0;

    final lineBars = <LineChartBarData>[];
    for (var i = 0; i < reports.length; i++) {
      final values = reports[i].getValues();
      if (values.isEmpty) continue;

      final spots = <FlSpot>[];
      for (var j = 0; j < values.length; j++) {
        final y = values[j] is double ? values[j] as double : (values[j] as num).toDouble();
        if (y.isFinite) {
          spots.add(FlSpot(j.toDouble(), y));
          if (y < globalMinY) globalMinY = y;
          if (y > globalMaxY) globalMaxY = y;
        }
      }
      if (spots.length < 2) continue;
      if (spots.length > globalMaxX) globalMaxX = spots.length.toDouble();

      final color = i < _seriesColors.length ? _seriesColors[i] : primaryColor;
      lineBars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    if (globalMinY == double.infinity) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text('No data', style: Theme.of(context).textTheme.bodyLarge),
      );
    }

    if (globalMaxY <= globalMinY) globalMaxY = globalMinY + 1.0;
    final padding = (globalMaxY - globalMinY) * 0.1;
    final chartMinY = globalMinY - padding;
    final chartMaxY = globalMaxY + padding;

    final lineData = LineChartData(
      minX: 0,
      maxX: (globalMaxX > 0 ? globalMaxX - 1 : 1).toDouble().clamp(1.0, double.infinity),
      minY: chartMinY,
      maxY: chartMaxY,
      backgroundColor: chartBg,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.withValues(alpha: 0.2),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (value, meta) => Text(
              value.toStringAsFixed(0),
              style: TextStyle(color: axisColor, fontSize: 10),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            getTitlesWidget: (value, meta) => Text(
              value.toStringAsFixed(0),
              style: TextStyle(color: axisColor, fontSize: 10),
            ),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: lineBars,
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) => touchedSpots
              .map((s) => LineTooltipItem(
                    s.y.toStringAsFixed(1),
                    TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ))
              .toList(),
        ),
      ),
    );

    return Container(
      height: 200,
      color: chartBg,
      padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
      child: LineChart(
        lineData,
        duration: const Duration(milliseconds: 250),
      ),
    );
  }
}
