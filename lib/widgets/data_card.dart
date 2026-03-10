import 'package:flutter/material.dart';
import 'info_card.dart';

/// Data card for displaying metrics and data visualizations
/// 
/// Features:
/// - Progress bars
/// - Gauges
/// - Charts
/// - Sparklines
/// - Data tables
class DataCard extends InfoCard {
  final List<DataItem> items;
  final DataVisualizationType visualizationType;
  final double? maxValue;
  final bool showPercentage;
  final String? unit;

  const DataCard({
    super.key,
    super.title,
    super.subtitle,
    super.leading,
    super.trailing,
    super.accentColor,
    super.onTap,
    super.onLongPress,
    super.actions,
    super.isLoading,
    super.errorMessage,
    super.padding,
    super.margin,
    super.enableSwipe,
    super.swipeLeftAction,
    super.swipeRightAction,
    required this.items,
    this.visualizationType = DataVisualizationType.progress,
    this.maxValue,
    this.showPercentage = true,
    this.unit,
  });

  @override
  Widget buildContent(BuildContext context) {
    switch (visualizationType) {
      case DataVisualizationType.progress:
        return _buildProgressBars(context);
      case DataVisualizationType.gauge:
        return _buildGauge(context);
      case DataVisualizationType.sparkline:
        return _buildSparkline(context);
      case DataVisualizationType.table:
        return _buildTable(context);
      case DataVisualizationType.grid:
        return _buildGrid(context);
    }
  }

