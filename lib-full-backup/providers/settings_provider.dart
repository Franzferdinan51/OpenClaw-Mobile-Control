import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Settings notifier using StateNotifier pattern
class SettingsNotifier extends StateNotifier<AppSettings> {
  final StorageService _storageService;
  final GatewayApiService _apiService;
  final GatewayWebSocketService _webSocketService;

  SettingsNotifier({
    required StorageService storageService,
    required GatewayApiService apiService,
    required GatewayWebSocketService webSocketService,
  })  : _storageService = storageService,
        _apiService = apiService,
        _webSocketService = webSocketService,
        super(const AppSettings()) {
    _loadSettings();
  }

  /// Load settings from local storage
  Future<void> _loadSettings() async {
    final settings = _storageService.getSettings();
    state = settings;
    
    // Apply settings to services
    _applySettings(settings);
  }

  /// Apply settings to services
  void _applySettings(AppSettings settings) {
    if (settings.gatewayUrl.isNotEmpty) {
      _apiService.updateBaseUrl(settings.gatewayUrl);
      _webSocketService.disconnect(); // Will reconnect with new URL
    }
    if (settings.gatewayToken != null) {
      _apiService.updateToken(settings.gatewayToken);
    }
  }

  /// Update gateway URL
  Future<void> setGatewayUrl(String url) async {
    state = state.copyWith(gatewayUrl: url);
    await _storageService.saveSettings(state);
    _apiService.updateBaseUrl(url);
  }

  /// Update gateway token
  Future<void> setGatewayToken(String? token) async {
    state = state.copyWith(gatewayToken: token);
    await _storageService.saveSettings(state);
    _apiService.updateToken(token);
  }

  /// Update theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _storageService.saveSettings(state);
  }

  /// Toggle notifications
  Future<void> toggleNotifications(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    await _storageService.saveSettings(state);
  }

  /// Toggle sound
  Future<void> toggleSound(bool enabled) async {
    state = state.copyWith(soundEnabled: enabled);
    await _storageService.saveSettings(state);
  }

  /// Toggle vibration
  Future<void> toggleVibration(bool enabled) async {
    state = state.copyWith(vibrationEnabled: enabled);
    await _storageService.saveSettings(state);
  }

  /// Set default agent
  Future<void> setDefaultAgent(String agentId) async {
    state = state.copyWith(defaultAgentId: agentId);
    await _storageService.saveSettings(state);
  }

  /// Set message font size
  Future<void> setMessageFontSize(int size) async {
    state = state.copyWith(messageFontSize: size);
    await _storageService.saveSettings(state);
  }

  /// Toggle markdown rendering
  Future<void> toggleMarkdown(bool enabled) async {
    state = state.copyWith(markdownEnabled: enabled);
    await _storageService.saveSettings(state);
  }

  /// Toggle code highlighting
  Future<void> toggleCodeHighlight(bool enabled) async {
    state = state.copyWith(codeHighlightEnabled: enabled);
    await _storageService.saveSettings(state);
  }

  /// Toggle timestamps display
  Future<void> toggleTimestamps(bool show) async {
    state = state.copyWith(showTimestamps: show);
    await _storageService.saveSettings(state);
  }

  /// Toggle token counts display
  Future<void> toggleTokenCounts(bool show) async {
    state = state.copyWith(showTokenCounts: show);
    await _storageService.saveSettings(state);
  }

  /// Set max history days
  Future<void> setMaxHistoryDays(int days) async {
    state = state.copyWith(maxHistoryDays: days);
    await _storageService.saveSettings(state);
  }

  /// Toggle auto-connect
  Future<void> toggleAutoConnect(bool enabled) async {
    state = state.copyWith(autoConnect: enabled);
    await _storageService.saveSettings(state);
  }

  /// Set connection timeout
  Future<void> setConnectionTimeout(int seconds) async {
    state = state.copyWith(connectionTimeout: seconds);
    await _storageService.saveSettings(state);
  }

  /// Set retry attempts
  Future<void> setRetryAttempts(int attempts) async {
    state = state.copyWith(retryAttempts: attempts);
    await _storageService.saveSettings(state);
  }

  /// Update multiple settings at once
  Future<void> updateSettings(AppSettings newSettings) async {
    state = newSettings;
    await _storageService.saveSettings(state);
    _applySettings(newSettings);
  }

  /// Reset to defaults
  Future<void> resetToDefaults() async {
    state = const AppSettings();
    await _storageService.saveSettings(state);
  }

  /// Clear all data
  Future<void> clearAllData() async {
    await _storageService.clearAll();
    state = const AppSettings();
  }
}

/// Storage service provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Main settings provider
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  final apiService = ref.watch(gatewayApiServiceProvider);
  final wsService = ref.watch(gatewayWebSocketServiceProvider);
  
  return SettingsNotifier(
    storageService: storageService,
    apiService: apiService,
    webSocketService: wsService,
  );
});

/// Convenience providers for specific settings
final gatewayUrlProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).gatewayUrl;
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).themeMode;
});

final notificationsEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).notificationsEnabled;
});

final soundEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).soundEnabled;
});

final defaultAgentIdProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).defaultAgentId;
});

final autoConnectProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).autoConnect;
});

/// Check if gateway is configured
final isGatewayConfiguredProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.gatewayUrl.isNotEmpty;
});