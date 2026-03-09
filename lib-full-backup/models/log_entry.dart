/// Log entry model for system logs
class LogEntry {
  final String id;
  final AppLogLevel level;
  final String source;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final String? stackTrace;

  const LogEntry({
    required this.id,
    required this.level,
    required this.source,
    required this.message,
    required this.timestamp,
    this.metadata,
    this.stackTrace,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] as String? ?? '',
      level: AppLogLevel.fromString(json['level'] as String? ?? 'info'),
      source: json['source'] as String? ?? 'unknown',
      message: json['message'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      stackTrace: json['stackTrace'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'level': level.name,
        'source': source,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
        'stackTrace': stackTrace,
      };

  String get formattedTimestamp {
    final now = DateTime.now();
    if (now.difference(timestamp).inDays == 0) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    }
    return '${timestamp.month}/${timestamp.day} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

enum AppLogLevel {
  debug,
  info,
  warn,
  error,
  fatal;

  static AppLogLevel fromString(String value) {
    return AppLogLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AppLogLevel.info,
    );
  }

  String get displayName => name.toUpperCase();
}

/// Log filter options
class LogFilter {
  final List<AppLogLevel> levels;
  final List<String> sources;
  final String? searchQuery;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? limit;

  const LogFilter({
    this.levels = const [],
    this.sources = const [],
    this.searchQuery,
    this.startTime,
    this.endTime,
    this.limit,
  });

  Map<String, dynamic> toJson() => {
        'levels': levels.map((e) => e.name).toList(),
        'sources': sources,
        'searchQuery': searchQuery,
        'startTime': startTime?.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'limit': limit,
      };

  LogFilter copyWith({
    List<AppLogLevel>? levels,
    List<String>? sources,
    String? searchQuery,
    DateTime? startTime,
    DateTime? endTime,
    int? limit,
  }) {
    return LogFilter(
      levels: levels ?? this.levels,
      sources: sources ?? this.sources,
      searchQuery: searchQuery ?? this.searchQuery,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      limit: limit ?? this.limit,
    );
  }
}