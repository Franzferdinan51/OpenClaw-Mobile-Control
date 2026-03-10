/// App Settings Service - Manages app-wide settings including user mode
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppMode {
  basic,
  powerUser,
  developer,
}

class AppSettingsService extends ChangeNotifier {
  static AppSettingsService? _instance;
  static bool _initialized = false;
  
  AppMode _currentMode = AppMode.basic;
  bool _notificationsEnabled = true;
  bool _hapticFeedback = true;
  String _theme = 'system'; // light, dark, system
  int _autoRefreshInterval = 30; // seconds
  bool _debugLogging = false;
  
  factory AppSettingsService() {
    _instance ??= AppSettingsService._internal();
    return _instance!;
  }

  AppSettingsService._internal();

  /// Initialize settings from storage - MUST be called before using the service
  static Future<void> initialize() async {
    if (_initialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    final instance = AppSettingsService();
    
    instance._currentMode = AppMode.values.byName(
      prefs.getString('app_mode') ?? 'basic'
    );
    instance._notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    instance._hapticFeedback = prefs.getBool('haptic_feedback') ?? true;
    instance._theme = prefs.getString('theme') ?? 'system';
    instance._autoRefreshInterval = prefs.getInt('auto_refresh_interval') ?? 30;
    instance._debugLogging = prefs.getBool('debug_logging') ?? false;
    
    _initialized = true;
    instance.notifyListeners();
  }

  /// Get current app mode
  AppMode get currentMode => _currentMode;

  /// Check if in basic mode
  bool get isBasicMode => _currentMode == AppMode.basic;

  /// Check if in power user mode
  bool get isPowerUserMode => _currentMode == AppMode.powerUser;

  /// Check if in developer mode
  bool get isDeveloperMode => _currentMode == AppMode.developer;

  /// Set app mode
  Future<void> setAppMode(AppMode mode) async {
    _currentMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_mode', mode.name);
    notifyListeners();
  }

  /// Get notifications enabled
  bool get notificationsEnabled => _notificationsEnabled;

  /// Set notifications enabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    notifyListeners();
  }

  /// Get haptic feedback enabled
  bool get hapticFeedback => _hapticFeedback;

  /// Set haptic feedback enabled
  Future<void> setHapticFeedback(bool enabled) async {
    _hapticFeedback = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('haptic_feedback', enabled);
    notifyListeners();
  }

  /// Get theme
  String get theme => _theme;

  /// Set theme
  Future<void> setTheme(String theme) async {
    _theme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', theme);
    notifyListeners();
  }

  /// Get auto-refresh interval
  int get autoRefreshInterval => _autoRefreshInterval;

  /// Set auto-refresh interval
  Future<void> setAutoRefreshInterval(int seconds) async {
    _autoRefreshInterval = seconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('auto_refresh_interval', seconds);
    notifyListeners();
  }

  /// Get debug logging enabled
  bool get debugLogging => _debugLogging;

  /// Set debug logging enabled
  Future<void> setDebugLogging(bool enabled) async {
    _debugLogging = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('debug_logging', enabled);
    notifyListeners();
  }

  /// Check if feature should be shown based on mode
  bool shouldShowFeature(String featureId) {
    switch (featureId) {
      // Basic mode features (always shown)
      case 'dashboard':
      case 'chat':
      case 'quick_actions_basic':
      case 'settings_basic':
        return true;

      // Power user features
      case 'control_panel':
      case 'logs':
      case 'quick_actions_advanced':
      case 'model_config':
      case 'automation':
      case 'node_management':
        return _currentMode == AppMode.powerUser || _currentMode == AppMode.developer;

      // Developer features
      case 'developer_tools':
      case 'api_explorer':
      case 'debug_console':
      case 'raw_logs':
      case 'advanced_config':
        return _currentMode == AppMode.developer;

      default:
        return true;
    }
  }

  /// Get number of nav tabs based on mode
  int get navTabCount {
    switch (_currentMode) {
      case AppMode.basic:
        return 4; // Home, Chat, Actions, Settings
      case AppMode.powerUser:
        return 6; // Home, Chat, Actions, Tools, Nodes, Settings
      case AppMode.developer:
        return 7; // Home, Chat, Actions, Tools, Nodes, Dev Tools, Settings
    }
  }

  /// Dispose resources
  void dispose() {
    _instance = null;
  }
}
