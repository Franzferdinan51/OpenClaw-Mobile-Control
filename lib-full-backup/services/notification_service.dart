import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Notification Service - Push notifications for OpenClaw Mobile
/// 
/// Handles:
/// - Firebase Cloud Messaging (FCM) setup
/// - Local notifications
/// - Notification channels and categories
/// - Background message handling
/// - Token management
class NotificationService {
  static NotificationService? _instance;

  final void Function(String level, String message, [dynamic data])? onLog;

  // Firebase Messaging
  FirebaseMessaging? _messaging;

  // Local Notifications
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // State
  bool _initialized = false;
  String? _fcmToken;
  final StreamController<String?> _tokenController =
      StreamController<String?>.broadcast();

  // Notification streams
  final StreamController<OpenClawNotification> _notificationController =
      StreamController<OpenClawNotification>.broadcast();
  
  final StreamController<RemoteMessage> _messageController =
      StreamController<RemoteMessage>.broadcast();

  // Callbacks
  void Function(OpenClawNotification notification)? onNotificationTap;
  Future<void> Function(RemoteMessage message)? onBackgroundMessage;

  // Notification channels
  static const String _defaultChannelId = 'openclaw_default';
  static const String _chatChannelId = 'openclaw_chat';
  static const String _alertChannelId = 'openclaw_alerts';
  static const String _systemChannelId = 'openclaw_system';

  factory NotificationService() {
    _instance ??= NotificationService._internal();
    return _instance!;
  }

  NotificationService._internal();

  // ==================== Getters ====================

  /// Whether the service is initialized
  bool get isInitialized => _initialized;

  /// Current FCM token
  String? get fcmToken => _fcmToken;

  /// Stream of FCM token changes
  Stream<String?> get tokenStream => _tokenController.stream;

  /// Stream of received notifications
  Stream<OpenClawNotification> get notificationStream =>
      _notificationController.stream;

  /// Stream of raw FCM messages
  Stream<RemoteMessage> get messageStream => _messageController.stream;

  // ==================== Initialization ====================

  /// Initialize notification service
  Future<void> initialize({
    required Future<void> Function(RemoteMessage message) onBackgroundHandler,
  }) async {
    if (_initialized) {
      _log('warn', 'Notification service already initialized');
      return;
    }

    _log('info', 'Initializing notification service...');

    try {
      // Initialize Firebase
      await Firebase.initializeApp();

      // Initialize Firebase Messaging
      _messaging = FirebaseMessaging.instance;

      // Request permissions
      await _requestPermissions();

      // Get initial token
      _fcmToken = await _messaging!.getToken();
      _log('info', 'FCM Token: ${_fcmToken?.substring(0, 20)}...');

      // Listen for token refresh
      _messaging!.onTokenRefresh.listen((token) {
        _fcmToken = token;
        _tokenController.add(token);
        _log('info', 'FCM Token refreshed');
      });

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Setup message handlers
      _setupMessageHandlers(onBackgroundHandler);

      // Get initial message (app opened from notification)
      _checkInitialMessage();

      _initialized = true;
      _log('info', 'Notification service initialized successfully');
    } catch (e) {
      _log('error', 'Failed to initialize notification service', e);
      rethrow;
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _messaging!.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: true,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );
    }

    if (Platform.isAndroid) {
      await _messaging!.requestPermission();
    }

