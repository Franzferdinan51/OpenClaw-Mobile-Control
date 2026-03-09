import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// Discovery Service - mDNS network scanning for OpenClaw Gateways
/// 
/// Automatically discovers OpenClaw Gateway instances on the local network
/// using mDNS/Bonjour protocol.
class DiscoveryService {
  static DiscoveryService? _instance;

  final void Function(String level, String message, [dynamic data])? onLog;

  // mDNS service types to discover
  static const String _openclawServiceType = '_openclaw._tcp';
  static const String _httpServiceType = '_http._tcp';
  static const String _httpsServiceType = '_https._tcp';

  // Network info
  final NetworkInfoPlus _networkInfo = NetworkInfoPlus();

  // Discovery state
  bool _isDiscovering = false;
  final List<DiscoveredGateway> _discoveredGateways = [];
  final StreamController<List<DiscoveredGateway>> _gatewaysController =
      StreamController<List<DiscoveredGateway>>.broadcast();

  // Known gateways (for persistence)
  final Map<String, DiscoveredGateway> _knownGateways = {};

  factory DiscoveryService() {
    _instance ??= DiscoveryService._internal();
    return _instance!;
  }

  DiscoveryService._internal();

  // ==================== Getters ====================

  /// Whether discovery is currently running
  bool get isDiscovering => _isDiscovering;

  /// Currently discovered gateways
  List<DiscoveredGateway> get gateways => List.unmodifiable(_discoveredGateways);

  /// Stream of discovered gateways
  Stream<List<DiscoveredGateway>> get gatewaysStream => _gatewaysController.stream;

  /// Known gateways (persisted across discoveries)
  Map<String, DiscoveredGateway> get knownGateways =>
      Map.unmodifiable(_knownGateways);

  // ==================== Discovery ====================

  /// Start mDNS discovery for OpenClaw Gateways
  Future<List<DiscoveredGateway>> discover({
    Duration timeout = const Duration(seconds: 10),
    bool includeHttp = true,
  }) async {
    if (_isDiscovering) {
      _log('warn', 'Discovery already in progress');
      return gateways;
    }

    _isDiscovering = true;
    _discoveredGateways.clear();
    _notifyGatewaysChanged();

    _log('info', 'Starting discovery (timeout: ${timeout.inSeconds}s)');

    try {
      // Get local network info
      final networkInfo = await _getLocalNetworkInfo();
      _log('debug', 'Local network: $networkInfo');

      // Simplified: Skip mDNS discovery for now
      // TODO: Re-enable mDNS when multicast_dns package issues are fixed
      _log('info', 'Discovery complete: found ${_discoveredGateways.length} gateways');
    } catch (e) {
      _log('error', 'Discovery failed', e);
    } finally {
      _isDiscovering = false;
    }

    _log('info', 'Discovery complete: found ${_discoveredGateways.length} gateways');
    return gateways;
  }

