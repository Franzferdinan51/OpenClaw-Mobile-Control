import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

/// Service for managing app settings - persistence and retrieval
class SettingsService {
  static const String _settingsKey = 'app_settings';
  static const String _legacyGatewayUrlKey = 'gateway_url';
  static const String _legacyGatewayTokenKey = 'gateway_token';

  late SharedPreferences _prefs;
  bool _initialized = false;

  /// Singleton instance
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  /// Initialize the settings service
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// Load settings from storage
  Future<AppSettings> loadSettings() async {
    await init();

    // Try new JSON format first
    final jsonString = _prefs.getString(_settingsKey);
    if (jsonString != null) {
      try {
        return AppSettings.fromJsonString(jsonString);
      } catch (e) {
        // Fall back to legacy format
      }
    }

    // Load from legacy SharedPreferences keys
    final gatewayUrl = _prefs.getString(_legacyGatewayUrlKey) ?? 'http://localhost:18789';
    final gatewayToken = _prefs.getString(_legacyGatewayTokenKey) ?? '';

    return AppSettings(
      gatewayUrl: gatewayUrl,
      gatewayToken: gatewayToken,
    );
  }

  /// Save settings to storage
  Future<void> saveSettings(AppSettings settings) async {
    await init();

    // Save as JSON
    await _prefs.setString(_settingsKey, settings.toJsonString());

    // Also keep legacy keys for backward compatibility
    await _prefs.setString(_legacyGatewayUrlKey, settings.gatewayUrl);
    if (settings.gatewayToken.isNotEmpty) {
      await _prefs.setString(_legacyGatewayTokenKey, settings.gatewayToken);
    }
  }

  /// Update a single setting
  Future<AppSettings> updateSetting(
    AppSettings currentSettings,
    AppSettings Function(AppSettings) updater,
  ) async {
    final newSettings = updater(currentSettings);
    await saveSettings(newSettings);
    return newSettings;
  }

  /// Reset all settings to defaults
  Future<AppSettings> resetAllSettings() async {
    await init();
    await _prefs.remove(_settingsKey);
    return const AppSettings();
  }

  /// Reset specific category
  Future<AppSettings> resetCategory(
    AppSettings currentSettings,
    SettingsCategory category,
  ) async {
    switch (category) {
      case SettingsCategory.gateway:
        return currentSettings.copyWith(
          gatewayUrl: 'http://localhost:18789',
          gatewayToken: '',
          autoDiscoverGateways: true,
          defaultGatewayUrl: '',
          savedGateways: [],
        );
      case SettingsCategory.appPreferences:
        return currentSettings.copyWith(
          themeMode: AppThemeMode.system,
          language: 'auto',
          notificationsEnabled: true,
          soundEnabled: true,
          vibrationEnabled: true,
          autoRefreshInterval: AutoRefreshInterval.oneMinute,
          dataSavingMode: false,
        );
      case SettingsCategory.agent:
        return currentSettings.copyWith(
          defaultAgentId: 'assistant',
          defaultAgentName: 'Assistant',
          responseStyle: AgentResponseStyle.balanced,
          multiAgentMode: false,
          agentTimeout: AgentTimeout.oneMinute,
        );
      case SettingsCategory.voice:
        return currentSettings.copyWith(
          wakeWord: WakeWord.openClaw,
          customWakeWord: '',
          voiceFeedbackEnabled: true,
          ttsVoice: 'default',
          ttsSpeed: 1.0,
          continuousListening: false,
        );
      case SettingsCategory.browseros:
        return currentSettings.copyWith(
          browserosUrl: 'http://localhost:9000',
          browserosAutoConnect: true,
          browserosDefaultModel: 'openai',
          browserosApiKey: '',
          workflowAutoSave: true,
        );
      case SettingsCategory.automation:
        return currentSettings.copyWith(
          webhookUrl: '',
          webhookSecret: '',
          scheduledTasksEnabled: true,
          taskNotificationsEnabled: true,
          iftttEnabled: false,
          iftttKey: '',
        );
      case SettingsCategory.termux:
        return currentSettings.copyWith(
          termuxEnabled: false,
          autoInstallOpenClaw: true,
          defaultShell: 'bash',
        );
      case SettingsCategory.advanced:
        return currentSettings.copyWith(
          developerMode: false,
          debugLogging: false,
        );
    }
  }

  /// Export settings to file
  Future<String> exportSettings(AppSettings settings) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${directory.path}/openclaw_settings_$timestamp.json');
    await file.writeAsString(settings.toJsonString());
    return file.path;
  }

  /// Import settings from file
  Future<AppSettings?> importSettings(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      
      final jsonString = await file.readAsString();
      return AppSettings.fromJsonString(jsonString);
    } catch (e) {
      return null;
    }
  }

  /// Get export directory path
  Future<String> getExportDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// Clear all cached data (cache, not settings)
  Future<void> clearCache() async {
    await init();
    // Clear any cached data but keep settings
    // Implementation depends on what needs to be cleared
  }

  /// Get settings as JSON string for debugging
  Future<String> getSettingsJson() async {
    final settings = await loadSettings();
    return const JsonEncoder.withIndent('  ').convert(settings.toJson());
  }
}

/// Settings categories for reset functionality
enum SettingsCategory {
  gateway,
  appPreferences,
  agent,
  voice,
  browseros,
  automation,
  termux,
  advanced;

  String get displayName {
    switch (this) {
      case SettingsCategory.gateway:
        return 'Gateway';
      case SettingsCategory.appPreferences:
        return 'App Preferences';
      case SettingsCategory.agent:
        return 'Agent';
      case SettingsCategory.voice:
        return 'Voice';
      case SettingsCategory.browseros:
        return 'BrowserOS';
      case SettingsCategory.automation:
        return 'Automation';
      case SettingsCategory.termux:
        return 'Termux';
      case SettingsCategory.advanced:
        return 'Advanced';
    }
  }
}