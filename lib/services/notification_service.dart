import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Notification types
enum NotificationType {
  gatewayStatus,
  newMessage,
  actionComplete,
  error,
  sync,
  reminder,
  system,
}

/// Notification priority
enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

/// Notification model
class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final NotificationPriority priority;
  final Map<String, dynamic>? data;
  final String? actionId;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.priority = NotificationPriority.normal,
    this.data,
    this.actionId,
  });

  String get typeIcon {
    switch (type) {
      case NotificationType.gatewayStatus:
        return '🔌';
      case NotificationType.newMessage:
        return '💬';
      case NotificationType.actionComplete:
        return '✅';
      case NotificationType.error:
        return '❌';
      case NotificationType.sync:
        return '🔄';
      case NotificationType.reminder:
        return '⏰';
      case NotificationType.system:
        return '📱';
    }
  }

  Color get priorityColor {
    switch (priority) {
      case NotificationPriority.low:
        return const Color(0xFF4CAF50);
      case NotificationPriority.normal:
        return const Color(0xFF2196F3);
      case NotificationPriority.high:
        return const Color(0xFFFF9800);
      case NotificationPriority.urgent:
        return const Color(0xFFF44336);
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
    'priority': priority.name,
    'data': data,
    'actionId': actionId,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.system,
      ),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['isRead'] ?? false,
      priority: NotificationPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => NotificationPriority.normal,
      ),
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
      actionId: json['actionId'],
    );
  }
}

/// Notification settings
class NotificationSettings {
  final bool enabled;
  final bool gatewayStatus;
  final bool newMessages;
  final bool actionComplete;
  final bool errors;
  final bool sync;
  final bool reminders;
  final bool sound;
  final bool vibration;
  final bool led;

  const NotificationSettings({
    this.enabled = true,
    this.gatewayStatus = true,
    this.newMessages = true,
    this.actionComplete = true,
    this.errors = true,
    this.sync = false,
    this.reminders = true,
    this.sound = true,
    this.vibration = true,
    this.led = true,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'gatewayStatus': gatewayStatus,
    'newMessages': newMessages,
    'actionComplete': actionComplete,
    'errors': errors,
    'sync': sync,
    'reminders': reminders,
    'sound': sound,
    'vibration': vibration,
    'led': led,
  };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      enabled: json['enabled'] ?? true,
      gatewayStatus: json['gatewayStatus'] ?? true,
      newMessages: json['newMessages'] ?? true,
      actionComplete: json['actionComplete'] ?? true,
      errors: json['errors'] ?? true,
      sync: json['sync'] ?? false,
      reminders: json['reminders'] ?? true,
      sound: json['sound'] ?? true,
      vibration: json['vibration'] ?? true,
      led: json['led'] ?? true,
    );
  }

  NotificationSettings copyWith({
    bool? enabled,
    bool? gatewayStatus,
    bool? newMessages,
    bool? actionComplete,
    bool? errors,
    bool? sync,
    bool? reminders,
    bool? sound,
    bool? vibration,
    bool? led,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      gatewayStatus: gatewayStatus ?? this.gatewayStatus,
      newMessages: newMessages ?? this.newMessages,
      actionComplete: actionComplete ?? this.actionComplete,
      errors: errors ?? this.errors,
      sync: sync ?? this.sync,
      reminders: reminders ?? this.reminders,
      sound: sound ?? this.sound,
      vibration: vibration ?? this.vibration,
      led: led ?? this.led,
    );
  }
}

/// Notification service for managing app notifications
class NotificationService extends ChangeNotifier {
  static const String _notificationsKey = 'app_notifications';
  static const String _settingsKey = 'notification_settings';
  
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  List<AppNotification> _notifications = [];
  NotificationSettings _settings = const NotificationSettings();
  bool _isInitialized = false;
  int _unreadCount = 0;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  NotificationSettings get settings => _settings;
  int get unreadCount => _unreadCount;
  bool get isInitialized => _isInitialized;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    await _loadNotifications();
    await _loadSettings();
    _updateUnreadCount();
    
    _isInitialized = true;
    notifyListeners();
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    final android = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ios = _localNotifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    
    bool granted = true;
    
    if (android != null) {
      granted = await android.requestNotificationsPermission() ?? false;
    }
    
