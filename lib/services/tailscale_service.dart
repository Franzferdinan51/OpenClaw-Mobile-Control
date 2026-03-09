import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gateway_status.dart';

/// Service for Tailscale integration - detect and connect via Tailscale
class TailscaleService {
  static const String _tailscaleKey = 'tailscale_config';
  
  /// Check if Tailscale is running on the device
  Future<bool> isTailscaleRunning() async {
    try {
      // On Android, we can check if Tailscale VPN is active
      // This is a simplified check - actual implementation may need platform channels
      final interfaces = await NetworkInterface.list();
      
      for (final interface in interfaces) {
        // Tailscale typically creates a 'tailscale0' or 'ts0' interface
        // On Android, it may appear as 'tun0' or similar
        if (interface.name.contains('tailscale') || 
            interface.name.contains('ts') ||
            interface.name == 'tun0') {
          // Check if it has a Tailscale IP (100.x.x.x range)
          for (final addr in interface.addresses) {
            if (addr.address.startsWith('100.')) {
              return true;
            }
          }
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking Tailscale status: $e');
      return false;
    }
  }

  /// Get device's Tailscale IP
  Future<String?> getTailscaleIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          // Tailscale uses 100.x.x.x range
          if (addr.address.startsWith('100.')) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error getting Tailscale IP: $e');
    }
    return null;
  }

  /// Discover gateways via Tailscale network
  /// This scans the Tailscale network for OpenClaw instances
  Future<List<GatewayConnection>> discoverTailscaleGateways() async {
    final List<GatewayConnection> found = [];
    
    if (!await isTailscaleRunning()) {
      print('Tailscale not running');
      return found;
    }
    
    // Get saved Tailscale gateway URLs
    final savedGateways = await getSavedTailscaleGateways();
    
    for (final gateway in savedGateways) {
      final canConnect = await _testTailscaleConnection(gateway);
      if (canConnect) {
        found.add(gateway);
      }
    }
    
    // Also try to scan the Tailscale network
    // Note: Full network scanning on Tailscale would require knowing the tailnet
    // For now, we rely on saved gateways + manual entry
    
    return found;
  }

  /// Test connection to a Tailscale gateway
  Future<bool> _testTailscaleConnection(GatewayConnection gateway) async {
    try {
      final response = await http.get(
        Uri.parse('${gateway.url}/api/mobile/status'),
        headers: {
          if (gateway.token != null) 'Authorization': 'Bearer ${gateway.token}',
        },
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('Tailscale connection test failed: $e');
      return false;
    }
  }

  /// Save a Tailscale gateway
  Future<void> saveTailscaleGateway(GatewayConnection gateway) async {
    final prefs = await SharedPreferences.getInstance();
    final config = await _getTailscaleConfig();
    
    // Add or update gateway
    config.removeWhere((g) => g['url'] == gateway.url);
    config.insert(0, gateway.toJson());
    
    // Keep max 10
    while (config.length > 10) {
      config.removeLast();
    }
    
    await prefs.setString(_tailscaleKey, jsonEncode(config));
  }

  /// Get saved Tailscale gateways
  Future<List<GatewayConnection>> getSavedTailscaleGateways() async {
    final config = await _getTailscaleConfig();
    return config
        .map((json) => GatewayConnection.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Remove a Tailscale gateway
  Future<void> removeTailscaleGateway(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final config = await _getTailscaleConfig();
    
    config.removeWhere((g) => g['url'] == url);
    
    await prefs.setString(_tailscaleKey, jsonEncode(config));
  }

  /// Parse Tailscale Serve/Funnel URL
  /// Examples:
  /// - https://node.tailnet-name.ts.net
  /// - http://100.116.54.125:18789
  static GatewayConnection? parseTailscaleUrl(String input, {String? name, String? token}) {
    // Clean up input
    String url = input.trim();
    
    // Add protocol if missing
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    
    // Check if it's a Tailscale URL
    final isTailscale = uri.host.startsWith('100.') || 
                        uri.host.endsWith('.ts.net') ||
                        uri.host.contains('.tailscale');
    
    if (!isTailscale) return null;
    
    return GatewayConnection(
      name: name ?? uri.host.split('.').first,
      url: url,
      ip: uri.host.startsWith('100.') ? uri.host : null,
      port: uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80),
      token: token,
      isOnline: true, // Will be verified on connection test
    );
  }

  /// Get raw Tailscale config from storage
  Future<List<Map<String, dynamic>>> _getTailscaleConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString(_tailscaleKey);
    
    if (configJson == null) return [];
    
    try {
      final List<dynamic> decoded = jsonDecode(configJson);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Error loading Tailscale config: $e');
      return [];
    }
  }

  /// Clear all Tailscale configuration
  Future<void> clearTailscaleConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tailscaleKey);
  }
}