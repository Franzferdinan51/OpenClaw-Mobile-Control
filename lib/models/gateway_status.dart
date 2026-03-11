// Gateway status model.
// Handles both:
// - /health endpoint: {"ok":true,"status":"live"}
// - Full status from WebSocket RPC

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

Map<String, dynamic>? _asMap(dynamic value) {
  return value is Map<String, dynamic> ? value : null;
}

class GatewayStatus {
  final bool online;
  final String version;
  final int uptime;
  final double? cpuPercent;
  final int? memoryUsed;
  final int? memoryTotal;
  final List<AgentInfo>? agents;
  final List<NodeInfo>? nodes;
  final List<CronInfo>? crons;
  final bool isPaused;
  final Map<String, dynamic>? rawData;

  GatewayStatus({
    required this.online,
    this.version = 'unknown',
    this.uptime = 0,
    this.cpuPercent,
    this.memoryUsed,
    this.memoryTotal,
    this.agents,
    this.nodes,
    this.crons,
    this.isPaused = false,
    this.rawData,
  });

  /// Parse from /health endpoint response
  ///
  /// /health returns: {"ok":true,"status":"live"}
  factory GatewayStatus.fromHealthJson(Map<String, dynamic> json) {
    final system = _asMap(json['system']);
    final memory = _asMap(system?['memory']) ?? _asMap(json['memory']);

    return GatewayStatus(
      online: json['ok'] == true || json['status'] == 'live',
      version: json['version'] ?? system?['version'] ?? 'unknown',
      uptime: _asInt(json['uptime']) ??
          ((_asInt(json['uptimeMs']) ?? _asInt(system?['uptimeMs'])) != null
              ? (((_asInt(json['uptimeMs']) ?? _asInt(system?['uptimeMs']))! ~/
                  1000))
              : 0),
      cpuPercent: _asDouble(json['cpu_percent']) ??
          _asDouble(system?['cpu_percent']) ??
          _asDouble(system?['cpu']),
      memoryUsed: _asInt(json['memory_used']) ??
          _asInt(memory?['used']) ??
          _asInt(system?['memory_used']) ??
          _asInt(system?['rss']),
      memoryTotal: _asInt(json['memory_total']) ??
          _asInt(memory?['total']) ??
          _asInt(system?['memory_total']),
      isPaused: json['paused'] == true,
      rawData: json,
    );
  }

