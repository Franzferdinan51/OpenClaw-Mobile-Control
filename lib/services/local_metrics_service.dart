/// Local Metrics Service for DuckBot Go
///
/// Provides real-time gateway status and system metrics when running
/// OpenClaw locally on Android (Termux). This service combines:
///
/// 1. HTTP API calls to local gateway (preferred, fastest)
/// 2. OpenClaw CLI commands (fallback when HTTP unavailable)
/// 3. System metrics from Android/Termux (CPU, memory, uptime)
///
/// Use this service in the dashboard to show real metrics instead of 'Unavailable'.
///
/// Architecture Choice:
/// - We use a hybrid approach: HTTP API + CLI fallback
/// - HTTP is preferred because it's faster and doesn't require spawning processes
/// - CLI fallback ensures we can get metrics even if HTTP binding is limited
/// - System metrics come from Android APIs (not CLI) for better performance
///
/// Why not pure HTTP?
/// - Gateway may bind to localhost only (not accessible from app sandbox)
/// - CLI provides richer system metrics
/// - More reliable across different Android versions
///
/// Why not pure CLI?
/// - Spawning processes is slow (500ms-2s)
/// - Higher battery impact
/// - HTTP is more standard and maintainable
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/gateway_status.dart';
import 'termux_service.dart';
import 'termux_run_command_service.dart';
import '../utils/android_package_detector.dart';

/// Local metrics data model
class LocalMetrics {
  final bool isAvailable;
  final String? source; // 'http', 'cli', 'hybrid'
  final GatewayStatus? gatewayStatus;
  final SystemMetrics? systemMetrics;
  final DateTime fetchedAt;
  final Duration fetchDuration;
  final String? error;

  LocalMetrics({
    required this.isAvailable,
    this.source,
    this.gatewayStatus,
    this.systemMetrics,
    required this.fetchedAt,
    this.fetchDuration = Duration.zero,
    this.error,
  });

  factory LocalMetrics.error(String error,
      {Duration fetchDuration = Duration.zero}) {
    return LocalMetrics(
      isAvailable: false,
      fetchedAt: DateTime.now(),
      fetchDuration: fetchDuration,
      error: error,
    );
  }

  Map<String, dynamic> toJson() => {
        'is_available': isAvailable,
        'source': source,
        'gateway_status': gatewayStatus?.toJson(),
        'system_metrics': systemMetrics?.toJson(),
        'fetched_at': fetchedAt.toIso8601String(),
        'fetch_duration_ms': fetchDuration.inMilliseconds,
        'error': error,
      };
}

/// Runtime/service status for local OpenClaw installs.
class LocalRuntimeStatus {
  final bool gatewayRunning;
  final bool helperRunning;
  final bool termuxInstalled;
  final bool termuxApiInstalled;
  final bool runCommandPermissionGranted;
  final String? gatewayUrl;
  final String? helperUrl;
  final int? gatewayLatencyMs;
  final int? helperLatencyMs;
  final String? gatewayError;
  final String? helperError;
  final TermuxReadinessSummary? readiness;
  final DateTime checkedAt;

  const LocalRuntimeStatus({
    required this.gatewayRunning,
    required this.helperRunning,
    required this.termuxInstalled,
    required this.termuxApiInstalled,
    required this.runCommandPermissionGranted,
    required this.checkedAt,
    this.gatewayUrl,
    this.helperUrl,
    this.gatewayLatencyMs,
    this.helperLatencyMs,
    this.gatewayError,
    this.helperError,
    this.readiness,
  });

  bool get canRepairLocally => termuxInstalled;
}

/// System metrics from Android/Termux
class SystemMetrics {
  final double? cpuPercent;
  final int? memoryUsed; // bytes
  final int? memoryTotal; // bytes
  final double? memoryPercent;
  final int? uptimeSeconds;
  final String? platform;
  final String? hostname;

