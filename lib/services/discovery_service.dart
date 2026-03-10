import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gateway_status.dart';

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
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}';
    final icon = {
      'info': 'ℹ️',
      'success': '✅',
      'warning': '⚠️',
      'error': '❌',
      'debug': '🔍',
    }[level] ?? '📝';
    return '[$time] $icon $message${details != null ? '\n  → $details' : ''}';
  }
}

/// Service for discovering OpenClaw gateways on the local network
/// 
/// IMPLEMENTATION NOTES (from studying reference repos):
/// - mDNS is a CONVENIENCE feature, not primary connection method
/// - Manual entry with IP:port is the MOST RELIABLE method
/// - Android Bionic libc can cause issues with networkInterfaces()
/// - Localhost (127.0.0.1) binding is used when gateway runs on device
/// - Network scanning is a fallback when mDNS fails
class DiscoveryService {
  // OpenClaw gateway advertises as _openclaw-gw._tcp
  static const String _serviceType = '_openclaw-gw._tcp';
  static const String _historyKey = 'gateway_history';
  static const String _lastConnectedKey = 'last_connected_gateway';
  static const int _maxHistoryItems = 10;
  static const Duration _scanTimeout = Duration(seconds: 8);
  static const Duration _connectionTimeout = Duration(seconds: 5);

  MDnsClient? _mdnsClient;
  Timer? _backgroundScanTimer;
  bool _isScanning = false;
  bool _isDisposed = false;

  // Debug logging
  final List<DiscoveryLogEntry> _logs = [];
  final StreamController<List<DiscoveryLogEntry>> _logsController =
      StreamController<List<DiscoveryLogEntry>>.broadcast();
  final int _maxLogs = 200;

  final StreamController<List<GatewayConnection>> _discoveredController =
      StreamController<List<GatewayConnection>>.broadcast();

  /// Stream of discovered gateways
  Stream<List<GatewayConnection>> get discoveredGateways =>
      _discoveredController.stream;

  /// Stream of discovery logs
  Stream<List<DiscoveryLogEntry>> get logs => _logsController.stream;

  /// Current list of discovered gateways
  List<GatewayConnection> _discovered = [];
  List<GatewayConnection> get discovered => List.unmodifiable(_discovered);

  /// Get all logs
  List<DiscoveryLogEntry> get allLogs => List.unmodifiable(_logs);

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
    debugPrint('[DiscoveryService] $message${details != null ? ' | $details' : ''}');
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

