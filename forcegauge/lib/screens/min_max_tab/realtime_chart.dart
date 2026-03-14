import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:forcegauge/bloc/cubit/device_cubit.dart';
import 'package:forcegauge/bloc/cubit/settings_cubit.dart';
import 'package:forcegauge/models/devices/device_data.dart';

class EvenMoreRealtime extends StatelessWidget {
  final bool showOnlyAbsolute;
  final double targetForce;
  /// When non-null, chart shows this snapshot instead of live data (e.g. when paused).
  final List<DeviceData>? frozenData;

  const EvenMoreRealtime(this.showOnlyAbsolute, this.targetForce, {super.key, this.frozenData});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeviceCubit, DeviceState>(
      buildWhen: (prev, curr) => true,
      builder: (context, state) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final chartBg = isDark ? const Color(0xFF121212) : Colors.white;
        final axisColor = isDark ? Colors.grey[400]! : const Color(0xFF424242);
        final device = state.device;
        final historicalData = frozenData ?? device.getHistoricalData();
        final primaryColor = context.read<SettingsCubit>().settings.primarySwatch;

        if (historicalData.isEmpty) {
          return Container(
            height: 280,
            alignment: Alignment.center,
            child: Text(
              'No data yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          );
        }

        final spots = <FlSpot>[];
        for (final d in historicalData) {
          final x = d.time.toDouble();
          final y = showOnlyAbsolute ? d.value.abs() : d.value.toDouble();
          if (x.isFinite && y.isFinite) spots.add(FlSpot(x, y));
        }
        if (spots.isEmpty) {
          return Container(
            height: 280,
            alignment: Alignment.center,
            child: Text('No data yet', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
          );
        }
        if (spots.length < 2) {
          spots.add(FlSpot(spots.first.x + 0.1, spots.first.y));
        }

        double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
        double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
        if (maxY <= minY) maxY = minY + 1.0;
        if (showOnlyAbsolute && targetForce > 0) {
          minY = 0;
          final dataMax = maxY;
          final targetMax = targetForce * 1.2;
          maxY = dataMax > targetMax ? dataMax : targetMax;
          const double step = 10.0;
          maxY = (maxY / step).ceilToDouble() * step;
          if (maxY < 10) maxY = 10;
        } else {
          const double minRange = 20.0;
          const double step = 10.0;
          double range = maxY - minY;
          if (range < minRange) {
            final pad = (minRange - range) / 2;
            minY -= pad;
            maxY += pad;
            range = minRange;
          }
          minY = (minY / step).floorToDouble() * step;
          maxY = (maxY / step).ceilToDouble() * step;
          if (maxY <= minY) maxY = minY + step;
          if (maxY - minY < minRange) {
            minY = (minY / step).floorToDouble() * step;
            maxY = minY + minRange;
          }
        }

        final minX = spots.map((s) => s.x).reduce((a, b) => a < b ? a : b);
        final maxX = spots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
        final rangeX = maxX - minX;
        final paddedMinX = rangeX > 0 ? minX - rangeX * 0.02 : minX - 0.1;
        final paddedMaxX = rangeX > 0 ? maxX + rangeX * 0.02 : maxX + 0.1;
        if (paddedMaxX <= paddedMinX) return Container(height: 280, alignment: Alignment.center, child: Text('No data yet', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)));

        final lineData = LineChartData(
          minX: paddedMinX,
          maxX: paddedMaxX,
          minY: minY,
          maxY: maxY,
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
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(color: axisColor, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: primaryColor,
              barWidth: 2,
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
          color: chartBg,
          padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: LineChart(
            lineData,
            duration: Duration.zero,
          ),
        );
      },
    );
  }
}