  /// Parse from full gateway status (WebSocket RPC or /api/gateway)
  factory GatewayStatus.fromJson(Map<String, dynamic> json) {
    // Handle different response formats
    final result = _asMap(json['result']);
    final gateway =
        _asMap(json['gateway']) ?? _asMap(result?['gateway']) ?? json;
    final system = _asMap(json['system']) ?? _asMap(gateway['system']);
    final memory = _asMap(system?['memory']) ??
        _asMap(gateway['memory']) ??
        _asMap(json['memory']);
    final agentsJson = (json['agents'] as List?) ??
        (json['sessions'] as List?) ??
        (result?['agents'] as List?) ??
        (result?['sessions'] as List?);
    final nodesJson = (json['nodes'] as List?) ?? (result?['nodes'] as List?);
    final cronsJson = (json['crons'] as List?) ?? (result?['crons'] as List?);

    return GatewayStatus(
      online: gateway['status'] == 'online' ||
          gateway['status'] == 'live' ||
          json['ok'] == true ||
          result?['ok'] == true ||
          agentsJson != null ||
          nodesJson != null,
      version: gateway['version'] ??
          json['version'] ??
          system?['version'] ??
          _asMap(gateway['server'])?['version'] ??
          _asMap(json['server'])?['version'] ??
          'unknown',
      uptime: _asInt(gateway['uptime']) ??
          _asInt(json['uptime']) ??
          ((_asInt(gateway['uptimeMs']) ??
                      _asInt(json['uptimeMs']) ??
                      _asInt(system?['uptimeMs'])) !=
                  null
              ? (((_asInt(gateway['uptimeMs']) ??
                      _asInt(json['uptimeMs']) ??
                      _asInt(system?['uptimeMs']))! ~/
                  1000))
              : 0),
      cpuPercent: _asDouble(gateway['cpu_percent']) ??
          _asDouble(json['cpu_percent']) ??
          _asDouble(system?['cpu_percent']) ??
          _asDouble(system?['cpu']),
      memoryUsed: _asInt(gateway['memory_used']) ??
          _asInt(json['memory_used']) ??
          _asInt(memory?['used']) ??
          _asInt(system?['memory_used']) ??
          _asInt(system?['rss']),
      memoryTotal: _asInt(gateway['memory_total']) ??
          _asInt(json['memory_total']) ??
          _asInt(memory?['total']) ??
          _asInt(system?['memory_total']),
      agents: agentsJson?.map((a) => AgentInfo.fromJson(a)).toList(),
      nodes: nodesJson?.map((n) => NodeInfo.fromJson(n)).toList(),
      crons: cronsJson?.map((c) => CronInfo.fromJson(c)).toList(),
      isPaused: json['paused'] == true || gateway['paused'] == true,
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() => {
        'gateway': {
          'status': online ? 'online' : 'offline',
          'version': version,
          'uptime': uptime,
          'cpu_percent': cpuPercent,
          'memory_used': memoryUsed,
          'memory_total': memoryTotal,
          'paused': isPaused,
        },
        'agents': agents?.map((a) => a.toJson()).toList(),
        'nodes': nodes?.map((n) => n.toJson()).toList(),
        'crons': crons?.map((c) => c.toJson()).toList(),
        'paused': isPaused,
      };

  /// Get formatted uptime string
  String get formattedUptime {
    if (uptime <= 0) return 'Unknown';

    final duration = Duration(seconds: uptime);
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  /// Get formatted memory usage
  String? get formattedMemory {
    if (memoryUsed == null || memoryTotal == null) return null;

    final used = memoryUsed! / 1024 / 1024; // MB
    final total = memoryTotal! / 1024 / 1024; // MB

    return '${used.toStringAsFixed(1)} MB / ${total.toStringAsFixed(1)} MB';
  }

  /// Get memory usage percentage
  double? get memoryPercent {
    if (memoryUsed == null || memoryTotal == null || memoryTotal == 0) {
      return null;
    }
    return (memoryUsed! / memoryTotal!) * 100;
  }
}

class AgentInfo {
  final String name;
  final String status;
  final String? currentTask;
  final String? model;
  final bool isActive;
  final int? totalTokens;

  AgentInfo({
    required this.name,
    required this.status,
    this.currentTask,
    this.model,
    this.isActive = false,
    this.totalTokens,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) {
    return AgentInfo(
      name: json['name'] ?? json['agentId'] ?? 'Unknown',
      status: json['status'] ?? 'unknown',
      currentTask: json['current_task'] ?? json['currentTask'],
      model: json['model'],
      isActive: json['isActive'] == true || json['status'] == 'active',
      totalTokens: json['totalTokens'] ?? json['total_tokens'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'status': status,
        'current_task': currentTask,
        'model': model,
        'isActive': isActive,
        'totalTokens': totalTokens,
      };
}

class NodeInfo {
  final String name;
  final String status;
  final String? connectionType;
  final String? ip;

  NodeInfo({
    required this.name,
    required this.status,
    this.connectionType,
    this.ip,
  });

  factory NodeInfo.fromJson(Map<String, dynamic> json) {
    return NodeInfo(
      name: json['name'] ?? json['nodeId'] ?? 'Unknown',
      status: json['status'] ?? 'unknown',
      connectionType: json['connection_type'] ?? json['connectionType'],
      ip: json['ip'] ?? json['address'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'status': status,
        'connection_type': connectionType,
        'ip': ip,
      };
}

class CronInfo {
  final String name;
  final String schedule;
  final bool enabled;
  final String? lastRun;
  final String? nextRun;
  final String? status;

  CronInfo({
    required this.name,
    required this.schedule,
    required this.enabled,
    this.lastRun,
    this.nextRun,
    this.status,
  });

  factory CronInfo.fromJson(Map<String, dynamic> json) {
    return CronInfo(
      name: json['name'] ?? json['cronName'] ?? 'Unknown',
      schedule: json['schedule'] ?? '',
      enabled: json['enabled'] ?? true,
      lastRun: json['last_run'] ?? json['lastRun'],
      nextRun: json['next_run'] ?? json['nextRun'],
      status: json['status'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'schedule': schedule,
        'enabled': enabled,
        'last_run': lastRun,
        'next_run': nextRun,
        'status': status,
      };
}

/// Connection Profile for remote gateway support
class ConnectionProfile {
  final String id;
  final String name;
  final String url;
  final String? token;
  final ConnectionType connectionType;
  final bool autoSelect;
  final String? networkType; // 'wifi' or 'cellular'
  final DateTime? lastConnected;
  final bool useBiometric;
  final DateTime createdAt;

  ConnectionProfile({
    required this.id,
    required this.name,
    required this.url,
    this.token,
    this.connectionType = ConnectionType.custom,
    this.autoSelect = false,
    this.networkType,
    this.lastConnected,
    this.useBiometric = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ConnectionProfile.fromJson(Map<String, dynamic> json) {
    return ConnectionProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      token: json['token'],
      connectionType: ConnectionType.values.firstWhere(
        (e) => e.name == json['connection_type'],
        orElse: () => ConnectionType.custom,
      ),
      autoSelect: json['auto_select'] ?? false,
      networkType: json['network_type'],
      lastConnected: json['last_connected'] != null
          ? DateTime.tryParse(json['last_connected'])
          : null,
      useBiometric: json['use_biometric'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'token': token,
        'connection_type': connectionType.name,
        'auto_select': autoSelect,
        'network_type': networkType,
        'last_connected': lastConnected?.toIso8601String(),
        'use_biometric': useBiometric,
        'created_at': createdAt.toIso8601String(),
      };

  ConnectionProfile copyWith({
    String? id,
    String? name,
    String? url,
    String? token,
    ConnectionType? connectionType,
    bool? autoSelect,
    String? networkType,
    DateTime? lastConnected,
    bool? useBiometric,
    DateTime? createdAt,
  }) {
    return ConnectionProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      token: token ?? this.token,
      connectionType: connectionType ?? this.connectionType,
      autoSelect: autoSelect ?? this.autoSelect,
      networkType: networkType ?? this.networkType,
      lastConnected: lastConnected ?? this.lastConnected,
      useBiometric: useBiometric ?? this.useBiometric,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum ConnectionType {
  local, // Local network (192.168.x.x)
  tailscale, // Tailscale Serve/Funnel
  sshTunnel, // SSH tunnel endpoint
  custom, // Custom HTTPS domain
}

extension ConnectionTypeExtension on ConnectionType {
  String get displayName {
    switch (this) {
      case ConnectionType.local:
        return 'Local Network';
      case ConnectionType.tailscale:
        return 'Tailscale (Serve/Funnel)';
      case ConnectionType.sshTunnel:
        return 'SSH Tunnel';
      case ConnectionType.custom:
        return 'Custom HTTPS';
    }
  }

  String get description {
    switch (this) {
      case ConnectionType.local:
        return 'Connect over local network (e.g., 192.168.1.x)';
      case ConnectionType.tailscale:
        return 'Connect via Tailscale Serve or Funnel URL';
      case ConnectionType.sshTunnel:
        return 'Connect through SSH tunnel';
      case ConnectionType.custom:
        return 'Connect via custom domain with HTTPS';
    }
  }
}

/// Offline cached state
class CachedGatewayState {
  final GatewayStatus? status;
  final DateTime cachedAt;
  final String profileId;

  CachedGatewayState({
    this.status,
    required this.cachedAt,
    required this.profileId,
  });

  factory CachedGatewayState.fromJson(Map<String, dynamic> json) {
    return CachedGatewayState(
      status: json['status'] != null
          ? GatewayStatus.fromJson(json['status'])
          : null,
      cachedAt:
          DateTime.parse(json['cached_at'] ?? DateTime.now().toIso8601String()),
      profileId: json['profile_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status?.toJson(),
        'cached_at': cachedAt.toIso8601String(),
        'profile_id': profileId,
      };

  bool get isStale => DateTime.now().difference(cachedAt).inMinutes > 5;
}

/// Queued action for offline mode
class QueuedAction {
  final String id;
  final String endpoint;
  final Map<String, dynamic> body;
  final DateTime queuedAt;
  final int retryCount;

  QueuedAction({
    required this.id,
    required this.endpoint,
    required this.body,
    DateTime? queuedAt,
    this.retryCount = 0,
  }) : queuedAt = queuedAt ?? DateTime.now();

  factory QueuedAction.fromJson(Map<String, dynamic> json) {
    return QueuedAction(
      id: json['id'] ?? '',
      endpoint: json['endpoint'] ?? '',
      body: json['body'] ?? {},
      queuedAt: json['queued_at'] != null
          ? DateTime.parse(json['queued_at'])
          : DateTime.now(),
      retryCount: json['retry_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'endpoint': endpoint,
        'body': body,
        'queued_at': queuedAt.toIso8601String(),
        'retry_count': retryCount,
      };
}

/// Connection test result
class ConnectionTestResult {
  final bool success;
  final int latencyMs;
  final String? error;
  final GatewayStatus? gatewayInfo;
  final DateTime testedAt;

  ConnectionTestResult({
    required this.success,
    this.latencyMs = 0,
    this.error,
    this.gatewayInfo,
    DateTime? testedAt,
  }) : testedAt = testedAt ?? DateTime.now();

  factory ConnectionTestResult.fromJson(Map<String, dynamic> json) {
    return ConnectionTestResult(
      success: json['success'] ?? false,
      latencyMs: json['latency_ms'] ?? 0,
      error: json['error'],
      gatewayInfo: json['gateway_info'] != null
          ? GatewayStatus.fromJson(json['gateway_info'])
          : null,
    );
  }
}

/// Gateway connection info for discovery
class GatewayConnection {
  final String name;
  final String url;
  final String? ip;
  final int? port;
  final String? token;
  final DateTime? lastConnected;
  final bool isOnline;

  GatewayConnection({
    required this.name,
    required this.url,
    this.ip,
    this.port,
    this.token,
    this.lastConnected,
    this.isOnline = false,
  });

  /// Returns name if available, otherwise url
  String get displayName => name.isNotEmpty ? name : url;

  factory GatewayConnection.fromMdns(String serviceName, String ip, int port) {
    return GatewayConnection(
      name: serviceName.replaceAll('._openclaw._tcp.local.', ''),
      url: 'http://$ip:$port',
      ip: ip,
      port: port,
      lastConnected: DateTime.now(),
      isOnline: true,
    );
  }

  factory GatewayConnection.fromJson(Map<String, dynamic> json) {
    return GatewayConnection(
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      ip: json['ip'],
      port: json['port'],
      token: json['token'],
      lastConnected: json['last_connected'] != null
          ? DateTime.tryParse(json['last_connected'])
          : null,
      isOnline: json['is_online'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'ip': ip,
        'port': port,
        'token': token,
        'last_connected': lastConnected?.toIso8601String(),
        'is_online': isOnline,
      };

  GatewayConnection copyWith({
    String? name,
    String? url,
    String? ip,
    int? port,
    String? token,
    DateTime? lastConnected,
    bool? isOnline,
  }) {
    return GatewayConnection(
      name: name ?? this.name,
      url: url ?? this.url,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      token: token ?? this.token,
      lastConnected: lastConnected ?? this.lastConnected,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
