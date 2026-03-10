import 'dart:convert';

/// App settings model - comprehensive settings for the mobile app
class AppSettings {
  // Gateway Settings
  final String gatewayUrl;
  final String gatewayToken;
  final bool autoDiscoverGateways;
  final String defaultGatewayUrl;
  final List<SavedGateway> savedGateways;

  // App Preferences
  final AppThemeMode themeMode;
  final String language;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final AutoRefreshInterval autoRefreshInterval;
  final bool dataSavingMode;

  // Agent Settings
  final String defaultAgentId;
  final String defaultAgentName;
  final AgentResponseStyle responseStyle;
  final bool multiAgentMode;
  final AgentTimeout agentTimeout;

  // Voice Settings
  final WakeWord wakeWord;
  final String customWakeWord;
  final bool voiceFeedbackEnabled;
  final String ttsVoice;
  final double ttsSpeed;
  final bool continuousListening;

  // BrowserOS Settings
  final String browserosUrl;
  final bool browserosAutoConnect;
  final String browserosDefaultModel;
  final String browserosApiKey;
  final bool workflowAutoSave;

  // Automation Settings
  final String webhookUrl;
  final String webhookSecret;
  final bool scheduledTasksEnabled;
  final bool taskNotificationsEnabled;
  final bool iftttEnabled;
  final String iftttKey;

  // Termux Settings
  final bool termuxEnabled;
  final bool autoInstallOpenClaw;
  final String defaultShell;

  // Advanced Settings
  final bool developerMode;
  final bool debugLogging;
  final String appVersion;

