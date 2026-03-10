import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'nodejs_installer_service.dart';

/// Unified Installer Service
/// 
/// Provides a high-level interface for installing and managing OpenClaw
/// on Android devices. Handles both local installation and remote gateway
/// connection scenarios.
class InstallerService {
  static InstallerService? _instance;
  
  final NodejsInstallerService _nodejsService = NodejsInstallerService();
  
  // Installation state
  bool _isInitialized = false;
  InstallationMode? _currentMode;
  
  // Callbacks
  void Function(InstallProgress progress)? onProgress;
  void Function(String level, String message, [dynamic data])? onLog;

  factory InstallerService() {
    _instance ??= InstallerService._internal();
    return _instance!;
  }

  InstallerService._internal();

  // Getters
  bool get isInitialized => _isInitialized;
  InstallationMode? get currentMode => _currentMode;
  bool get isInstalling => _nodejsService.isInstalling;

  /// Initialize the installer service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _log('info', 'Initializing InstallerService...');
      
      // Setup Node.js installer callbacks
      _nodejsService.onProgress = (step, progress, message) {
        onProgress?.call(InstallProgress(
          step: step.name,
          message: message,
          progress: progress,
          isError: false,
          isComplete: progress >= 1.0,
        ));
      };

      _nodejsService.onLog = (level, message, [details]) {
        _log(level, message, details);
      };

      _nodejsService.onStateChange = (state) {
        _log('debug', 'Installation state changed: $state');
      };

      _isInitialized = true;
      _log('success', 'InstallerService initialized');
      return true;
    } catch (e, stackTrace) {
      _log('error', 'Failed to initialize InstallerService', '$e\n$stackTrace');
      return false;
    }
  }

  /// Install OpenClaw locally on the device
  /// 
  /// This installs Node.js (if needed) and OpenClaw CLI, then configures
  /// the environment for running the gateway locally.
  Future<InstallResult> installLocal() async {
    _log('info', 'Starting local OpenClaw installation...');
    _currentMode = InstallationMode.local;

    try {
      final success = await _nodejsService.installOpenClaw();
      
      if (success) {
        _log('success', 'Local installation completed successfully');
        return InstallResult.success(
          message: 'OpenClaw installed successfully!',
          gatewayUrl: 'http://127.0.0.1:18789',
        );
      } else {
        final error = _nodejsService.lastError ?? 'Installation failed';
        _log('error', 'Local installation failed', error);
        return InstallResult.failure(error);
      }
    } catch (e, stackTrace) {
      _log('error', 'Installation exception', '$e\n$stackTrace');
      return InstallResult.failure('Installation error: $e');
    }
  }

  /// Start the local gateway
  /// 
  /// Returns true if the gateway was started successfully
  Future<bool> startLocalGateway() async {
    _log('info', 'Starting local gateway...');
    
    try {
      final success = await _nodejsService.startGateway();
      
      if (success) {
        _log('success', 'Local gateway started on port 18789');
      } else {
        _log('error', 'Failed to start local gateway', _nodejsService.lastError);
      }
      
      return success;
    } catch (e) {
      _log('error', 'Gateway start exception', e.toString());
      return false;
    }
  }

  /// Stop the local gateway
  Future<bool> stopLocalGateway() async {
    _log('info', 'Stopping local gateway...');
    return await _nodejsService.stopGateway();
  }

  /// Check if OpenClaw is installed locally
  Future<bool> isInstalledLocally() async {
    return await NodejsInstallerService.isInstalled();
  }

  /// Check if local gateway is running
  Future<bool> isLocalGatewayRunning() async {
    try {
      // Quick health check
      final result = await _nodejsService.startGateway();
      return result;
    } catch (_) {
      return false;
    }
  }

  /// Get installation info
  Future<InstallInfo?> getInstallInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isInstalled = prefs.getBool('openclaw_installed') ?? false;
      
      if (!isInstalled) return null;
      
      return InstallInfo(
        isInstalled: true,
        installPath: prefs.getString('openclaw_install_path'),
        installTime: prefs.getInt('openclaw_install_time') != null
            ? DateTime.fromMillisecondsSinceEpoch(prefs.getInt('openclaw_install_time')!)
            : null,
        gatewayUrl: 'http://127.0.0.1:18789',
      );
    } catch (e) {
      _log('error', 'Failed to get install info', e.toString());
      return null;
    }
  }

  /// Uninstall OpenClaw (remove local installation)
  Future<bool> uninstall() async {
    _log('info', 'Uninstalling OpenClaw...');
    
    try {
      // Stop gateway if running
      await stopLocalGateway();
      
      // Clear preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('openclaw_installed');
      await prefs.remove('openclaw_install_path');
      await prefs.remove('openclaw_install_time');
      
      _log('success', 'OpenClaw uninstalled');
      return true;
    } catch (e) {
      _log('error', 'Uninstall failed', e.toString());
      return false;
    }
  }

  /// Get installation logs as formatted text
  String getFormattedLogs(List<InstallLogEntry> logs) {
    final buffer = StringBuffer();
    buffer.writeln('=== OpenClaw Installation Logs ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total entries: ${logs.length}');
    buffer.writeln('');
    
    for (final log in logs) {
      final time = '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';
      buffer.writeln('[$time] [${log.level.toUpperCase()}] ${log.message}');
      if (log.details != null) {
        buffer.writeln('  → ${log.details}');
      }
    }
    
    return buffer.toString();
  }

  /// Log helper
  void _log(String level, String message, [dynamic data]) {
    if (kDebugMode) {
      debugPrint('[InstallerService][$level] $message ${data ?? ''}');
    }
    onLog?.call(level, message, data);
  }

  /// Dispose resources
  void dispose() {
    _nodejsService.dispose();
    _instance = null;
  }
}

