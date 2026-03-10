/// Chart Intent Detector
/// 
/// Detects when a user message requests data visualization
/// and extracts the necessary chart parameters.
///
/// Example triggers:
/// - "Show my token usage this week"
/// - "Display message history trend"
/// - "Show model usage breakdown"
/// - "What's my quota usage?"
///
/// The detector uses pattern matching and keyword extraction
/// to determine:
/// 1. Whether a chart is requested
/// 2. What type of chart is best
/// 3. What data to visualize
/// 4. Any time context (today, this week, etc.)

import 'package:flutter/foundation.dart';

/// Chart request intent
class ChartIntent {
  final bool isChartRequest;
  final String? chartType;
  final String? dataType;
  final String? timeRange;
  final String? title;
  final double confidence;
  final Map<String, dynamic>? parameters;

  const ChartIntent({
    required this.isChartRequest,
    this.chartType,
    this.dataType,
    this.timeRange,
    this.title,
    this.confidence = 0.0,
    this.parameters,
  });

  bool get isValid => isChartRequest && confidence > 0.5;
}

/// Chart Intent Detector - detects visualization requests in messages
class ChartIntentDetector {
  // Keywords that trigger chart visualization
  static const _chartTriggers = [
    'show', 'display', 'graph', 'chart', 'plot', 'visualize',
    'usage', 'history', 'trend', 'breakdown', 'statistics',
    'how many', 'how much', 'total', 'compare', 'overview',
  ];

  // Data type keywords
  static const _dataTypePatterns = {
    'tokens': ['token', 'tokens', 'usage', 'consumption'],
    'messages': ['message', 'messages', 'chat', 'chats', 'conversation'],
    'models': ['model', 'models', 'ai', 'llm', 'provider'],
    'quota': ['quota', 'limit', 'remaining', 'budget'],
    'activity': ['activity', 'actions', 'events', 'interactions'],
    'cost': ['cost', 'spending', 'expense', 'price', 'money'],
    'sessions': ['session', 'sessions', 'uptime', 'time'],
    'errors': ['error', 'errors', 'failures', 'issues'],
  };

  // Chart type indicators
  static const _chartTypePatterns = {
    'bar': ['compare', 'comparison', 'breakdown', 'by', 'versus', 'vs', 'each'],
    'line': ['trend', 'over time', 'history', 'progress', 'growth', 'change'],
    'pie': ['breakdown', 'proportion', 'percentage', 'share', 'distribution', 'split'],
    'gauge': ['progress', 'remaining', 'left', 'used', 'quota', 'limit', '%'],
  };

  // Time range patterns
  static const _timeRangePatterns = {
    'today': ['today', 'current day', 'this day'],
    'yesterday': ['yesterday'],
    'week': ['this week', 'weekly', 'past week', 'last week', '7 days'],
    'month': ['this month', 'monthly', 'past month', 'last month', '30 days'],
    'all': ['all time', 'ever', 'total', 'lifetime', 'overall'],
  };

  /// Detect chart intent from a message
  ChartIntent detect(String message) {
    final lowerMessage = message.toLowerCase();
    
    // Check if this is a chart request
    final isChartRequest = _isChartRequest(lowerMessage);
    if (!isChartRequest) {
      return const ChartIntent(isChartRequest: false);
    }

    // Extract chart parameters
    final chartType = _detectChartType(lowerMessage);
    final dataType = _detectDataType(lowerMessage);
    final timeRange = _detectTimeRange(lowerMessage);
    final confidence = _calculateConfidence(lowerMessage, chartType, dataType);

    return ChartIntent(
      isChartRequest: true,
      chartType: chartType,
      dataType: dataType,
      timeRange: timeRange,
      title: _generateTitle(dataType, timeRange),
      confidence: confidence,
      parameters: _extractParameters(lowerMessage),
    );
  }

  /// Check if message is a chart request
  bool _isChartRequest(String message) {
    // Check for chart trigger keywords
    for (final trigger in _chartTriggers) {
      if (message.contains(trigger)) {
        // Verify it's about data, not just the word
        for (final dataType in _dataTypePatterns.keys) {
          for (final pattern in _dataTypePatterns[dataType]!) {
            if (message.contains(pattern)) {
              return true;
            }
          }
        }
      }
    }
    
    // Check for explicit chart words
    if (message.contains('chart') || message.contains('graph') || 
        message.contains('plot') || message.contains('visualize')) {
      return true;
    }

    return false;
  }

  /// Detect the best chart type for the message
  String? _detectChartType(String message) {
    final scores = <String, int>{};
    
    for (final entry in _chartTypePatterns.entries) {
      scores[entry.key] = 0;
      for (final pattern in entry.value) {
        if (message.contains(pattern)) {
          scores[entry.key] = scores[entry.key]! + 1;
        }
      }
    }
    
    // Find highest score
    String? bestType;
    int bestScore = 0;
    
    for (final entry in scores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestType = entry.key;
      }
    }
    
