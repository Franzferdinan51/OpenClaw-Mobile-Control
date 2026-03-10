import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Token usage statistics
class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final double? estimatedCost;
  final DateTime timestamp;
  final String? modelId;

  TokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    this.estimatedCost,
    required this.timestamp,
    this.modelId,
  });

  factory TokenUsage.fromJson(Map<String, dynamic> json) {
    return TokenUsage(
      promptTokens: json['promptTokens'] ?? json['prompt_tokens'] ?? 0,
      completionTokens: json['completionTokens'] ?? json['completion_tokens'] ?? 0,
      totalTokens: json['totalTokens'] ?? json['total_tokens'] ?? 0,
      estimatedCost: json['estimatedCost']?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      modelId: json['modelId'],
    );
  }

  Map<String, dynamic> toJson() => {
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'totalTokens': totalTokens,
    'estimatedCost': estimatedCost,
    'timestamp': timestamp.toIso8601String(),
    'modelId': modelId,
  };
}

/// Token quota information
class TokenQuota {
  final int monthlyLimit;
  final int weeklyLimit;
  final int usedThisMonth;
  final int usedThisWeek;
  final DateTime? resetDate;

  TokenQuota({
    required this.monthlyLimit,
    required this.weeklyLimit,
    required this.usedThisMonth,
    required this.usedThisWeek,
    this.resetDate,
  });

  double get monthPercentage => 
      monthlyLimit > 0 ? (usedThisMonth / monthlyLimit) * 100 : 0;
  double get weekPercentage => 
      weeklyLimit > 0 ? (usedThisWeek / weeklyLimit) * 100 : 0;
  
  int get monthRemaining => monthlyLimit - usedThisMonth;
  int get weekRemaining => weeklyLimit - usedThisWeek;
  
  bool get isMonthWarning => monthPercentage >= 80;
  bool get isWeekWarning => weekPercentage >= 80;
  bool get isMonthCritical => monthPercentage >= 95;
  bool get isWeekCritical => weekPercentage >= 95;
}

/// Service for tracking token usage
class TokenService {
  static const String _usageHistoryKey = 'duckbot_token_usage_history';
  static const String _sessionUsageKey = 'duckbot_session_token_usage';
  
  List<TokenUsage> _usageHistory = [];
  TokenUsage? _currentSessionUsage;
  TokenQuota? _quota;
  
  List<TokenUsage> get usageHistory => List.unmodifiable(_usageHistory);
  TokenUsage? get currentSessionUsage => _currentSessionUsage;
  TokenQuota? get quota => _quota;
  
  // Accumulated session tokens
  int _sessionPromptTokens = 0;
  int _sessionCompletionTokens = 0;
  int _sessionTotalTokens = 0;
  double _sessionEstimatedCost = 0.0;
  
  int get sessionPromptTokens => _sessionPromptTokens;
  int get sessionCompletionTokens => _sessionCompletionTokens;
  int get sessionTotalTokens => _sessionTotalTokens;
  double get sessionEstimatedCost => _sessionEstimatedCost;
  
  final StreamController<TokenUsage?> _sessionUsageController = 
      StreamController<TokenUsage?>.broadcast();
  final StreamController<TokenQuota?> _quotaController = 
      StreamController<TokenQuota?>.broadcast();
  
  Stream<TokenUsage?> get sessionUsageStream => _sessionUsageController.stream;
  Stream<TokenQuota?> get quotaStream => _quotaController.stream;

  /// Initialize the service
  Future<void> initialize() async {
    await _loadUsageHistory();
    resetSessionCounter();
  }