    // Request local notification permissions for Android 13+
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> _initializeLocalNotifications() async {
    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  Future<void> _createNotificationChannels() async {
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) return;

    // Default channel
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _defaultChannelId,
        'OpenClaw Notifications',
        description: 'General notifications from OpenClaw',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Chat channel
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _chatChannelId,
        'Chat Messages',
        description: 'Chat messages from your agents',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    // Alerts channel
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _alertChannelId,
        'Alerts',
        description: 'Important alerts and warnings',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ),
    );

    // System channel
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _systemChannelId,
        'System',
        description: 'System notifications',
        importance: Importance.low,
        playSound: false,
      ),
    );

    _log('debug', 'Notification channels created');
  }

  void _setupMessageHandlers(
    Future<void> Function(RemoteMessage message) onBackgroundHandler,
  ) {
    // Background message handler
    FirebaseMessaging.onBackgroundMessage(onBackgroundHandler);

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((message) {
      _log('debug', 'Received foreground message: ${message.messageId}');
      _handleMessage(message, isForeground: true);
    });

    // Message opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _log('debug', 'Message opened from background: ${message.messageId}');
      _handleMessageOpened(message);
    });
  }

  Future<void> _checkInitialMessage() async {
    final message = await _messaging!.getInitialMessage();
    if (message != null) {
      _log('debug', 'App opened from terminated state via notification');
      _handleMessageOpened(message);
    }
  }

  // ==================== Message Handling ====================

  void _handleMessage(RemoteMessage message, {bool isForeground = false}) {
    // Add to stream
    _messageController.add(message);

    // Parse notification
    final notification = _parseRemoteMessage(message);

    // Add to notification stream
    _notificationController.add(notification);

    // Show local notification if in foreground
    if (isForeground) {
      showLocalNotification(notification);
    }
  }

  void _handleMessageOpened(RemoteMessage message) {
    final notification = _parseRemoteMessage(message);
    _notificationController.add(notification);

    if (onNotificationTap != null) {
      onNotificationTap!(notification);
    }
  }

  OpenClawNotification _parseRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;

    return OpenClawNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: notification?.title ?? data['title'] ?? 'OpenClaw',
      body: notification?.body ?? data['body'] ?? '',
      type: _parseNotificationType(data['type']),
      data: data,
      receivedAt: DateTime.now(),
      imageUrl: notification?.android?.imageUrl ?? data['image'],
      channelId: _getChannelForType(data['type']),
    );
  }

  NotificationType _parseNotificationType(String? type) {
    switch (type?.toLowerCase()) {
      case 'chat':
      case 'message':
        return NotificationType.chat;
      case 'alert':
      case 'warning':
        return NotificationType.alert;
      case 'system':
        return NotificationType.system;
      case 'agent':
        return NotificationType.agent;
      default:
        return NotificationType.general;
    }
  }

  String _getChannelForType(String? type) {
    switch (type?.toLowerCase()) {
      case 'chat':
      case 'message':
        return _chatChannelId;
      case 'alert':
      case 'warning':
        return _alertChannelId;
      case 'system':
        return _systemChannelId;
      default:
        return _defaultChannelId;
    }
  }

  // ==================== Local Notifications ====================

  /// Show a local notification
  Future<void> showLocalNotification(OpenClawNotification notification) async {
    final androidDetails = AndroidNotificationDetails(
      notification.channelId ?? _defaultChannelId,
      'OpenClaw',
      channelDescription: 'OpenClaw notifications',
      importance: notification.type == NotificationType.alert
          ? Importance.max
          : Importance.high,
      priority: notification.type == NotificationType.alert
          ? Priority.max
          : Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(notification.body),
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
      notification.id.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(notification.toJson()),
    );

    _log('debug', 'Local notification shown: ${notification.title}');
  }

  /// Show a simple notification
  Future<void> show({
    required String title,
    required String body,
    String? id,
    NotificationType type = NotificationType.general,
    Map<String, dynamic>? data,
  }) async {
    await showLocalNotification(OpenClawNotification(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      data: data ?? {},
      receivedAt: DateTime.now(),
      channelId: _getChannelForType(type.name),
    ));
  }

  /// Show a chat notification
  Future<void> showChatMessage({
    required String senderName,
    required String message,
    String? sessionId,
  }) async {
    await show(
      title: senderName,
      body: message,
      type: NotificationType.chat,
      data: {
        'type': 'chat',
        if (sessionId != null) 'sessionId': sessionId,
      },
    );
  }

  /// Show an alert notification
  Future<void> showAlert({
    required String title,
    required String message,
    String? alertType,
    Map<String, dynamic>? data,
  }) async {
    await show(
      title: '⚠️ $title',
      body: message,
      type: NotificationType.alert,
      data: {
        'type': 'alert',
        if (alertType != null) 'alertType': alertType,
        ...?data,
      },
    );
  }

  /// Cancel a specific notification
  Future<void> cancel(String id) async {
    await _localNotifications.cancel(id.hashCode);
    _log('debug', 'Notification cancelled: $id');
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
    _log('debug', 'All notifications cancelled');
  }

  /// Clear the notification badge
  Future<void> clearBadge() async {
    if (Platform.isIOS) {
      await _messaging!.setAutoInitEnabled(true);
    }
    await _localNotifications.cancelAll();
  }

  // ==================== Notification Response ====================

  void _onNotificationResponse(NotificationResponse response) {
    _log('debug', 'Notification tapped: ${response.id}');

    if (response.payload != null) {
      try {
        final json = jsonDecode(response.payload!) as Map<String, dynamic>;
        final notification = OpenClawNotification.fromJson(json);

        if (onNotificationTap != null) {
          onNotificationTap!(notification);
        }
      } catch (e) {
        _log('error', 'Failed to parse notification payload', e);
      }
    }
  }

  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    // Static handler for background notification taps
    debugPrint('[NotificationService] Background notification tapped: ${response.id}');
  }

  // ==================== Token Management ====================

  /// Delete the current FCM token and get a new one
  Future<String?> refreshToken() async {
    if (_messaging == null) {
      throw NotificationException('Notification service not initialized');
    }

    await _messaging!.deleteToken();
    _fcmToken = await _messaging!.getToken();
    _tokenController.add(_fcmToken);
    _log('info', 'FCM Token refreshed');
    return _fcmToken;
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    if (_messaging == null) {
      throw NotificationException('Notification service not initialized');
    }

    await _messaging!.subscribeToTopic(topic);
    _log('info', 'Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (_messaging == null) {
      throw NotificationException('Notification service not initialized');
    }

    await _messaging!.unsubscribeFromTopic(topic);
    _log('info', 'Unsubscribed from topic: $topic');
  }

  // ==================== Cleanup ====================

  void _log(String level, String message, [dynamic data]) {
    if (onLog != null) {
      onLog!(level, message, data);
    } else if (kDebugMode) {
      debugPrint('[NotificationService][$level] $message ${data ?? ''}');
    }
  }

  void dispose() {
    _tokenController.close();
    _notificationController.close();
    _messageController.close();
    _instance = null;
  }
}

