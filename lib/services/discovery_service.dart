import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gateway_status.dart';
import 'openclaw_companion_service.dart';

/// Log entry for discovery process debugging
class DiscoveryLogEntry {
  final DateTime timestamp;
  final String level; // 'info', 'success', 'warning', 'error', 'debug'
  final String message;
  final String? details;

  DiscoveryLogEntry({
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

  @override
  String toString() {
    final time =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    final icon = {
          'info': 'ℹ️',
          'success': '✅',
          'warning': '⚠️',
          'error': '❌',
          'debug': '🔍',
        }[level] ??
        '📝';
    return '[$time] $icon $message${details != null ? '\n  → $details' : ''}';
  }
}

/// Parameters for scanning a single IP
class _ScanIpParams {
  final String ip;
  final int port;
  final int timeoutMs;

  _ScanIpParams({
    required this.ip,
    required this.port,
    required this.timeoutMs,
  });
}

/// Result from IP scan
class _ScanResult {
  final String ip;
  final bool found;
  final String? url;
  final String? name;
  final String? error;

  _ScanResult({
    required this.ip,
    required this.found,
    this.url,
    this.name,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'found': found,
        'url': url,
        'name': name,
        'error': error,
      };

  factory _ScanResult.fromJson(Map<String, dynamic> json) => _ScanResult(
        ip: json['ip'] as String,
        found: json['found'] as bool,
        url: json['url'] as String?,
        name: json['name'] as String?,
        error: json['error'] as String?,
      );
}

/// Service for discovering OpenClaw gateways on the local network
///
/// IMPLEMENTATION NOTES:
/// - mDNS is a CONVENIENCE feature, not primary connection method
/// - Manual entry with IP:port is the MOST RELIABLE method
/// - Android Bionic libc can cause issues with networkInterfaces()
/// - Localhost (127.0.0.1) binding is used when gateway runs on device
/// - Network scanning is a fallback when mDNS fails
/// - OpenClaw gateway /health endpoint returns {"ok":true,"status":"live"}
/// - Parallel scanning using isolates for performance
class DiscoveryService {
  // OpenClaw gateway advertises as _openclaw-gw._tcp
  static const String _serviceType = '_openclaw-gw._tcp';
  static const String _historyKey = 'gateway_history';
  static const String _lastConnectedKey = 'last_connected_gateway';
  static const int _maxHistoryItems = 10;
  static const Duration _scanTimeout = Duration(seconds: 8);
  static const Duration _connectionTimeout = Duration(seconds: 5);
  static const List<String> _probeEndpoints = [
    '/health',
    '/api/gateway',
    '/api/status',
    '/status',
    '/api/health',
  ];

  // Scanning configuration
  static const int _isolateBatchSize = 25; // IPs per batch
  static const int _ipTimeoutMs = 500; // Timeout per IP check

  MDnsClient? _mdnsClient;
  Timer? _backgroundScanTimer;
  bool _isScanning = false;
  bool _isDisposed = false;
  int _totalIpsToScan = 0;
  int _ipsScanned = 0;

  // Debug logging
  final List<DiscoveryLogEntry> _logs = [];
  final StreamController<List<DiscoveryLogEntry>> _logsController =
      StreamController<List<DiscoveryLogEntry>>.broadcast();
  final int _maxLogs = 200;

  final StreamController<List<GatewayConnection>> _discoveredController =
      StreamController<List<GatewayConnection>>.broadcast();

  final StreamController<ScanProgress> _progressController =
      StreamController<ScanProgress>.broadcast();

  /// Stream of discovered gateways
  Stream<List<GatewayConnection>> get discoveredGateways =>
      _discoveredController.stream;

  /// Stream of discovery logs
  Stream<List<DiscoveryLogEntry>> get logs => _logsController.stream;

  /// Stream of scan progress
  Stream<ScanProgress> get scanProgress => _progressController.stream;

  /// Current list of discovered gateways
  List<GatewayConnection> _discovered = [];
  List<GatewayConnection> get discovered => List.unmodifiable(_discovered);

  /// Get all logs
  List<DiscoveryLogEntry> get allLogs => List.unmodifiable(_logs);

  /// Check if currently scanning
  bool get isScanning => _isScanning;

  /// Get scan progress percentage (0-100)
  int get scanProgressPercent =>
      _totalIpsToScan > 0 ? (_ipsScanned * 100 ~/ _totalIpsToScan) : 0;

  /// Add a log entry
  void _log(String level, String message, {String? details}) {
    final entry = DiscoveryLogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      details: details,
    );
    _logs.add(entry);

    // Keep only last N logs
    while (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    // Notify listeners
    if (!_logsController.isClosed) {
      _logsController.add(List.unmodifiable(_logs));
    }

    // Also print to console for debugging
    debugPrint(
        '[DiscoveryService] $message${details != null ? ' | $details' : ''}');
  }

  /// Clear all logs
  void clearLogs() {
    _logs.clear();
    if (!_logsController.isClosed) {
      _logsController.add([]);
    }
    _log('info', 'Logs cleared');
  }

  /// Get logs as formatted text for copying/sharing
  String getLogsAsText() {
    final buffer = StringBuffer();
    buffer.writeln('=== OpenClaw Discovery Logs ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total entries: ${_logs.length}');
    buffer.writeln('');
    for (final log in _logs) {
      buffer.writeln(log.toString());
      buffer.writeln('');
    }
    return buffer.toString();
  }

  /// Start background scanning (every 60 seconds)
  void startBackgroundScan() {
    if (_isDisposed) return;

    _log('info', 'Starting background discovery scanning (60s interval)');

    // Initial scan
    scan();

    // Set up periodic scanning
    _backgroundScanTimer?.cancel();
    _backgroundScanTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => scan(),
    );
  }

  /// Stop background scanning
  void stopBackgroundScan() {
    _backgroundScanTimer?.cancel();
    _backgroundScanTimer = null;
    _log('info', 'Background scanning stopped');
  }

  /// Scan for OpenClaw gateways on the local network
  ///
  /// PRIORITY ORDER:
  /// 1. mDNS/Bonjour discovery (if available)
  /// 2. Local subnet scanning (all IPs in detected subnets)
  /// 3. Common network ranges scan (fallback)
  /// 4. Tailscale network scan
  Future<List<GatewayConnection>> scan(
      {bool stopAtFirstHealthy = false}) async {
    if (_isDisposed) return _discovered;

    if (_isScanning) {
      _log('info', 'Scan already in progress, returning cached results');
      return _discovered;
    }

    _isScanning = true;
    _ipsScanned = 0;
    _totalIpsToScan = 0;
    clearLogs();
    _log('info', '🔍 Starting comprehensive gateway discovery...',
        details: 'Service type: $_serviceType');

    _updateProgress(0, 0, 'Starting scan...');

    final List<GatewayConnection> found = [];

    try {
      // STEP 1: Check localhost first (fastest - for on-device gateway)
      _log(
        'info',
        'Step 1: Checking localhost companion and gateway endpoints',
      );
      _updateProgress(0, 1, 'Checking localhost...');
      final localhostGateway = await _checkLocalhost();
      if (localhostGateway != null) {
        found.add(localhostGateway);
        _log('success', 'Gateway found on localhost!',
            details: localhostGateway.url);
        if (stopAtFirstHealthy) {
          _discovered = found;
          _updateProgress(100, _totalIpsToScan, 'Found localhost gateway');
          return _discovered;
        }
      }

      // STEP 2: Try mDNS discovery
      _log('info', 'Step 2: Starting mDNS discovery');
      _updateProgress(0, 1, 'Scanning mDNS...');
      try {
        final mdnsGateways = await _scanMdns();
        for (final gateway in mdnsGateways) {
          if (!found.any((g) => g.url == gateway.url)) {
            found.add(gateway);
            _log('success', 'Gateway found via mDNS', details: gateway.url);
          }
        }
        if (stopAtFirstHealthy && found.isNotEmpty) {
          _discovered = found;
          _updateProgress(100, _totalIpsToScan, 'Found gateway via mDNS');
          return _discovered;
        }
      } catch (e) {
        _log('warning', 'mDNS discovery failed', details: e.toString());
      }

      // STEP 3: Scan local subnets comprehensively
      _log('info', 'Step 3: Scanning local subnets');
      _updateProgress(0, 0, 'Scanning local subnets...');
      final localGateways = await _scanLocalSubnets();
      for (final gateway in localGateways) {
        if (!found.any((g) => g.url == gateway.url)) {
          found.add(gateway);
          _log('success', 'Gateway found on local subnet',
              details: gateway.url);
        }
      }
      if (stopAtFirstHealthy && found.isNotEmpty) {
        _discovered = found;
        _updateProgress(100, _totalIpsToScan, 'Found gateway on local subnet');
        return _discovered;
      }

      // STEP 4: Scan common network ranges as fallback
      if (found.isEmpty) {
        _log('info', 'Step 4: Scanning common network ranges');
        _updateProgress(0, 0, 'Scanning common ranges...');
        final commonGateways = await _scanCommonNetworks();
        for (final gateway in commonGateways) {
          if (!found.any((g) => g.url == gateway.url)) {
            found.add(gateway);
            _log('success', 'Gateway found in common range',
                details: gateway.url);
          }
        }
      }

      // STEP 5: Scan Tailscale network
      if (found.isEmpty) {
        _log('info', 'Step 5: Scanning Tailscale network');
        _updateProgress(0, 0, 'Scanning Tailscale...');
        final tailscaleGateways = await _scanTailscale();
        for (final gateway in tailscaleGateways) {
          if (!found.any((g) => g.url == gateway.url)) {
            found.add(gateway);
            _log('success', 'Gateway found via Tailscale',
                details: gateway.url);
          }
        }
      } else {
        _log('info', 'Step 5: Skipping Tailscale scan',
            details: 'Healthy gateway already discovered locally');
      }

      _discovered = found;
      if (found.isNotEmpty) {
        _log('success', 'Discovery complete!',
            details:
                '${found.length} gateway(s) found: ${found.map((g) => g.url).join(", ")}');
        _updateProgress(
            100, _totalIpsToScan, 'Found ${found.length} gateway(s)!');
      } else {
        _log('warning', 'Discovery complete - no gateways found',
            details: 'Use Manual tab to enter gateway IP directly');
        _updateProgress(100, _totalIpsToScan, 'No gateways found');
      }
    } catch (e) {
      _log('error', 'Discovery error', details: '$e');
      _discovered = found;
      _updateProgress(100, _totalIpsToScan, 'Error: $e');
    } finally {
      _isScanning = false;
      try {
        _mdnsClient?.stop();
      } catch (e) {
        // Ignore cleanup errors
      }
      _mdnsClient = null;
    }

    if (!_isDisposed && !_discoveredController.isClosed) {
      _discoveredController.add(_discovered);
    }
    return _discovered;
  }

  /// Update scan progress
  void _updateProgress(int percent, int scanned, String status) {
    if (!_progressController.isClosed) {
      _progressController.add(ScanProgress(
        percent: percent,
        scanned: scanned,
        total: _totalIpsToScan,
        status: status,
      ));
    }
  }

  /// Check localhost for on-device gateway
  Future<GatewayConnection?> _checkLocalhost() async {
    final localhostCandidates = <({int port, String name})>[
      (
        port: OpenClawCompanionService.defaultPort,
        name: 'Local OpenClaw Companion',
      ),
      (
        port: 18789,
        name: 'Local Gateway (This Device)',
      ),
    ];

    for (final candidate in localhostCandidates) {
      final gateway = await _quickCheckGateway(
        '127.0.0.1',
        candidate.port,
        name: candidate.name,
      );
      if (gateway != null) {
        return gateway;
      }
    }

    return null;
  }

  /// Scan using mDNS/Bonjour with improved Android compatibility
  Future<List<GatewayConnection>> _scanMdns() async {
    final List<GatewayConnection> found = [];

    try {
      _mdnsClient?.stop();
      _mdnsClient = MDnsClient();

      // Start mDNS client with specific settings for Android compatibility
      await _mdnsClient!.start(
        interfacesFactory: (InternetAddressType type) async {
          try {
            final interfaces = await NetworkInterface.list(
              type: type,
              includeLinkLocal: false,
            );
            _log('debug', 'Network interfaces found: ${interfaces.length}');
            for (final iface in interfaces) {
              _log('debug', 'Interface: ${iface.name}');
              for (final addr in iface.addresses) {
                _log('debug', '  Address: ${addr.address} (${addr.type.name})');
              }
            }
            return interfaces;
          } catch (e) {
            _log('warning', 'Error listing network interfaces',
                details: e.toString());
            return [];
          }
        },
      );
      _log('success', 'mDNS client started');

      // Query for PTR records with shorter timeout
      _log('info', 'Querying mDNS PTR records...');
      final ptrRecords = await _queryPtrRecords();
      _log('info', 'PTR query complete',
          details: 'Found ${ptrRecords.length} service(s)');

      // Resolve each service
      for (final serviceName in ptrRecords) {
        try {
          _log('info', 'Resolving service: $serviceName');
          final gateway = await _resolveService(serviceName);
          if (gateway != null && !found.any((g) => g.url == gateway.url)) {
            found.add(gateway);
          }
        } catch (e) {
          _log('warning', 'Error resolving service $serviceName',
              details: e.toString());
        }
      }
    } catch (e) {
      _log('error', 'mDNS scan error', details: e.toString());
    } finally {
      try {
        _mdnsClient?.stop();
      } catch (e) {
        // Ignore
      }
      _mdnsClient = null;
    }

    return found;
  }

  /// Query for PTR records with timeout
  Future<List<String>> _queryPtrRecords() async {
    final List<String> serviceNames = [];

    try {
      await for (final PtrResourceRecord ptr in _mdnsClient!
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer('$_serviceType.local.'),
          )
          .timeout(_scanTimeout)) {
        _log('debug', 'PTR record received', details: ptr.domainName);
        serviceNames.add(ptr.domainName);
      }
    } on TimeoutException {
      _log('warning', 'PTR query timed out after ${_scanTimeout.inSeconds}s');
    } catch (e) {
      _log('error', 'PTR query error', details: e.toString());
    }

    return serviceNames;
  }

  /// Resolve a service to get host and port
  Future<GatewayConnection?> _resolveService(String serviceName) async {
    try {
      // Query SRV record for host and port
      String? host;
      int? port;

      _log('debug', 'Querying SRV record for $serviceName');
      await for (final SrvResourceRecord srv in _mdnsClient!
          .lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(serviceName),
          )
          .timeout(const Duration(seconds: 5))) {
        host = srv.target;
        port = srv.port;
        _log('debug', 'SRV record received', details: 'host=$host, port=$port');
        break;
      }

      if (host == null || port == null) {
        _log('warning', 'No SRV record found for $serviceName');
        return null;
      }

      // Query TXT records for metadata
      Map<String, String> txtRecords = {};
      try {
        _log('debug', 'Querying TXT records for $serviceName');
        await for (final TxtResourceRecord txt in _mdnsClient!
            .lookup<TxtResourceRecord>(
              ResourceRecordQuery.text(serviceName),
            )
            .timeout(const Duration(seconds: 3))) {
          final text = txt.text;
          final parts = text.split('=');
          if (parts.length >= 2) {
            txtRecords[parts[0]] = parts.sublist(1).join('=');
          } else if (parts.length == 1 && parts[0].isNotEmpty) {
            txtRecords['info'] = parts[0];
          }
        }
      } catch (e) {
        // TXT records are optional
      }

      // Extract IP from host
      String ip = _extractIpFromHost(host);

      // If we couldn't extract IP, try to resolve hostname
      if (ip.isEmpty) {
        ip = host.replaceAll('.local.', '');
        try {
          final addresses = await InternetAddress.lookup(ip);
          if (addresses.isNotEmpty) {
            ip = addresses.first.address;
            _log('debug', 'Hostname resolved', details: '$host → $ip');
          }
        } catch (e) {
          _log('warning', 'Could not resolve hostname $ip',
              details: e.toString());
        }
      }

      // Build gateway connection
      final gatewayName = txtRecords['name'] ??
          txtRecords['hostname'] ??
          _extractGatewayName(serviceName);

      return GatewayConnection(
        name: gatewayName,
        url: 'http://$ip:$port',
        ip: ip,
        port: port,
        isOnline: true,
      );
    } catch (e) {
      _log('error', 'Error resolving service $serviceName',
          details: e.toString());
      return null;
    }
  }

