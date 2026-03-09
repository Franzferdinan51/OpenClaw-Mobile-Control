/// App settings model
class AppSettings {
  final String gatewayUrl;
  final String? gatewayToken;
  final AppThemeMode themeMode;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final String defaultAgentId;
  final int messageFontSize;
  final bool markdownEnabled;
  final bool codeHighlightEnabled;
  final bool showTimestamps;
  final bool showTokenCounts;
  final int maxHistoryDays;
  final bool autoConnect;
  final int connectionTimeout;
  final int retryAttempts;

  const AppSettings({
    this.gatewayUrl = '',
    this.gatewayToken,
    this.themeMode = AppThemeMode.system,
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.defaultAgentId = '',
    this.messageFontSize = 16,
    this.markdownEnabled = true,
    this.codeHighlightEnabled = true,
    this.showTimestamps = true,
    this.showTokenCounts = false,
    this.maxHistoryDays = 30,
    this.autoConnect = true,
    this.connectionTimeout = 30,
    this.retryAttempts = 3,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      gatewayUrl: json['gatewayUrl'] as String? ?? '',
      gatewayToken: json['gatewayToken'] as String?,
      themeMode: AppThemeMode.fromString(json['themeMode'] as String? ?? 'system'),
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      defaultAgentId: json['defaultAgentId'] as String? ?? '',
      messageFontSize: json['messageFontSize'] as int? ?? 16,
      markdownEnabled: json['markdownEnabled'] as bool? ?? true,
      codeHighlightEnabled: json['codeHighlightEnabled'] as bool? ?? true,
      showTimestamps: json['showTimestamps'] as bool? ?? true,
      showTokenCounts: json['showTokenCounts'] as bool? ?? false,
      maxHistoryDays: json['maxHistoryDays'] as int? ?? 30,
      autoConnect: json['autoConnect'] as bool? ?? true,
      connectionTimeout: json['connectionTimeout'] as int? ?? 30,
      retryAttempts: json['retryAttempts'] as int? ?? 3,
    );
  }

  Map<String, dynamic> toJson() => {
        'gatewayUrl': gatewayUrl,
        'gatewayToken': gatewayToken,
        'themeMode': themeMode.name,
        'notificationsEnabled': notificationsEnabled,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'defaultAgentId': defaultAgentId,
        'messageFontSize': messageFontSize,
        'markdownEnabled': markdownEnabled,
        'codeHighlightEnabled': codeHighlightEnabled,
        'showTimestamps': showTimestamps,
        'showTokenCounts': showTokenCounts,
        'maxHistoryDays': maxHistoryDays,
        'autoConnect': autoConnect,
        'connectionTimeout': connectionTimeout,
        'retryAttempts': retryAttempts,
      };

  AppSettings copyWith({
    String? gatewayUrl,
    String? gatewayToken,
    AppThemeMode? themeMode,
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    String? defaultAgentId,
    int? messageFontSize,
    bool? markdownEnabled,
    bool? codeHighlightEnabled,
    bool? showTimestamps,
    bool? showTokenCounts,
    int? maxHistoryDays,
    bool? autoConnect,
    int? connectionTimeout,
    int? retryAttempts,
  }) {
    return AppSettings(
      gatewayUrl: gatewayUrl ?? this.gatewayUrl,
      gatewayToken: gatewayToken ?? this.gatewayToken,
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      defaultAgentId: defaultAgentId ?? this.defaultAgentId,
      messageFontSize: messageFontSize ?? this.messageFontSize,
      markdownEnabled: markdownEnabled ?? this.markdownEnabled,
      codeHighlightEnabled:
          codeHighlightEnabled ?? this.codeHighlightEnabled,
      showTimestamps: showTimestamps ?? this.showTimestamps,
      showTokenCounts: showTokenCounts ?? this.showTokenCounts,
      maxHistoryDays: maxHistoryDays ?? this.maxHistoryDays,
      autoConnect: autoConnect ?? this.autoConnect,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      retryAttempts: retryAttempts ?? this.retryAttempts,
    );
  }
}

enum AppThemeMode {
  system,
  light,
  dark;

  static AppThemeMode fromString(String value) {
    return AppThemeMode.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AppThemeMode.system,
    );
  }
}