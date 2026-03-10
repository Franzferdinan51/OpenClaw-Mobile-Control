import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Analytics event types
enum AnalyticsEventType {
  appOpen,
  appClose,
  screenView,
  actionExecute,
  messageSent,
  messageReceived,
  gatewayConnect,
  gatewayDisconnect,
  syncStart,
  syncComplete,
  backupCreate,
  backupRestore,
  error,
  voiceCommand,
  search,
}

/// Analytics event model
class AnalyticsEvent {
  final String id;
  final AnalyticsEventType type;
  final String name;
  final DateTime timestamp;
  final Map<String, dynamic>? properties;
  final Duration? duration;

  AnalyticsEvent({
    required this.id,
    required this.type,
    required this.name,
    required this.timestamp,
    this.properties,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'timestamp': timestamp.toIso8601String(),
    'properties': properties,
    'duration': duration?.inMilliseconds,
  };

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      id: json['id'] ?? '',
      type: AnalyticsEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AnalyticsEventType.actionExecute,
      ),
      name: json['name'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      properties: json['properties'] != null
          ? Map<String, dynamic>.from(json['properties'])
          : null,
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'])
          : null,
    );
  }
}

/// Usage statistics model
class UsageStatistics {
  final DateTime date;
  final int sessionsCount;
  final int messagesCount;
  final int actionsCount;
  final int gatewayConnections;
  final int syncsCount;
  final int backupsCount;
  final Duration totalTime;
  final Map<String, int> actionBreakdown;
  final Map<String, int> screenViews;

  UsageStatistics({
    required this.date,
    this.sessionsCount = 0,
    this.messagesCount = 0,
    this.actionsCount = 0,
    this.gatewayConnections = 0,
    this.syncsCount = 0,
    this.backupsCount = 0,
    this.totalTime = Duration.zero,
    this.actionBreakdown = const {},
    this.screenViews = const {},
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'sessionsCount': sessionsCount,
    'messagesCount': messagesCount,
    'actionsCount': actionsCount,
    'gatewayConnections': gatewayConnections,
    'syncsCount': syncsCount,
    'backupsCount': backupsCount,
    'totalTime': totalTime.inMinutes,
    'actionBreakdown': actionBreakdown,
    'screenViews': screenViews,
  };

  factory UsageStatistics.fromJson(Map<String, dynamic> json) {
    return UsageStatistics(
      date: DateTime.parse(json['date']),
      sessionsCount: json['sessionsCount'] ?? 0,
      messagesCount: json['messagesCount'] ?? 0,
      actionsCount: json['actionsCount'] ?? 0,
      gatewayConnections: json['gatewayConnections'] ?? 0,
      syncsCount: json['syncsCount'] ?? 0,
      backupsCount: json['backupsCount'] ?? 0,
      totalTime: Duration(minutes: json['totalTime'] ?? 0),
      actionBreakdown: json['actionBreakdown'] != null
          ? Map<String, int>.from(json['actionBreakdown'])
          : {},
      screenViews: json['screenViews'] != null
          ? Map<String, int>.from(json['screenViews'])
          : {},
    );
  }
}

/// Analytics configuration
class AnalyticsConfig {
  final bool enabled;
  final bool trackScreenViews;
  final bool trackActions;
  final bool trackMessages;
  final bool trackGatewayConnections;
  final bool trackErrors;
  final int retentionDays;

  const AnalyticsConfig({
    this.enabled = true,
    this.trackScreenViews = true,
    this.trackActions = true,
    this.trackMessages = true,
    this.trackGatewayConnections = true,
    this.trackErrors = true,
    this.retentionDays = 30,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'trackScreenViews': trackScreenViews,
    'trackActions': trackActions,
    'trackMessages': trackMessages,
    'trackGatewayConnections': trackGatewayConnections,
    'trackErrors': trackErrors,
    'retentionDays': retentionDays,
  };

  factory AnalyticsConfig.fromJson(Map<String, dynamic> json) {
    return AnalyticsConfig(
      enabled: json['enabled'] ?? true,
      trackScreenViews: json['trackScreenViews'] ?? true,
      trackActions: json['trackActions'] ?? true,
      trackMessages: json['trackMessages'] ?? true,
      trackGatewayConnections: json['trackGatewayConnections'] ?? true,
      trackErrors: json['trackErrors'] ?? true,
      retentionDays: json['retentionDays'] ?? 30,
    );
  }
}

/// Analytics service for tracking app usage
class AnalyticsService extends ChangeNotifier {
  static const String _eventsKey = 'analytics_events';
  static const String _statsKey = 'analytics_stats';
  static const String _configKey = 'analytics_config';
  
