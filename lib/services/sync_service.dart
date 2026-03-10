import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Sync status enum
enum SyncState {
  idle,
  syncing,
  success,
  error,
  conflict,
}

/// Sync direction
enum SyncDirection {
  upload,
  download,
  bidirectional,
}

/// Sync item status
class SyncItemStatus {
  final String key;
  final DateTime? localModified;
  final DateTime? remoteModified;
  final bool hasConflict;
  final String? conflictResolution;

  SyncItemStatus({
    required this.key,
    this.localModified,
    this.remoteModified,
    this.hasConflict = false,
    this.conflictResolution,
  });
}

/// Sync result
class SyncResult {
  final bool success;
  final int itemsUploaded;
  final int itemsDownloaded;
  final int conflictsFound;
  final int conflictsResolved;
  final String? error;
  final Duration duration;

  SyncResult({
    required this.success,
    this.itemsUploaded = 0,
    this.itemsDownloaded = 0,
    this.conflictsFound = 0,
    this.conflictsResolved = 0,
    this.error,
    this.duration = Duration.zero,
  });
}

/// Sync configuration
class SyncConfig {
  final bool enabled;
  final bool autoSync;
  final Duration syncInterval;
  final SyncDirection direction;
  final bool syncConversations;
  final bool syncSettings;
  final bool syncProfiles;
  final bool syncOnWifiOnly;
  final bool syncOnChargeOnly;

  const SyncConfig({
    this.enabled = false,
    this.autoSync = false,
    this.syncInterval = const Duration(minutes: 30),
    this.direction = SyncDirection.bidirectional,
    this.syncConversations = true,
    this.syncSettings = true,
    this.syncProfiles = true,
    this.syncOnWifiOnly = false,
    this.syncOnChargeOnly = false,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'autoSync': autoSync,
    'syncInterval': syncInterval.inMinutes,
    'direction': direction.name,
    'syncConversations': syncConversations,
    'syncSettings': syncSettings,
    'syncProfiles': syncProfiles,
    'syncOnWifiOnly': syncOnWifiOnly,
    'syncOnChargeOnly': syncOnChargeOnly,
  };

  factory SyncConfig.fromJson(Map<String, dynamic> json) {
    return SyncConfig(
      enabled: json['enabled'] ?? false,
      autoSync: json['autoSync'] ?? false,
      syncInterval: Duration(minutes: json['syncInterval'] ?? 30),
      direction: SyncDirection.values.firstWhere(
        (e) => e.name == json['direction'],
        orElse: () => SyncDirection.bidirectional,
      ),
      syncConversations: json['syncConversations'] ?? true,
      syncSettings: json['syncSettings'] ?? true,
      syncProfiles: json['syncProfiles'] ?? true,
      syncOnWifiOnly: json['syncOnWifiOnly'] ?? false,
      syncOnChargeOnly: json['syncOnChargeOnly'] ?? false,
    );
  }

  SyncConfig copyWith({
    bool? enabled,
    bool? autoSync,
    Duration? syncInterval,
    SyncDirection? direction,
    bool? syncConversations,
    bool? syncSettings,
    bool? syncProfiles,
    bool? syncOnWifiOnly,
    bool? syncOnChargeOnly,
  }) {
    return SyncConfig(
      enabled: enabled ?? this.enabled,
      autoSync: autoSync ?? this.autoSync,
      syncInterval: syncInterval ?? this.syncInterval,
      direction: direction ?? this.direction,
      syncConversations: syncConversations ?? this.syncConversations,
      syncSettings: syncSettings ?? this.syncSettings,
      syncProfiles: syncProfiles ?? this.syncProfiles,
      syncOnWifiOnly: syncOnWifiOnly ?? this.syncOnWifiOnly,
      syncOnChargeOnly: syncOnChargeOnly ?? this.syncOnChargeOnly,
    );
  }
}

/// Sync service for synchronizing data across devices
class SyncService extends ChangeNotifier {
  static const String _configKey = 'sync_config';
  static const String _lastSyncKey = 'last_sync_time';
  static const String _syncDataKey = 'sync_data';

  SyncConfig _config = const SyncConfig();
  SyncState _state = SyncState.idle;
  DateTime? _lastSyncTime;
  String? _lastError;
  double _progress = 0.0;
  Timer? _autoSyncTimer;
  String? _gatewayUrl;
  String? _gatewayToken;