  /// Load usage history from storage
  Future<void> _loadUsageHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_usageHistoryKey);
    
    if (historyJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(historyJson);
        _usageHistory = decoded
            .map((u) => TokenUsage.fromJson(u))
            .toList();
      } catch (e) {
        _usageHistory = [];
      }
    }
  }

  /// Save usage history to storage
  Future<void> _saveUsageHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_usageHistory.map((u) => u.toJson()).toList());
    await prefs.setString(_usageHistoryKey, json);
  }

  /// Record token usage for a message
  void recordUsage({
    required int promptTokens,
    required int completionTokens,
    String? modelId,
    double? costPer1kTokens,
  }) {
    final total = promptTokens + completionTokens;
    double? cost;
    
    if (costPer1kTokens != null) {
      cost = (total / 1000) * costPer1kTokens;
    }
    
    _sessionPromptTokens += promptTokens;
    _sessionCompletionTokens += completionTokens;
    _sessionTotalTokens += total;
    if (cost != null) {
      _sessionEstimatedCost += cost;
    }
    
    _currentSessionUsage = TokenUsage(
      promptTokens: _sessionPromptTokens,
      completionTokens: _sessionCompletionTokens,
      totalTokens: _sessionTotalTokens,
      estimatedCost: _sessionEstimatedCost,
      timestamp: DateTime.now(),
      modelId: modelId,
    );
    
    _sessionUsageController.add(_currentSessionUsage);
    
    // Update quota usage
    _updateQuotaUsage(total);
  }

  /// Update quota usage
  void _updateQuotaUsage(int additionalTokens) {
    if (_quota != null) {
      _quota = TokenQuota(
        monthlyLimit: _quota!.monthlyLimit,
        weeklyLimit: _quota!.weeklyLimit,
        usedThisMonth: _quota!.usedThisMonth + additionalTokens,
        usedThisWeek: _quota!.usedThisWeek + additionalTokens,
        resetDate: _quota!.resetDate,
      );
      _quotaController.add(_quota);
    }
  }

  /// Set quota information from gateway
  void setQuota({
    required int monthlyLimit,
    required int weeklyLimit,
    required int usedThisMonth,
    required int usedThisWeek,
    DateTime? resetDate,
  }) {
    _quota = TokenQuota(
      monthlyLimit: monthlyLimit,
      weeklyLimit: weeklyLimit,
      usedThisMonth: usedThisMonth,
      usedThisWeek: usedThisWeek,
      resetDate: resetDate,
    );
    _quotaController.add(_quota);
  }

  /// Reset session token counter
  void resetSessionCounter() {
    _sessionPromptTokens = 0;
    _sessionCompletionTokens = 0;
    _sessionTotalTokens = 0;
    _sessionEstimatedCost = 0.0;
    _currentSessionUsage = null;
    _sessionUsageController.add(null);
  }

  /// Get total usage for a time period
  int getTotalUsageForPeriod(DateTime start, DateTime end) {
    return _usageHistory
        .where((u) => u.timestamp.isAfter(start) && u.timestamp.isBefore(end))
        .fold(0, (sum, u) => sum + u.totalTokens);
  }

  /// Get daily usage summary
  Map<DateTime, int> getDailyUsageSummary({int days = 7}) {
    final now = DateTime.now();
    final summary = <DateTime, int>{};
    
    for (int i = 0; i < days; i++) {
      final day = DateTime(now.year, now.month, now.day - i);
      final dayStart = day;
      final dayEnd = day.add(const Duration(days: 1));
      
      summary[day] = _usageHistory
          .where((u) => u.timestamp.isAfter(dayStart) && u.timestamp.isBefore(dayEnd))
          .fold(0, (sum, u) => sum + u.totalTokens);
    }
    
    return summary;
  }

  /// Save current session to history
  Future<void> saveSessionToHistory() async {
    if (_currentSessionUsage == null) return;
    
    _usageHistory.insert(0, _currentSessionUsage!);
    
    // Keep only last 100 sessions
    if (_usageHistory.length > 100) {
      _usageHistory = _usageHistory.sublist(0, 100);
    }
    
    await _saveUsageHistory();
  }

  /// Estimate tokens from text (rough estimate: ~4 chars per token)
  int estimateTokens(String text) {
    return (text.length / 4).ceil();
  }

  /// Get context window percentage
  double getContextWindowPercentage(int currentTokens, int maxTokens) {
    if (maxTokens <= 0) return 0;
    return (currentTokens / maxTokens) * 100;
  }

  /// Check if context window is near limit
  bool isContextNearLimit(int currentTokens, int maxTokens, {double threshold = 0.8}) {
    return getContextWindowPercentage(currentTokens, maxTokens) >= threshold * 100;
  }

  /// Dispose resources
  void dispose() {
    _sessionUsageController.close();
    _quotaController.close();
  }
}