  List<AnalyticsEvent> _events = [];
  Map<String, UsageStatistics> _dailyStats = {};
  AnalyticsConfig _config = const AnalyticsConfig();
  
  DateTime? _sessionStart;
  String? _currentScreen;
  
  int _totalEvents = 0;
  int _totalMessages = 0;
  int _totalActions = 0;
  int _totalGatewayConnections = 0;

  List<AnalyticsEvent> get events => List.unmodifiable(_events);
  AnalyticsConfig get config => _config;
  int get totalEvents => _totalEvents;
  int get totalMessages => _totalMessages;
  int get totalActions => _totalActions;
  int get totalGatewayConnections => _totalGatewayConnections;

  /// Initialize analytics service
  Future<void> initialize() async {
    await _loadEvents();
    await _loadStats();
    await _loadConfig();
    
    // Clean old events
    await _cleanOldEvents();
    
    // Track app open
    _sessionStart = DateTime.now();
    await trackEvent(
      type: AnalyticsEventType.appOpen,
      name: 'app_opened',
    );
  }

  /// Track an analytics event
  Future<void> trackEvent({
    required AnalyticsEventType type,
    required String name,
    Map<String, dynamic>? properties,
    Duration? duration,
  }) async {
    if (!_config.enabled) return;
    
    // Check if this event type should be tracked
    if (!_shouldTrackType(type)) return;

    final event = AnalyticsEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      name: name,
      timestamp: DateTime.now(),
      properties: properties,
      duration: duration,
    );

    _events.add(event);
    _totalEvents++;
    
    // Update counters
    switch (type) {
      case AnalyticsEventType.messageSent:
      case AnalyticsEventType.messageReceived:
        _totalMessages++;
        break;
      case AnalyticsEventType.actionExecute:
        _totalActions++;
        break;
      case AnalyticsEventType.gatewayConnect:
        _totalGatewayConnections++;
        break;
      default:
        break;
    }
    
    // Update daily stats
    await _updateDailyStats(event);
    
    // Save events
    await _saveEvents();
    
    notifyListeners();
  }

  /// Track screen view
  Future<void> trackScreenView(String screenName) async {
    if (!_config.trackScreenViews) return;
    
    _currentScreen = screenName;
    
    await trackEvent(
      type: AnalyticsEventType.screenView,
      name: 'screen_$screenName',
      properties: {'screen': screenName},
    );
  }

  /// Track action execution
  Future<void> trackAction(String actionName, {bool success = true, Duration? duration}) async {
    if (!_config.trackActions) return;
    
    await trackEvent(
      type: AnalyticsEventType.actionExecute,
      name: 'action_$actionName',
      properties: {'action': actionName, 'success': success},
      duration: duration,
    );
  }

  /// Track message
  Future<void> trackMessage(bool isSent, {int? tokenCount, String? model}) async {
    if (!_config.trackMessages) return;
    
    await trackEvent(
      type: isSent ? AnalyticsEventType.messageSent : AnalyticsEventType.messageReceived,
      name: isSent ? 'message_sent' : 'message_received',
      properties: {
        if (tokenCount != null) 'tokenCount': tokenCount,
        if (model != null) 'model': model,
      },
    );
  }

  /// Track gateway connection
  Future<void> trackGatewayConnection(String gatewayName, bool connected) async {
    if (!_config.trackGatewayConnections) return;
    
    await trackEvent(
      type: connected ? AnalyticsEventType.gatewayConnect : AnalyticsEventType.gatewayDisconnect,
      name: connected ? 'gateway_connected' : 'gateway_disconnected',
      properties: {'gateway': gatewayName},
    );
  }

  /// Track error
  Future<void> trackError(String error, {StackTrace? stackTrace, Map<String, dynamic>? context}) async {
    if (!_config.trackErrors) return;
    
    await trackEvent(
      type: AnalyticsEventType.error,
      name: 'error',
      properties: {
        'error': error,
        if (stackTrace != null) 'stackTrace': stackTrace.toString(),
        ...?context,
      },
    );
  }