  /// Start background scanning (every 60 seconds - less aggressive)
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
  /// PRIORITY ORDER (based on reference implementations):
  /// 1. mDNS/Bonjour discovery (if available)
  /// 2. Localhost check (127.0.0.1:18789) - for on-device gateway
  /// 3. Common network ranges scan (fallback)
  Future<List<GatewayConnection>> scan() async {
    if (_isDisposed) return _discovered;

    if (_isScanning) {
      _log('info', 'Scan already in progress, returning cached results');
      return _discovered;
    }

    _isScanning = true;
    clearLogs();
    _log('info', '🔍 Starting gateway discovery...', 
        details: 'Service type: $_serviceType');

    final List<GatewayConnection> found = [];

    try {
      // STEP 1: Check localhost first (fastest - for on-device gateway)
      _log('info', 'Step 1: Checking localhost (127.0.0.1:18789)');
      final localhostGateway = await _checkLocalhost();
      if (localhostGateway != null) {
        found.add(localhostGateway);
        _log('success', 'Gateway found on localhost!', details: localhostGateway.url);
      }

      // STEP 2: Try mDNS discovery
      _log('info', 'Step 2: Starting mDNS discovery');
      try {
        final mdnsGateways = await _scanMdns();
        for (final gateway in mdnsGateways) {
          if (!found.any((g) => g.url == gateway.url)) {
            found.add(gateway);
            _log('success', 'Gateway found via mDNS', details: gateway.url);
          }
        }
      } catch (e) {
        _log('warning', 'mDNS discovery failed', details: e.toString());
      }

      // STEP 3: Network scan fallback (if mDNS found nothing new)
      if (found.isEmpty) {
        _log('warning', 'No gateways found yet, trying network scan');
        final networkGateways = await _scanCommonNetworks();
        for (final gateway in networkGateways) {
          if (!found.any((g) => g.url == gateway.url)) {
            found.add(gateway);
            _log('success', 'Gateway found via network scan', details: gateway.url);
          }
        }
      }

      _discovered = found;
      if (found.isNotEmpty) {
        _log('success', 'Discovery complete!', 
            details: '${found.length} gateway(s) found: ${found.map((g) => g.url).join(", ")}');
      } else {
        _log('warning', 'Discovery complete - no gateways found', 
            details: 'Use Manual tab to enter gateway IP directly');
      }
    } catch (e, stackTrace) {
      _log('error', 'Discovery error', details: '$e');
      _discovered = found;
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

  /// Check localhost for on-device gateway
  Future<GatewayConnection?> _checkLocalhost() async {
    return await _quickCheckGateway('127.0.0.1', 18789, name: 'Local Gateway (This Device)');
  }

  /// Scan using mDNS/Bonjour
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
            _log('warning', 'Error listing network interfaces', details: e.toString());
            return [];
          }
        },
      );
      _log('success', 'mDNS client started');

      // Query for PTR records
      _log('info', 'Querying mDNS PTR records...');
      final ptrRecords = await _queryPtrRecords();
      _log('info', 'PTR query complete', details: 'Found ${ptrRecords.length} service(s)');

      // Resolve each service
      for (final serviceName in ptrRecords) {
        try {
          _log('info', 'Resolving service: $serviceName');
          final gateway = await _resolveService(serviceName);
          if (gateway != null && !found.any((g) => g.url == gateway.url)) {
            found.add(gateway);
          }
        } catch (e) {
          _log('warning', 'Error resolving service $serviceName', details: e.toString());
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
      await for (final PtrResourceRecord ptr in _mdnsClient!.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('$_serviceType.local.'),
      ).timeout(_scanTimeout)) {
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
      await for (final SrvResourceRecord srv in _mdnsClient!.lookup<SrvResourceRecord>(
        ResourceRecordQuery.service(serviceName),
      ).timeout(const Duration(seconds: 5))) {
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
        await for (final TxtResourceRecord txt in _mdnsClient!.lookup<TxtResourceRecord>(
          ResourceRecordQuery.text(serviceName),
        ).timeout(const Duration(seconds: 3))) {
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
          _log('warning', 'Could not resolve hostname $ip', details: e.toString());
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
      _log('error', 'Error resolving service $serviceName', details: e.toString());
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

  /// Scan common network ranges
  Future<List<GatewayConnection>> _scanCommonNetworks() async {
    final List<GatewayConnection> found = [];

    _log('info', 'Scanning common network ranges...');

    // Get local IP to determine subnet
    String? localSubnet;
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
              
              localSubnet = '${parts[0]}.${parts[1]}.${parts[2]}';
              _log('debug', 'Local subnet detected: $localSubnet.x');
              break;
            }
          }
        }
        if (localSubnet != null) break;
      }
    } catch (e) {
      _log('warning', 'Error detecting local subnet', details: e.toString());
    }

    // Build list of IPs to scan
    final List<String> ipsToScan = [];

    // 1. Local subnet if detected
    if (localSubnet != null) {
      final commonIds = [1, 2, 10, 50, 100, 101, 150, 200, 254];
      for (final id in commonIds) {
        ipsToScan.add('$localSubnet.$id');
      }
    }

    // 2. Common default subnets
    final commonSubnets = ['192.168.0', '192.168.1', '192.168.2', '10.0.0'];
    for (final subnet in commonSubnets) {
      final commonIds = [1, 2, 10, 50, 100, 101, 150, 200, 254];
      for (final id in commonIds) {
        final ip = '$subnet.$id';
        if (!ipsToScan.contains(ip)) {
          ipsToScan.add(ip);
        }
      }
    }

    // 3. Tailscale range (sample)
    for (int i = 64; i <= 127; i += 32) {
      for (int j = 1; j <= 50; j += 10) {
        final ip = '100.$i.$j.1';
        if (!ipsToScan.contains(ip)) {
          ipsToScan.add(ip);
        }
      }
    }

    _log('info', 'Scanning ${ipsToScan.length} IPs...');

    // Scan in parallel batches
    const batchSize = 8;
    for (int i = 0; i < ipsToScan.length; i += batchSize) {
      final batch = ipsToScan.skip(i).take(batchSize).toList();
      final futures = batch.map((ip) => _quickCheckGateway(ip, 18789)).toList();
      final results = await Future.wait(futures);

      for (final result in results) {
        if (result != null && !found.any((g) => g.url == result.url)) {
          found.add(result);
          _log('success', 'Gateway found!', details: result.url);
        }
      }
    }

    if (found.isEmpty) {
      _log('warning', 'Network scan complete - no gateways found');
    } else {
      _log('success', 'Network scan complete', details: 'Found ${found.length} gateway(s)');
    }

    return found;
  }

  /// Quick check if a host is running OpenClaw
  Future<GatewayConnection?> _quickCheckGateway(String ip, int port, {String? name}) async {
    try {
      final url = 'http://$ip:$port';
      final response = await http.get(
        Uri.parse('$url/api/mobile/status'),
      ).timeout(const Duration(milliseconds: 1000));

      if (response.statusCode == 200) {
        return GatewayConnection(
          name: name ?? 'OpenClaw ($ip)',
          url: url,
          ip: ip,
          port: port,
          isOnline: true,
        );
      }
    } catch (e) {
      // Connection failed - don't log every failure to avoid spam
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

  /// Test connection to a gateway
  Future<bool> testConnection(GatewayConnection gateway) async {
    _log('info', 'Testing connection to ${gateway.url}');
    try {
      final url = gateway.url;
      final response = await http.get(
        Uri.parse('$url/api/mobile/status'),
        headers: {
          if (gateway.token != null) 'Authorization': 'Bearer ${gateway.token}',
        },
      ).timeout(_connectionTimeout);

      final success = response.statusCode == 200;
      if (success) {
        _log('success', 'Connection test passed for ${gateway.url}');
      } else {
        _log('error', 'Connection test failed', details: 'HTTP ${response.statusCode}');
      }
      return success;
    } catch (e) {
      _log('error', 'Connection test failed for ${gateway.url}', details: e.toString());
      return false;
    }
  }

  /// Get connection history from storage
  Future<List<GatewayConnection>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_historyKey);

    if (historyJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(historyJson);
      return decoded
          .map((item) => GatewayConnection.fromJson(item as Map<String, dynamic>))
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
    try {
      _mdnsClient?.stop();
    } catch (e) {
      // Ignore
    }
    _mdnsClient = null;
  }
}

// Helper for debug printing
void debugPrint(String message) {
  // ignore: avoid_print
  print(message);
}
