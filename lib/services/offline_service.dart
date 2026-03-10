import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Offline data model
class OfflineData {
  final String key;
  final dynamic data;
  final DateTime cachedAt;
  final String? etag;
  final int? maxAgeSeconds;

  OfflineData({
    required this.key,
    required this.data,
    required this.cachedAt,
    this.etag,
    this.maxAgeSeconds,
  });

  bool get isExpired {
    if (maxAgeSeconds == null) return false;
    return DateTime.now().difference(cachedAt).inSeconds > maxAgeSeconds!;
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'data': data,
    'cachedAt': cachedAt.toIso8601String(),
    'etag': etag,
    'maxAgeSeconds': maxAgeSeconds,
  };

  factory OfflineData.fromJson(Map<String, dynamic> json) {
    return OfflineData(
      key: json['key'] ?? '',
      data: json['data'],
      cachedAt: DateTime.parse(json['cachedAt']),
      etag: json['etag'],
      maxAgeSeconds: json['maxAgeSeconds'],
    );
  }
}

/// Queued action for sync when online
class QueuedAction {
  final String id;
  final String action;
  final Map<String, dynamic> params;
  final DateTime queuedAt;
  int retryCount;
  String? lastError;

  QueuedAction({
    required this.id,
    required this.action,
    required this.params,
    required this.queuedAt,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action,
    'params': params,
    'queuedAt': queuedAt.toIso8601String(),
    'retryCount': retryCount,
    'lastError': lastError,
  };

  factory QueuedAction.fromJson(Map<String, dynamic> json) {
    return QueuedAction(
      id: json['id'] ?? '',
      action: json['action'] ?? '',
      params: Map<String, dynamic>.from(json['params'] ?? {}),
      queuedAt: DateTime.parse(json['queuedAt']),
      retryCount: json['retryCount'] ?? 0,
      lastError: json['lastError'],
    );
  }
}

/// Offline service for caching data and queuing actions
class OfflineService extends ChangeNotifier {
  static const String _cacheKey = 'offline_cache';
  static const String _queueKey = 'offline_queue';
  static const String _offlineModeKey = 'offline_mode_enabled';
  
  Directory? _cacheDirectory;
  Map<String, OfflineData> _cache = {};
  List<QueuedAction> _actionQueue = [];
  bool _isOfflineMode = false;
  bool _isSyncing = false;
  String? _lastSyncError;
  
  // Stream controller for sync status
  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  bool get isOfflineMode => _isOfflineMode;
  bool get isSyncing => _isSyncing;
  String? get lastSyncError => _lastSyncError;
  int get queuedActionsCount => _actionQueue.length;
  int get cachedItemsCount => _cache.length;
  List<QueuedAction> get queuedActions => List.unmodifiable(_actionQueue);

  /// Initialize the offline service
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDirectory = Directory('${appDir.path}/offline_cache');
    
    if (!await _cacheDirectory!.exists()) {
      await _cacheDirectory!.create(recursive: true);
    }
    
    await _loadCache();
    await _loadQueue();
    await _loadOfflineMode();
  }

