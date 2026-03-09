import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Logs state using AsyncNotifier pattern
class LogsNotifier extends StateNotifier<AsyncValue<List<LogEntry>>> {
  final GatewayApiService _apiService;
  final GatewayWebSocketService _webSocketService;

  LogFilter _currentFilter = const LogFilter();
  bool _autoScroll = true;
  int _maxLogs = 1000;

  LogsNotifier({
    required GatewayApiService apiService,
    required GatewayWebSocketService webSocketService,
  })  : _apiService = apiService,
        _webSocketService = webSocketService,
        super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    // Subscribe to log events
    _webSocketService.subscribeToLogs();
    
    // Listen for real-time log entries
    _webSocketService.events.listen((event) {
      if (event.type == GatewayEventType.logEntry) {
        final entry = event.logEntry;
        if (entry != null) {
          _addLogEntry(entry);
        }
      }
    });
  }

  /// Load logs with optional filter
  Future<void> loadLogs({LogFilter? filter}) async {
    _currentFilter = filter ?? _currentFilter;
    state = const AsyncValue.loading();
    
    try {
      final logs = await _apiService.getLogs(filter: _currentFilter);
      state = AsyncValue.data(logs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Refresh logs with current filter
  Future<void> refresh() async {
    await loadLogs(filter: _currentFilter);
  }

  /// Update filter and reload
  Future<void> setFilter(LogFilter filter) async {
    _currentFilter = filter;
    await loadLogs(filter: filter);
  }

  /// Clear all logs
  Future<bool> clearLogs() async {
    try {
      await _apiService.clearLogs();
      state = const AsyncValue.data([]);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Add a log entry from WebSocket
  void _addLogEntry(LogEntry entry) {
    // Check if entry passes current filter
    if (!_passesFilter(entry)) return;

    final currentLogs = state.valueOrNull ?? [];
    
    // Enforce max logs limit
    List<LogEntry> newLogs;
    if (currentLogs.length >= _maxLogs) {
      newLogs = [...currentLogs.skip(1), entry];
    } else {
      newLogs = [...currentLogs, entry];
    }
    
    state = AsyncValue.data(newLogs);
  }

  /// Check if entry passes current filter
  bool _passesFilter(LogEntry entry) {
    // Check level filter
    if (_currentFilter.levels.isNotEmpty &&
        !_currentFilter.levels.contains(entry.level)) {
      return false;
    }

    // Check source filter
    if (_currentFilter.sources.isNotEmpty &&
        !_currentFilter.sources.contains(entry.source)) {
      return false;
    }

    // Check search query
    if (_currentFilter.searchQuery != null &&
        _currentFilter.searchQuery!.isNotEmpty) {
      final query = _currentFilter.searchQuery!.toLowerCase();
      if (!entry.message.toLowerCase().contains(query) &&
          !entry.source.toLowerCase().contains(query)) {
        return false;
      }
    }

    // Check time range
    if (_currentFilter.startTime != null &&
        entry.timestamp.isBefore(_currentFilter.startTime!)) {
      return false;
    }
    if (_currentFilter.endTime != null &&
        entry.timestamp.isAfter(_currentFilter.endTime!)) {
      return false;
    }

    return true;
  }

  /// Filter logs locally (for UI filtering without API call)
  List<LogEntry> filterLocally({
    List<LogLevel>? levels,
    List<String>? sources,
    String? searchQuery,
  }) {
    final logs = state.valueOrNull ?? [];
    
    return logs.where((entry) {
      if (levels != null && levels.isNotEmpty && !levels.contains(entry.level)) {
        return false;
      }
      if (sources != null && sources.isNotEmpty && !sources.contains(entry.source)) {
        return false;
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!entry.message.toLowerCase().contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Get unique sources from current logs
  List<String> get availableSources {
    final logs = state.valueOrNull ?? [];
    return logs.map((e) => e.source).toSet().toList()..sort();
  }

  /// Get log count by level
  Map<LogLevel, int> get logCountByLevel {
    final logs = state.valueOrNull ?? [];
    final map = <LogLevel, int>{};
    for (final level in LogLevel.values) {
      map[level] = logs.where((e) => e.level == level).length;
    }
    return map;
  }

  /// Toggle auto-scroll
  void setAutoScroll(bool enabled) {
    _autoScroll = enabled;
  }

  bool get autoScroll => _autoScroll;

  /// Set max logs limit
  void setMaxLogs(int max) {
    _maxLogs = max;
  }

  int get maxLogs => _maxLogs;

  /// Get current filter
  LogFilter get currentFilter => _currentFilter;
}

/// Log filter state for UI
class LogFilterNotifier extends StateNotifier<LogFilter> {
  LogFilterNotifier() : super(const LogFilter());

  void setLevels(List<LogLevel> levels) {
    state = state.copyWith(levels: levels);
  }

  void toggleLevel(LogLevel level) {
    final currentLevels = List<LogLevel>.from(state.levels);
    if (currentLevels.contains(level)) {
      currentLevels.remove(level);
    } else {
      currentLevels.add(level);
    }
    state = state.copyWith(levels: currentLevels);
  }

  void setSources(List<String> sources) {
    state = state.copyWith(sources: sources);
  }

  void toggleSource(String source) {
    final currentSources = List<String>.from(state.sources);
    if (currentSources.contains(source)) {
      currentSources.remove(source);
    } else {
      currentSources.add(source);
    }
    state = state.copyWith(sources: currentSources);
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
  }

  void setTimeRange(DateTime? start, DateTime? end) {
    state = state.copyWith(startTime: start, endTime: end);
  }

  void setLimit(int? limit) {
    state = state.copyWith(limit: limit);
  }

  void reset() {
    state = const LogFilter();
  }
}

/// Provider for logs list
final logsProvider =
    StateNotifierProvider<LogsNotifier, AsyncValue<List<LogEntry>>>((ref) {
  final apiService = ref.watch(gatewayApiServiceProvider);
  final wsService = ref.watch(gatewayWebSocketServiceProvider);
  
  return LogsNotifier(
    apiService: apiService,
    webSocketService: wsService,
  );
});

/// Provider for log filter
final logFilterProvider =
    StateNotifierProvider<LogFilterNotifier, LogFilter>((ref) {
  return LogFilterNotifier();
});

/// Provider for filtered logs (using local filter state)
final filteredLogsProvider = Provider<List<LogEntry>>((ref) {
  final logs = ref.watch(logsProvider).valueOrNull ?? [];
  final filter = ref.watch(logFilterProvider);
  
  return logs.where((entry) {
    if (filter.levels.isNotEmpty && !filter.levels.contains(entry.level)) {
      return false;
    }
    if (filter.sources.isNotEmpty && !filter.sources.contains(entry.source)) {
      return false;
    }
    if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
      final query = filter.searchQuery!.toLowerCase();
      if (!entry.message.toLowerCase().contains(query)) {
        return false;
      }
    }
    return true;
  }).toList();
});

/// Provider for available sources
final logSourcesProvider = Provider<List<String>>((ref) {
  return ref.watch(logsProvider).valueOrNull
          ?.map((e) => e.source)
          .toSet()
          .toList()
        ..sort() ??
      [];
});

/// Provider for log count by level
final logCountByLevelProvider = Provider<Map<LogLevel, int>>((ref) {
  final logs = ref.watch(logsProvider).valueOrNull ?? [];
  final map = <LogLevel, int>{};
  for (final level in LogLevel.values) {
    map[level] = logs.where((e) => e.level == level).length;
  }
  return map;
});

/// Provider for error count
final errorLogCountProvider = Provider<int>((ref) {
  final logs = ref.watch(logsProvider).valueOrNull ?? [];
  return logs.where((e) => 
      e.level == LogLevel.error || e.level == LogLevel.fatal).length;
});

/// Provider for auto-scroll state
final logAutoScrollProvider = Provider<bool>((ref) {
  return ref.watch(logsProvider.notifier).autoScroll;
});