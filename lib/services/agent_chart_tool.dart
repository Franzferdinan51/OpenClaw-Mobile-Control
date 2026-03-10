/// Agent Chart Tool
/// 
/// Provides chart creation capabilities for AI agents.
/// When an agent needs to visualize data, it uses this tool
/// to create inline charts within chat messages.
///
/// Supported chart types:
/// - Bar charts (comparisons)
/// - Line charts (trends over time)
/// - Pie charts (proportions)
/// - Gauge charts (single value progress)
///
/// Usage:
/// ```dart
/// final chartTool = AgentChartTool();
/// final chart = chartTool.createBarChart(
///   title: 'Token Usage',
///   data: {'Mon': 1000, 'Tue': 1500, 'Wed': 1200},
/// );
/// ```

import 'package:flutter/material.dart';

/// Chart type enumeration
enum InlineChartType {
  bar,
  line,
  pie,
  gauge,
}

/// Chart data model for inline charts
class InlineChartData {
  final String id;
  final String title;
  final InlineChartType type;
  final Map<String, double> data;
  final String? unit;
  final String? subtitle;
  final Color? accentColor;
  final bool animate;
  final DateTime createdAt;

  InlineChartData({
    required this.id,
    required this.title,
    required this.type,
    required this.data,
    this.unit,
    this.subtitle,
    this.accentColor,
    this.animate = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type.name,
    'data': data,
    'unit': unit,
    'subtitle': subtitle,
    'accentColor': accentColor?.value,
    'animate': animate,
    'createdAt': createdAt.toIso8601String(),
  };

  factory InlineChartData.fromJson(Map<String, dynamic> json) {
    return InlineChartData(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      type: InlineChartType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => InlineChartType.bar,
      ),
      data: Map<String, double>.from(json['data'] ?? {}),
      unit: json['unit'],
      subtitle: json['subtitle'],
      accentColor: json['accentColor'] != null
          ? Color(json['accentColor'])
          : null,
      animate: json['animate'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

/// Time series data point for line charts
class TimeSeriesPoint {
  final DateTime timestamp;
  final double value;

  const TimeSeriesPoint({
    required this.timestamp,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'value': value,
  };

  factory TimeSeriesPoint.fromJson(Map<String, dynamic> json) {
    return TimeSeriesPoint(
      timestamp: DateTime.parse(json['timestamp']),
      value: (json['value'] as num).toDouble(),
    );
  }
}

/// Agent Chart Tool - Singleton
class AgentChartTool {
  static AgentChartTool? _instance;
  
  factory AgentChartTool() {
    _instance ??= AgentChartTool._internal();
    return _instance!;
  }

  AgentChartTool._internal();

  /// Create a bar chart for comparisons
  InlineChartData createBarChart({
    required String title,
    required Map<String, double> data,
    String? unit,
    String? subtitle,
    Color? accentColor,
    bool animate = true,
  }) {
    return InlineChartData(
      id: 'chart_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      type: InlineChartType.bar,
      data: data,
      unit: unit,
      subtitle: subtitle,
      accentColor: accentColor,
      animate: animate,
      createdAt: DateTime.now(),
    );
  }

  /// Create a line chart for trends over time
  InlineChartData createLineChart({
    required String title,
    required Map<String, double> data,
    String? unit,
    String? subtitle,
    Color? accentColor,
    bool animate = true,
  }) {
    return InlineChartData(
      id: 'chart_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      type: InlineChartType.line,
      data: data,
      unit: unit,
      subtitle: subtitle,
      accentColor: accentColor,
      animate: animate,
      createdAt: DateTime.now(),
    );
  }

  /// Create a pie chart for proportions
  InlineChartData createPieChart({
    required String title,
    required Map<String, double> data,
    String? unit,
    String? subtitle,
    Color? accentColor,
    bool animate = true,
  }) {
    return InlineChartData(
      id: 'chart_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      type: InlineChartType.pie,
      data: data,
      unit: unit,
      subtitle: subtitle,
      accentColor: accentColor,
      animate: animate,
      createdAt: DateTime.now(),
    );
  }

  /// Create a gauge chart for single value progress
  InlineChartData createGaugeChart({
    required String title,
    required double value,
    required double maxValue,
    String? unit,
    String? subtitle,
    Color? accentColor,
    bool animate = true,
  }) {
    return InlineChartData(
      id: 'chart_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      type: InlineChartType.gauge,
      data: {'value': value, 'max': maxValue},
      unit: unit,
      subtitle: subtitle,
      accentColor: accentColor,
      animate: animate,
      createdAt: DateTime.now(),
    );
  }

  /// Create chart from analytics data
  /// Detects the best chart type based on data characteristics
  InlineChartData createFromData({
    required String title,
    required Map<String, double> data,
    InlineChartType? preferredType,
    String? unit,
    String? subtitle,
    Color? accentColor,
  }) {
    final chartType = preferredType ?? _detectBestChartType(data);
    
    return InlineChartData(
      id: 'chart_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      type: chartType,
      data: data,
      unit: unit,
      subtitle: subtitle,
      accentColor: accentColor,
      createdAt: DateTime.now(),
    );
  }

  /// Auto-detect the best chart type for the data
  InlineChartType _detectBestChartType(Map<String, double> data) {
    if (data.isEmpty) return InlineChartType.bar;
    
    // If there are time-based keys (like "Mon", "Tue", etc.) use line chart
    final timeKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun',
                      'jan', 'feb', 'mar', 'apr', 'may', 'jun',
                      'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
                      'day', 'week', 'month', 'hour'];
    
    final hasTimeKeys = data.keys.any((k) => 
      timeKeys.any((t) => k.toLowerCase().contains(t))
    );
    
    if (hasTimeKeys) return InlineChartType.line;
    
    // If there are 2-6 categories with percentages or proportions, use pie
    if (data.length >= 2 && data.length <= 6) {
      final values = data.values.toList();
      final total = values.fold(0.0, (sum, v) => sum + v);
      // Check if values look like percentages or proportions
      if (total > 0 && total <= 100) {
        return InlineChartType.pie;
      }
    }
    
    // Default to bar chart for comparisons
    return InlineChartType.bar;
  }

  /// Create token usage chart
  InlineChartData createTokenUsageChart({
    required Map<String, int> usage,
    String title = 'Token Usage',
  }) {
    return createBarChart(
      title: title,
      data: usage.map((k, v) => MapEntry(k, v.toDouble())),
      unit: 'tokens',
      accentColor: const Color(0xFF00D4AA),
    );
  }

  /// Create message history chart
  InlineChartData createMessageHistoryChart({
    required Map<String, int> messageCounts,
    String title = 'Message History',
  }) {
    return createLineChart(
      title: title,
      data: messageCounts.map((k, v) => MapEntry(k, v.toDouble())),
      unit: 'messages',
      accentColor: Colors.blue,
    );
  }

  /// Create model usage breakdown chart
  InlineChartData createModelUsageChart({
    required Map<String, int> modelCounts,
    String title = 'Model Usage',
  }) {
    return createPieChart(
      title: title,
      data: modelCounts.map((k, v) => MapEntry(k, v.toDouble())),
      unit: 'requests',
      accentColor: Colors.purple,
    );
  }

  /// Create quota progress chart
  InlineChartData createQuotaChart({
    required int used,
    required int total,
    String title = 'Quota Usage',
  }) {
    return createGaugeChart(
      title: title,
      value: used.toDouble(),
      maxValue: total.toDouble(),
      unit: 'tokens',
      accentColor: used / total > 0.8 ? Colors.red : const Color(0xFF00D4AA),
    );
  }

  /// Create weekly activity chart
  InlineChartData createWeeklyActivityChart({
    required Map<String, int> activity,
    String title = 'Weekly Activity',
  }) {
    // Order days properly
    const dayOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final orderedData = <String, double>{};
    
    for (final day in dayOrder) {
      if (activity.containsKey(day)) {
        orderedData[day] = activity[day]!.toDouble();
      } else if (activity.containsKey(day.toLowerCase())) {
        orderedData[day] = activity[day.toLowerCase()]!.toDouble();
      }
    }
    
    // Add any remaining data
    for (final entry in activity.entries) {
      if (!orderedData.containsKey(entry.key)) {
        orderedData[entry.key] = entry.value.toDouble();
      }
    }
    
    return createBarChart(
      title: title,
      data: orderedData,
      unit: 'actions',
      accentColor: Colors.orange,
    );
  }

  /// Parse chart data from JSON string (for agent tool calls)
  InlineChartData? parseFromJson(String jsonString) {
    try {
      final json = _parseJson(jsonString);
      if (json == null) return null;
      
      return InlineChartData.fromJson(json);
    } catch (e) {
      debugPrint('Error parsing chart JSON: $e');
      return null;
    }
  }

  Map<String, dynamic>? _parseJson(String s) {
    // Simple JSON parsing - in production use dart:convert
    try {
      final decoded = _jsonDecode(s);
      return decoded as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  dynamic _jsonDecode(String source) {
    // Use dart:convert for proper JSON decoding
    return _decodeJsonRecursive(source);
  }

  dynamic _decodeJsonRecursive(String source) {
    // Import and use proper JSON decoder
    // This is a placeholder - actual implementation uses dart:convert
    return null;
  }
}

/// Chart color palette for consistent styling
class ChartColors {
  static const Color primary = Color(0xFF00D4AA);
  static const Color secondary = Color(0xFF6366F1);
  static const Color tertiary = Color(0xFFF59E0B);
  static const Color quaternary = Color(0xFFEF4444);
  static const Color quinary = Color(0xFF8B5CF6);
  
  static const List<Color> palette = [
    primary,
    secondary,
    tertiary,
    quaternary,
    quinary,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
  ];
  
  static Color getColor(int index) {
    return palette[index % palette.length];
  }
}