    if (ios != null) {
      granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      ) ?? false;
    }
    
    return granted;
  }

  /// Show a notification
  Future<bool> showNotification({
    required NotificationType type,
    required String title,
    required String body,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic>? data,
    String? actionId,
  }) async {
    if (!_settings.enabled) return false;
    
    // Check if this type is enabled
    if (!_isTypeEnabled(type)) return false;
    
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      priority: priority,
      data: data,
      actionId: actionId,
    );
    
    // Add to list
    _notifications.insert(0, notification);
    await _saveNotifications();
    _updateUnreadCount();
    notifyListeners();
    
    // Show local notification
    await _showLocalNotification(notification);
    
    return true;
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = AppNotification(
        id: _notifications[index].id,
        type: _notifications[index].type,
        title: _notifications[index].title,
        body: _notifications[index].body,
        createdAt: _notifications[index].createdAt,
        isRead: true,
        priority: _notifications[index].priority,
        data: _notifications[index].data,
        actionId: _notifications[index].actionId,
      );
      await _saveNotifications();
      _updateUnreadCount();
      notifyListeners();
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    _notifications = _notifications.map((n) => AppNotification(
      id: n.id,
      type: n.type,
      title: n.title,
      body: n.body,
      createdAt: n.createdAt,
      isRead: true,
      priority: n.priority,
      data: n.data,
      actionId: n.actionId,
    )).toList();
    
    await _saveNotifications();
    _updateUnreadCount();
    notifyListeners();
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    await _saveNotifications();
    _updateUnreadCount();
    notifyListeners();
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    _notifications.clear();
    await _saveNotifications();
    _updateUnreadCount();
    notifyListeners();
    
    // Cancel all local notifications
    await _localNotifications.cancelAll();
  }

  /// Update notification settings
  Future<void> updateSettings(NotificationSettings newSettings) async {
    _settings = newSettings;
    await _saveSettings();
    notifyListeners();
  }

  /// Get notifications by type
  List<AppNotification> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  /// Get unread notifications
  List<AppNotification> getUnreadNotifications() {
    return _notifications.where((n) => !n.isRead).toList();
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(String notificationId) async {
    await _localNotifications.cancel(id: notificationId.hashCode);
  }

  /// Show gateway status notification
  Future<void> showGatewayStatusNotification(String status, {String? details}) async {
    await showNotification(
      type: NotificationType.gatewayStatus,
      title: 'Gateway Status',
      body: details ?? 'Gateway is $status',
      priority: status == 'offline' ? NotificationPriority.urgent : NotificationPriority.normal,
    );
  }

  /// Show new message notification
  Future<void> showNewMessageNotification(String from, String message) async {
    await showNotification(
      type: NotificationType.newMessage,
      title: from,
      body: message,
      priority: NotificationPriority.high,
    );
  }

  /// Show action complete notification
  Future<void> showActionCompleteNotification(String action, bool success, {String? details}) async {
    await showNotification(
      type: NotificationType.actionComplete,
      title: success ? '✅ $action Complete' : '❌ $action Failed',
      body: details ?? (success ? 'Action completed successfully' : 'Action failed'),
      priority: success ? NotificationPriority.low : NotificationPriority.high,
    );
  }

  /// Show error notification
  Future<void> showErrorNotification(String error, {String? details}) async {
    await showNotification(
      type: NotificationType.error,
      title: 'Error',
      body: details ?? error,
      priority: NotificationPriority.urgent,
    );
  }

  // Private methods
  bool _isTypeEnabled(NotificationType type) {
    switch (type) {
      case NotificationType.gatewayStatus:
        return _settings.gatewayStatus;
      case NotificationType.newMessage:
        return _settings.newMessages;
      case NotificationType.actionComplete:
        return _settings.actionComplete;
      case NotificationType.error:
        return _settings.errors;
      case NotificationType.sync:
        return _settings.sync;
      case NotificationType.reminder:
        return _settings.reminders;
      case NotificationType.system:
        return true;
    }
  }

  Future<void> _showLocalNotification(AppNotification notification) async {
    final androidDetails = AndroidNotificationDetails(
      'duckbot_${notification.type.name}',
      'DuckBot ${notification.type.name}',
      channelDescription: 'Notifications for ${notification.type.name}',
      importance: _getImportance(notification.priority),
      priority: _getPriority(notification.priority),
      playSound: _settings.sound,
      enableVibration: _settings.vibration,
      enableLights: _settings.led,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      id: notification.id.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
      payload: jsonEncode(notification.toJson()),
    );
  }

  Importance _getImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Importance.low;
      case NotificationPriority.normal:
        return Importance.defaultImportance;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.urgent:
        return Importance.max;
    }
  }

  Priority _getPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Priority.low;
      case NotificationPriority.normal:
        return Priority.defaultPriority;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.urgent:
        return Priority.max;
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final notification = AppNotification.fromJson(json);
        // Handle notification tap - could navigate to specific screen
        debugPrint('Notification tapped: ${notification.title}');
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
  }

  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_notificationsKey);
      
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json);
        _notifications = decoded.map((e) => AppNotification.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      _notifications = [];
    }
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_notifications.map((e) => e.toJson()).toList());
      await prefs.setString(_notificationsKey, json);
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_settingsKey);
      
      if (json != null) {
        _settings = NotificationSettings.fromJson(jsonDecode(json));
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, jsonEncode(_settings.toJson()));
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
    }
  }
}