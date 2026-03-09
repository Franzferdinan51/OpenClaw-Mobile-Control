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

  GatewayStatus({
    required this.online,
    required this.version,
    required this.uptime,
    this.cpuPercent,
    this.memoryUsed,
    this.memoryTotal,
    this.agents,
    this.nodes,
    this.crons,
    this.isPaused = false,
  });

  factory GatewayStatus.fromJson(Map<String, dynamic> json) {
    return GatewayStatus(
      online: json['gateway']?['status'] == 'online',
      version: json['gateway']?['version'] ?? 'unknown',
      uptime: json['gateway']?['uptime'] ?? 0,
      cpuPercent: json['gateway']?['cpu_percent']?.toDouble(),
      memoryUsed: json['gateway']?['memory_used'],
      memoryTotal: json['gateway']?['memory_total'],
      agents: (json['agents'] as List?)
          ?.map((a) => AgentInfo.fromJson(a))
          .toList(),
      nodes: (json['nodes'] as List?)
          ?.map((n) => NodeInfo.fromJson(n))
          .toList(),
      crons: (json['crons'] as List?)
          ?.map((c) => CronInfo.fromJson(c))
          .toList(),
      isPaused: json['paused'] == true || json['gateway']?['paused'] == true,
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
}

class AgentInfo {
  final String name;
  final String status;
  final String? currentTask;
  final String? model;

  AgentInfo({
    required this.name,
    required this.status,
    this.currentTask,
    this.model,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) {
    return AgentInfo(
      name: json['name'] ?? 'Unknown',
      status: json['status'] ?? 'unknown',
      currentTask: json['current_task'],
      model: json['model'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status,
    'current_task': currentTask,
    'model': model,
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
      name: json['name'] ?? 'Unknown',
      status: json['status'] ?? 'unknown',
      connectionType: json['connection_type'],
      ip: json['ip'],
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
      name: json['name'] ?? 'Unknown',
      schedule: json['schedule'] ?? '',
      enabled: json['enabled'] ?? true,
      lastRun: json['last_run'],
      nextRun: json['next_run'],
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
  local,      // Local network (192.168.x.x)
  tailscale,  // Tailscale Serve/Funnel
  sshTunnel,  // SSH tunnel endpoint
  custom,     // Custom HTTPS domain
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
      cachedAt: DateTime.parse(json['cached_at'] ?? DateTime.now().toIso8601String()),
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
}