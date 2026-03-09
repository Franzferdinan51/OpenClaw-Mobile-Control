/// OpenClaw Installer Service - Auto-discovery, installation, and configuration
/// 
/// Provides network discovery, installation management, gateway configuration,
/// node setup, and skill installation for OpenClaw deployments.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'termux_service.dart';

/// Discovered OpenClaw instance
class DiscoveredInstance {
  final String name;
  final String host;
  final int port;
  final String? version;
  final String? platform;
  final bool isOnline;
  final DateTime discoveredAt;

  const DiscoveredInstance({
    required this.name,
    required this.host,
    required this.port,
    this.version,
    this.platform,
    this.isOnline = true,
    required this.discoveredAt,
  });

  String get address => '$host:$port';
  String get httpUrl => 'http://$address';

  factory DiscoveredInstance.fromJson(Map<String, dynamic> json) {
    return DiscoveredInstance(
      name: json['name'] ?? 'Unknown',
      host: json['host'] ?? '',
      port: json['port'] ?? 18789,
      version: json['version'],
      platform: json['platform'],
      isOnline: json['isOnline'] ?? true,
      discoveredAt: DateTime.parse(json['discoveredAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'host': host,
    'port': port,
    'version': version,
    'platform': platform,
    'isOnline': isOnline,
    'discoveredAt': discoveredAt.toIso8601String(),
  };

  @override
  String toString() => 'DiscoveredInstance($name at $address)';
}

/// Installation progress
class InstallationProgress {
  final String step;
  final String message;
  final double progress;
  final bool isError;
  final bool isComplete;

  const InstallationProgress({
    required this.step,
    required this.message,
    this.progress = 0.0,
    this.isError = false,
    this.isComplete = false,
  });

  InstallationProgress copyWith({
    String? step,
    String? message,
    double? progress,
    bool? isError,
    bool? isComplete,
  }) {
    return InstallationProgress(
      step: step ?? this.step,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      isError: isError ?? this.isError,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

/// Gateway configuration
class GatewayConfig {
  final String host;
  final int port;
  final String? token;
  final String? jwtToken;
  final bool autoConnect;

  const GatewayConfig({
    required this.host,
    this.port = 18789,
    this.token,
    this.jwtToken,
    this.autoConnect = true,
  });

  String get address => '$host:$port';
  String get httpUrl => 'http://$address';
  String get wsUrl => 'ws://$address';

  factory GatewayConfig.fromJson(Map<String, dynamic> json) {
    return GatewayConfig(
      host: json['host'] ?? 'localhost',
      port: json['port'] ?? 18789,
      token: json['token'],
      jwtToken: json['jwtToken'],
      autoConnect: json['autoConnect'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'token': token,
    'jwtToken': jwtToken,
    'autoConnect': autoConnect,
  };
}

/// Node configuration
class NodeConfig {
  final String name;
  final String? deviceId;
  final String? adbHost;
  final int? adbPort;
  final List<String> capabilities;

  const NodeConfig({
    required this.name,
    this.deviceId,
    this.adbHost,
    this.adbPort,
    this.capabilities = const [],
  });

  factory NodeConfig.fromJson(Map<String, dynamic> json) {
    return NodeConfig(
      name: json['name'] ?? 'Unnamed Node',
      deviceId: json['deviceId'],
      adbHost: json['adbHost'],
      adbPort: json['adbPort'],
      capabilities: (json['capabilities'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'deviceId': deviceId,
    'adbHost': adbHost,
    'adbPort': adbPort,
    'capabilities': capabilities,
  };
}

/// OpenClaw Installer Service
class OpenClawInstallerService {
  static OpenClawInstallerService? _instance;
  
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));
  
  final NetworkInfo _networkInfo = NetworkInfo();
  
  // Progress callback
  void Function(InstallationProgress progress)? onProgress;
  void Function(String level, String message, [dynamic data])? onLog;
  
  // Discovery state
  final List<DiscoveredInstance> _discoveredInstances = [];
  bool _isDiscovering = false;
  Timer? _discoveryTimer;

  factory OpenClawInstallerService() {
    _instance ??= OpenClawInstallerService._internal();
    return _instance!;
  }

  OpenClawInstallerService._internal();

  // ==================== Network Discovery ====================

  /// Start network discovery via mDNS
  Future<List<DiscoveredInstance>> startDiscovery({
    Duration timeout = const Duration(seconds: 30),
    bool scanCommonPorts = true,
  }) async {
    if (_isDiscovering) {
      _log('warn', 'Discovery already in progress');
      return _discoveredInstances;
    }

    _isDiscovering = true;
    _discoveredInstances.clear();
    
    onProgress?.call(InstallationProgress(
      step: 'discovery',
      message: 'Starting network discovery...',
      progress: 0.0,
    ));

    try {
      // Run mDNS discovery and port scan in parallel
      final results = await Future.wait([
        _discoverViaMdns(timeout),
        if (scanCommonPorts) _scanCommonPorts(),
      ]);

      // Merge results
      for (final result in results) {
        for (final instance in result) {
          if (!_discoveredInstances.any((i) => i.address == instance.address)) {
            _discoveredInstances.add(instance);
          }
        }
      }

      onProgress?.call(InstallationProgress(
        step: 'discovery',
        message: 'Discovered ${_discoveredInstances.length} instances',
        progress: 1.0,
        isComplete: true,
      ));

      return _discoveredInstances;
    } catch (e) {
      _log('error', 'Discovery failed', e);
      onProgress?.call(InstallationProgress(
        step: 'discovery',
        message: 'Discovery failed: $e',
        isError: true,
      ));
      return _discoveredInstances;
    } finally {
      _isDiscovering = false;
    }
  }

  /// Discover via mDNS (Bonjour/Avahi)
  Future<List<DiscoveredInstance>> _discoverViaMdns(Duration timeout) async {
    final instances = <DiscoveredInstance>[];
    
    try {
      final client = MDnsClient();
      await client.start();

      onProgress?.call(InstallationProgress(
        step: 'discovery',
        message: 'Scanning via mDNS...',
        progress: 0.1,
      ));

      // Look for OpenClaw services
      await for (final ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('_openclaw._tcp.local'),
      )) {
        await for (final srv in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          final instance = DiscoveredInstance(
            name: srv.name.replaceAll('._openclaw._tcp.local', ''),
            host: srv.target.replaceAll('.local', ''),
            port: srv.port,
            discoveredAt: DateTime.now(),
          );
          instances.add(instance);
          _log('info', 'Found OpenClaw instance: ${instance.name} at ${instance.address}');
        }
      }

      // Also look for HTTP services
      await for (final ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('_http._tcp.local'),
      )) {
        await for (final srv in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          // Try to check if this is an OpenClaw instance
          final isInstance = await _checkOpenClawInstance(
            srv.target.replaceAll('.local', ''),
            srv.port,
          );
          
          if (isInstance != null) {
            instances.add(isInstance);
          }
        }
      }

      client.stop();
    } catch (e) {
      _log('warn', 'mDNS discovery error: $e');
    }

    return instances;
  }

  /// Scan common ports for OpenClaw instances
  Future<List<DiscoveredInstance>> _scanCommonPorts() async {
    final instances = <DiscoveredInstance>[];
    
    try {
      final wifiIP = await _networkInfo.getWifiIP();
      if (wifiIP == null) return instances;

      // Get network range
      final parts = wifiIP.split('.');
      final baseIP = '${parts[0]}.${parts[1]}.${parts[2]}';
      
      onProgress?.call(InstallationProgress(
        step: 'discovery',
        message: 'Scanning network $baseIP.0/24...',
        progress: 0.2,
      ));

      // Common ports to scan
      const ports = [18789, 3000, 8080, 80, 443];
      
      // Scan a subset of IPs (to avoid long wait times)
      final ipsToScan = [1, 2, 100, 101, 102, 103, 104, 105, 110, 111, 112, 113, 114, 115];
      
      for (var i = 0; i < ipsToScan.length; i++) {
        final lastOctet = ipsToScan[i];
        final ip = '$baseIP.$lastOctet';
        
        for (final port in ports) {
          final instance = await _checkOpenClawInstance(ip, port);
          if (instance != null) {
            instances.add(instance);
          }
        }
        
        onProgress?.call(InstallationProgress(
          step: 'discovery',
          message: 'Scanning network...',
          progress: 0.2 + (i / ipsToScan.length) * 0.7,
        ));
      }
    } catch (e) {
      _log('warn', 'Port scan error: $e');
    }

    return instances;
  }

  /// Check if a host:port is an OpenClaw instance
  Future<DiscoveredInstance?> _checkOpenClawInstance(String host, int port) async {
    try {
      final response = await _dio.get(
        'http://$host:$port/health',
        options: Options(
          receiveTimeout: const Duration(milliseconds: 2000),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && (data['name']?.toString().contains('openclaw') ?? false)) {
          return DiscoveredInstance(
            name: data['name'] ?? 'OpenClaw',
            host: host,
            port: port,
            version: data['version'],
            platform: data['platform'],
            discoveredAt: DateTime.now(),
          );
        }
      }
    } catch (_) {}
    
    return null;
  }

  /// Stop discovery
  void stopDiscovery() {
    _discoveryTimer?.cancel();
    _isDiscovering = false;
  }

  /// Get discovered instances
  List<DiscoveredInstance> get discoveredInstances => List.unmodifiable(_discoveredInstances);

  // ==================== Installation ====================

  /// Download and install OpenClaw
  Future<bool> installOpenClaw({
    String? version,
    String? installPath,
    bool useNpm = true,
  }) async {
    onProgress?.call(InstallationProgress(
      step: 'install',
      message: 'Starting OpenClaw installation...',
      progress: 0.0,
    ));

    try {
      // Check prerequisites
      onProgress?.call(InstallationProgress(
        step: 'install',
        message: 'Checking prerequisites...',
        progress: 0.1,
      ));

      final hasNode = await _checkCommand('node', '--version');
      if (!hasNode) {
        onProgress?.call(InstallationProgress(
          step: 'install',
          message: 'Node.js not found. Please install Node.js first.',
          isError: true,
        ));
        return false;
      }

      final hasNpm = await _checkCommand('npm', '--version');
      if (!hasNpm) {
        onProgress?.call(InstallationProgress(
          step: 'install',
          message: 'npm not found. Please install npm first.',
          isError: true,
        ));
        return false;
      }

      // Install OpenClaw
      onProgress?.call(InstallationProgress(
        step: 'install',
        message: 'Installing OpenClaw via npm...',
        progress: 0.3,
      ));

      final termuxService = TermuxService();
      final result = await termuxService.installNpmPackage(
        'openclaw',
        global: true,
        version: version,
      );

      if (!result.success) {
        onProgress?.call(InstallationProgress(
          step: 'install',
          message: 'Installation failed: ${result.stderr}',
          isError: true,
        ));
        return false;
      }

      // Verify installation
      onProgress?.call(InstallationProgress(
        step: 'install',
        message: 'Verifying installation...',
        progress: 0.8,
      ));

      final verifyResult = await termuxService.executeCommand('openclaw', args: ['--version']);
      if (!verifyResult.success) {
        onProgress?.call(InstallationProgress(
          step: 'install',
          message: 'Installation verification failed',
          isError: true,
        ));
        return false;
      }

      onProgress?.call(InstallationProgress(
        step: 'install',
        message: 'OpenClaw installed successfully!',
        progress: 1.0,
        isComplete: true,
      ));

      return true;
    } catch (e) {
      _log('error', 'Installation failed', e);
      onProgress?.call(InstallationProgress(
        step: 'install',
        message: 'Installation error: $e',
        isError: true,
      ));
      return false;
    }
  }

  /// Check if a command is available
  Future<bool> _checkCommand(String command, String testArg) async {
    try {
      final result = await Process.run(command, [testArg]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  // ==================== Gateway Configuration ====================

  /// Configure gateway connection
  Future<bool> configureGateway(GatewayConfig config) async {
    onProgress?.call(InstallationProgress(
      step: 'configure',
      message: 'Configuring gateway connection...',
      progress: 0.0,
    ));

    try {
      // Test connection
      onProgress?.call(InstallationProgress(
        step: 'configure',
        message: 'Testing connection to ${config.address}...',
        progress: 0.3,
      ));

      final isReachable = await _testGatewayConnection(config);
      if (!isReachable) {
        onProgress?.call(InstallationProgress(
          step: 'configure',
          message: 'Cannot connect to gateway at ${config.address}',
          isError: true,
        ));
        return false;
      }

      // Validate token if provided
      if (config.token != null) {
        onProgress?.call(InstallationProgress(
          step: 'configure',
          message: 'Validating gateway token...',
          progress: 0.6,
        ));

        final isValid = await _validateGatewayToken(config);
        if (!isValid) {
          onProgress?.call(InstallationProgress(
            step: 'configure',
            message: 'Invalid gateway token',
            isError: true,
          ));
          return false;
        }
      }

      // Save configuration
      onProgress?.call(InstallationProgress(
        step: 'configure',
        message: 'Saving configuration...',
        progress: 0.8,
      ));

      await _saveGatewayConfig(config);

      onProgress?.call(InstallationProgress(
        step: 'configure',
        message: 'Gateway configured successfully!',
        progress: 1.0,
        isComplete: true,
      ));

      return true;
    } catch (e) {
      _log('error', 'Gateway configuration failed', e);
      onProgress?.call(InstallationProgress(
        step: 'configure',
        message: 'Configuration error: $e',
        isError: true,
      ));
      return false;
    }
  }

  /// Test gateway connection
  Future<bool> _testGatewayConnection(GatewayConfig config) async {
    try {
      final response = await _dio.get(
        '${config.httpUrl}/health',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Validate gateway token
  Future<bool> _validateGatewayToken(GatewayConfig config) async {
    try {
      final response = await _dio.get(
        '${config.httpUrl}/api/session/status',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${config.token}',
          },
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Save gateway configuration
  Future<void> _saveGatewayConfig(GatewayConfig config) async {
    // In a real implementation, this would save to secure storage
    // For now, we'll just log it
    _log('info', 'Gateway config saved: ${config.address}');
  }

  // ==================== Node Setup ====================

  /// Setup a node connection
  Future<bool> setupNode(NodeConfig config, {bool useAdb = true}) async {
    onProgress?.call(InstallationProgress(
      step: 'node',
      message: 'Setting up node: ${config.name}...',
      progress: 0.0,
    ));

    try {
      if (useAdb && (config.adbHost != null || config.deviceId != null)) {
        return await _setupAdbNode(config);
      }

      // Non-ADB setup (just save configuration)
      onProgress?.call(InstallationProgress(
        step: 'node',
        message: 'Node configured: ${config.name}',
        progress: 1.0,
        isComplete: true,
      ));

      return true;
    } catch (e) {
      _log('error', 'Node setup failed', e);
      onProgress?.call(InstallationProgress(
        step: 'node',
        message: 'Node setup error: $e',
        isError: true,
      ));
      return false;
    }
  }

  /// Setup node via ADB
  Future<bool> _setupAdbNode(NodeConfig config) async {
    final termuxService = TermuxService();
    
    // Check ADB availability
    onProgress?.call(InstallationProgress(
      step: 'node',
      message: 'Checking ADB...',
      progress: 0.1,
    ));

    final adbAvailable = await termuxService.isAdbAvailable();
    if (!adbAvailable) {
      onProgress?.call(InstallationProgress(
        step: 'node',
        message: 'ADB not available. Install Android Tools first.',
        isError: true,
      ));
      return false;
    }

    // Connect to device
    if (config.adbHost != null) {
      onProgress?.call(InstallationProgress(
        step: 'node',
        message: 'Connecting to ${config.adbHost}...',
        progress: 0.3,
      ));

      final connectResult = await termuxService.connectAdbDevice(
        config.adbHost!,
        port: config.adbPort ?? 5555,
      );

      if (!connectResult.success) {
        onProgress?.call(InstallationProgress(
          step: 'node',
          message: 'Failed to connect: ${connectResult.stderr}',
          isError: true,
        ));
        return false;
      }
    }

    // Verify device connection
    onProgress?.call(InstallationProgress(
      step: 'node',
      message: 'Verifying device connection...',
      progress: 0.5,
    ));

    final devices = await termuxService.listAdbDevices();
    final device = devices.firstWhere(
      (d) => d.id == config.deviceId || d.isOnline,
      orElse: () => const AdbDevice(id: '', status: 'not_found'),
    );

    if (device.id.isEmpty) {
      onProgress?.call(InstallationProgress(
        step: 'node',
        message: 'No device found',
        isError: true,
      ));
      return false;
    }

    if (device.isUnauthorized) {
      onProgress?.call(InstallationProgress(
        step: 'node',
        message: 'Device is unauthorized. Please accept the ADB connection on the device.',
        isError: true,
      ));
      return false;
    }

    // Setup OpenClaw on device (optional)
    onProgress?.call(InstallationProgress(
      step: 'node',
      message: 'Node ready: ${config.name}',
      progress: 1.0,
      isComplete: true,
    ));

    return true;
  }

  // ==================== Skills Installation ====================

  /// Install a skill from ClawHub
  Future<bool> installSkill(String skillName, {String? version}) async {
    onProgress?.call(InstallationProgress(
      step: 'skill',
      message: 'Installing skill: $skillName...',
      progress: 0.0,
    ));

    try {
      final termuxService = TermuxService();
      
      // Check if OpenClaw is installed
      final isOpenClawInstalled = await termuxService.isOpenClawInstalled();
      if (!isOpenClawInstalled) {
        onProgress?.call(InstallationProgress(
          step: 'skill',
          message: 'OpenClaw not installed. Install OpenClaw first.',
          isError: true,
        ));
        return false;
      }

      // Install skill via clawhub CLI
      onProgress?.call(InstallationProgress(
        step: 'skill',
        message: 'Downloading skill...',
        progress: 0.3,
      ));

      final args = ['clawhub', 'install', skillName];
      if (version != null) {
        args.addAll(['--version', version]);
      }

      final result = await termuxService.runOpenClaw(
        'clawhub',
        args: ['install', skillName],
      );

      if (!result.success) {
        onProgress?.call(InstallationProgress(
          step: 'skill',
          message: 'Skill installation failed: ${result.stderr}',
          isError: true,
        ));
        return false;
      }

      onProgress?.call(InstallationProgress(
        step: 'skill',
        message: 'Skill $skillName installed successfully!',
        progress: 1.0,
        isComplete: true,
      ));

      return true;
    } catch (e) {
      _log('error', 'Skill installation failed', e);
      onProgress?.call(InstallationProgress(
        step: 'skill',
        message: 'Installation error: $e',
        isError: true,
      ));
      return false;
    }
  }

  /// Search for skills on ClawHub
  Future<List<Map<String, dynamic>>> searchSkills(String query) async {
    try {
      final response = await _dio.get(
        'https://clawhub.com/api/skills/search',
        queryParameters: {'q': query},
      );

      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      _log('error', 'Failed to search skills', e);
    }

    return [];
  }

  /// List installed skills
  Future<List<String>> listInstalledSkills() async {
    final termuxService = TermuxService();
    
    final result = await termuxService.runOpenClaw(
      'clawhub',
      args: ['list'],
    );

    if (result.success) {
      // Parse output to get skill names
      return result.stdout
          .split('\n')
          .where((line) => line.isNotEmpty && !line.startsWith('Total'))
          .toList();
    }

    return [];
  }

  // ==================== Connection Test ====================

  /// Test the complete setup
  Future<Map<String, dynamic>> testConnection(GatewayConfig config) async {
    onProgress?.call(InstallationProgress(
      step: 'test',
      message: 'Testing connection...',
      progress: 0.0,
    ));

    final results = <String, dynamic>{
      'gateway': false,
      'auth': false,
      'agents': false,
      'nodes': false,
      'latency': 0,
    };

    try {
      final stopwatch = Stopwatch()..start();

      // Test gateway health
      onProgress?.call(InstallationProgress(
        step: 'test',
        message: 'Testing gateway health...',
        progress: 0.2,
      ));

      final healthResponse = await _dio.get('${config.httpUrl}/health');
      results['gateway'] = healthResponse.statusCode == 200;

      stopwatch.stop();
      results['latency'] = stopwatch.elapsedMilliseconds;

      // Test authentication
      if (config.token != null) {
        onProgress?.call(InstallationProgress(
          step: 'test',
          message: 'Testing authentication...',
          progress: 0.4,
        ));

        final authResponse = await _dio.get(
          '${config.httpUrl}/api/session/status',
          options: Options(
            headers: {'Authorization': 'Bearer ${config.token}'},
          ),
        );
        results['auth'] = authResponse.statusCode == 200;
      }

      // Test agents endpoint
      onProgress?.call(InstallationProgress(
        step: 'test',
        message: 'Testing agents endpoint...',
        progress: 0.6,
      ));

      final agentsResponse = await _dio.get(
        '${config.httpUrl}/api/agents',
        options: Options(
          headers: config.token != null 
              ? {'Authorization': 'Bearer ${config.token}'}
              : null,
        ),
      );
      results['agents'] = agentsResponse.statusCode == 200;

      // Test nodes endpoint
      onProgress?.call(InstallationProgress(
        step: 'test',
        message: 'Testing nodes endpoint...',
        progress: 0.8,
      ));

      final nodesResponse = await _dio.get(
        '${config.httpUrl}/api/nodes',
        options: Options(
          headers: config.token != null 
              ? {'Authorization': 'Bearer ${config.token}'}
              : null,
        ),
      );
      results['nodes'] = nodesResponse.statusCode == 200;

      onProgress?.call(InstallationProgress(
        step: 'test',
        message: 'Connection test complete!',
        progress: 1.0,
        isComplete: true,
      ));
    } catch (e) {
      _log('error', 'Connection test failed', e);
      onProgress?.call(InstallationProgress(
        step: 'test',
        message: 'Connection test error: $e',
        isError: true,
      ));
    }

    return results;
  }

  // ==================== Helpers ====================

  void _log(String level, String message, [dynamic data]) {
    if (onLog != null) {
      onLog!(level, message, data);
    } else if (kDebugMode) {
      debugPrint('[OpenClawInstaller][$level] $message ${data ?? ''}');
    }
  }

  /// Dispose resources
  void dispose() {
    stopDiscovery();
    _dio.close();
  }
}

/// Installation exception
class InstallationException implements Exception {
  final String message;
  final String? step;

  const InstallationException({
    required this.message,
    this.step,
  });

  @override
  String toString() => 'InstallationException: $message (step: $step)';
}