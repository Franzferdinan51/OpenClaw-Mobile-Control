/// Inline Chart Widget
/// 
/// ChatGPT-style inline charts that appear within chat messages.
/// Supports bar, line, pie, and gauge charts with animations and tooltips.
///
/// Usage:
/// ```dart
/// InlineChartWidget(
///   chartData: InlineChartData(
///     title: 'Token Usage',
///     type: InlineChartType.bar,
///     data: {'Mon': 1000, 'Tue': 1500},
///   ),
/// )
/// ```

import 'dart:math' show pi, max, min;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/agent_chart_tool.dart';

/// Inline chart widget for chat messages
class InlineChartWidget extends StatefulWidget {
  final InlineChartData chartData;
  final double maxWidth;
  final double height;
  final bool compact;
  final VoidCallback? onTap;

  const InlineChartWidget({
    super.key,
    required this.chartData,
    this.maxWidth = 400,
    this.height = 200,
    this.compact = false,
    this.onTap,
  });

  @override
  State<InlineChartWidget> createState() => _InlineChartWidgetState();
}

class _InlineChartWidgetState extends State<InlineChartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    
    if (widget.chartData.animate) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = widget.chartData.accentColor ?? const Color(0xFF00D4AA);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Icon(
                    _getChartIcon(),
                    size: 18,
                    color: accentColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.chartData.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (widget.chartData.subtitle != null)
                    Text(
                      widget.chartData.subtitle!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            
            // Chart
            Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return SizedBox(
                    height: widget.compact ? 120 : widget.height,
                    child: _buildChart(context, accentColor),
                  );
                },
              ),
            ),
            
            // Footer with summary
            if (!widget.compact) _buildSummaryFooter(theme, colorScheme, accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, Color accentColor) {
    switch (widget.chartData.type) {
      case InlineChartType.bar:
        return _buildBarChart(context, accentColor);
      case InlineChartType.line:
        return _buildLineChart(context, accentColor);
      case InlineChartType.pie:
        return _buildPieChart(context, accentColor);
      case InlineChartType.gauge:
        return _buildGaugeChart(context, accentColor);
    }
  }

  Widget _buildBarChart(BuildContext context, Color accentColor) {
    final data = widget.chartData.data.entries.toList();
    if (data.isEmpty) return _buildEmptyState();

    final maxY = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY * 1.2,
            barTouchData: BarTouchData(
              touchCallback: (event, response) {
                setState(() {
                  if (response != null && response.spot != null) {
                    _touchedIndex = response.spot!.touchedBarGroupIndex;
                  } else {
                    _touchedIndex = null;
                  }
                });
              },
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${data[groupIndex].key}: ${_formatValue(rod.toY)}${widget.chartData.unit ?? ''}',
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
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= data.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        data[index].key,
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      _formatValue(value),
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.withOpacity(0.1),
                  strokeWidth: 1,
                );
              },
            ),
            barGroups: data.asMap().entries.map((entry) {
              final isTouched = entry.key == _touchedIndex;
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: entry.value.value * _animation.value,
                    color: isTouched ? accentColor.withOpacity(0.8) : accentColor,
                    width: widget.compact ? 12 : 18,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY * 1.2,
                      color: Colors.grey.withOpacity(0.1),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildLineChart(BuildContext context, Color accentColor) {
    final data = widget.chartData.data.entries.toList();
    if (data.isEmpty) return _buildEmptyState();

    final colorScheme = Theme.of(context).colorScheme;
    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    final maxY = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final minY = data.map((e) => e.value).reduce((a, b) => a < b ? a : b);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return LineChart(
          LineChartData(
            minX: 0,
            maxX: (data.length - 1).toDouble(),
            minY: minY < 0 ? 0 : minY * 0.9,
            maxY: maxY * 1.1,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.withOpacity(0.1),
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
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= data.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        data[index].key,
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      _formatValue(value),
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();
                    return LineTooltipItem(
                      '${data[index].key}: ${_formatValue(spot.y)}${widget.chartData.unit ?? ''}',
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
                spots: spots.map((s) => FlSpot(s.x, s.y * _animation.value)).toList(),
                isCurved: true,
                curveSmoothness: 0.3,
                color: accentColor,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: data.length <= 10,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: accentColor,
                      strokeWidth: 2,
                      strokeColor: Theme.of(context).colorScheme.surface,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accentColor.withOpacity(0.3 * _animation.value),
                      accentColor.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPieChart(BuildContext context, Color accentColor) {
    final data = widget.chartData.data.entries.toList();
    if (data.isEmpty) return _buildEmptyState();

    final colorScheme = Theme.of(context).colorScheme;
    final total = data.fold<double>(0, (sum, e) => sum + e.value);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return PieChart(
          PieChartData(
            pieTouchData: PieTouchData(
              touchCallback: (event, response) {
                setState(() {
                  if (response != null && response.touchedSection != null) {
                    _touchedIndex = response.touchedSection!.touchedSectionIndex;
                  } else {
                    _touchedIndex = null;
                  }
                });
              },
            ),
            sectionsSpace: 2,
            centerSpaceRadius: widget.compact ? 30 : 50,
            sections: data.asMap().entries.map((entry) {
              final isTouched = entry.key == _touchedIndex;
              final percentage = (entry.value.value / total) * 100;
              final color = ChartColors.getColor(entry.key);
              
              return PieChartSectionData(
                value: entry.value.value * _animation.value,
                title: isTouched || data.length <= 4
                    ? '${percentage.toStringAsFixed(1)}%'
                    : '',
                color: color,
                radius: isTouched ? 60 : 50,
                titleStyle: TextStyle(
                  fontSize: isTouched ? 14 : 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildGaugeChart(BuildContext context, Color accentColor) {
    final value = widget.chartData.data['value'] ?? 0;
    final maxValue = widget.chartData.data['max'] ?? 100;
    final percentage = (value / maxValue).clamp(0.0, 1.0);
    
    final color = percentage > 0.9
        ? Colors.red
        : percentage > 0.7
            ? Colors.orange
            : accentColor;

    return Center(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 12,
                    color: Colors.grey.withOpacity(0.1),
                  ),
                ),
                // Value circle
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: percentage * _animation.value,
                    strokeWidth: 12,
                    color: color,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                // Center text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_formatValue(value)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      '${(percentage * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryFooter(ThemeData theme, ColorScheme colorScheme, Color accentColor) {
    final data = widget.chartData.data.entries.toList();
    if (data.isEmpty) return const SizedBox.shrink();

    final total = data.fold<double>(0, (sum, e) => sum + e.value);
    final average = total / data.length;
    final maxVal = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final minVal = data.map((e) => e.value).reduce((a, b) => a < b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(theme, 'Total', _formatValue(total)),
          Container(width: 1, height: 20, color: Colors.grey.withOpacity(0.2)),
          _buildStatItem(theme, 'Avg', _formatValue(average)),
          Container(width: 1, height: 20, color: Colors.grey.withOpacity(0.2)),
          _buildStatItem(theme, 'Max', _formatValue(maxVal)),
        ],
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.grey[500],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'No data available',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  IconData _getChartIcon() {
    switch (widget.chartData.type) {
      case InlineChartType.bar:
        return Icons.bar_chart_rounded;
      case InlineChartType.line:
        return Icons.show_chart_rounded;
      case InlineChartType.pie:
        return Icons.pie_chart_rounded;
      case InlineChartType.gauge:
        return Icons.donut_large_rounded;
    }
  }

  String _formatValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
  }
}

/// Chart legend widget
class ChartLegend extends StatelessWidget {
  final Map<String, double> data;
  final int? selectedIndex;
  final Function(int)? onSelected;

  const ChartLegend({
    super.key,
    required this.data,
    this.selectedIndex,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: entries.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isSelected = index == selectedIndex;
        final color = ChartColors.getColor(index);

        return GestureDetector(
          onTap: onSelected != null ? () => onSelected!(index) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected ? color : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  item.key,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Mini sparkline chart for inline use
class SparklineChart extends StatelessWidget {
  final List<double> data;
  final Color? color;
  final double height;
  final bool fill;

  const SparklineChart({
    super.key,
    required this.data,
    this.color,
    this.height = 30,
    this.fill = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || data.length < 2) {
      return SizedBox(height: height);
    }

    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();

    final chartColor = color ?? const Color(0xFF00D4AA);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          minY: data.reduce(min),
          maxY: data.reduce(max),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: chartColor,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: fill
                  ? BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          chartColor.withOpacity(0.2),
                          chartColor.withOpacity(0),
                        ],
                      ),
                    )
                  : BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}