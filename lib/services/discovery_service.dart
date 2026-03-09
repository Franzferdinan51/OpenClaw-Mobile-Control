import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:multicast_dns/multicast_dns.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gateway_status.dart';

/// Service for discovering OpenClaw gateways on the local network via mDNS/Bonjour
class DiscoveryService {
  static const String _serviceType = '_openclaw._tcp.local.';
  static const String _historyKey = 'gateway_history';
  static const String _lastConnectedKey = 'last_connected_gateway';
  static const int _maxHistoryItems = 5;
  static const Duration _scanTimeout = Duration(seconds: 5);

  final MDnsClient _mdnsClient = MDnsClient();
  Timer? _backgroundScanTimer;
  bool _isScanning = false;
  
  final StreamController<List<GatewayConnection>> _discoveredController =
      StreamController<List<GatewayConnection>>.broadcast();

  /// Stream of discovered gateways
  Stream<List<GatewayConnection>> get discoveredGateways =>
      _discoveredController.stream;

  /// Current list of discovered gateways
  List<GatewayConnection> _discovered = [];
  List<GatewayConnection> get discovered => List.unmodifiable(_discovered);

  /// Start background scanning (every 30 seconds)
  void startBackgroundScan() {
    // Initial scan
    scan();
    
    // Set up periodic scanning
    _backgroundScanTimer?.cancel();
    _backgroundScanTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => scan(),
    );
  }

  /// Stop background scanning
  void stopBackgroundScan() {
    _backgroundScanTimer?.cancel();
    _backgroundScanTimer = null;
  }

  /// Scan for OpenClaw gateways on the local network via mDNS
  Future<List<GatewayConnection>> scan() async {
    if (_isScanning) {
      // Already scanning, wait for result
      await Future.delayed(const Duration(milliseconds: 500));
      return _discovered;
    }

    _isScanning = true;
    final List<GatewayConnection> found = [];

    try {
      // Start mDNS client
      await _mdnsClient.start();
      
      // Look for OpenClaw service via PTR records
      await for (final PtrResourceRecord ptr in _mdnsClient.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(_serviceType),
      )) {
        final serviceName = ptr.domainName;
        
        // Query for SRV record to get host and port
        await for (final SrvResourceRecord srv in _mdnsClient.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(serviceName),
        )) {
          final host = srv.target;
          final port = srv.port;
          
          // Extract IP from host name (e.g., "192.168.1.100.local.")
          String ip = _extractIpFromHost(host);
          
          // If we couldn't extract IP, try TXT records for additional info
          if (ip.isEmpty) {
            // Use hostname as-is, connection will resolve it
            ip = host.replaceAll('.local.', '');
          }
          
          final gateway = GatewayConnection(
            name: _extractGatewayName(serviceName),
            url: 'http://$ip:$port',
            ip: ip,
            port: port,
            isOnline: true,
          );
          
          // Avoid duplicates
          if (!found.any((g) => g.url == gateway.url)) {
            // Verify connection in background
            found.add(gateway);
          }
        }
      }
      
      _discovered = found;
    } catch (e) {
      print('mDNS scan error: $e');
      // Fall back to simple network scan
      _discovered = await _simpleNetworkScan();
    } finally {
      _isScanning = false;
      _mdnsClient.stop();
    }

    _discoveredController.add(_discovered);
    return _discovered;
  }

  /// Extract IP from mDNS host name
  String _extractIpFromHost(String host) {
    // Common patterns:
    // - "192.168.1.100.local." -> "192.168.1.100"
    // - "openclaw-gateway.local." -> "" (need to resolve)
    
    final ipPattern = RegExp(r'^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})');
    final match = ipPattern.firstMatch(host);
    if (match != null) {
      return match.group(1)!;
    }
    
    // If hostname is not an IP, return empty - will be resolved during connection
    return '';
  }

  /// Simple network scan as fallback (scans common ports on local subnet)
  Future<List<GatewayConnection>> _simpleNetworkScan() async {
    final List<GatewayConnection> found = [];
    
    try {
      // Get local IP to determine subnet
      final interfaces = await NetworkInterface.list();
      String? localSubnet;
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          // Look for IPv4 address on local network
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              localSubnet = '${parts[0]}.${parts[1]}.${parts[2]}';
              break;
            }
          }
        }
        if (localSubnet != null) break;
      }
      
      if (localSubnet == null) {
        print('Could not determine local subnet');
        return found;
      }
      
      print('Scanning subnet: $localSubnet.x');
      
      // Quick scan of common IPs on port 18789
      final futures = <Future<GatewayConnection?>>[];
      
      for (int i = 1; i < 255; i++) {
        final ip = '$localSubnet.$i';
        futures.add(_quickCheckGateway(ip, 18789));
        
        // Limit concurrent scans to avoid overwhelming network
        if (futures.length >= 20) {
          final results = await Future.wait(futures);
          for (final result in results) {
            if (result != null) found.add(result);
          }
          futures.clear();
        }
      }
      
      // Wait for remaining scans
      if (futures.isNotEmpty) {
        final results = await Future.wait(futures);
        for (final result in results) {
          if (result != null) found.add(result);
        }
      }
      
      print('Network scan found ${found.length} gateways');
    } catch (e) {
      print('Network scan error: $e');
    }
    
    return found;
  }

  /// Quick check if a host is running OpenClaw
  Future<GatewayConnection?> _quickCheckGateway(String ip, int port) async {
    try {
      final url = 'http://$ip:$port';
      final response = await http.get(
        Uri.parse('$url/api/mobile/status'),
      ).timeout(const Duration(milliseconds: 500));
      
      if (response.statusCode == 200) {
        return GatewayConnection(
          name: 'OpenClaw ($ip)',
          url: url,
          ip: ip,
          port: port,
          isOnline: true,
        );
      }
    } catch (e) {
      // Ignore connection failures
    }
    return null;
  }

  /// Extract gateway name from mDNS service name
  String _extractGatewayName(String serviceName) {
    // Remove service type suffix
    return serviceName
        .replaceAll('.$_serviceType', '')
        .replaceAll('._openclaw._tcp.local.', '')
        .replaceAll('.local.', '')
        .replaceAll('._tcp', '')
        .replaceAll('._openclaw', '');
  }

  /// Test connection to a gateway
  Future<bool> testConnection(GatewayConnection gateway) async {
    try {
      final url = gateway.url;
      final response = await http.get(
        Uri.parse('$url/api/mobile/status'),
        headers: {
          if (gateway.token != null) 'Authorization': 'Bearer ${gateway.token}',
        },
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
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
      print('Error loading history: $e');
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
  }

  /// Clear all history
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    await prefs.remove(_lastConnectedKey);
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
    stopBackgroundScan();
    _discoveredController.close();
    _mdnsClient.stop();
  }
}