  Future<void> _discoverServiceType(
    MDnsClient client,
    String serviceType,
    Duration timeout,
  ) async {
    _log('debug', 'Scanning for $serviceType');

    final completer = Completer<void>();

    Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      client.start();

      final subscription = client.lookup<SRVResourceRecord>(
        ResourceRecordQuery.serverPointer(serviceType),
      ).listen((record) async {
        _log('debug', 'Found SRV record: ${record.name}');

        // Resolve the service
        await _resolveService(client, record, serviceType);
      });

      subscription.onDone(() {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

      await completer.future;
      await subscription.cancel();
    } catch (e) {
      _log('error', 'Service type scan failed: $serviceType', e);
    }
  }

  Future<void> _resolveService(
    MDnsClient client,
    SRVResourceRecord srvRecord,
    String serviceType,
  ) async {
    try {
      // Resolve host to IP addresses
      final addresses = await _resolveHost(srvRecord.target);

      if (addresses.isEmpty) {
        _log('warn', 'Could not resolve host: ${srvRecord.target}');
        return;
      }

      // Determine if this is an OpenClaw gateway
      final isKnownOpenClaw = serviceType == _openclawServiceType ||
          srvRecord.name.toLowerCase().contains('openclaw');

      // Create gateway object
      final gateway = DiscoveredGateway(
        id: _generateId(srvRecord.target, srvRecord.port),
        name: _extractName(srvRecord.name),
        host: addresses.first,
        port: srvRecord.port,
        serviceType: serviceType,
        isOpenClaw: isKnownOpenClaw,
        discoveredAt: DateTime.now(),
        metadata: {
          'hostname': srvRecord.target,
          'allAddresses': addresses,
          'priority': srvRecord.priority,
          'weight': srvRecord.weight,
        },
      );

      // Add to discovered list
      if (!_discoveredGateways.any((g) => g.id == gateway.id)) {
        _discoveredGateways.add(gateway);
        _knownGateways[gateway.id] = gateway;
        _notifyGatewaysChanged();
        _log('info', 'Discovered: ${gateway.name} at ${gateway.host}:${gateway.port}');
      }
    } catch (e) {
      _log('error', 'Failed to resolve service: ${srvRecord.name}', e);
    }
  }

  Future<List<String>> _resolveHost(String hostname) async {
    final addresses = <String>[];

    try {
      // Remove trailing dot from hostname
      final cleanHost = hostname.endsWith('.')
          ? hostname.substring(0, hostname.length - 1)
          : hostname;

      // Try to resolve using InternetAddress
      final results = await InternetAddress.lookup(cleanHost);
      for (final addr in results) {
        final ip = addr.address;
        if (!addresses.contains(ip)) {
          addresses.add(ip);
        }
      }
    } catch (e) {
      _log('debug', 'Could not resolve hostname: $hostname');
    }

    return addresses;
  }

  String _extractName(String serviceName) {
    // Extract friendly name from service record
    // Example: "OpenClaw-Gateway._openclaw._tcp.local" -> "OpenClaw-Gateway"
    final parts = serviceName.split('.');
    if (parts.isNotEmpty) {
      return parts.first;
    }
    return serviceName;
  }

  String _generateId(String host, int port) {
    return '${host}_$port';
  }

  // ==================== Network Info ====================

  /// Get local network information
  Future<LocalNetworkInfo> _getLocalNetworkInfo() async {
    try {
      final wifiIp = await _networkInfo.getWifiIP();
      final wifiGateway = await _networkInfo.getWifiGatewayIP();
      final wifiSubmask = await _networkInfo.getWifiSubmask();
      final wifiBroadcast = await _networkInfo.getWifiBroadcast();

      return LocalNetworkInfo(
        ipAddress: wifiIp,
        gateway: wifiGateway,
        subnetMask: wifiSubmask,
        broadcast: wifiBroadcast,
      );
    } catch (e) {
      _log('error', 'Failed to get network info', e);
      return LocalNetworkInfo();
    }
  }

  /// Check if an IP address is on the local network
  Future<bool> isLocalAddress(String ip) async {
    try {
      final networkInfo = await _getLocalNetworkInfo();
      if (networkInfo.ipAddress == null) return false;

      // Simple check: compare first 3 octets for IPv4
      final localParts = networkInfo.ipAddress!.split('.');
      final ipParts = ip.split('.');

      if (localParts.length >= 3 && ipParts.length >= 3) {
        return localParts[0] == ipParts[0] &&
            localParts[1] == ipParts[1] &&
            localParts[2] == ipParts[2];
      }
    } catch (e) {
      _log('error', 'Failed to check local address', e);
    }
    return false;
  }

  // ==================== Gateway Management ====================

  /// Add a gateway manually (for gateways not discovered via mDNS)
  void addGateway(DiscoveredGateway gateway) {
    if (!_discoveredGateways.any((g) => g.id == gateway.id)) {
      _discoveredGateways.add(gateway);
      _knownGateways[gateway.id] = gateway;
      _notifyGatewaysChanged();
      _log('info', 'Added gateway: ${gateway.name}');
    }
  }

  /// Remove a gateway
  void removeGateway(String id) {
    _discoveredGateways.removeWhere((g) => g.id == id);
    _knownGateways.remove(id);
    _notifyGatewaysChanged();
    _log('info', 'Removed gateway: $id');
  }

  /// Clear all discovered gateways
  void clearGateways() {
    _discoveredGateways.clear();
    _notifyGatewaysChanged();
    _log('info', 'Cleared all gateways');
  }

  /// Get gateway by ID
  DiscoveredGateway? getGateway(String id) {
    return _knownGateways[id];
  }

  /// Mark gateway as verified
  void markVerified(String id) {
    final gateway = _knownGateways[id];
    if (gateway != null) {
      _knownGateways[id] = DiscoveredGateway(
        id: gateway.id,
        name: gateway.name,
        host: gateway.host,
        port: gateway.port,
        serviceType: gateway.serviceType,
        isOpenClaw: gateway.isOpenClaw,
        discoveredAt: gateway.discoveredAt,
        verifiedAt: DateTime.now(),
        metadata: gateway.metadata,
      );
      _notifyGatewaysChanged();
      _log('info', 'Gateway verified: ${gateway.name}');
    }
  }

  void _notifyGatewaysChanged() {
    _gatewaysController.add(List.from(_discoveredGateways));
  }

  void _log(String level, String message, [dynamic data]) {
    if (onLog != null) {
      onLog!(level, message, data);
    } else if (kDebugMode) {
      debugPrint('[DiscoveryService][$level] $message ${data ?? ''}');
    }
  }

  // ==================== Cleanup ====================

  /// Dispose of resources
  void dispose() {
    _gatewaysController.close();
    _instance = null;
  }
}

// ==================== Models ====================

/// Discovered gateway information
class DiscoveredGateway {
  final String id;
  final String name;
  final String host;
  final int port;
  final String serviceType;
  final bool isOpenClaw;
  final DateTime discoveredAt;
  final DateTime? verifiedAt;
  final Map<String, dynamic> metadata;

