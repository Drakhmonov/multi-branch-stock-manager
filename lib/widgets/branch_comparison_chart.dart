import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class BranchComparisonData {
  final String branchName;
  final double sold;
  final double wasted;

  const BranchComparisonData({
    required this.branchName,
    required this.sold,
    required this.wasted,
  });
}

/// Grouped bar chart comparing sold vs wasted value across branches, so an
/// outlier branch's waste is visible at a glance instead of read off a list
/// of £ figures. Sold/wasted are two independent magnitudes (not a status),
/// so they get the first two slots of a fixed, colorblind-validated
/// categorical order rather than a semantic red/green pairing.
class BranchComparisonChart extends StatelessWidget {
  static const soldColor = Color(0xFF2A78D6);
  static const wastedColor = Color(0xFFEB6834);

  final List<BranchComparisonData> data;

  const BranchComparisonChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final maxValue = data.fold<double>(
      0,
      (max, d) => [max, d.sold, d.wasted].reduce((a, b) => a > b ? a : b),
    );
    final maxY = _niceMaxY(maxValue);
    final interval = maxY / 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          children: [
            _LegendItem(color: soldColor, label: 'Sold'),
            _LegendItem(color: wastedColor, label: 'Wasted'),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              groupsSpace: 24,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: interval,
                    getTitlesWidget: (value, meta) => Text(
                      '£${value.toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= data.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          data[index].branchName,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final label = rodIndex == 0 ? 'Sold' : 'Wasted';
                    return BarTooltipItem(
                      '$label\n£${rod.toY.toStringAsFixed(2)}',
                      TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < data.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      BarChartRodData(
                        toY: data[i].sold,
                        color: soldColor,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: data[i].wasted,
                        color: wastedColor,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Rounds up to a clean-looking axis max (1/2/5 x a power of ten) so ticks
/// land on round numbers instead of an arbitrary max like "£1,347".
double _niceMaxY(double maxValue) {
  if (maxValue <= 0) return 10;
  final magnitude = pow(10, (log(maxValue) / ln10).floor()).toDouble();
  final normalized = maxValue / magnitude;
  final niceNormalized = normalized <= 1
      ? 1
      : normalized <= 2
      ? 2
      : normalized <= 5
      ? 5
      : 10;
  return niceNormalized * magnitude;
}
