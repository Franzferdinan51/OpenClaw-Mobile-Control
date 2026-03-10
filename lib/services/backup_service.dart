import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Backup metadata model
class BackupMetadata {
  final String filename;
  final DateTime createdAt;
  final int sizeBytes;
  final String version;
  final Map<String, dynamic>? checksums;

  BackupMetadata({
    required this.filename,
    required this.createdAt,
    required this.sizeBytes,
    required this.version,
    this.checksums,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    return DateFormat('yyyy-MM-dd HH:mm').format(createdAt);
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return formattedDate;
  }

  Map<String, dynamic> toJson() => {
    'filename': filename,
    'createdAt': createdAt.toIso8601String(),
    'sizeBytes': sizeBytes,
    'version': version,
    'checksums': checksums,
  };

  factory BackupMetadata.fromJson(Map<String, dynamic> json) {
    return BackupMetadata(
      filename: json['filename'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      sizeBytes: json['sizeBytes'] ?? 0,
      version: json['version'] ?? '1.0',
      checksums: json['checksums'],
    );
  }
}

/// Backup service for creating and restoring app data backups
class BackupService extends ChangeNotifier {
  static const String _backupPrefix = 'backup_';
  static const String _backupExtension = '.json';
  static const String _metadataFile = 'backup_metadata.json';
  static const String _lastBackupKey = 'last_backup_date';
  static const String _autoBackupKey = 'auto_backup_enabled';
  static const String _backupVersion = '2.0';

  Directory? _backupDirectory;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  String? _lastError;

  bool get isBackingUp => _isBackingUp;
  bool get isRestoring => _isRestoring;
  String? get lastError => _lastError;

  /// Initialize the backup service
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _backupDirectory = Directory('${appDir.path}/backups');
    
    if (!await _backupDirectory!.exists()) {
      await _backupDirectory!.create(recursive: true);
    }
  }

  /// Create a backup of all app data
  Future<bool> backup() async {
    if (_isBackingUp) return false;
    
    _isBackingUp = true;
    _lastError = null;
    notifyListeners();

    try {
      await initialize();
      
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final filename = '$_backupPrefix$timestamp$_backupExtension';
      
      // Collect all data to backup
      final backupData = <String, dynamic>{
        'version': _backupVersion,
        'createdAt': DateTime.now().toIso8601String(),
        'appSettings': await _backupAppSettings(prefs),
        'connectionProfiles': await _backupConnectionProfiles(prefs),
        'preferences': await _backupPreferences(prefs),
      };

      // Write backup file
      final file = File('${_backupDirectory!.path}/$filename');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(backupData));

      // Update last backup timestamp
      await prefs.setString(_lastBackupKey, DateTime.now().toIso8601String());

      // Cleanup old backups (keep last 10)
      await _cleanupOldBackups();

      _isBackingUp = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isBackingUp = false;
      notifyListeners();
      return false;
    }
  }

  /// Restore from a backup file
  Future<bool> restore(String filename) async {
    if (_isRestoring) return false;
    
    _isRestoring = true;
    _lastError = null;
    notifyListeners();

    try {
      await initialize();
      
      final file = File('${_backupDirectory!.path}/$filename');
      if (!await file.exists()) {
        throw Exception('Backup file not found: $filename');
      }

      final content = await file.readAsString();
      final backupData = jsonDecode(content) as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();

      // Restore app settings
      if (backupData['appSettings'] != null) {
        await _restoreAppSettings(prefs, backupData['appSettings'] as Map<String, dynamic>);
      }

      // Restore connection profiles
      if (backupData['connectionProfiles'] != null) {
        await _restoreConnectionProfiles(prefs, backupData['connectionProfiles'] as Map<String, dynamic>);
      }

      // Restore preferences
      if (backupData['preferences'] != null) {
        await _restorePreferences(prefs, backupData['preferences'] as Map<String, dynamic>);
      }

      _isRestoring = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      _isRestoring = false;
      notifyListeners();
      return false;
    }
  }

  /// Get list of available backup files with metadata
  Future<List<BackupMetadata>> getBackupFiles() async {
    await initialize();
    
    final files = await _backupDirectory!
        .list()
        .where((entity) => 
            entity is File && 
            entity.path.endsWith(_backupExtension) &&
            entity.path.contains(_backupPrefix))
        .cast<File>()
        .toList();

    final backups = <BackupMetadata>[];

    for (final file in files) {
      try {
        final stat = await file.stat();
        final filename = file.path.split('/').last;
        
        // Try to read metadata from file
        String version = '1.0';
        try {
          final content = await file.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          version = data['version'] ?? '1.0';
        } catch (_) {}

        backups.add(BackupMetadata(
          filename: filename,
          createdAt: stat.modified,
          sizeBytes: stat.size,
          version: version,
        ));
      } catch (e) {
        // Skip files that can't be read
        continue;
      }
    }

    // Sort by creation date (newest first)
    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return backups;
  }

  /// Get the last backup date
  Future<DateTime?> getLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackupStr = prefs.getString(_lastBackupKey);
    
    if (lastBackupStr == null) {
      // Check backup files as fallback
      final backups = await getBackupFiles();
      if (backups.isNotEmpty) {
        return backups.first.createdAt;
      }
      return null;
    }
    