  /// Enable or disable offline mode
  Future<void> setOfflineMode(bool enabled) async {
    _isOfflineMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_offlineModeKey, enabled);
    notifyListeners();
  }

  /// Cache data for offline access
  Future<bool> cacheData(String key, dynamic data, {String? etag, int? maxAgeSeconds}) async {
    try {
      final offlineData = OfflineData(
        key: key,
        data: data,
        cachedAt: DateTime.now(),
        etag: etag,
        maxAgeSeconds: maxAgeSeconds,
      );
      
      _cache[key] = offlineData;
      await _saveCache();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error caching data: $e');
      return false;
    }
  }

  /// Get cached data
  OfflineData? getCachedData(String key) {
    final data = _cache[key];
    if (data == null) return null;
    if (data.isExpired) {
      _cache.remove(key);
      return null;
    }
    return data;
  }

  /// Remove cached data
  Future<bool> removeCachedData(String key) async {
    try {
      _cache.remove(key);
      await _saveCache();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear all cached data
  Future<bool> clearCache() async {
    try {
      _cache.clear();
      await _saveCache();
      
      // Clear cache directory
      if (_cacheDirectory != null && await _cacheDirectory!.exists()) {
        await for (final entity in _cacheDirectory!.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Queue an action for later execution
  Future<bool> queueAction(String action, Map<String, dynamic> params) async {
    try {
      final queuedAction = QueuedAction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        action: action,
        params: params,
        queuedAt: DateTime.now(),
      );
      
      _actionQueue.add(queuedAction);
      await _saveQueue();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove a queued action
  Future<bool> removeQueuedAction(String id) async {
    try {
      _actionQueue.removeWhere((action) => action.id == id);
      await _saveQueue();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Clear all queued actions
  Future<bool> clearQueue() async {
    try {
      _actionQueue.clear();
      await _saveQueue();
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sync queued actions with gateway
  Future<SyncResult> syncQueuedActions(Future<bool> Function(String action, Map<String, dynamic> params) executeAction) async {
    if (_isSyncing) {
      return SyncResult(success: false, message: 'Sync already in progress');
    }
    
    _isSyncing = true;
    _lastSyncError = null;
    _syncStatusController.add(SyncStatus.started);
    notifyListeners();
    
    int successCount = 0;
    int failureCount = 0;
    List<String> failedActions = [];
    
    for (final action in List.from(_actionQueue)) {
      try {
        final success = await executeAction(action.action, action.params);
        
        if (success) {
          _actionQueue.removeWhere((a) => a.id == action.id);
          successCount++;
        } else {
          action.retryCount++;
          action.lastError = 'Action execution failed';
          failureCount++;
          failedActions.add(action.action);
          
          // Remove if too many retries
          if (action.retryCount >= 3) {
            _actionQueue.removeWhere((a) => a.id == action.id);
          }
        }
      } catch (e) {
        action.retryCount++;
        action.lastError = e.toString();
        failureCount++;
        failedActions.add(action.action);
      }
    }
    
    await _saveQueue();
    
    _isSyncing = false;
    _lastSyncError = failureCount > 0 ? '${failureCount} actions failed' : null;
    _syncStatusController.add(SyncStatus.completed);
    notifyListeners();
    
    return SyncResult(
      success: failureCount == 0,
      message: 'Synced $successCount actions, $failureCount failed',
      successCount: successCount,
      failureCount: failureCount,
      failedActions: failedActions,
    );
  }

  /// Get cache size
  Future<int> getCacheSize() async {
    int totalSize = 0;
    
    if (_cacheDirectory != null && await _cacheDirectory!.exists()) {
      await for (final entity in _cacheDirectory!.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
    }
    
    return totalSize;
  }

  /// Get formatted cache size
  Future<String> getFormattedCacheSize() async {
    final size = await getCacheSize();
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get all cached items summary
  List<Map<String, dynamic>> getCachedItemsSummary() {
    return _cache.entries.map((entry) {
      return {
        'key': entry.key,
        'cachedAt': entry.value.cachedAt,
        'isExpired': entry.value.isExpired,
        'hasEtag': entry.value.etag != null,
      };
    }).toList();
  }

  // Private methods
  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_cacheKey);
      
      if (cacheJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(cacheJson);
        _cache = decoded.map((key, value) {
          return MapEntry(key, OfflineData.fromJson(value));
        });
      }
    } catch (e) {
      debugPrint('Error loading cache: $e');
      _cache = {};
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = jsonEncode(_cache.map((key, value) => MapEntry(key, value.toJson())));
      await prefs.setString(_cacheKey, cacheJson);
    } catch (e) {
      debugPrint('Error saving cache: $e');
    }
  }

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      
      if (queueJson != null) {
        final List<dynamic> decoded = jsonDecode(queueJson);
        _actionQueue = decoded.map((e) => QueuedAction.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error loading queue: $e');
      _actionQueue = [];
    }
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_actionQueue.map((e) => e.toJson()).toList());
      await prefs.setString(_queueKey, queueJson);
    } catch (e) {
      debugPrint('Error saving queue: $e');
    }
  }

  Future<void> _loadOfflineMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isOfflineMode = prefs.getBool(_offlineModeKey) ?? false;
    } catch (e) {
      _isOfflineMode = false;
    }
  }

  @override
  void dispose() {
    _syncStatusController.close();
    super.dispose();
  }
}

/// Sync status enum
enum SyncStatus {
  started,
  completed,
  failed,
}

/// Sync result model
class SyncResult {
  final bool success;
  final String message;
  final int successCount;
  final int failureCount;
  final List<String> failedActions;

  SyncResult({
    required this.success,
    required this.message,
    this.successCount = 0,
    this.failureCount = 0,
    this.failedActions = const [],
  });
}