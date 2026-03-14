import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:forcegauge/models/tabata/report.dart';
import 'package:forcegauge/bloc/cubit/settings_cubit.dart';

class ReportGraph extends StatelessWidget {
  final ReportValues report;

  const ReportGraph(this.report, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chartBg = isDark ? const Color(0xFF121212) : Colors.white;
    final axisColor = isDark ? Colors.grey[400]! : const Color(0xFF424242);
    final values = report.getValues();
    if (values.isEmpty) {
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

    final spots = <FlSpot>[];
    for (var i = 0; i < values.length; i++) {
      final y = (values[i] is double ? values[i] as double : (values[i] as num).toDouble());
      if (y.isFinite) spots.add(FlSpot(i.toDouble(), y));
    }
    if (spots.length < 2) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text('Not enough data to chart', style: Theme.of(context).textTheme.bodyLarge),
      );
    }

    double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxY <= minY) maxY = minY + 1.0;
    final padding = (maxY - minY) * 0.1;
    final chartMinY = minY - padding;
    final chartMaxY = maxY + padding;

    final minX = spots.map((s) => s.x).reduce((a, b) => a < b ? a : b);
    final maxX = spots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
    if (maxX <= minX) return Container(height: 200, alignment: Alignment.center, child: Text('Not enough data to chart', style: Theme.of(context).textTheme.bodyLarge));

    final lineData = LineChartData(
      minX: minX,
      maxX: maxX,
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
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: primaryColor,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ],
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