    return DateTime.tryParse(lastBackupStr);
  }

  /// Get the last backup metadata
  Future<BackupMetadata?> getLastBackup() async {
    final backups = await getBackupFiles();
    return backups.isNotEmpty ? backups.first : null;
  }

  /// Delete a backup file
  Future<bool> deleteBackup(String filename) async {
    try {
      await initialize();
      
      final file = File('${_backupDirectory!.path}/$filename');
      if (await file.exists()) {
        await file.delete();
        notifyListeners();
      }
      return true;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  /// Check if auto-backup is enabled
  Future<bool> isAutoBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoBackupKey) ?? false;
  }

  /// Set auto-backup enabled
  Future<void> setAutoBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupKey, enabled);
    notifyListeners();
  }

  /// Get backup directory size
  Future<int> getBackupDirectorySize() async {
    await initialize();
    
    int totalSize = 0;
    await for (final entity in _backupDirectory!.list()) {
      if (entity is File) {
        final stat = await entity.stat();
        totalSize += stat.size;
      }
    }
    return totalSize;
  }

  /// Get formatted backup directory size
  Future<String> getFormattedBackupSize() async {
    final size = await getBackupDirectorySize();
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Private helper methods

  Future<Map<String, dynamic>> _backupAppSettings(SharedPreferences prefs) async {
    return {
      'appMode': prefs.getString('app_mode') ?? 'basic',
      'theme': prefs.getString('theme') ?? 'system',
      'notificationsEnabled': prefs.getBool('notifications_enabled') ?? false,
      'hapticFeedback': prefs.getBool('haptic_feedback') ?? true,
      'autoRefreshInterval': prefs.getInt('auto_refresh_interval') ?? 30,
      'debugLogging': prefs.getBool('debug_logging') ?? false,
    };
  }

  Future<void> _restoreAppSettings(SharedPreferences prefs, Map<String, dynamic> data) async {
    if (data['appMode'] != null) await prefs.setString('app_mode', data['appMode']);
    if (data['theme'] != null) await prefs.setString('theme', data['theme']);
    if (data['notificationsEnabled'] != null) await prefs.setBool('notifications_enabled', data['notificationsEnabled']);
    if (data['hapticFeedback'] != null) await prefs.setBool('haptic_feedback', data['hapticFeedback']);
    if (data['autoRefreshInterval'] != null) await prefs.setInt('auto_refresh_interval', data['autoRefreshInterval']);
    if (data['debugLogging'] != null) await prefs.setBool('debug_logging', data['debugLogging']);
  }

  Future<Map<String, dynamic>> _backupConnectionProfiles(SharedPreferences prefs) async {
    return {
      'gatewayUrl': prefs.getString('gateway_url'),
      'gatewayToken': prefs.getString('gateway_token'),
      'gatewayName': prefs.getString('gateway_name'),
      'tailscaleGateways': prefs.getStringList('tailscale_gateways') ?? [],
      'connectionHistory': prefs.getStringList('connection_history') ?? [],
    };
  }

  Future<void> _restoreConnectionProfiles(SharedPreferences prefs, Map<String, dynamic> data) async {
    if (data['gatewayUrl'] != null) await prefs.setString('gateway_url', data['gatewayUrl']);
    if (data['gatewayToken'] != null) await prefs.setString('gateway_token', data['gatewayToken']);
    if (data['gatewayName'] != null) await prefs.setString('gateway_name', data['gatewayName']);
    if (data['tailscaleGateways'] != null) {
      await prefs.setStringList('tailscale_gateways', List<String>.from(data['tailscaleGateways']));
    }
    if (data['connectionHistory'] != null) {
      await prefs.setStringList('connection_history', List<String>.from(data['connectionHistory']));
    }
  }

  Future<Map<String, dynamic>> _backupPreferences(SharedPreferences prefs) async {
    // Get all keys that aren't already backed up
    final allKeys = prefs.getKeys();
    final settingsKeys = {
      'app_mode', 'theme', 'notifications_enabled', 'haptic_feedback',
      'auto_refresh_interval', 'debug_logging', _lastBackupKey, _autoBackupKey,
    };
    final connectionKeys = {
      'gateway_url', 'gateway_token', 'gateway_name', 'tailscale_gateways', 'connection_history',
    };
    
    final otherPrefs = <String, dynamic>{};
    for (final key in allKeys) {
      if (!settingsKeys.contains(key) && !connectionKeys.contains(key)) {
        final value = prefs.get(key);
        if (value != null) {
          otherPrefs[key] = value;
        }
      }
    }
    
    return otherPrefs;
  }

  Future<void> _restorePreferences(SharedPreferences prefs, Map<String, dynamic> data) async {
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is bool) {
        await prefs.setBool(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else if (value is double) {
        await prefs.setDouble(entry.key, value);
      } else if (value is List) {
        await prefs.setStringList(entry.key, List<String>.from(value));
      }
    }
  }

  Future<void> _cleanupOldBackups({int keep = 10}) async {
    final backups = await getBackupFiles();
    
    if (backups.length > keep) {
      for (int i = keep; i < backups.length; i++) {
        final file = File('${_backupDirectory!.path}/${backups[i].filename}');
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }
}