  // Stream controllers
  final _stateController = StreamController<SyncState>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  Stream<SyncState> get stateStream => _stateController.stream;
  Stream<double> get progressStream => _progressController.stream;

  SyncConfig get config => _config;
  SyncState get state => _state;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;
  double get progress => _progress;
  bool get isSyncing => _state == SyncState.syncing;

  /// Initialize sync service
  Future<void> initialize() async {
    await _loadConfig();
    await _loadLastSyncTime();
    
    if (_config.autoSync) {
      startAutoSync();
    }
  }

  /// Set gateway connection info
  void setGatewayConnection(String url, String? token) {
    _gatewayUrl = url;
    _gatewayToken = token;
  }

  /// Update sync configuration
  Future<void> updateConfig(SyncConfig newConfig) async {
    _config = newConfig;
    await _saveConfig();
    
    if (_config.autoSync) {
      startAutoSync();
    } else {
      stopAutoSync();
    }
    
    notifyListeners();
  }

  /// Start auto-sync timer
  void startAutoSync() {
    stopAutoSync();
    _autoSyncTimer = Timer.periodic(_config.syncInterval, (_) {
      sync();
    });
  }

  /// Stop auto-sync timer
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Perform sync
  Future<SyncResult> sync() async {
    if (_state == SyncState.syncing) {
      return SyncResult(success: false, error: 'Sync already in progress');
    }

    if (!_config.enabled) {
      return SyncResult(success: false, error: 'Sync is disabled');
    }

    if (_gatewayUrl == null) {
      return SyncResult(success: false, error: 'No gateway configured');
    }

    final startTime = DateTime.now();
    _state = SyncState.syncing;
    _progress = 0.0;
    _lastError = null;
    _stateController.add(_state);
    notifyListeners();

    try {
      int uploaded = 0;
      int downloaded = 0;
      int conflicts = 0;
      int resolved = 0;

      // Get local data
      final localData = await _getLocalData();
      _progress = 0.2;
      _progressController.add(_progress);
      notifyListeners();

      // Get remote data
      final remoteData = await _getRemoteData();
      _progress = 0.4;
      _progressController.add(_progress);
      notifyListeners();

      // Compare and merge
      if (_config.direction == SyncDirection.bidirectional ||
          _config.direction == SyncDirection.upload) {
        // Upload changes
        final uploadResult = await _uploadChanges(localData, remoteData);
        uploaded = uploadResult.uploaded;
        conflicts += uploadResult.conflicts;
      }

      _progress = 0.6;
      _progressController.add(_progress);
      notifyListeners();

      if (_config.direction == SyncDirection.bidirectional ||
          _config.direction == SyncDirection.download) {
        // Download changes
        final downloadResult = await _downloadChanges(localData, remoteData);
        downloaded = downloadResult.downloaded;
        conflicts += downloadResult.conflicts;
        resolved = downloadResult.resolved;
      }

      _progress = 0.9;
      _progressController.add(_progress);
      notifyListeners();

      // Update last sync time
      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime();

      _progress = 1.0;
      _state = conflicts > 0 ? SyncState.conflict : SyncState.success;
      _stateController.add(_state);
      _progressController.add(_progress);
      notifyListeners();

      final duration = DateTime.now().difference(startTime);
      return SyncResult(
        success: true,
        itemsUploaded: uploaded,
        itemsDownloaded: downloaded,
        conflictsFound: conflicts,
        conflictsResolved: resolved,
        duration: duration,
      );
    } catch (e) {
      _lastError = e.toString();
      _state = SyncState.error;
      _stateController.add(_state);
      notifyListeners();
      return SyncResult(success: false, error: e.toString());
    }
  }

  /// Force upload all data
  Future<SyncResult> forceUpload() async {
    if (_state == SyncState.syncing) {
      return SyncResult(success: false, error: 'Sync already in progress');
    }

    _state = SyncState.syncing;
    _progress = 0.0;
    notifyListeners();

    try {
      final localData = await _getLocalData();
      _progress = 0.3;
      notifyListeners();

      await _uploadAll(localData);
      _progress = 1.0;
      _state = SyncState.success;
      
      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime();
      
      notifyListeners();
      return SyncResult(success: true, itemsUploaded: localData.length);
    } catch (e) {
      _lastError = e.toString();
      _state = SyncState.error;
      notifyListeners();
      return SyncResult(success: false, error: e.toString());
    }
  }