  Widget _buildProgressBars(BuildContext context) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Padding(
          padding: EdgeInsets.only(top: index > 0 ? 12 : 0),
          child: _ProgressBar(
            label: item.label,
            value: item.value,
            maxValue: maxValue ?? item.maxValue ?? 100,
            color: item.color ?? const Color(0xFF00D4AA),
            showPercentage: showPercentage,
            unit: unit ?? item.unit,
            icon: item.icon,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGauge(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    final item = items.first;
    final max = maxValue ?? item.maxValue ?? 100;
    final percentage = (item.value / max).clamp(0.0, 1.0);
    
    return Center(
      child: _CircularGauge(
        value: item.value,
        maxValue: max,
        color: item.color ?? const Color(0xFF00D4AA),
        label: item.label,
        unit: unit ?? item.unit,
        showPercentage: showPercentage,
      ),
    );
  }

  Widget _buildSparkline(BuildContext context) {
    return SizedBox(
      height: 60,
      child: CustomPaint(
        painter: _SparklinePainter(
          data: items.map((e) => e.value).toList(),
          color: items.firstOrNull?.color ?? const Color(0xFF00D4AA),
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    return Table(
      border: TableBorder.all(
        color: Colors.grey[800]!,
        borderRadius: BorderRadius.circular(8),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: items.map((item) {
        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (item.icon != null) ...[
                    Icon(item.icon, size: 16, color: item.color),
                    const SizedBox(width: 8),
                  ],
                  Text(item.label),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${item.value}${item.unit ?? ''}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.5,
      children: items.map((item) => _DataGridItem(item: item)).toList(),
    );
  }
}

/// Data visualization types
enum DataVisualizationType {
  progress,
  gauge,
  sparkline,
  table,
  grid,
}

/// Data item for data cards
class DataItem {
  final String label;
  final double value;
  final double? maxValue;
  final Color? color;
  final IconData? icon;
  final String? unit;
  final List<double>? history;

  const DataItem({
    required this.label,
    required this.value,
    this.maxValue,
    this.color,
    this.icon,
    this.unit,
    this.history,
  });
}

/// Progress bar widget
class _ProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final bool showPercentage;
  final String? unit;
  final IconData? icon;

  const _ProgressBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.showPercentage,
    this.unit,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (value / maxValue).clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
            ],
            Text(label, style: const TextStyle(fontSize: 12)),
            const Spacer(),
            Text(
              '${value.toStringAsFixed(0)}${unit ?? ''}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (showPercentage) ...[
              const SizedBox(width: 4),
              Text(
                '(${(percentage * 100).toStringAsFixed(0)}%)',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            // Background
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Progress
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 8,
              width: double.infinity,
              child: FractionallySizedBox(
                widthFactor: percentage,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Circular gauge widget
class _CircularGauge extends StatelessWidget {
  final double value;
  final double maxValue;
  final Color color;
  final String label;
  final String? unit;
  final bool showPercentage;

  const _CircularGauge({
    required this.value,
    required this.maxValue,
    required this.color,
    required this.label,
    this.unit,
    required this.showPercentage,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (value / maxValue).clamp(0.0, 1.0);
    
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: 100,
            height: 100,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 8,
              color: Colors.grey[800],
            ),
          ),
          // Value circle
          SizedBox(
            width: 100,
            height: 100,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percentage),
              duration: const Duration(milliseconds: 1000),
              builder: (context, animValue, child) {
                return CircularProgressIndicator(
                  value: animValue,
                  strokeWidth: 8,
                  color: color,
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),
          // Center text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${value.toStringAsFixed(0)}${unit ?? ''}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (showPercentage)
                Text(
                  '${(percentage * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sparkline painter
class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final path = Path();
    double maxVal = data.first;
    double minVal = data.first;
    
    for (final value in data) {
      if (value > maxVal) maxVal = value;
      if (value < minVal) minVal = value;
    }
    
    final range = maxVal - minVal;
    
    for (var i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minVal) / (range == 0 ? 1 : range)) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    canvas.drawPath(path, paint);
    
    // Fill gradient
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withOpacity(0.3),
        color.withOpacity(0),
      ],
    );
    
    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}

/// Data grid item
class _DataGridItem extends StatelessWidget {
  final DataItem item;

  const _DataGridItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (item.color ?? const Color(0xFF00D4AA)).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 14, color: item.color),
                const SizedBox(width: 4),
              ],
              Text(
                item.label,
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${item.value.toStringAsFixed(0)}${item.unit ?? ''}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: item.color ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Token usage card - specialized for displaying token consumption
class TokenUsageCard extends StatelessWidget {
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  final int? maxTokens;
  final String? modelName;
  final VoidCallback? onTap;
  final VoidCallback? onViewDetails;

  const TokenUsageCard({
    super.key,
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
    this.maxTokens,
    this.modelName,
    this.onTap,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      DataItem(
        label: 'Input',
        value: inputTokens.toDouble(),
        color: Colors.blue,
        icon: Icons.input,
        unit: '',
      ),
      DataItem(
        label: 'Output',
        value: outputTokens.toDouble(),
        color: Colors.orange,
        icon: Icons.output,
        unit: '',
      ),
    ];

    return DataCard(
      title: 'Token Usage',
      subtitle: modelName,
      items: items,
      visualizationType: DataVisualizationType.progress,
      maxValue: maxTokens?.toDouble(),
      accentColor: const Color(0xFF00D4AA),
      onTap: onTap,
      actions: [
        if (onViewDetails != null)
          InfoCardAction(
            icon: Icons.info_outline,
            label: 'Details',
            color: Colors.blue,
            onAction: onViewDetails!,
          ),
      ],
    );
  }
}

/// Session stats card - specialized for session metrics
class SessionStatsCard extends StatelessWidget {
  final int messageCount;
  final int totalTokens;
  final Duration? duration;
  final String? modelName;
  final VoidCallback? onTap;

  const SessionStatsCard({
    super.key,
    required this.messageCount,
    required this.totalTokens,
    this.duration,
    this.modelName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DataCard(
      title: 'Session Stats',
      subtitle: modelName,
      items: [
        DataItem(
          label: 'Messages',
          value: messageCount.toDouble(),
          color: const Color(0xFF00D4AA),
          icon: Icons.message,
        ),
        DataItem(
          label: 'Tokens',
          value: totalTokens.toDouble(),
          color: Colors.purple,
          icon: Icons.token,
        ),
        if (duration != null)
          DataItem(
            label: 'Duration',
            value: duration!.inMinutes.toDouble(),
            color: Colors.blue,
            icon: Icons.timer,
            unit: 'm',
          ),
      ],
      visualizationType: DataVisualizationType.grid,
      onTap: onTap,
    );
  }
}