  SystemMetrics({
    this.cpuPercent,
    this.memoryUsed,
    this.memoryTotal,
    this.memoryPercent,
    this.uptimeSeconds,
    this.platform,
    this.hostname,
  });

  factory SystemMetrics.fromJson(Map<String, dynamic> json) {
    return SystemMetrics(
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble(),
      memoryUsed: json['memory_used'] as int?,
      memoryTotal: json['memory_total'] as int?,
      memoryPercent: (json['memory_percent'] as num?)?.toDouble(),
      uptimeSeconds: json['uptime_seconds'] as int?,
      platform: json['platform'] as String?,
      hostname: json['hostname'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'cpu_percent': cpuPercent,
        'memory_used': memoryUsed,
        'memory_total': memoryTotal,
        'memory_percent': memoryPercent,
        'uptime_seconds': uptimeSeconds,
        'platform': platform,
        'hostname': hostname,
      };

  /// Get formatted memory string
  String? get formattedMemory {
    if (memoryUsed == null || memoryTotal == null) return null;
    final usedMb = memoryUsed! / 1024 / 1024;
    final totalMb = memoryTotal! / 1024 / 1024;
    return '${usedMb.toStringAsFixed(1)} MB / ${totalMb.toStringAsFixed(1)} MB';
  }

  /// Get formatted uptime string
  String? get formattedUptime {
    if (uptimeSeconds == null) return null;
    final duration = Duration(seconds: uptimeSeconds!);
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) return '${days}d ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}

/// Service for fetching local OpenClaw metrics
///
/// This service is designed for Android/Termux local installations.
/// It tries multiple methods to get metrics, from fastest to slowest:
///
/// 1. HTTP API (localhost:18789/health) - ~50ms
/// 2. HTTP API (localhost:18789/api/gateway) - ~100ms
/// 3. OpenClaw CLI (openclaw status --json) - ~500-2000ms
/// 4. System metrics from Android APIs - ~10ms
class LocalMetricsService {
  final TermuxService _termuxService;
  final TermuxRunCommandService _termuxBridge;
  final http.Client _httpClient;

  bool _isInitialized = false;
  bool _isTermuxEnvironment = false;
  String? _gatewayUrl;

  // Cache to avoid rapid repeated calls
  LocalMetrics? _cachedMetrics;
  DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(seconds: 10);

  LocalMetricsService()
      : _termuxService = TermuxService(),
        _termuxBridge = TermuxRunCommandService(),
        _httpClient = http.Client();

  /// Initialize the service
  Future<bool> initialize(
      {String gatewayUrl = 'http://127.0.0.1:18789'}) async {
    if (_isInitialized) return true;

    try {
      _gatewayUrl = gatewayUrl;

      // Initialize Termux service
      await _termuxService.initialize();
      _isTermuxEnvironment = _termuxService.isTermuxAvailable;

      _log('LocalMetricsService initialized (Termux: $_isTermuxEnvironment)');
      _isInitialized = true;
      return true;
    } catch (e) {
      _log('Failed to initialize: $e');
      return false;
    }
  }

  /// Get local metrics with automatic fallback
  ///
  /// This is the main method to call from the dashboard.
  /// It tries all available methods and returns the best result.
  Future<LocalMetrics> getMetrics({bool forceRefresh = false}) async {
    // Return cached result if fresh enough
    if (!forceRefresh && _cachedMetrics != null && _cacheTimestamp != null) {
      if (DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
        _log(
            'Returning cached metrics (${_cacheTimestamp!.toIso8601String()})');
        return _cachedMetrics!;
      }
    }

    final stopwatch = Stopwatch()..start();

    try {
      // Method 1: Try HTTP API (fastest)
      _log('Trying HTTP API...');
      final httpMetrics = await _getMetricsViaHttp();
      if (httpMetrics.isAvailable && httpMetrics.gatewayStatus != null) {
        final result = httpMetrics.copyWith(
          fetchDuration: stopwatch.elapsed,
        );
        _updateCache(result);
        _log('HTTP succeeded in ${stopwatch.elapsed.inMilliseconds}ms');
        return result;
      }

      // Method 2: Try OpenClaw CLI (fallback)
      if (_isTermuxEnvironment) {
        _log('HTTP failed, trying CLI...');
        final cliMetrics = await _getMetricsViaCli();
        if (cliMetrics.isAvailable) {
          final result = cliMetrics.copyWith(
            fetchDuration: stopwatch.elapsed,
          );
          _updateCache(result);
          _log('CLI succeeded in ${stopwatch.elapsed.inMilliseconds}ms');
          return result;
        }
      }

      // Method 3: Try system metrics only
      _log('Trying system metrics...');
      final systemMetrics = await _getSystemMetrics();
      if (systemMetrics != null) {
        final result = LocalMetrics(
          isAvailable: true,
          source: 'system',
          systemMetrics: systemMetrics,
          fetchedAt: DateTime.now(),
          fetchDuration: stopwatch.elapsed,
        );
        _updateCache(result);
        _log(
            'System metrics succeeded in ${stopwatch.elapsed.inMilliseconds}ms');
        return result;
      }

      // All methods failed
      const error = 'All metrics sources unavailable';
      _log('Error: $error');
      return LocalMetrics.error(error, fetchDuration: stopwatch.elapsed);
    } catch (e) {
      _log('Exception: $e');
      return LocalMetrics.error(e.toString(), fetchDuration: stopwatch.elapsed);
    } finally {
      stopwatch.stop();
    }
  }

  /// Check runtime/service availability for local installs and repair flows.
  Future<LocalRuntimeStatus> getRuntimeStatus({
    bool includeReadiness = true,
  }) async {
    if (!_isInitialized) {
      await initialize(gatewayUrl: _gatewayUrl ?? 'http://127.0.0.1:18789');
    }

    final gatewayProbe = await _probeHttpEndpoint(
      _gatewayUrl != null ? '$_gatewayUrl/health' : null,
    );
    final helperUrl = _deriveHelperUrl();
    final helperProbe = await _probeHttpEndpoint(
      helperUrl != null ? '$helperUrl/status' : null,
    );

    TermuxReadinessSummary? readiness;
    if (includeReadiness) {
      try {
        readiness = await TermuxPrerequisiteChecker.getReadinessSummary();
      } catch (e) {
        _log('Readiness probe failed: $e');
      }
    }

    var hasRunCommandPermission = false;
    try {
      hasRunCommandPermission = await _termuxBridge.hasRunCommandPermission();
    } catch (e) {
      _log('RUN_COMMAND permission probe failed: $e');
    }

    return LocalRuntimeStatus(
      gatewayRunning: gatewayProbe.isReachable,
      helperRunning: helperProbe.isReachable,
      termuxInstalled: _termuxService.isTermuxAvailable,
      termuxApiInstalled: _termuxService.isTermuxApiAvailable,
      runCommandPermissionGranted: hasRunCommandPermission,
      gatewayUrl: _gatewayUrl,
      helperUrl: helperUrl,
      gatewayLatencyMs: gatewayProbe.latencyMs,
      helperLatencyMs: helperProbe.latencyMs,
      gatewayError: gatewayProbe.error,
      helperError: helperProbe.error,
      readiness: readiness,
      checkedAt: DateTime.now(),
    );
  }

  /// Get metrics via HTTP API
  Future<LocalMetrics> _getMetricsViaHttp() async {
    final helperUrl = _deriveHelperUrl();

    // Try dedicated mobile metrics helper first
    if (helperUrl != null) {
      try {
        final helperResponse = await _httpClient
            .get(
              Uri.parse('$helperUrl/status'),
            )
            .timeout(const Duration(seconds: 3));

        if (helperResponse.statusCode == 200) {
          final helperJson =
              jsonDecode(helperResponse.body) as Map<String, dynamic>;
          return LocalMetrics(
            isAvailable: true,
            source: 'helper',
            gatewayStatus: GatewayStatus.fromJson(helperJson),
            systemMetrics: _extractSystemMetricsFromHelper(helperJson),
            fetchedAt: DateTime.now(),
          );
        }
      } catch (e) {
        _log('Helper /status error: $e');
      }
    }

    try {
      // Try /health endpoint first (lightweight)
      final healthResponse = await _httpClient
          .get(
            Uri.parse('$_gatewayUrl/health'),
          )
          .timeout(const Duration(seconds: 3));

      if (healthResponse.statusCode == 200) {
        final healthJson = jsonDecode(healthResponse.body);
        final gatewayStatus = GatewayStatus.fromHealthJson(healthJson);

        // Get system metrics separately
        final systemMetrics = await _getSystemMetrics();

        return LocalMetrics(
          isAvailable: true,
          source: 'http',
          gatewayStatus: gatewayStatus,
          systemMetrics: systemMetrics,
          fetchedAt: DateTime.now(),
        );
      }
    } on TimeoutException {
      _log('HTTP /health timeout');
    } on SocketException {
      _log('HTTP /health connection refused');
    } catch (e) {
      _log('HTTP /health error: $e');
    }

    // Try /api/gateway endpoint (more detailed)
    try {
      final gatewayResponse = await _httpClient
          .get(
            Uri.parse('$_gatewayUrl/api/gateway'),
          )
          .timeout(const Duration(seconds: 5));

      if (gatewayResponse.statusCode == 200) {
        final gatewayJson = jsonDecode(gatewayResponse.body);
        final gatewayStatus = GatewayStatus.fromJson(gatewayJson);

        // Get system metrics separately
        final systemMetrics = await _getSystemMetrics();

        return LocalMetrics(
          isAvailable: true,
          source: 'http',
          gatewayStatus: gatewayStatus,
          systemMetrics: systemMetrics,
          fetchedAt: DateTime.now(),
        );
      }
    } on TimeoutException {
      _log('HTTP /api/gateway timeout');
    } on SocketException {
      _log('HTTP /api/gateway connection refused');
    } catch (e) {
      _log('HTTP /api/gateway error: $e');
    }

    return LocalMetrics.error('HTTP endpoints unavailable');
  }

  /// Get metrics via OpenClaw CLI
  Future<LocalMetrics> _getMetricsViaCli() async {
    try {
      // Run: openclaw status --json
      final result = await _termuxService.executeCommand(
        'openclaw status --json',
        useProot: true,
        timeout: const Duration(seconds: 10),
      );

      if (result.success && result.stdout.isNotEmpty) {
        // Parse JSON output
        final jsonStr = result.stdout.trim();
        final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(jsonStr);

        if (jsonMatch != null) {
          final statusJson = jsonDecode(jsonMatch.group(0)!);
          final gatewayStatus = GatewayStatus.fromJson(statusJson);

          // Get system metrics
          final systemMetrics = await _getSystemMetrics();

          return LocalMetrics(
            isAvailable: true,
            source: 'cli',
            gatewayStatus: gatewayStatus,
            systemMetrics: systemMetrics,
            fetchedAt: DateTime.now(),
          );
        }
      }

      // Fallback: try without --json flag
      final simpleResult = await _termuxService.executeCommand(
        'openclaw status',
        useProot: true,
        timeout: const Duration(seconds: 10),
      );

      if (simpleResult.success) {
        // Parse text output (basic parsing)
        final output = simpleResult.stdout;
        final gatewayStatus = _parseStatusText(output);

        final systemMetrics = await _getSystemMetrics();

        return LocalMetrics(
          isAvailable: gatewayStatus != null,
          source: 'cli',
          gatewayStatus: gatewayStatus,
          systemMetrics: systemMetrics,
          fetchedAt: DateTime.now(),
        );
      }
    } catch (e) {
      _log('CLI error: $e');
    }

    return LocalMetrics.error('CLI commands failed');
  }

  /// Parse text output from `openclaw status`
  GatewayStatus? _parseStatusText(String text) {
    try {
      // Basic parsing - look for key patterns
      final versionMatch = RegExp(r'Version:\s*(\S+)').firstMatch(text);
      final uptimeMatch = RegExp(r'Uptime:\s*(\d+)').firstMatch(text);
      final statusMatch = RegExp(r'Status:\s*(\w+)').firstMatch(text);

      return GatewayStatus(
        online: statusMatch?.group(1)?.toLowerCase() == 'live' ||
            statusMatch?.group(1)?.toLowerCase() == 'online',
        version: versionMatch?.group(1) ?? 'unknown',
        uptime: int.tryParse(uptimeMatch?.group(1) ?? '0') ?? 0,
      );
    } catch (e) {
      _log('Failed to parse status text: $e');
      return null;
    }
  }

  /// Get system metrics from Android/Termux
  Future<SystemMetrics?> _getSystemMetrics() async {
    try {
      // Try to get system info via Android APIs or CLI
      if (Platform.isAndroid && _isTermuxEnvironment) {
        // Use Termux commands for system info
        final meminfoResult = await _termuxService.executeCommand(
          'cat /proc/meminfo',
          useProot: false, // Don't use proot for system files
          timeout: const Duration(seconds: 2),
        );

        if (meminfoResult.success) {
          final meminfo = _parseMeminfo(meminfoResult.stdout);

          // Get uptime
          final uptimeResult = await _termuxService.executeCommand(
            'cat /proc/uptime',
            useProot: false,
            timeout: const Duration(seconds: 2),
          );

          int? uptimeSeconds;
          if (uptimeResult.success) {
            final uptimeMatch =
                RegExp(r'^(\d+)').firstMatch(uptimeResult.stdout);
            uptimeSeconds = int.tryParse(uptimeMatch?.group(1) ?? '0');
          }

          // Get CPU usage (simplified - average of all cores)
          double? cpuPercent;
          try {
            final statResult = await _termuxService.executeCommand(
              'top -bn1 | grep "Cpu(s)"',
              useProot: false,
              timeout: const Duration(seconds: 2),
            );
            if (statResult.success) {
              final cpuMatch = RegExp(r'(\d+\.?\d*)\s*%?\s*us')
                  .firstMatch(statResult.stdout);
              cpuPercent = double.tryParse(cpuMatch?.group(1) ?? '0');
            }
          } catch (e) {
            _log('CPU measurement failed: $e');
          }

          return SystemMetrics(
            cpuPercent: cpuPercent,
            memoryUsed:
                meminfo['MemTotal'] != null && meminfo['MemAvailable'] != null
                    ? (meminfo['MemTotal']! - meminfo['MemAvailable']!) * 1024
                    : null,
            memoryTotal: meminfo['MemTotal'] != null
                ? meminfo['MemTotal']! * 1024
                : null,
            memoryPercent:
                meminfo['MemTotal'] != null && meminfo['MemAvailable'] != null
                    ? ((meminfo['MemTotal']! - meminfo['MemAvailable']!) /
                            meminfo['MemTotal']!) *
                        100
                    : null,
            uptimeSeconds: uptimeSeconds,
            platform: 'Android',
            hostname: 'localhost',
          );
        }
      }

      // Fallback: use Dart's Platform info (limited)
      return SystemMetrics(
        platform: Platform.operatingSystem,
        hostname: Platform.localHostname,
      );
    } catch (e) {
      _log('System metrics error: $e');
      return null;
    }
  }

  /// Parse /proc/meminfo output
  Map<String, int> _parseMeminfo(String content) {
    final result = <String, int>{};
    for (final line in content.split('\n')) {
      final parts = line.split(':');
      if (parts.length == 2) {
        final key = parts[0].trim();
        final valueMatch = RegExp(r'(\d+)').firstMatch(parts[1]);
        if (valueMatch != null) {
          result[key] = int.parse(valueMatch.group(1)!);
        }
      }
    }
    return result;
  }

  String? _deriveHelperUrl() {
    if (_gatewayUrl == null || _gatewayUrl!.isEmpty) return null;
    try {
      final uri = Uri.parse(_gatewayUrl!);
      final host = uri.host;
      if (host.isEmpty) return null;
      return '${uri.scheme}://$host:18790';
    } catch (_) {
      return null;
    }
  }

  Future<_EndpointProbeResult> _probeHttpEndpoint(String? url) async {
    if (url == null || url.isEmpty) {
      return const _EndpointProbeResult(
        isReachable: false,
        error: 'Unavailable',
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      final response = await _httpClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 3));
      stopwatch.stop();

      if (response.statusCode == 200) {
        return _EndpointProbeResult(
          isReachable: true,
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }

      return _EndpointProbeResult(
        isReachable: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        error: 'HTTP ${response.statusCode}',
      );
    } on TimeoutException {
      stopwatch.stop();
      return _EndpointProbeResult(
        isReachable: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        error: 'Timed out',
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return _EndpointProbeResult(
        isReachable: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        error: e.message,
      );
    } catch (e) {
      stopwatch.stop();
      return _EndpointProbeResult(
        isReachable: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        error: e.toString(),
      );
    }
  }

  SystemMetrics? _extractSystemMetricsFromHelper(Map<String, dynamic> json) {
    try {
      final system = json['system'] as Map<String, dynamic>?;
      final memory = system?['memory'] as Map<String, dynamic>?;
      return SystemMetrics(
        cpuPercent: (system?['cpu_percent'] as num?)?.toDouble(),
        memoryUsed: memory?['used'] as int?,
        memoryTotal: memory?['total'] as int?,
        memoryPercent: (memory?['percent'] as num?)?.toDouble(),
        uptimeSeconds: system?['uptime'] as int?,
        platform: system?['platform'] as String?,
        hostname: system?['host'] as String?,
      );
    } catch (e) {
      _log('Helper system metrics parse error: $e');
      return null;
    }
  }

  /// Update cache
  void _updateCache(LocalMetrics metrics) {
    _cachedMetrics = metrics;
    _cacheTimestamp = DateTime.now();
  }

  /// Clear cache
  void clearCache() {
    _cachedMetrics = null;
    _cacheTimestamp = null;
  }

  /// Log helper
  void _log(String message) {
    debugPrint('LocalMetricsService: $message');
  }

  /// Check if local metrics are available
  Future<bool> isAvailable() async {
    final metrics = await getMetrics();
    return metrics.isAvailable;
  }

  /// Get gateway URL
  String? get gatewayUrl => _gatewayUrl;

  /// Set gateway URL
  void setGatewayUrl(String url) {
    _gatewayUrl = url;
    clearCache();
    _log('Gateway URL updated: $_gatewayUrl');
  }

  /// Dispose
  void dispose() {
    _httpClient.close();
    _cachedMetrics = null;
    _cacheTimestamp = null;
  }
}

class _EndpointProbeResult {
  final bool isReachable;
  final int? latencyMs;
  final String? error;

  const _EndpointProbeResult({
    required this.isReachable,
    this.latencyMs,
    this.error,
  });
}

/// Extension to add copyWith to LocalMetrics
extension LocalMetricsExtension on LocalMetrics {
  LocalMetrics copyWith({
    bool? isAvailable,
    String? source,
    GatewayStatus? gatewayStatus,
    SystemMetrics? systemMetrics,
    DateTime? fetchedAt,
    Duration? fetchDuration,
    String? error,
  }) {
    return LocalMetrics(
      isAvailable: isAvailable ?? this.isAvailable,
      source: source ?? this.source,
      gatewayStatus: gatewayStatus ?? this.gatewayStatus,
      systemMetrics: systemMetrics ?? this.systemMetrics,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      fetchDuration: fetchDuration ?? this.fetchDuration,
      error: error ?? this.error,
    );
  }
}