  const AppSettings({
    this.gatewayUrl = 'http://localhost:18789',
    this.gatewayToken = '',
    this.autoDiscoverGateways = true,
    this.defaultGatewayUrl = '',
    this.savedGateways = const [],
    this.themeMode = AppThemeMode.system,
    this.language = 'auto',
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.autoRefreshInterval = AutoRefreshInterval.oneMinute,
    this.dataSavingMode = false,
    this.defaultAgentId = 'assistant',
    this.defaultAgentName = 'Assistant',
    this.responseStyle = AgentResponseStyle.balanced,
    this.multiAgentMode = false,
    this.agentTimeout = AgentTimeout.oneMinute,
    this.wakeWord = WakeWord.openClaw,
    this.customWakeWord = '',
    this.voiceFeedbackEnabled = true,
    this.ttsVoice = 'default',
    this.ttsSpeed = 1.0,
    this.continuousListening = false,
    this.browserosUrl = 'http://localhost:9000',
    this.browserosAutoConnect = true,
    this.browserosDefaultModel = 'openai',
    this.browserosApiKey = '',
    this.workflowAutoSave = true,
    this.webhookUrl = '',
    this.webhookSecret = '',
    this.scheduledTasksEnabled = true,
    this.taskNotificationsEnabled = true,
    this.iftttEnabled = false,
    this.iftttKey = '',
    this.termuxEnabled = false,
    this.autoInstallOpenClaw = true,
    this.defaultShell = 'bash',
    this.developerMode = false,
    this.debugLogging = false,
    this.appVersion = '3.0.0',
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      gatewayUrl: json['gatewayUrl'] as String? ?? 'http://localhost:18789',
      gatewayToken: json['gatewayToken'] as String? ?? '',
      autoDiscoverGateways: json['autoDiscoverGateways'] as bool? ?? true,
      defaultGatewayUrl: json['defaultGatewayUrl'] as String? ?? '',
      savedGateways: (json['savedGateways'] as List<dynamic>?)
              ?.map((e) => SavedGateway.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      themeMode: AppThemeMode.fromString(json['themeMode'] as String? ?? 'system'),
      language: json['language'] as String? ?? 'auto',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      autoRefreshInterval: AutoRefreshInterval.fromString(
          json['autoRefreshInterval'] as String? ?? 'oneMinute'),
      dataSavingMode: json['dataSavingMode'] as bool? ?? false,
      defaultAgentId: json['defaultAgentId'] as String? ?? 'assistant',
      defaultAgentName: json['defaultAgentName'] as String? ?? 'Assistant',
      responseStyle: AgentResponseStyle.fromString(
          json['responseStyle'] as String? ?? 'balanced'),
      multiAgentMode: json['multiAgentMode'] as bool? ?? false,
      agentTimeout:
          AgentTimeout.fromString(json['agentTimeout'] as String? ?? 'oneMinute'),
      wakeWord: WakeWord.fromString(json['wakeWord'] as String? ?? 'openClaw'),
      customWakeWord: json['customWakeWord'] as String? ?? '',
      voiceFeedbackEnabled: json['voiceFeedbackEnabled'] as bool? ?? true,
      ttsVoice: json['ttsVoice'] as String? ?? 'default',
      ttsSpeed: (json['ttsSpeed'] as num?)?.toDouble() ?? 1.0,
      continuousListening: json['continuousListening'] as bool? ?? false,
      browserosUrl: json['browserosUrl'] as String? ?? 'http://localhost:9000',
      browserosAutoConnect: json['browserosAutoConnect'] as bool? ?? true,
      browserosDefaultModel:
          json['browserosDefaultModel'] as String? ?? 'openai',
      browserosApiKey: json['browserosApiKey'] as String? ?? '',
      workflowAutoSave: json['workflowAutoSave'] as bool? ?? true,
      webhookUrl: json['webhookUrl'] as String? ?? '',
      webhookSecret: json['webhookSecret'] as String? ?? '',
      scheduledTasksEnabled: json['scheduledTasksEnabled'] as bool? ?? true,
      taskNotificationsEnabled: json['taskNotificationsEnabled'] as bool? ?? true,
      iftttEnabled: json['iftttEnabled'] as bool? ?? false,
      iftttKey: json['iftttKey'] as String? ?? '',
      termuxEnabled: json['termuxEnabled'] as bool? ?? false,
      autoInstallOpenClaw: json['autoInstallOpenClaw'] as bool? ?? true,
      defaultShell: json['defaultShell'] as String? ?? 'bash',
      developerMode: json['developerMode'] as bool? ?? false,
      debugLogging: json['debugLogging'] as bool? ?? false,
      appVersion: json['appVersion'] as String? ?? '3.0.0',
    );
  }

  Map<String, dynamic> toJson() => {
        'gatewayUrl': gatewayUrl,
        'gatewayToken': gatewayToken,
        'autoDiscoverGateways': autoDiscoverGateways,
        'defaultGatewayUrl': defaultGatewayUrl,
        'savedGateways': savedGateways.map((e) => e.toJson()).toList(),
        'themeMode': themeMode.name,
        'language': language,
        'notificationsEnabled': notificationsEnabled,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'autoRefreshInterval': autoRefreshInterval.name,
        'dataSavingMode': dataSavingMode,
        'defaultAgentId': defaultAgentId,
        'defaultAgentName': defaultAgentName,
        'responseStyle': responseStyle.name,
        'multiAgentMode': multiAgentMode,
        'agentTimeout': agentTimeout.name,
        'wakeWord': wakeWord.name,
        'customWakeWord': customWakeWord,
        'voiceFeedbackEnabled': voiceFeedbackEnabled,
        'ttsVoice': ttsVoice,
        'ttsSpeed': ttsSpeed,
        'continuousListening': continuousListening,
        'browserosUrl': browserosUrl,
        'browserosAutoConnect': browserosAutoConnect,
        'browserosDefaultModel': browserosDefaultModel,
        'browserosApiKey': browserosApiKey,
        'workflowAutoSave': workflowAutoSave,
        'webhookUrl': webhookUrl,
        'webhookSecret': webhookSecret,
        'scheduledTasksEnabled': scheduledTasksEnabled,
        'taskNotificationsEnabled': taskNotificationsEnabled,
        'iftttEnabled': iftttEnabled,
        'iftttKey': iftttKey,
        'termuxEnabled': termuxEnabled,
        'autoInstallOpenClaw': autoInstallOpenClaw,
        'defaultShell': defaultShell,
        'developerMode': developerMode,
        'debugLogging': debugLogging,
        'appVersion': appVersion,
      };

  String toJsonString() => jsonEncode(toJson());

  factory AppSettings.fromJsonString(String jsonString) {
    return AppSettings.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  AppSettings copyWith({
    String? gatewayUrl,
    String? gatewayToken,
    bool? autoDiscoverGateways,
    String? defaultGatewayUrl,
    List<SavedGateway>? savedGateways,
    AppThemeMode? themeMode,
    String? language,
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    AutoRefreshInterval? autoRefreshInterval,
    bool? dataSavingMode,
    String? defaultAgentId,
    String? defaultAgentName,
    AgentResponseStyle? responseStyle,
    bool? multiAgentMode,
    AgentTimeout? agentTimeout,
    WakeWord? wakeWord,
    String? customWakeWord,
    bool? voiceFeedbackEnabled,
    String? ttsVoice,
    double? ttsSpeed,
    bool? continuousListening,
    String? browserosUrl,
    bool? browserosAutoConnect,
    String? browserosDefaultModel,
    String? browserosApiKey,
    bool? workflowAutoSave,
    String? webhookUrl,
    String? webhookSecret,
    bool? scheduledTasksEnabled,
    bool? taskNotificationsEnabled,
    bool? iftttEnabled,
    String? iftttKey,
    bool? termuxEnabled,
    bool? autoInstallOpenClaw,
    String? defaultShell,
    bool? developerMode,
    bool? debugLogging,
    String? appVersion,
  }) {
    return AppSettings(
      gatewayUrl: gatewayUrl ?? this.gatewayUrl,
      gatewayToken: gatewayToken ?? this.gatewayToken,
      autoDiscoverGateways: autoDiscoverGateways ?? this.autoDiscoverGateways,
      defaultGatewayUrl: defaultGatewayUrl ?? this.defaultGatewayUrl,
      savedGateways: savedGateways ?? this.savedGateways,
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      autoRefreshInterval: autoRefreshInterval ?? this.autoRefreshInterval,
      dataSavingMode: dataSavingMode ?? this.dataSavingMode,
      defaultAgentId: defaultAgentId ?? this.defaultAgentId,
      defaultAgentName: defaultAgentName ?? this.defaultAgentName,
      responseStyle: responseStyle ?? this.responseStyle,
      multiAgentMode: multiAgentMode ?? this.multiAgentMode,
      agentTimeout: agentTimeout ?? this.agentTimeout,
      wakeWord: wakeWord ?? this.wakeWord,
      customWakeWord: customWakeWord ?? this.customWakeWord,
      voiceFeedbackEnabled: voiceFeedbackEnabled ?? this.voiceFeedbackEnabled,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      continuousListening: continuousListening ?? this.continuousListening,
      browserosUrl: browserosUrl ?? this.browserosUrl,
      browserosAutoConnect: browserosAutoConnect ?? this.browserosAutoConnect,
      browserosDefaultModel:
          browserosDefaultModel ?? this.browserosDefaultModel,
      browserosApiKey: browserosApiKey ?? this.browserosApiKey,
      workflowAutoSave: workflowAutoSave ?? this.workflowAutoSave,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      webhookSecret: webhookSecret ?? this.webhookSecret,
      scheduledTasksEnabled:
          scheduledTasksEnabled ?? this.scheduledTasksEnabled,
      taskNotificationsEnabled:
          taskNotificationsEnabled ?? this.taskNotificationsEnabled,
      iftttEnabled: iftttEnabled ?? this.iftttEnabled,
      iftttKey: iftttKey ?? this.iftttKey,
      termuxEnabled: termuxEnabled ?? this.termuxEnabled,
      autoInstallOpenClaw: autoInstallOpenClaw ?? this.autoInstallOpenClaw,
      defaultShell: defaultShell ?? this.defaultShell,
      developerMode: developerMode ?? this.developerMode,
      debugLogging: debugLogging ?? this.debugLogging,
      appVersion: appVersion ?? this.appVersion,
    );
  }
}

/// Saved gateway model
class SavedGateway {
  final String name;
  final String url;
  final String? token;
  final DateTime? lastConnected;

  const SavedGateway({
    required this.name,
    required this.url,
    this.token,
    this.lastConnected,
  });

  factory SavedGateway.fromJson(Map<String, dynamic> json) {
    return SavedGateway(
      name: json['name'] as String? ?? 'Unknown',
      url: json['url'] as String? ?? '',
      token: json['token'] as String?,
      lastConnected: json['lastConnected'] != null
          ? DateTime.parse(json['lastConnected'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'token': token,
        'lastConnected': lastConnected?.toIso8601String(),
      };

  SavedGateway copyWith({
    String? name,
    String? url,
    String? token,
    DateTime? lastConnected,
  }) {
    return SavedGateway(
      name: name ?? this.name,
      url: url ?? this.url,
      token: token ?? this.token,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }
}

/// Theme mode enum
enum AppThemeMode {
  system,
  light,
  dark;

  String get displayName {
    switch (this) {
      case AppThemeMode.system:
        return 'System';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  static AppThemeMode fromString(String value) {
    return AppThemeMode.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AppThemeMode.system,
    );
  }
}

/// Auto refresh interval enum
enum AutoRefreshInterval {
  fifteenSeconds,
  thirtySeconds,
  oneMinute,
  fiveMinutes;

  String get displayName {
    switch (this) {
      case AutoRefreshInterval.fifteenSeconds:
        return '15 seconds';
      case AutoRefreshInterval.thirtySeconds:
        return '30 seconds';
      case AutoRefreshInterval.oneMinute:
        return '1 minute';
      case AutoRefreshInterval.fiveMinutes:
        return '5 minutes';
    }
  }

  int get milliseconds {
    switch (this) {
      case AutoRefreshInterval.fifteenSeconds:
        return 15000;
      case AutoRefreshInterval.thirtySeconds:
        return 30000;
      case AutoRefreshInterval.oneMinute:
        return 60000;
      case AutoRefreshInterval.fiveMinutes:
        return 300000;
    }
  }

  static AutoRefreshInterval fromString(String value) {
    return AutoRefreshInterval.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AutoRefreshInterval.oneMinute,
    );
  }
}

/// Agent response style enum
enum AgentResponseStyle {
  concise,
  balanced,
  detailed,
  technical;

  String get displayName {
    switch (this) {
      case AgentResponseStyle.concise:
        return 'Concise';
      case AgentResponseStyle.balanced:
        return 'Balanced';
      case AgentResponseStyle.detailed:
        return 'Detailed';
      case AgentResponseStyle.technical:
        return 'Technical';
    }
  }

  String get description {
    switch (this) {
      case AgentResponseStyle.concise:
        return 'Brief responses, just the facts';
      case AgentResponseStyle.balanced:
        return 'Moderate detail, friendly tone';
      case AgentResponseStyle.detailed:
        return 'Comprehensive responses with explanations';
      case AgentResponseStyle.technical:
        return 'Technical depth, precise terminology';
    }
  }

  static AgentResponseStyle fromString(String value) {
    return AgentResponseStyle.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AgentResponseStyle.balanced,
    );
  }
}

/// Agent timeout enum
enum AgentTimeout {
  thirtySeconds,
  oneMinute,
  fiveMinutes,
  noLimit;

  String get displayName {
    switch (this) {
      case AgentTimeout.thirtySeconds:
        return '30 seconds';
      case AgentTimeout.oneMinute:
        return '1 minute';
      case AgentTimeout.fiveMinutes:
        return '5 minutes';
      case AgentTimeout.noLimit:
        return 'No limit';
    }
  }

  int? get seconds {
    switch (this) {
      case AgentTimeout.thirtySeconds:
        return 30;
      case AgentTimeout.oneMinute:
        return 60;
      case AgentTimeout.fiveMinutes:
        return 300;
      case AgentTimeout.noLimit:
        return null;
    }
  }

  static AgentTimeout fromString(String value) {
    return AgentTimeout.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AgentTimeout.oneMinute,
    );
  }
}

/// Wake word enum
enum WakeWord {
  openClaw,
  heyDuckBot,
  custom;

  String get displayName {
    switch (this) {
      case WakeWord.openClaw:
        return 'OpenClaw';
      case WakeWord.heyDuckBot:
        return 'Hey DuckBot';
      case WakeWord.custom:
        return 'Custom';
    }
  }

  static WakeWord fromString(String value) {
    return WakeWord.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => WakeWord.openClaw,
    );
  }
}

/// Available TTS voices
class TtsVoice {
  final String id;
  final String name;
  final String description;

  const TtsVoice({
    required this.id,
    required this.name,
    required this.description,
  });

  static const List<TtsVoice> availableVoices = [
    TtsVoice(id: 'default', name: 'Default', description: 'System default voice'),
    TtsVoice(id: 'nova', name: 'Nova', description: 'Warm, slightly British'),
    TtsVoice(id: 'shimmer', name: 'Shimmer', description: 'Soft and friendly'),
    TtsVoice(id: 'echo', name: 'Echo', description: 'Clear and robotic'),
    TtsVoice(id: 'fable', name: 'Fable', description: 'Expressive and varied'),
    TtsVoice(id: 'onyx', name: 'Onyx', description: 'Deep and authoritative'),
    TtsVoice(id: 'alloy', name: 'Alloy', description: 'Neutral and versatile'),
  ];
}

/// BrowserOS model options
class BrowserOsModel {
  final String id;
  final String name;

  const BrowserOsModel({
    required this.id,
    required this.name,
  });

  static const List<BrowserOsModel> availableModels = [
    BrowserOsModel(id: 'openai', name: 'OpenAI'),
    BrowserOsModel(id: 'anthropic', name: 'Claude'),
    BrowserOsModel(id: 'google', name: 'Gemini'),
    BrowserOsModel(id: 'bailian', name: 'Bailian'),
  ];
}

/// Shell options for Termux
enum ShellType {
  bash,
  zsh,
  fish;

  String get displayName {
    switch (this) {
      case ShellType.bash:
        return 'Bash';
      case ShellType.zsh:
        return 'Zsh';
      case ShellType.fish:
        return 'Fish';
    }
  }

  static ShellType fromString(String value) {
    return ShellType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ShellType.bash,
    );
  }
}