// ==================== Models ====================

/// Notification types
enum NotificationType {
  general,
  chat,
  alert,
  system,
  agent,
}

/// OpenClaw notification model
class OpenClawNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final Map<String, dynamic> data;
  final DateTime receivedAt;
  final String? imageUrl;
  final String? channelId;

  OpenClawNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.data,
    required this.receivedAt,
    this.imageUrl,
    this.channelId,
  });

  bool get isAlert => type == NotificationType.alert;
  bool get isChat => type == NotificationType.chat;
  bool get isSystem => type == NotificationType.system;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.name,
      'data': data,
      'receivedAt': receivedAt.toIso8601String(),
      'imageUrl': imageUrl,
      'channelId': channelId,
    };
  }

  factory OpenClawNotification.fromJson(Map<String, dynamic> json) {
    return OpenClawNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: NotificationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => NotificationType.general,
      ),
      data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
      receivedAt: DateTime.parse(json['receivedAt'] as String),
      imageUrl: json['imageUrl'] as String?,
      channelId: json['channelId'] as String?,
    );
  }

  @override
  String toString() {
    return 'OpenClawNotification(id: $id, title: $title, type: $type)';
  }
}

/// Notification exception
class NotificationException implements Exception {
  final String message;

  NotificationException(this.message);

  @override
  String toString() => 'NotificationException: $message';
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background message handling
  await Firebase.initializeApp();
  
  debugPrint('[OpenClaw] Background message: ${message.messageId}');
}