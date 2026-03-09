import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/chat_message.dart' show Conversation;
import '../models/settings.dart';

/// Storage Service - Hive-based local database for OpenClaw Mobile
/// 
/// Provides persistent local storage for:
/// - User settings and preferences
/// - Cached data for offline access
/// - Chat history
/// - Gateway configurations
/// - Authentication tokens (secured)
class StorageService {
  static StorageService? _instance;

  final void Function(String level, String message, [dynamic data])? onLog;

  // Box names
  static const String _settingsBox = 'settings';
  static const String _cacheBox = 'cache';
  static const String _chatBox = 'chat_history';
  static const String _gatewayBox = 'gateways';
  static const String _secureBox = 'secure';

  // Boxes
  Box<dynamic>? _settings;
  Box<dynamic>? _cache;
  Box<dynamic>? _chatHistory;
  Box<dynamic>? _gateways;
  Box<dynamic>? _secure;

  // State
  bool _initialized = false;

  factory StorageService() {
    _instance ??= StorageService._internal();
    return _instance!;
  }

  StorageService._internal();

  // ==================== Initialization ====================

  /// Initialize Hive and open all boxes
  Future<void> initialize() async {
    if (_initialized) {
      _log('warn', 'Storage already initialized');
      return;
    }

    _log('info', 'Initializing storage...');

    try {
      // Get application documents directory for mobile
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final appDocDir = await getApplicationDocumentsDirectory();
        Hive.init(appDocDir.path);
      } else {
        // For desktop/web, use default initialization
        await Hive.initFlutter();
      }

      // Register adapters for custom types
      _registerAdapters();

      // Open all boxes
      _settings = await Hive.openBox(_settingsBox);
      _cache = await Hive.openBox(_cacheBox);
      _chatHistory = await Hive.openBox(_chatBox);
      _gateways = await Hive.openBox(_gatewayBox);
      _secure = await Hive.openBox(_secureBox);

      _initialized = true;
      _log('info', 'Storage initialized successfully');
    } catch (e) {
      _log('error', 'Failed to initialize storage', e);
      rethrow;
    }
  }

  void _registerAdapters() {
    // Register adapters for custom types if needed
    // Example: Hive.registerAdapter(CustomTypeAdapter());
  }

  /// Ensure storage is initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw StorageException('Storage not initialized. Call initialize() first.');
    }
  }

  // ==================== Settings ====================

  /// Get a setting value
  T? getSetting<T>(String key, {T? defaultValue}) {
    _ensureInitialized();
    try {
      final value = _settings!.get(key);
      return value as T? ?? defaultValue;
    } catch (e) {
      _log('error', 'Failed to get setting: $key', e);
      return defaultValue;
    }
  }

  /// Set a setting value
  Future<void> setSetting<T>(String key, T value) async {
    _ensureInitialized();
    try {
      await _settings!.put(key, value);
      _log('debug', 'Setting saved: $key');
    } catch (e) {
      _log('error', 'Failed to save setting: $key', e);
      rethrow;
    }
  }

  /// Remove a setting
  Future<void> removeSetting(String key) async {
    _ensureInitialized();
    await _settings!.delete(key);
    _log('debug', 'Setting removed: $key');
  }

  /// Clear all settings
  Future<void> clearSettings() async {
    _ensureInitialized();
    await _settings!.clear();
    _log('info', 'All settings cleared');
  }

  /// Get all settings
  Map<String, dynamic> getAllSettings() {
    _ensureInitialized();
    return Map<String, dynamic>.from(_settings!.toMap());
  }

  // ==================== Cache ====================

  /// Get cached data
  T? getCache<T>(String key) {
    _ensureInitialized();
    final cached = _cache!.get(key);
    if (cached == null) return null;

    try {
      final entry = CachedEntry.fromJson(
        Map<String, dynamic>.from(cached as Map),
      );
      
      // Check if expired
      if (entry.isExpired) {
        _log('debug', 'Cache expired: $key');
        return null;
      }

      return entry.data as T?;
    } catch (e) {
      _log('error', 'Failed to get cache: $key', e);
      return null;
    }
  }

  /// Set cached data with optional expiry
  Future<void> setCache<T>(
    String key,
    T data, {
    Duration? expiry,
  }) async {
    _ensureInitialized();
    try {
      final entry = CachedEntry(
        data: data,
        createdAt: DateTime.now(),
        expiresAt: expiry != null ? DateTime.now().add(expiry) : null,
      );
      await _cache!.put(key, entry.toJson());
      _log('debug', 'Cache saved: $key');
    } catch (e) {
      _log('error', 'Failed to save cache: $key', e);
      rethrow;
    }
  }

  /// Remove cached data
  Future<void> removeCache(String key) async {
    _ensureInitialized();
    await _cache!.delete(key);
    _log('debug', 'Cache removed: $key');
  }

  /// Clear all cache
  Future<void> clearCache() async {
    _ensureInitialized();
    await _cache!.clear();
    _log('info', 'All cache cleared');
  }

  /// Clear expired cache entries
  Future<void> clearExpiredCache() async {
    _ensureInitialized();
    final keysToDelete = <dynamic>[];

    for (final key in _cache!.keys) {
      final cached = _cache!.get(key);
      if (cached != null) {
        try {
          final entry = CachedEntry.fromJson(
            Map<String, dynamic>.from(cached as Map),
          );
          if (entry.isExpired) {
            keysToDelete.add(key);
          }
        } catch (_) {
          // Invalid entry, mark for deletion
          keysToDelete.add(key);
        }
      }
    }

    for (final key in keysToDelete) {
      await _cache!.delete(key);
    }

    _log('info', 'Cleared ${keysToDelete.length} expired cache entries');
  }

  // ==================== Chat History ====================

  /// Save a chat message
  Future<void> saveChatMessage(chat_models.ChatMessage message) async {
    _ensureInitialized();
    try {
      await _chatHistory!.put(message.id, message.toJson());
      _log('debug', 'Chat message saved: ${message.id}');
    } catch (e) {
      _log('error', 'Failed to save chat message', e);
      rethrow;
    }
  }

  /// Get chat messages for a session
  List<chat_models.ChatMessage> getChatMessages({String? sessionId, int? limit}) {
    _ensureInitialized();
    try {
      final messages = <chat_models.ChatMessage>[];

      for (final key in _chatHistory!.keys) {
        final data = _chatHistory!.get(key);
        if (data != null) {
          final message = chat_models.ChatMessage.fromJson(
            Map<String, dynamic>.from(data as Map),
          );
          
          // Filter by session if provided
          if (sessionId != null && message.sessionId != sessionId) {
            continue;
          }
          
          messages.add(message);
        }
      }

      // Sort by timestamp (newest last)
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Apply limit if provided
      if (limit != null && messages.length > limit) {
        return messages.skip(messages.length - limit).toList();
      }

      return messages;
    } catch (e) {
      _log('error', 'Failed to get chat messages', e);
      return [];
    }
  }

  /// Delete a chat message
  Future<void> deleteChatMessage(String id) async {
    _ensureInitialized();
    await _chatHistory!.delete(id);
    _log('debug', 'Chat message deleted: $id');
  }

  /// Clear chat history
  Future<void> clearChatHistory({String? sessionId}) async {
    _ensureInitialized();
    
    if (sessionId == null) {
      await _chatHistory!.clear();
      _log('info', 'All chat history cleared');
    } else {
      // Delete only messages for specific session
      final keysToDelete = <dynamic>[];
      
      for (final key in _chatHistory!.keys) {
        final data = _chatHistory!.get(key);
        if (data != null) {
          final message = ChatMessage.fromJson(
            Map<String, dynamic>.from(data as Map),
          );
          if (message.sessionId == sessionId) {
            keysToDelete.add(key);
          }
        }
      }
      
      for (final key in keysToDelete) {
        await _chatHistory!.delete(key);
      }
      
      _log('info', 'Chat history cleared for session: $sessionId');
    }
  }

  // ==================== Gateways ====================

  /// Save a gateway configuration
  Future<void> saveGateway(GatewayConfig gateway) async {
    _ensureInitialized();
    await _gateways!.put(gateway.id, gateway.toJson());
    _log('debug', 'Gateway saved: ${gateway.id}');
  }

  /// Get all saved gateways
  List<GatewayConfig> getGateways() {
    _ensureInitialized();
    try {
      final gateways = <GatewayConfig>[];
      
      for (final key in _gateways!.keys) {
        final data = _gateways!.get(key);
        if (data != null) {
          gateways.add(
            GatewayConfig.fromJson(Map<String, dynamic>.from(data as Map)),
          );
        }
      }
      
      return gateways;
    } catch (e) {
      _log('error', 'Failed to get gateways', e);
      return [];
    }
  }

  /// Get a specific gateway
  GatewayConfig? getGateway(String id) {
    _ensureInitialized();
    final data = _gateways!.get(id);
    if (data == null) return null;
    
    try {
      return GatewayConfig.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      _log('error', 'Failed to get gateway: $id', e);
      return null;
    }
  }

  /// Delete a gateway
  Future<void> deleteGateway(String id) async {
    _ensureInitialized();
    await _gateways!.delete(id);
    _log('debug', 'Gateway deleted: $id');
  }

  /// Mark gateway as default
  Future<void> setDefaultGateway(String id) async {
    _ensureInitialized();
    
    // Clear previous default
    for (final gateway in getGateways()) {
      if (gateway.isDefault && gateway.id != id) {
        await saveGateway(gateway.copyWith(isDefault: false));
      }
    }
    
    // Set new default
    final gateway = getGateway(id);
    if (gateway != null) {
      await saveGateway(gateway.copyWith(isDefault: true));
      _log('info', 'Default gateway set: $id');
    }
  }

  // ==================== Conversations ====================

  /// Save a conversation
  Future<void> saveConversation(Conversation conv) async {
    _ensureInitialized();
    final box = await Hive.openBox('conversations');
    await box.put(conv.id, conv.toJson());
    _log('debug', 'Conversation saved: ${conv.id}');
  }

  /// Get all conversations
  List<Conversation> getConversations() {
    _ensureInitialized();
    try {
      // Note: Would need to open conversations box - simplified for now
      return [];
    } catch (e) {
      _log('error', 'Failed to get conversations', e);
      return [];
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(String id) async {
    _ensureInitialized();
    try {
      final box = await Hive.openBox('conversations');
      await box.delete(id);
      // Also delete messages for this conversation
      final msgBox = await Hive.openBox('messages');
      final keysToDelete = <dynamic>[];
      for (final key in msgBox.keys) {
        if (key.toString().startsWith('${id}_')) {
          keysToDelete.add(key);
        }
      }
      for (final key in keysToDelete) {
        await msgBox.delete(key);
      }
      _log('debug', 'Conversation deleted: $id');
    } catch (e) {
      _log('error', 'Failed to delete conversation', e);
    }
  }

  // ==================== Messages ====================

  /// Save a message to a conversation
  Future<void> saveMessage(String convId, ChatMessage msg) async {
    _ensureInitialized();
    try {
      final box = await Hive.openBox('messages');
      await box.put('${convId}_${msg.id}', msg.toJson());
      _log('debug', 'Message saved: ${msg.id}');
    } catch (e) {
      _log('error', 'Failed to save message', e);
    }
  }

  /// Get all messages for a conversation
  List<ChatMessage> getMessages(String convId) {
    _ensureInitialized();
    try {
      final box = Hive.box<dynamic>('messages');
      final messages = <ChatMessage>[];
      for (final key in box.keys) {
        if (key.toString().startsWith('${convId}_')) {
          final data = box.get(key);
          if (data != null) {
            messages.add(ChatMessage.fromJson(Map<String, dynamic>.from(data as Map)));
          }
        }
      }
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return messages;
    } catch (e) {
      _log('error', 'Failed to get messages', e);
      return [];
    }
  }

  // ==================== Settings ====================

  /// Save settings state
  Future<void> saveSettings(AppSettings state) async {
    _ensureInitialized();
    await setSetting('app_settings', state.toJson());
    _log('debug', 'Settings saved');
  }

  /// Get settings state
  AppSettings? getSettings() {
    _ensureInitialized();
    try {
      final data = getSetting<Map>('app_settings');
      if (data != null) {
        return AppSettings.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      _log('error', 'Failed to get settings', e);
      return null;
    }
  }

  // ==================== Favorite Actions ====================

  /// Toggle favorite status for an action
  Future<void> toggleFavoriteAction(String actionId, bool isFavorite) async {
    _ensureInitialized();
    try {
      final favorites = getSetting<Map>('favorite_actions') ?? {};
      if (isFavorite) {
        favorites[actionId] = true;
      } else {
        favorites.remove(actionId);
      }
      await setSetting('favorite_actions', favorites);
      _log('debug', 'Favorite toggled: $actionId = $isFavorite');
    } catch (e) {
      _log('error', 'Failed to toggle favorite', e);
    }
  }

  /// Get all favorite action IDs
  Set<String> getFavoriteActions() {
    _ensureInitialized();
    try {
      final favorites = getSetting<Map>('favorite_actions');
      if (favorites != null) {
        return favorites.keys.cast<String>().toSet();
      }
      return {};
    } catch (e) {
      _log('error', 'Failed to get favorites', e);
      return {};
    }
  }

  // ==================== Secure Storage ====================

  /// Store a secure value (tokens, keys, etc.)
  Future<void> setSecureValue(String key, String value) async {
    _ensureInitialized();
    // In production, consider using flutter_secure_storage
    // For now, we use Hive but mark as secure
    final encrypted = _obfuscate(value);
    await _secure!.put(key, encrypted);
    _log('debug', 'Secure value saved: $key');
  }

  /// Get a secure value
  String? getSecureValue(String key) {
    _ensureInitialized();
    final encrypted = _secure!.get(key) as String?;
    if (encrypted == null) return null;
    return _deobfuscate(encrypted);
  }

  /// Delete a secure value
  Future<void> deleteSecureValue(String key) async {
    _ensureInitialized();
    await _secure!.delete(key);
    _log('debug', 'Secure value deleted: $key');
  }

  /// Clear all secure values
  Future<void> clearSecureStorage() async {
    _ensureInitialized();
    await _secure!.clear();
    _log('info', 'All secure values cleared');
  }

  // Simple obfuscation (replace with proper encryption in production)
  String _obfuscate(String value) {
    final bytes = utf8.encode(value);
    final encoded = base64.encode(bytes);
    return encoded.split('').reversed.join();
  }

  String _deobfuscate(String value) {
    final reversed = value.split('').reversed.join();
    final bytes = base64.decode(reversed);
    return utf8.decode(bytes);
  }

  // ==================== Maintenance ====================

  /// Get storage statistics
  StorageStats getStats() {
    _ensureInitialized();
    return StorageStats(
      settingsCount: _settings!.length,
      cacheCount: _cache!.length,
      chatMessagesCount: _chatHistory!.length,
      gatewaysCount: _gateways!.length,
      secureValuesCount: _secure!.length,
    );
  }

  /// Compact storage (reduce file size)
  Future<void> compact() async {
    _ensureInitialized();
    await _settings!.compact();
    await _cache!.compact();
    await _chatHistory!.compact();
    await _gateways!.compact();
    await _secure!.compact();
    _log('info', 'Storage compacted');
  }

  /// Clear all data
  Future<void> clearAll() async {
    _ensureInitialized();
    await clearSettings();
    await clearCache();
    await clearChatHistory();
    await _gateways!.clear();
    await clearSecureStorage();
    _log('info', 'All storage cleared');
  }

  /// Close all boxes
  Future<void> close() async {
    await _settings?.close();
    await _cache?.close();
    await _chatHistory?.close();
    await _gateways?.close();
    await _secure?.close();
    _initialized = false;
    _log('info', 'Storage closed');
  }

  void _log(String level, String message, [dynamic data]) {
    if (onLog != null) {
      onLog!(level, message, data);
    } else if (kDebugMode) {
      debugPrint('[StorageService][$level] $message ${data ?? ''}');
    }
  }

  /// Dispose and clear instance
  void dispose() {
    close();
    _instance = null;
  }
}

// ==================== Models ====================

/// Cached entry with expiry support
class CachedEntry {
  final dynamic data;
  final DateTime createdAt;
  final DateTime? expiresAt;

  CachedEntry({
    required this.data,
    required this.createdAt,
    this.expiresAt,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory CachedEntry.fromJson(Map<String, dynamic> json) {
    return CachedEntry(
      data: json['data'],
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }
}

/// Chat message model
class ChatMessage {
  final String id;
  final String content;
  final bool isFromUser;
  final DateTime timestamp;
  final String? sessionId;
  final String? agentId;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isFromUser,
    required this.timestamp,
    this.sessionId,
    this.agentId,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isFromUser': isFromUser,
      'timestamp': timestamp.toIso8601String(),
      'sessionId': sessionId,
      'agentId': agentId,
      'metadata': metadata,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      isFromUser: json['isFromUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      sessionId: json['sessionId'] as String?,
      agentId: json['agentId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Gateway configuration
class GatewayConfig {
  final String id;
  final String name;
  final String baseUrl;
  final String? wsUrl;
  final bool isDefault;
  final bool autoConnect;
  final DateTime addedAt;
  final DateTime? lastConnectedAt;
  final Map<String, dynamic>? metadata;

  GatewayConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.wsUrl,
    this.isDefault = false,
    this.autoConnect = true,
    required this.addedAt,
    this.lastConnectedAt,
    this.metadata,
  });

  GatewayConfig copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? wsUrl,
    bool? isDefault,
    bool? autoConnect,
    DateTime? addedAt,
    DateTime? lastConnectedAt,
    Map<String, dynamic>? metadata,
  }) {
    return GatewayConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      wsUrl: wsUrl ?? this.wsUrl,
      isDefault: isDefault ?? this.isDefault,
      autoConnect: autoConnect ?? this.autoConnect,
      addedAt: addedAt ?? this.addedAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'wsUrl': wsUrl,
      'isDefault': isDefault,
      'autoConnect': autoConnect,
      'addedAt': addedAt.toIso8601String(),
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory GatewayConfig.fromJson(Map<String, dynamic> json) {
    return GatewayConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      wsUrl: json['wsUrl'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      autoConnect: json['autoConnect'] as bool? ?? true,
      addedAt: DateTime.parse(json['addedAt'] as String),
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.parse(json['lastConnectedAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Storage statistics
class StorageStats {
  final int settingsCount;
  final int cacheCount;
  final int chatMessagesCount;
  final int gatewaysCount;
  final int secureValuesCount;

  StorageStats({
    required this.settingsCount,
    required this.cacheCount,
    required this.chatMessagesCount,
    required this.gatewaysCount,
    required this.secureValuesCount,
  });

  int get totalItems =>
      settingsCount +
      cacheCount +
      chatMessagesCount +
      gatewaysCount +
      secureValuesCount;

  @override
  String toString() {
    return 'StorageStats(total: $totalItems, settings: $settingsCount, cache: $cacheCount, chat: $chatMessagesCount, gateways: $gatewaysCount, secure: $secureValuesCount)';
  }
}

/// Storage exception
class StorageException implements Exception {
  final String message;

  StorageException(this.message);

  @override
  String toString() => 'StorageException: $message';
}