  /// Extract IP from mDNS host name
  String _extractIpFromHost(String host) {
    final ipPattern = RegExp(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})');
    final match = ipPattern.firstMatch(host);
    if (match != null) {
      return match.group(1)!;
    }
    return '';
  }

  /// Scan ALL IPs in detected local subnets using parallel isolates
  Future<List<GatewayConnection>> _scanLocalSubnets() async {
    final List<GatewayConnection> found = [];

    _log('info', 'Detecting local network interfaces...');

    // Get all network interfaces
    final List<String> subnets = [];
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final firstOctet = int.parse(parts[0]);
              // Skip link-local and special ranges
              if (firstOctet == 127 || firstOctet == 169) continue;

              final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
              if (!subnets.contains(subnet)) {
                subnets.add(subnet);
                _log('debug', 'Detected subnet: $subnet.x (${interface.name})');
              }
            }
          }
        }
      }
    } catch (e) {
      _log('warning', 'Error detecting network interfaces',
          details: e.toString());
    }

    if (subnets.isEmpty) {
      _log('warning', 'No local subnets detected');
      return found;
    }

    // Build list of ALL IPs to scan in detected subnets
    final List<String> ipsToScan = [];
    for (final subnet in subnets) {
      for (int i = 1; i <= 254; i++) {
        ipsToScan.add('$subnet.$i');
      }
    }

    _log('info',
        'Scanning ${ipsToScan.length} IPs across ${subnets.length} subnet(s)');
    _totalIpsToScan += ipsToScan.length;

    // Scan using parallel isolates
    final results = await _scanIPsInParallel(ipsToScan, port: 18789);

    for (final result in results) {
      if (result.found && result.url != null) {
        final gateway = GatewayConnection(
          name: result.name ?? 'OpenClaw (${result.ip})',
          url: result.url!,
          ip: result.ip,
          port: 18789,
          isOnline: true,
        );
        if (!found.any((g) => g.url == gateway.url)) {
          found.add(gateway);
        }
      }
    }

    _log('info', 'Local subnet scan complete',
        details: 'Found ${found.length} gateway(s)');
    return found;
  }

  /// Scan common network ranges (fallback when subnet detection fails)
  Future<List<GatewayConnection>> _scanCommonNetworks() async {
    final List<GatewayConnection> found = [];

    _log('info', 'Scanning common network ranges...');

    // Build list of IPs to scan - common gateway positions
    final List<String> ipsToScan = [];

    // Common subnets with likely gateway positions
    final commonSubnets = [
      '192.168.0',
      '192.168.1',
      '192.168.2',
      '10.0.0',
      '10.0.1'
    ];
    final commonIds = [1, 2, 10, 50, 100, 101, 150, 200, 254];

    for (final subnet in commonSubnets) {
      for (final id in commonIds) {
        ipsToScan.add('$subnet.$id');
      }
    }

    _log('info', 'Scanning ${ipsToScan.length} IPs in common ranges');
    _totalIpsToScan += ipsToScan.length;

    // Scan using parallel isolates
    final results = await _scanIPsInParallel(ipsToScan, port: 18789);

    for (final result in results) {
      if (result.found && result.url != null) {
        final gateway = GatewayConnection(
          name: result.name ?? 'OpenClaw (${result.ip})',
          url: result.url!,
          ip: result.ip,
          port: 18789,
          isOnline: true,
        );
        if (!found.any((g) => g.url == gateway.url)) {
          found.add(gateway);
        }
      }
    }

    _log('info', 'Common range scan complete',
        details: 'Found ${found.length} gateway(s)');
    return found;
  }

  /// Scan Tailscale network range (100.64.0.0 - 100.127.255.255)
  Future<List<GatewayConnection>> _scanTailscale() async {
    final List<GatewayConnection> found = [];

    _log('info', 'Scanning Tailscale network...');

    // Build list of IPs to scan - focus on common Tailscale ranges
    // Tailscale uses 100.64.0.0/10 (100.64.0.0 - 100.127.255.255)
    // We'll scan a representative sample to keep scan time reasonable
    final List<String> ipsToScan = [];

    // Scan common Tailscale ranges (sample every 32 IPs to reduce scan time)
    for (int i = 64; i <= 127; i++) {
      for (int j = 0; j <= 255; j += 8) {
        // Sample every 8th
        for (int k = 1; k <= 254; k += 32) {
          // Sample every 32nd
          ipsToScan.add('100.$i.$j.$k');
        }
      }
    }

    // Also scan some common Tailscale gateway positions
    for (int i = 64; i <= 127; i++) {
      ipsToScan.add('100.$i.0.1');
      ipsToScan.add('100.$i.1.1');
    }

    // Remove duplicates
    final uniqueIps = ipsToScan.toSet().toList();

    _log('info', 'Scanning ${uniqueIps.length} IPs in Tailscale range');
    _totalIpsToScan += uniqueIps.length;

    // Scan using parallel isolates
    final results = await _scanIPsInParallel(uniqueIps, port: 18789);

    for (final result in results) {
      if (result.found && result.url != null) {
        final gateway = GatewayConnection(
          name: result.name ?? 'OpenClaw Tailscale (${result.ip})',
          url: result.url!,
          ip: result.ip,
          port: 18789,
          isOnline: true,
        );
        if (!found.any((g) => g.url == gateway.url)) {
          found.add(gateway);
        }
      }
    }

    _log('info', 'Tailscale scan complete',
        details: 'Found ${found.length} gateway(s)');
    return found;
  }

  /// Scan IPs in parallel using compute()
  Future<List<_ScanResult>> _scanIPsInParallel(List<String> ips,
      {required int port}) async {
    final List<_ScanResult> allResults = [];

    _log('debug', 'Scanning ${ips.length} IPs in parallel using compute()');

    // Process IPs in batches to avoid overwhelming the system
    for (int i = 0; i < ips.length; i += _isolateBatchSize) {
      final batch = ips.skip(i).take(_isolateBatchSize).toList();

      // Create futures for each IP in the batch
      final futures =
          batch.map((ip) => compute<_ScanIpParams, Map<String, dynamic>>(
                _checkGatewayIsolate,
                _ScanIpParams(ip: ip, port: port, timeoutMs: _ipTimeoutMs),
              ));

      // Wait for all scans in this batch
      final results = await Future.wait(futures);

      // Convert results back to _ScanResult objects
      for (final resultJson in results) {
        final result = _ScanResult.fromJson(resultJson);
        allResults.add(result);
      }

      // Update progress
      _ipsScanned += batch.length;
      final percent =
          _totalIpsToScan > 0 ? (_ipsScanned * 100 ~/ _totalIpsToScan) : 0;
      _updateProgress(
          percent, _ipsScanned, 'Scanned $_ipsScanned/$_totalIpsToScan IPs...');

      // Small delay to prevent overwhelming the system
      await Future.delayed(const Duration(milliseconds: 10));
    }

    return allResults;
  }

  /// Isolate function for checking a single gateway
  /// This runs in a separate isolate using compute()
  static Future<Map<String, dynamic>> _checkGatewayIsolate(
      _ScanIpParams params) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = Duration(milliseconds: params.timeoutMs);

      for (final endpoint in _probeEndpoints) {
        final request = await client
            .getUrl(Uri.parse('http://${params.ip}:${params.port}$endpoint'));
        final response = await request.close().timeout(
              Duration(milliseconds: params.timeoutMs),
            );

        if (response.statusCode != 200) {
          continue;
        }

        final body = await response.transform(utf8.decoder).join();
        try {
          final json = jsonDecode(body);
          if (endpoint == '/health' &&
              json is Map<String, dynamic> &&
              json['ok'] != true &&
              json['status'] != 'live') {
            continue;
          }
        } catch (e) {
          // Non-JSON bodies are acceptable for discovery as long as the
          // gateway responds successfully on a known endpoint.
        }

        return _ScanResult(
          ip: params.ip,
          found: true,
          url: 'http://${params.ip}:${params.port}',
          name: 'OpenClaw Gateway (${params.ip})',
        ).toJson();
      }

      return _ScanResult(ip: params.ip, found: false).toJson();
    } on TimeoutException {
      return _ScanResult(ip: params.ip, found: false, error: 'Timeout')
          .toJson();
    } catch (e) {
      return _ScanResult(ip: params.ip, found: false, error: e.toString())
          .toJson();
    }
  }

  /// Quick check if a host is running OpenClaw (non-isolate version)
  Future<GatewayConnection?> _quickCheckGateway(String ip, int port,
      {String? name}) async {
    return probeGatewayUrl('http://$ip:$port', name: name ?? 'OpenClaw ($ip)');
  }

  /// Probe a specific base URL using the same fallback endpoints as the app.
  Future<GatewayConnection?> probeGatewayUrl(
    String url, {
    String? name,
    String? token,
  }) async {
    try {
      final normalized =
          url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final uri = Uri.parse(normalized);
      final headers = token != null
          ? {'Authorization': 'Bearer $token'}
          : <String, String>{};

      for (final endpoint in _probeEndpoints) {
        final response = await http
            .get(
              Uri.parse('$normalized$endpoint'),
              headers: headers,
            )
            .timeout(const Duration(milliseconds: 1200));

        if (response.statusCode != 200) {
          continue;
        }

        if (endpoint == '/health') {
          try {
            final json = jsonDecode(response.body);
            if (json is Map<String, dynamic> &&
                json['ok'] != true &&
                json['status'] != 'live') {
              continue;
            }
          } catch (_) {
            // A successful health response is enough for discovery.
          }
        }

        return GatewayConnection(
          name: name ?? uri.host,
          url: normalized,
          ip: uri.host,
          port: uri.hasPort ? uri.port : 18789,
          token: token,
          isOnline: true,
        );
      }
    } catch (e) {
      // Intentionally silent for probing; callers handle misses.
    }
    return null;
  }

  /// Extract gateway name from mDNS service name
  String _extractGatewayName(String serviceName) {
    return serviceName
        .replaceAll('.$_serviceType.local.', '')
        .replaceAll('._openclaw-gw._tcp.local.', '')
        .replaceAll('._openclaw._tcp.local.', '')
        .replaceAll('.local.', '')
        .replaceAll('._tcp', '')
        .replaceAll('._openclaw-gw', '')
        .replaceAll('._openclaw', '');
  }

  /// Test connection to a gateway with detailed diagnostics
  Future<Map<String, dynamic>> testConnection(GatewayConnection gateway) async {
    _log('info', 'Testing connection to ${gateway.url}');

    const endpoints = _probeEndpoints;
    final errors = <String>[];

    for (final endpoint in endpoints) {
      try {
        final url = '${gateway.url}$endpoint';
        _log('debug', 'Trying endpoint: $url');

        final response = await http
            .get(
              Uri.parse(url),
              headers: gateway.token != null
                  ? {'Authorization': 'Bearer ${gateway.token}'}
                  : {},
            )
            .timeout(_connectionTimeout);

        if (response.statusCode == 200) {
          _log('success', 'Connection test passed for ${gateway.url}');
          return {
            'success': true,
            'endpoint': endpoint,
            'url': url,
          };
        } else {
          errors.add('$endpoint: HTTP ${response.statusCode}');
        }
      } on SocketException catch (e) {
        final errorMsg = _parseSocketError(e);
        errors.add('$endpoint: $errorMsg');
        _log('error', 'Socket error for $endpoint', details: errorMsg);
      } on TimeoutException {
        errors.add('$endpoint: Timeout');
        _log('warning', 'Timeout for $endpoint');
      } catch (e) {
        errors.add('$endpoint: ${e.toString()}');
        _log('error', 'Error for $endpoint', details: e.toString());
      }
    }

    _log('error', 'Connection test failed for ${gateway.url}');
    return {
      'success': false,
      'error': _getUserFriendlyError(errors),
      'details': errors.join('\n'),
      'endpoints_tried': endpoints,
    };
  }

  /// Parse socket error into user-friendly message
  String _parseSocketError(SocketException e) {
    final message = e.message.toLowerCase();
    final osErrorMessage = e.osError?.message;
    final osError = osErrorMessage?.toLowerCase() ?? '';

    if (message.contains('no route to host') ||
        osError.contains('no route to host')) {
      return 'No route to host - Gateway unreachable';
    }

    if (message.contains('connection refused') ||
        osError.contains('connection refused')) {
      return 'Connection refused - Gateway not listening';
    }

    if (message.contains('network is unreachable') ||
        osError.contains('network is unreachable')) {
      return 'Network unreachable - Check WiFi connection';
    }

    if (message.contains('timed out') || message.contains('timeout')) {
      return 'Connection timed out';
    }

    return e.message;
  }

  /// Get user-friendly error message from list of errors
  String _getUserFriendlyError(List<String> errors) {
    // Check for specific error patterns
    for (final error in errors) {
      if (error.contains('No route to host')) {
        return '''No route to host - The gateway is unreachable.

Troubleshooting:
1. Check that OpenClaw gateway is running:
   openclaw gateway status

2. Verify gateway is bound to LAN (not just localhost):
   openclaw gateway run --bind lan

3. Ensure phone and gateway are on the same network

4. Check firewall settings - port 18789 must be open''';
      }

      if (error.contains('Connection refused')) {
        return '''Connection refused - Gateway not listening.

Troubleshooting:
1. Start the gateway:
   openclaw gateway run

2. Check if port 18789 is in use:
   lsof -i :18789

3. Try a different port:
   openclaw gateway run --port 18790''';
      }

      if (error.contains('Network unreachable')) {
        return 'Network unreachable - Check that your phone is connected to WiFi';
      }

      if (error.contains('Timeout')) {
        return 'Connection timed out - Gateway may be slow or unreachable. Try again.';
      }
    }

    return 'Could not connect to gateway. Check the debug logs for details.';
  }

  /// Get connection history from storage
  Future<List<GatewayConnection>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);

    if (historyJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(historyJson);
      return decoded
          .map((item) =>
              GatewayConnection.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _log('error', 'Error loading history', details: e.toString());
      return [];
    }
  }

  /// Save connection to history
  Future<void> saveToHistory(GatewayConnection gateway) async {
    final history = await getHistory();

    // Remove existing entry with same URL if exists
    history.removeWhere((g) => g.url == gateway.url);

    // Add current connection with updated timestamp
    final updatedGateway = GatewayConnection(
      url: gateway.url,
      ip: gateway.ip,
      port: gateway.port,
      token: gateway.token,
      lastConnected: DateTime.now(),
      name: gateway.name,
      isOnline: gateway.isOnline,
    );

    history.insert(0, updatedGateway);

    // Keep only last N items
    while (history.length > _maxHistoryItems) {
      history.removeLast();
    }

    // Save to storage
    final prefs = await SharedPreferences.getInstance();
    final historyJson = jsonEncode(
      history.map((g) => g.toJson()).toList(),
    );
    await prefs.setString(_historyKey, historyJson);

    // Also save as last connected
    await prefs.setString(_lastConnectedKey, gateway.url);
    _log('info', 'Gateway saved to history: ${gateway.url}');
  }

  /// Remove a gateway from history
  Future<void> removeFromHistory(String url) async {
    final history = await getHistory();
    history.removeWhere((g) => g.url == url);

    final prefs = await SharedPreferences.getInstance();
    final historyJson = jsonEncode(
      history.map((g) => g.toJson()).toList(),
    );
    await prefs.setString(_historyKey, historyJson);
    _log('info', 'Gateway removed from history: $url');
  }

  /// Clear all history
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    await prefs.remove(_lastConnectedKey);
    _log('info', 'Connection history cleared');
  }

  /// Get the last connected gateway URL
  Future<String?> getLastConnectedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastConnectedKey);
  }

  /// Get the last connected gateway with full details
  Future<GatewayConnection?> getLastConnected() async {
    final history = await getHistory();
    return history.isNotEmpty ? history.first : null;
  }

  /// Dispose resources
  void dispose() {
    _isDisposed = true;
    stopBackgroundScan();
    _discoveredController.close();
    _logsController.close();
    _progressController.close();
    try {
      _mdnsClient?.stop();
    } catch (e) {
      // Ignore
    }
    _mdnsClient = null;
  }
}

/// Scan progress information
class ScanProgress {
  final int percent;
  final int scanned;
  final int total;
  final String status;

  ScanProgress({
    required this.percent,
    required this.scanned,
    required this.total,
    required this.status,
  });

  @override
  String toString() => 'ScanProgress($percent%, $scanned/$total, $status)';
}

// Helper for debug printing
void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}
