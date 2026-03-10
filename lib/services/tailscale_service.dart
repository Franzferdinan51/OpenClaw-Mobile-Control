import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gateway_status.dart';

/// Service for Tailscale integration - detect and connect via Tailscale
class TailscaleService {
  static const String _tailscaleKey = 'tailscale_config';
  static const String _tailscaleApiKey = 'tailscale_api_key';
  static const Duration _connectionTimeout = Duration(seconds: 5);
  static const Duration _scanTimeout = Duration(seconds: 10);

  /// Check if Tailscale is running on the device
  Future<bool> isTailscaleRunning() async {
    try {
      // Method 1: Check for Tailscale IP in network interfaces
      final interfaces = await NetworkInterface.list();

      for (final interface in interfaces) {
        // Check for Tailscale interface names
        final isTailscaleInterface = interface.name.contains('tailscale') ||
            interface.name.contains('ts0') ||
            interface.name == 'tun0';

        if (isTailscaleInterface) {
          // Check if it has a Tailscale IP (100.x.x.x range)
          for (final addr in interface.addresses) {
            if (addr.address.startsWith('100.') &&
                !_isPrivateRange(addr.address)) {
              return true;
            }
          }
        }

        // Method 2: Check any interface for Tailscale IP range
        for (final addr in interface.addresses) {
          if (addr.address.startsWith('100.')) {
            // Verify it's in Tailscale's CGNAT range (100.64.0.0/10)
            final parts = addr.address.split('.');
            if (parts.length >= 2) {
              final secondOctet = int.tryParse(parts[1]) ?? 0;
              // 100.64.0.0/10 means second octet 64-127
              if (secondOctet >= 64 && secondOctet <= 127) {
                return true;
              }
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

  /// Check if IP is in a private range (not Tailscale)
  bool _isPrivateRange(String ip) {
    // Exclude common private ranges that aren't Tailscale
    if (ip.startsWith('100.100.') || ip.startsWith('100.101.')) {
      return true; // These might be carrier-grade NAT, not Tailscale
    }
    return false;
  }

  /// Get device's Tailscale IP
  Future<String?> getTailscaleIp() async {
    try {
      final interfaces = await NetworkInterface.list();

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          // Tailscale uses 100.x.x.x range
          if (addr.address.startsWith('100.')) {
            // Verify it's in Tailscale's CGNAT range
            final parts = addr.address.split('.');
            if (parts.length >= 2) {
              final secondOctet = int.tryParse(parts[1]) ?? 0;
              if (secondOctet >= 64 && secondOctet <= 127) {
                return addr.address;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error getting Tailscale IP: $e');
    }
    return null;
  }

  /// Discover gateways via Tailscale network
  /// Combines saved gateways, mDNS over Tailscale, and network scan
  Future<List<GatewayConnection>> discoverTailscaleGateways() async {
    final List<GatewayConnection> found = [];

    if (!await isTailscaleRunning()) {
      print('Tailscale not running');
      return found;
    }

    try {
      // Get saved Tailscale gateway URLs first
      final savedGateways = await getSavedTailscaleGateways();

      // Test saved gateways first
      for (final gateway in savedGateways) {
        try {
          final canConnect = await testTailscaleConnection(gateway);
          if (canConnect) {
            found.add(gateway.copyWith(isOnline: true));
          }
        } catch (e) {
          print('Error testing saved gateway ${gateway.url}: $e');
        }
      }

      // Scan Tailscale IP range for OpenClaw instances
      await _scanTailscaleRange(found);

      // Try mDNS over Tailscale if available
      final mdnsGateways = await _discoverMdnsOverTailscale();
      for (final gateway in mdnsGateways) {
        if (!found.any((g) => g.url == gateway.url)) {
          found.add(gateway);
        }
      }
    } catch (e) {
      print('Error during Tailscale discovery: $e');
    }

    return found;
  }

  /// Try to discover gateways via mDNS over Tailscale
  Future<List<GatewayConnection>> _discoverMdnsOverTailscale() async {
    final List<GatewayConnection> found = [];

    try {
      // Try to query Tailscale's MagicDNS for OpenClaw services
      // This requires the gateway to be advertising via mDNS on the Tailscale interface
      final myIp = await getTailscaleIp();
      if (myIp == null) return found;

      // Extract Tailscale network prefix (first 2 octets)
      final parts = myIp.split('.');
      if (parts.length < 2) return found;

      final basePrefix = '${parts[0]}.${parts[1]}';

      // Common hostnames that might be OpenClaw gateways
      final commonHostnames = [
        'openclaw',
        'openclaw-gw',
        'gateway',
        'claw',
        'duckbot',
        'server',
        'home',
        'pi',
        'nas',
      ];

      final futures = <Future<void>>[];

      for (final hostname in commonHostnames) {
        // Try to resolve hostname.openclaw.ts.net or similar
        final fqdn = '$hostname.${parts[1]}.ts.net';
        futures.add(_tryResolveHostname(fqdn, found));

        // Also try direct IP patterns
        for (int third = 0; third <= 255; third += 50) {
          for (int fourth = 1; fourth <= 254; fourth += 50) {
            final ip = '$basePrefix.$third.$fourth';
            if (ip == myIp) continue;
            futures.add(_scanSingleIp(ip, found));
          }
        }
      }

      // Run limited parallel scans
      await Future.wait(futures.take(20));
    } catch (e) {
      print('mDNS over Tailscale error: $e');
    }

    return found;
  }

  /// Try to resolve a hostname
  Future<void> _tryResolveHostname(String hostname, List<GatewayConnection> found) async {
    try {
      final result = await InternetAddress.lookup(hostname).timeout(const Duration(seconds: 2));
      if (result.isNotEmpty) {
        final ip = result.first.address;
        final gateway = GatewayConnection(
          url: 'http://$ip:18789',
          name: 'Tailscale ($hostname)',
          ip: ip,
          port: 18789,
        );

        if (await testTailscaleConnection(gateway)) {
          found.add(gateway.copyWith(isOnline: true));
        }
      }
    } catch (e) {
      // Ignore resolution failures
    }
  }

  /// Scan Tailscale IP range for OpenClaw instances
  Future<void> _scanTailscaleRange(List<GatewayConnection> found) async {
    final myIp = await getTailscaleIp();
    if (myIp == null) return;

    // Extract first two octets (100.x)
    final parts = myIp.split('.');
    if (parts.length < 2) return;

    final baseIp = '${parts[0]}.${parts[1]}';

    // Scan common third octet ranges (simplified scan)
    final commonThirdOctets = [0, 1, 10, 50, 100, 200];
    final commonFourthOctets = [1, 2, 50, 100];

    // Create a list of futures for parallel scanning
    final List<Future<void>> scanFutures = [];

    for (final third in commonThirdOctets) {
      for (final fourth in commonFourthOctets) {
        final ip = '$baseIp.$third.$fourth';

        // Skip self
        if (ip == myIp) continue;

        // Skip already found
        if (found.any((g) => g.ip == ip)) continue;

        scanFutures.add(_scanSingleIp(ip, found));
      }
    }

    // Run scans in parallel with a limit
    await Future.wait(scanFutures);
  }

  /// Scan a single IP for OpenClaw
  Future<void> _scanSingleIp(String ip, List<GatewayConnection> found) async {
    try {
      final gateway = GatewayConnection(
        url: 'http://$ip:18789',
        name: 'Tailscale Gateway ($ip)',
        ip: ip,
        port: 18789,
      );

      final canConnect = await testTailscaleConnection(gateway);
      if (canConnect) {
        found.add(gateway.copyWith(isOnline: true));
      }
    } catch (e) {
      // Silently ignore connection failures during scan
    }
  }

  /// Test connection to a Tailscale gateway
  Future<bool> testTailscaleConnection(GatewayConnection gateway) async {
    try {
      // Try the mobile status endpoint first
      var response = await http.get(
        Uri.parse('${gateway.url}/api/mobile/status'),
        headers: {
          if (gateway.token != null) 'Authorization': 'Bearer ${gateway.token}',
        },
      ).timeout(_connectionTimeout);

      if (response.statusCode == 200) {
        return true;
      }

      // Fallback to root endpoint
      response = await http.get(
        Uri.parse(gateway.url),
        headers: {
          if (gateway.token != null) 'Authorization': 'Bearer ${gateway.token}',
        },
      ).timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      // Silently fail - don't print for every failed scan
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
  /// - 100.116.54.125:18789
  /// - 100.116.54.125 (defaults to port 18789)
  /// - node.tailnet-name.ts.net
  static GatewayConnection? parseTailscaleUrl(String input, {String? name, String? token}) {
    // Clean up input
    String url = input.trim();

    // Remove trailing slashes
    url = url.replaceAll(RegExp(r'/+$'), '');

    // Add protocol if missing
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // Check if it's an IP address (starts with 100.)
      if (url.startsWith('100.')) {
        url = 'http://$url'; // Use HTTP for Tailscale IPs
      } else {
        url = 'https://$url'; // Use HTTPS for domain names
      }
    }

    // Add default port for Tailscale IPs if not specified
    if (url.startsWith('http://100.') && !url.contains(':')) {
      url = '$url:18789';
    }

    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // Check if it's a Tailscale URL
    final isTailscale = uri.host.startsWith('100.') ||
                        uri.host.endsWith('.ts.net') ||
                        uri.host.contains('.tailscale');

    if (!isTailscale) return null;

    // Determine port
    int port;
    if (uri.hasPort) {
      port = uri.port;
    } else if (uri.scheme == 'https') {
      port = 443;
    } else {
      port = 18789; // Default OpenClaw port
    }

    // Generate display name
    String displayName = name ?? '';
    if (displayName.isEmpty) {
      if (uri.host.startsWith('100.')) {
        displayName = 'Tailscale (${uri.host})';
      } else {
        displayName = uri.host.split('.').first;
      }
    }

    return GatewayConnection(
      name: displayName,
      url: url,
      ip: uri.host.startsWith('100.') ? uri.host : null,
      port: port,
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
    await prefs.remove(_tailscaleApiKey);
  }

  /// Save Tailscale API key for advanced features
  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tailscaleApiKey, apiKey);
  }

  /// Get Tailscale API key
  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tailscaleApiKey);
  }
}