  DiscoveredGateway({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.serviceType,
    this.isOpenClaw = false,
    required this.discoveredAt,
    this.verifiedAt,
    this.metadata = const {},
  });

  /// Get the base URL for this gateway
  String get baseUrl {
    final scheme = port == 443 || serviceType.contains('https')
        ? 'https'
        : 'http';
    return '$scheme://$host:$port';
  }

  /// Get WebSocket URL for this gateway
  String get wsUrl {
    final scheme = port == 443 || serviceType.contains('https')
        ? 'wss'
        : 'ws';
    return '$scheme://$host:$port/ws';
  }

  /// Whether this gateway has been verified
  bool get isVerified => verifiedAt != null;

  /// Copy with modified values
  DiscoveredGateway copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? serviceType,
    bool? isOpenClaw,
    DateTime? discoveredAt,
    DateTime? verifiedAt,
    Map<String, dynamic>? metadata,
  }) {
    return DiscoveredGateway(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      serviceType: serviceType ?? this.serviceType,
      isOpenClaw: isOpenClaw ?? this.isOpenClaw,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'serviceType': serviceType,
      'isOpenClaw': isOpenClaw,
      'discoveredAt': discoveredAt.toIso8601String(),
      'verifiedAt': verifiedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory DiscoveredGateway.fromJson(Map<String, dynamic> json) {
    return DiscoveredGateway(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      serviceType: json['serviceType'] as String,
      isOpenClaw: json['isOpenClaw'] as bool? ?? false,
      discoveredAt: DateTime.parse(json['discoveredAt'] as String),
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.parse(json['verifiedAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  String toString() {
    return 'DiscoveredGateway(name: $name, host: $host, port: $port, isOpenClaw: $isOpenClaw)';
  }
}

/// Local network information
class LocalNetworkInfo {
  final String? ipAddress;
  final String? gateway;
  final String? subnetMask;
  final String? broadcast;

  LocalNetworkInfo({
    this.ipAddress,
    this.gateway,
    this.subnetMask,
    this.broadcast,
  });

  bool get hasInfo =>
      ipAddress != null || gateway != null || subnetMask != null;

  @override
  String toString() {
    return 'LocalNetworkInfo(ip: $ipAddress, gateway: $gateway, subnet: $subnetMask)';
  }
}