    return bestScore > 0 ? bestType : null;
  }

  /// Detect the data type being requested
  String? _detectDataType(String message) {
    for (final entry in _dataTypePatterns.entries) {
      for (final pattern in entry.value) {
        if (message.contains(pattern)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Detect the time range for the data
  String? _detectTimeRange(String message) {
    for (final entry in _timeRangePatterns.entries) {
      for (final pattern in entry.value) {
        if (message.contains(pattern)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Calculate confidence score for the intent
  double _calculateConfidence(String message, String? chartType, String? dataType) {
    double confidence = 0.0;
    
    // Base confidence for chart request
    if (_isChartRequest(message)) {
      confidence += 0.3;
    }
    
    // Boost for detected chart type
    if (chartType != null) {
      confidence += 0.2;
    }
    
    // Boost for detected data type
    if (dataType != null) {
      confidence += 0.3;
    }
    
    // Boost for explicit chart words
    if (message.contains('chart') || message.contains('graph')) {
      confidence += 0.2;
    }
    
    // Boost for question words
    if (message.contains('how many') || message.contains('how much') ||
        message.contains('what') || message.contains('show')) {
      confidence += 0.1;
    }
    
    return confidence.clamp(0.0, 1.0);
  }

  /// Generate a title for the chart
  String? _generateTitle(String? dataType, String? timeRange) {
    if (dataType == null) return null;
    
    String title = '';
    
    // Capitalize data type
    title += _capitalize(dataType);
    
    // Add time context
    if (timeRange != null) {
      title += ' - ${_capitalize(timeRange)}';
    }
    
    return title;
  }

  /// Extract additional parameters from the message
  Map<String, dynamic>? _extractParameters(String message) {
    final params = <String, dynamic>{};
    
    // Check for comparison requests
    if (message.contains('compare') || message.contains('versus') || 
        message.contains(' vs ')) {
      params['comparison'] = true;
    }
    
    // Check for percentage requests
    if (message.contains('percent') || message.contains('%') || 
        message.contains('percentage')) {
      params['showPercentage'] = true;
    }
    
    // Check for specific model mentions
    final modelPatterns = ['gpt', 'claude', 'gemini', 'qwen', 'glm', 'minimax'];
    for (final model in modelPatterns) {
      if (message.contains(model)) {
        params['filter'] = model;
        break;
      }
    }
    
    return params.isNotEmpty ? params : null;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

/// Chart Data Provider - provides data for chart generation
/// 
/// This class bridges the intent detector with the analytics service
/// to fetch the appropriate data for charts.
class ChartDataProvider {
  /// Get token usage data
  Future<Map<String, double>> getTokenUsageData({
    String? timeRange,
    Map<String, dynamic>? parameters,
  }) async {
    // In production, this would fetch from AnalyticsService
    // For now, return sample data
    final now = DateTime.now();
    
    switch (timeRange) {
      case 'today':
        return {
          'Input': 2500,
          'Output': 1800,
        };
      case 'week':
        return {
          'Mon': 5200,
          'Tue': 4800,
          'Wed': 6500,
          'Thu': 4200,
          'Fri': 7100,
          'Sat': 3800,
          'Sun': 2900,
        };
      case 'month':
        return {
          'Week 1': 28000,
          'Week 2': 32000,
          'Week 3': 29000,
          'Week 4': 31000,
        };
      default:
        return {
          'Total': 120000,
          'Used': 85000,
          'Remaining': 35000,
        };
    }
  }

  /// Get message history data
  Future<Map<String, double>> getMessageHistoryData({
    String? timeRange,
    Map<String, dynamic>? parameters,
  }) async {
    // In production, this would fetch from AnalyticsService
    switch (timeRange) {
      case 'today':
        return {
          'Morning': 12,
          'Afternoon': 25,
          'Evening': 18,
        };
      case 'week':
        return {
          'Mon': 45,
          'Tue': 52,
          'Wed': 38,
          'Thu': 61,
          'Fri': 55,
          'Sat': 28,
          'Sun': 22,
        };
      default:
        return {
          'This Week': 301,
          'Last Week': 278,
          'This Month': 1245,
        };
    }
  }

  /// Get model usage breakdown
  Future<Map<String, double>> getModelUsageData({
    String? timeRange,
    Map<String, dynamic>? parameters,
  }) async {
    // In production, this would fetch from AnalyticsService
    return {
      'Qwen 3.5 Plus': 45,
      'MiniMax M2.5': 28,
      'GLM-5': 15,
      'Kimi K2.5': 12,
    };
  }

  /// Get quota usage data
  Future<Map<String, double>> getQuotaData() async {
    // In production, this would fetch from TokenService
    return {
      'Used': 15000,
      'Remaining': 3000,
    };
  }

  /// Get activity data
  Future<Map<String, double>> getActivityData({
    String? timeRange,
    Map<String, dynamic>? parameters,
  }) async {
    // In production, this would fetch from AnalyticsService
    switch (timeRange) {
      case 'today':
        return {
          'Messages': 45,
          'Actions': 12,
          'Searches': 8,
          'Commands': 5,
        };
      case 'week':
        return {
          'Mon': 89,
          'Tue': 112,
          'Wed': 76,
          'Thu': 134,
          'Fri': 98,
          'Sat': 45,
          'Sun': 32,
        };
      default:
        return {
          'Messages': 1205,
          'Actions': 456,
          'Searches': 234,
          'Commands': 189,
        };
    }
  }

  /// Get data for a specific intent
  Future<Map<String, double>?> getDataForIntent(ChartIntent intent) async {
    if (!intent.isValid) return null;

    switch (intent.dataType) {
      case 'tokens':
        return getTokenUsageData(
          timeRange: intent.timeRange,
          parameters: intent.parameters,
        );
      case 'messages':
        return getMessageHistoryData(
          timeRange: intent.timeRange,
          parameters: intent.parameters,
        );
      case 'models':
        return getModelUsageData(
          timeRange: intent.timeRange,
          parameters: intent.parameters,
        );
      case 'quota':
        return getQuotaData();
      case 'activity':
        return getActivityData(
          timeRange: intent.timeRange,
          parameters: intent.parameters,
        );
      default:
        return null;
    }
  }
}