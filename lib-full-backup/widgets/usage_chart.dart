import 'dart:math' show log, pow;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

/// Data point for usage chart
class UsageDataPoint {
  final DateTime timestamp;
  final double value;

  const UsageDataPoint({
    required this.timestamp,
    required this.value,
  });
}

/// Type of usage being tracked
enum UsageType {
  messages,
  tokens,
  cost,
  requests,
  memory,
  cpu,
}

/// A Material 3 chart widget for displaying usage metrics over time.
/// 
/// Uses fl_chart for beautiful, interactive line charts.
/// 
/// Usage:
/// ```dart
/// UsageChart(
///   title: 'Message Usage',
///   data: usageDataPoints,
///   type: UsageType.messages,
/// )
/// ```
class UsageChart extends StatelessWidget {
  /// Chart title
  final String title;
  
  /// Data points to display
  final List<UsageDataPoint> data;
  
  /// Type of usage being tracked
  final UsageType type;
  
  /// Whether to show grid
  final bool showGrid;
  
  /// Whether to enable touch interactions
  final bool enableTouch;
  
  /// Custom unit label
  final String? unitLabel;
  
  /// Chart height
  final double height;
  
  /// Whether to animate chart
  final bool animate;

  const UsageChart({
    super.key,
    required this.title,
    required this.data,
    required this.type,
    this.showGrid = true,
    this.enableTouch = true,
    this.unitLabel,
    this.height = 200,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildLegendChip(context, colorScheme),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: data.isEmpty
                  ? _buildEmptyState(context, colorScheme)
                  : _buildChart(context, colorScheme),
            ),
            if (data.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSummaryRow(context, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegendChip(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _getTypeLabel(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 48,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'No data available',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, ColorScheme colorScheme) {
    final spots = _getSpots();
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: showGrid,
          drawVerticalLine: false,
          horizontalInterval: _calculateInterval(maxY - minY),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: colorScheme.onSurfaceVariant.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _calculateTimeInterval(),
              getTitlesWidget: (value, meta) => _buildBottomTitle(value, meta, context),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: _calculateInterval(maxY - minY),
              getTitlesWidget: (value, meta) => _buildLeftTitle(value, meta, context),
            ),
          ),
        ),
        borderData: FlBorderData(
          show: false,
        ),
        minX: spots.first.x,
        maxX: spots.last.x,
        minY: minY < 0 ? 0 : minY,
        maxY: maxY * 1.1, // Add 10% padding
        lineTouchData: LineTouchData(
          enabled: enableTouch,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)} ${_getUnitLabel()}',
                  TextStyle(
                    color: colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: colorScheme.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: data.length <= 20,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: colorScheme.primary,
                  strokeWidth: 2,
                  strokeColor: colorScheme.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.primary.withOpacity(0.3),
                  colorScheme.primary.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: animate ? const Duration(milliseconds: 300) : Duration.zero,
    );
  }

  Widget _buildBottomTitle(double value, TitleMeta meta, BuildContext context) {
    final theme = Theme.of(context);
    
    // Find the closest data point for this value
    final index = value.toInt();
    if (index < 0 || index >= data.length) {
      return const SizedBox.shrink();
    }
    
    final point = data[index];
    final now = DateTime.now();
    final isToday = point.timestamp.day == now.day;
    
    String label;
    if (isToday) {
      label = '${point.timestamp.hour.toString().padLeft(2, '0')}:${point.timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      label = '${point.timestamp.month}/${point.timestamp.day}';
    }
    
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildLeftTitle(double value, TitleMeta meta, BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        _formatValue(value),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, ColorScheme colorScheme) {
    final total = data.fold<double>(0, (sum, point) => sum + point.value);
    final average = total / data.length;
    final max = data.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildSummaryItem(
          context,
          label: 'Total',
          value: _formatValueWithUnit(total),
        ),
        _buildSummaryItem(
          context,
          label: 'Average',
          value: _formatValueWithUnit(average),
        ),
        _buildSummaryItem(
          context,
          label: 'Peak',
          value: _formatValueWithUnit(max),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  List<FlSpot> _getSpots() {
    return data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();
  }

  double _calculateInterval(double range) {
    if (range <= 0) return 1;
    final magnitude = (range / 5).abs();
    // Calculate scale using log base 10
    final exponent = magnitude > 0 ? (log(magnitude) / log(10)).floor() : 0;
    final scale = pow(10, exponent).toDouble();
    return (magnitude / scale).ceilToDouble() * scale;
  }

  double _calculateTimeInterval() {
    if (data.isEmpty) return 1;
    // Show label every N points based on data size
    if (data.length <= 6) return 1;
    if (data.length <= 12) return 2;
    if (data.length <= 24) return 4;
    return (data.length / 6).ceilToDouble();
  }

  String _getTypeLabel() {
    switch (type) {
      case UsageType.messages:
        return 'Messages';
      case UsageType.tokens:
        return 'Tokens';
      case UsageType.cost:
        return 'Cost';
      case UsageType.requests:
        return 'Requests';
      case UsageType.memory:
        return 'Memory';
      case UsageType.cpu:
        return 'CPU';
    }
  }

  String _getUnitLabel() {
    if (unitLabel != null) return unitLabel!;
    
    switch (type) {
      case UsageType.messages:
        return 'msg';
      case UsageType.tokens:
        return 'k';
      case UsageType.cost:
        return '\$';
      case UsageType.requests:
        return 'req';
      case UsageType.memory:
        return '%';
      case UsageType.cpu:
        return '%';
    }
  }

  String _formatValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }

  String _formatValueWithUnit(double value) {
    return '${_formatValue(value)} ${_getUnitLabel()}';
  }
}

/// A bar chart variant for usage comparison
class UsageBarChart extends StatelessWidget {
  final String title;
  final Map<String, double> data;
  final UsageType type;
  final double height;

  const UsageBarChart({
    super.key,
    required this.title,
    required this.data,
    required this.type,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(
                height: height,
                child: Center(
                  child: Text(
                    'No data available',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    final entries = data.entries.toList();
    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toStringAsFixed(1)}',
                          TextStyle(
                            color: colorScheme.onInverseSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              entries[index].key,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: entries.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value,
                          color: colorScheme.primary,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}