  /// Force download all data
  Future<SyncResult> forceDownload() async {
    if (_state == SyncState.syncing) {
      return SyncResult(success: false, error: 'Sync already in progress');
    }

    _state = SyncState.syncing;
    _progress = 0.0;
    notifyListeners();

    try {
      final remoteData = await _getRemoteData();
      _progress = 0.3;
      notifyListeners();

      await _downloadAll(remoteData);
      _progress = 1.0;
      _state = SyncState.success;
      
      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime();
      
      notifyListeners();
      return SyncResult(success: true, itemsDownloaded: remoteData.length);
    } catch (e) {
      _lastError = e.toString();
      _state = SyncState.error;
      notifyListeners();
      return SyncResult(success: false, error: e.toString());
    }
  }

  /// Get sync status for specific items
  Future<List<SyncItemStatus>> getSyncStatus() async {
    final localData = await _getLocalData();
    final remoteData = await _getRemoteData();
    
    final statuses = <SyncItemStatus>[];
    final allKeys = {...localData.keys, ...remoteData.keys};

    for (final key in allKeys) {
      final local = localData[key];
      final remote = remoteData[key];
      
      DateTime? localModified;
      DateTime? remoteModified;
      bool hasConflict = false;

      if (local != null && local is Map) {
        localModified = local['modifiedAt'] != null
            ? DateTime.tryParse(local['modifiedAt'])
            : null;
      }
      
      if (remote != null && remote is Map) {
        remoteModified = remote['modifiedAt'] != null
            ? DateTime.tryParse(remote['modifiedAt'])
            : null;
      }

      // Check for conflict (both modified since last sync)
      if (_lastSyncTime != null) {
        hasConflict = (localModified != null && localModified.isAfter(_lastSyncTime!)) &&
                      (remoteModified != null && remoteModified.isAfter(_lastSyncTime!));
      }

      statuses.add(SyncItemStatus(
        key: key,
        localModified: localModified,
        remoteModified: remoteModified,
        hasConflict: hasConflict,
      ));
    }

    return statuses;
  }

  /// Resolve conflict for specific item
  Future<bool> resolveConflict(String key, {bool keepLocal = true}) async {
    try {
      if (keepLocal) {
        // Upload local version
        final prefs = await SharedPreferences.getInstance();
        final localData = _getLocalItem(prefs, key);
        if (localData != null) {
          await _uploadItem(key, localData);
        }
      } else {
        // Download remote version
        final remoteData = await _downloadItem(key);
        if (remoteData != null) {
          final prefs = await SharedPreferences.getInstance();
          await _setLocalItem(prefs, key, remoteData);
        }
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  /// Clear sync data
  Future<void> clearSyncData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncDataKey);
    _lastSyncTime = null;
    await prefs.remove(_lastSyncKey);
    notifyListeners();
  }

  // Private methods
  Future<Map<String, dynamic>> _getLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};

    if (_config.syncConversations) {
      final conversations = prefs.getString('conversations');
      if (conversations != null) {
        data['conversations'] = jsonDecode(conversations);
      }
    }

    if (_config.syncSettings) {
      final settingsKeys = [
        'app_mode', 'theme', 'notifications_enabled', 'haptic_feedback',
        'auto_refresh_interval', 'debug_logging', 'default_agent_id',
      ];
      final settings = <String, dynamic>{};
      for (final key in settingsKeys) {
        final value = prefs.get(key);
        if (value != null) {
          settings[key] = value;
        }
      }
      if (settings.isNotEmpty) {
        data['settings'] = settings;
      }
    }

    if (_config.syncProfiles) {
      final gateways = prefs.getString('saved_gateways');
      if (gateways != null) {
        data['profiles'] = jsonDecode(gateways);
      }
    }

    data['modifiedAt'] = DateTime.now().toIso8601String();
    return data;
  }