  /// Get usage statistics for a date range
  Future<List<UsageStatistics>> getUsageStatistics({DateTime? startDate, DateTime? end}) async {
    final start = startDate ?? DateTime.now().subtract(const Duration(days: 7));
    final endDate = end ?? DateTime.now();
    
    final stats = <UsageStatistics>[];
    
    for (var date = start; date.isBefore(endDate) || date.isAtSameMomentAs(endDate); 
         date = date.add(const Duration(days: 1))) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      if (_dailyStats.containsKey(key)) {
        stats.add(_dailyStats[key]!);
      }
    }
    
    return stats;
  }

  /// Get today's statistics
  UsageStatistics getTodayStatistics() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _dailyStats[today] ?? UsageStatistics(date: DateTime.now());
  }

  /// Get statistics summary
  Map<String, dynamic> getStatisticsSummary() {
    final today = getTodayStatistics();
    
    // Calculate totals from daily stats
    int totalSessions = 0;
    int totalMessages = 0;
    int totalActions = 0;
    Duration totalDuration = Duration.zero;
    
    for (final stat in _dailyStats.values) {
      totalSessions += stat.sessionsCount;
      totalMessages += stat.messagesCount;
      totalActions += stat.actionsCount;
      totalDuration += stat.totalTime;
    }
    
    // Get top actions
    final actionCounts = <String, int>{};
    for (final event in _events.where((e) => e.type == AnalyticsEventType.actionExecute)) {
      final action = event.properties?['action'] as String? ?? event.name;
      actionCounts[action] = (actionCounts[action] ?? 0) + 1;
    }
    
    final topActions = actionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return {
      'today': today.toJson(),
      'totalSessions': totalSessions,
      'totalMessages': totalMessages,
      'totalActions': totalActions,
      'totalDuration': totalDuration.inMinutes,
      'topActions': topActions.take(10).map((e) => {'name': e.key, 'count': e.value}).toList(),
      'totalGatewayConnections': _totalGatewayConnections,
    };
  }

  /// Get events by type
  List<AnalyticsEvent> getEventsByType(AnalyticsEventType type) {
    return _events.where((e) => e.type == type).toList();
  }

  /// Get events by date range
  List<AnalyticsEvent> getEventsByDateRange(DateTime start, DateTime end) {
    return _events.where((e) => 
      e.timestamp.isAfter(start) && e.timestamp.isBefore(end)
    ).toList();
  }

  /// Get action breakdown
  Map<String, int> getActionBreakdown({DateTime? since}) {
    final breakdown = <String, int>{};
    final events = since != null
        ? _events.where((e) => e.timestamp.isAfter(since))
        : _events;
    
    for (final event in events.where((e) => e.type == AnalyticsEventType.actionExecute)) {
      final action = event.properties?['action'] as String? ?? event.name;
      breakdown[action] = (breakdown[action] ?? 0) + 1;
    }
    
    return breakdown;
  }

  /// Update configuration
  Future<void> updateConfig(AnalyticsConfig newConfig) async {
    _config = newConfig;
    await _saveConfig();
    notifyListeners();
  }

  /// Clear all analytics data
  Future<void> clearAllData() async {
    _events.clear();
    _dailyStats.clear();
    _totalEvents = 0;
    _totalMessages = 0;
    _totalActions = 0;
    _totalGatewayConnections = 0;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eventsKey);
    await prefs.remove(_statsKey);
    
    notifyListeners();
  }

  /// Export analytics data
  Future<String> exportToJson() async {
    final data = {
      'events': _events.map((e) => e.toJson()).toList(),
      'dailyStats': _dailyStats.map((k, v) => MapEntry(k, v.toJson())),
      'summary': getStatisticsSummary(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
    
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  // Private methods
  bool _shouldTrackType(AnalyticsEventType type) {
    switch (type) {
      case AnalyticsEventType.screenView:
        return _config.trackScreenViews;
      case AnalyticsEventType.actionExecute:
        return _config.trackActions;
      case AnalyticsEventType.messageSent:
      case AnalyticsEventType.messageReceived:
        return _config.trackMessages;
      case AnalyticsEventType.gatewayConnect:
      case AnalyticsEventType.gatewayDisconnect:
        return _config.trackGatewayConnections;
      case AnalyticsEventType.error:
        return _config.trackErrors;
      default:
        return true;
    }
  }

  Future<void> _updateDailyStats(AnalyticsEvent event) async {
    final key = DateFormat('yyyy-MM-dd').format(event.timestamp);
    
    if (!_dailyStats.containsKey(key)) {
      _dailyStats[key] = UsageStatistics(date: event.timestamp);
    }
    
    final stat = _dailyStats[key]!;
    final updated = UsageStatistics(
      date: stat.date,
      sessionsCount: event.type == AnalyticsEventType.appOpen
          ? stat.sessionsCount + 1
          : stat.sessionsCount,
      messagesCount: event.type == AnalyticsEventType.messageSent ||
              event.type == AnalyticsEventType.messageReceived
          ? stat.messagesCount + 1
          : stat.messagesCount,
      actionsCount: event.type == AnalyticsEventType.actionExecute
          ? stat.actionsCount + 1
          : stat.actionsCount,
      gatewayConnections: event.type == AnalyticsEventType.gatewayConnect
          ? stat.gatewayConnections + 1
          : stat.gatewayConnections,
      syncsCount: event.type == AnalyticsEventType.syncComplete
          ? stat.syncsCount + 1
          : stat.syncsCount,
      backupsCount: event.type == AnalyticsEventType.backupCreate
          ? stat.backupsCount + 1
          : stat.backupsCount,
      totalTime: _sessionStart != null
          ? DateTime.now().difference(_sessionStart!)
          : stat.totalTime,
      actionBreakdown: _updateActionBreakdown(stat.actionBreakdown, event),
      screenViews: _updateScreenViews(stat.screenViews, event),
    );
    
    _dailyStats[key] = updated;
    await _saveStats();
  }

  Map<String, int> _updateActionBreakdown(Map<String, int> current, AnalyticsEvent event) {
    if (event.type != AnalyticsEventType.actionExecute) return current;
    
    final action = event.properties?['action'] as String? ?? event.name;
    final updated = Map<String, int>.from(current);
    updated[action] = (updated[action] ?? 0) + 1;
    return updated;
  }

  Map<String, int> _updateScreenViews(Map<String, int> current, AnalyticsEvent event) {
    if (event.type != AnalyticsEventType.screenView) return current;
    
    final screen = event.properties?['screen'] as String? ?? event.name;
    final updated = Map<String, int>.from(current);
    updated[screen] = (updated[screen] ?? 0) + 1;
    return updated;
  }

  Future<void> _loadEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_eventsKey);
      
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json);
        _events = decoded.map((e) => AnalyticsEvent.fromJson(e)).toList();
        _totalEvents = _events.length;
      }
    } catch (e) {
      debugPrint('Error loading events: $e');
      _events = [];
    }
  }

  Future<void> _saveEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_events.map((e) => e.toJson()).toList());
      await prefs.setString(_eventsKey, json);
    } catch (e) {
      debugPrint('Error saving events: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_statsKey);
      
      if (json != null) {
        final Map<String, dynamic> decoded = jsonDecode(json);
        _dailyStats = decoded.map((k, v) => MapEntry(k, UsageStatistics.fromJson(v)));
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      _dailyStats = {};
    }
  }

  Future<void> _saveStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_dailyStats.map((k, v) => MapEntry(k, v.toJson())));
      await prefs.setString(_statsKey, json);
    } catch (e) {
      debugPrint('Error saving stats: $e');
    }
  }

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_configKey);
      
      if (json != null) {
        _config = AnalyticsConfig.fromJson(jsonDecode(json));
      }
    } catch (e) {
      debugPrint('Error loading config: $e');
    }
  }

  Future<void> _saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, jsonEncode(_config.toJson()));
    } catch (e) {
      debugPrint('Error saving config: $e');
    }
  }

  Future<void> _cleanOldEvents() async {
    final cutoff = DateTime.now().subtract(Duration(days: _config.retentionDays));
    _events.removeWhere((e) => e.timestamp.isBefore(cutoff));
    
    // Also clean old daily stats
    final statsCutoff = DateFormat('yyyy-MM-dd').format(cutoff);
    _dailyStats.removeWhere((k, _) => k.compareTo(statsCutoff) < 0);
    
    await _saveEvents();
    await _saveStats();
  }
}