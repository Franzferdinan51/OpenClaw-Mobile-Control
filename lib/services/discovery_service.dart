import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:multicast_dns/multicast_dns.dart'; // Disabled - using simple scan instead
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gateway_status.dart';

/// Service for discovering OpenClaw gateways on the local network via mDNS/Bonjour
class DiscoveryService {
  static const String _serviceType = '_openclaw._tcp.local.';
  static const String _historyKey = 'gateway_history';
  static const int _maxHistoryItems = 5;
  static const Duration _scanTimeout = Duration(seconds: 5);

  Timer? _backgroundScanTimer;
  final StreamController<List<GatewayConnection>> _discoveredController =
      StreamController<List<GatewayConnection>>.broadcast();

  /// Stream of discovered gateways
  Stream<List<GatewayConnection>> get discoveredGateways =>
      _discoveredController.stream;

  /// Current list of discovered gateways
  List<GatewayConnection> _discovered = [];
  List<GatewayConnection> get discovered => _discovered;

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

  /// Scan for OpenClaw gateways on the local network
  /// Note: mDNS disabled - use manual entry or history instead
  Future<List<GatewayConnection>> scan() async {
    // mDNS discovery disabled - requires native platform support
    // Users can add gateways manually or use connection history
    final List<GatewayConnection> found = [];

    // Simple network scan could be added here in the future
    // For now, return empty list - manual entry will work

    _discovered = found;
    _discoveredController.add(found);
    return found;
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
  }

  /// Get the last connected gateway
  Future<GatewayConnection?> getLastConnected() async {
    final history = await getHistory();
    return history.isNotEmpty ? history.first : null;
  }

  /// Dispose resources
  void dispose() {
    stopBackgroundScan();
    _discoveredController.close();
  }
}