/// Installation mode
enum InstallationMode {
  local,      // Install OpenClaw locally on device
  remote,     // Connect to remote gateway
  hybrid,     // Local + remote capabilities
}

/// Installation progress
class InstallProgress {
  final String step;
  final String message;
  final double progress;
  final bool isError;
  final bool isComplete;

  InstallProgress({
    required this.step,
    required this.message,
    this.progress = 0.0,
    this.isError = false,
    this.isComplete = false,
  });
}

/// Installation result
class InstallResult {
  final bool success;
  final String message;
  final String? error;
  final String? gatewayUrl;
  final Map<String, dynamic>? metadata;

  InstallResult({
    required this.success,
    required this.message,
    this.error,
    this.gatewayUrl,
    this.metadata,
  });

  factory InstallResult.success({
    required String message,
    String? gatewayUrl,
    Map<String, dynamic>? metadata,
  }) {
    return InstallResult(
      success: true,
      message: message,
      gatewayUrl: gatewayUrl,
      metadata: metadata,
    );
  }

  factory InstallResult.failure(String error) {
    return InstallResult(
      success: false,
      message: 'Installation failed',
      error: error,
    );
  }
}

/// Installation info
class InstallInfo {
  final bool isInstalled;
  final String? installPath;
  final DateTime? installTime;
  final String? gatewayUrl;

  InstallInfo({
    required this.isInstalled,
    this.installPath,
    this.installTime,
    this.gatewayUrl,
  });

  Map<String, dynamic> toJson() => {
    'isInstalled': isInstalled,
    'installPath': installPath,
    'installTime': installTime?.toIso8601String(),
    'gatewayUrl': gatewayUrl,
  };

  factory InstallInfo.fromJson(Map<String, dynamic> json) {
    return InstallInfo(
      isInstalled: json['isInstalled'] ?? false,
      installPath: json['installPath'],
      installTime: json['installTime'] != null
          ? DateTime.parse(json['installTime'])
          : null,
      gatewayUrl: json['gatewayUrl'],
    );
  }
}

/// Installation log entry
class InstallLogEntry {
  final DateTime timestamp;
  final String level;
  final String message;
  final String? details;

  InstallLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.details,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level,
    'message': message,
    'details': details,
  };

  factory InstallLogEntry.fromJson(Map<String, dynamic> json) {
    return InstallLogEntry(
      timestamp: DateTime.parse(json['timestamp']),
      level: json['level'],
      message: json['message'],
      details: json['details'],
    );
  }
}

/// Installation exception
class InstallationException implements Exception {
  final String message;
  final String? step;
  final dynamic cause;

  InstallationException({
    required this.message,
    this.step,
    this.cause,
  });

  @override
  String toString() => 'InstallationException: $message (step: $step)';
}