  Future<Map<String, dynamic>> _getRemoteData() async {
    if (_gatewayUrl == null) return {};

    try {
      final response = await http.get(
        Uri.parse('$_gatewayUrl/api/sync/data'),
        headers: {
          if (_gatewayToken != null) 'Authorization': 'Bearer $_gatewayToken',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      debugPrint('Error getting remote data: $e');
      return {};
    }
  }

  Future<({int uploaded, int conflicts})> _uploadChanges(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) async {
    int uploaded = 0;
    int conflicts = 0;

    for (final entry in local.entries) {
      if (entry.key == 'modifiedAt') continue;
      
      final localValue = entry.value;
      final remoteValue = remote[entry.key];
      
      // Check if needs upload (local newer or not on remote)
      bool needsUpload = false;
      
      if (remoteValue == null) {
        needsUpload = true;
      } else if (localValue is Map && remoteValue is Map) {
        final localTime = localValue['modifiedAt'];
        final remoteTime = remoteValue['modifiedAt'];
        
        if (localTime != null && remoteTime != null) {
          final localDate = DateTime.tryParse(localTime);
          final remoteDate = DateTime.tryParse(remoteTime);
          
          if (localDate != null && remoteDate != null) {
            if (localDate.isAfter(remoteDate)) {
              needsUpload = true;
            }
          }
        }
      }

      if (needsUpload) {
        await _uploadItem(entry.key, localValue);
        uploaded++;
      }
    }

    return (uploaded: uploaded, conflicts: conflicts);
  }

  Future<({int downloaded, int conflicts, int resolved})> _downloadChanges(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) async {
    int downloaded = 0;
    int conflicts = 0;
    int resolved = 0;

    final prefs = await SharedPreferences.getInstance();

    for (final entry in remote.entries) {
      if (entry.key == 'modifiedAt') continue;
      
      final remoteValue = entry.value;
      final localValue = local[entry.key];
      
      bool needsDownload = false;
      
      if (localValue == null) {
        needsDownload = true;
      } else if (remoteValue is Map && localValue is Map) {
        final remoteTime = remoteValue['modifiedAt'];
        final localTime = localValue['modifiedAt'];
        
        if (remoteTime != null && localTime != null) {
          final remoteDate = DateTime.tryParse(remoteTime);
          final localDate = DateTime.tryParse(localTime);
          
          if (remoteDate != null && localDate != null) {
            if (remoteDate.isAfter(localDate)) {
              needsDownload = true;
            } else if (remoteDate.isAtSameMomentAs(localDate) == false) {
              conflicts++;
              // Auto-resolve: keep newer (remote)
              needsDownload = true;
              resolved++;
            }
          }
        }
      }

      if (needsDownload) {
        await _setLocalItem(prefs, entry.key, remoteValue);
        downloaded++;
      }
    }

    return (downloaded: downloaded, conflicts: conflicts, resolved: resolved);
  }

  Future<void> _uploadAll(Map<String, dynamic> data) async {
    if (_gatewayUrl == null) return;

    await http.post(
      Uri.parse('$_gatewayUrl/api/sync/data'),
      headers: {
        'Content-Type': 'application/json',
        if (_gatewayToken != null) 'Authorization': 'Bearer $_gatewayToken',
      },
      body: jsonEncode(data),
    );
  }

  Future<void> _downloadAll(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    
    for (final entry in data.entries) {
      if (entry.key == 'modifiedAt') continue;
      await _setLocalItem(prefs, entry.key, entry.value);
    }
  }

  Future<void> _uploadItem(String key, dynamic value) async {
    if (_gatewayUrl == null) return;

    await http.put(
      Uri.parse('$_gatewayUrl/api/sync/item/$key'),
      headers: {
        'Content-Type': 'application/json',
        if (_gatewayToken != null) 'Authorization': 'Bearer $_gatewayToken',
      },
      body: jsonEncode({'key': key, 'value': value}),
    );
  }

  Future<dynamic> _downloadItem(String key) async {
    if (_gatewayUrl == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_gatewayUrl/api/sync/item/$key'),
        headers: {
          if (_gatewayToken != null) 'Authorization': 'Bearer $_gatewayToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['value'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  dynamic _getLocalItem(SharedPreferences prefs, String key) {
    return prefs.get(key);
  }

  Future<void> _setLocalItem(SharedPreferences prefs, String key, dynamic value) async {
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is List) {
      await prefs.setStringList(key, List<String>.from(value));
    } else {
      await prefs.setString(key, jsonEncode(value));
    }
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_configKey);
    
    if (json != null) {
      _config = SyncConfig.fromJson(jsonDecode(json));
    }
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(_config.toJson()));
  }

  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_lastSyncKey);
    
    if (timeStr != null) {
      _lastSyncTime = DateTime.tryParse(timeStr);
    }
  }

  Future<void> _saveLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    if (_lastSyncTime != null) {
      await prefs.setString(_lastSyncKey, _lastSyncTime!.toIso8601String());
    }
  }

  @override
  void dispose() {
    stopAutoSync();
    _stateController.close();
    _progressController.close();
    super.dispose();
  }
}