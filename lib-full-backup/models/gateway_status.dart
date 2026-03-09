/// Gateway connection status model
class GatewayStatus {
  final bool isOnline;
  final String version;
  final String uptime;
  final int activeConnections;
  final DateTime lastHeartbeat;
  final SystemResources resources;

  const GatewayStatus({
    required this.isOnline,
    required this.version,
    required this.uptime,
    required this.activeConnections,
    required this.lastHeartbeat,
    required this.resources,
  });

  factory GatewayStatus.fromJson(Map<String, dynamic> json) {
    return GatewayStatus(
      isOnline: json['isOnline'] as bool? ?? false,
      version: json['version'] as String? ?? 'unknown',
      uptime: json['uptime'] as String? ?? '0',
      activeConnections: json['activeConnections'] as int? ?? 0,
      lastHeartbeat: json['lastHeartbeat'] != null
          ? DateTime.parse(json['lastHeartbeat'] as String)
          : DateTime.now(),
      resources: SystemResources.fromJson(
        json['resources'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'isOnline': isOnline,
        'version': version,
        'uptime': uptime,
        'activeConnections': activeConnections,
        'lastHeartbeat': lastHeartbeat.toIso8601String(),
        'resources': resources.toJson(),
      };
}

class SystemResources {
  final double cpuUsage;
  final double memoryUsage;
  final double diskUsage;
  final String memoryUsed;
  final String memoryTotal;

  const SystemResources({
    required this.cpuUsage,
    required this.memoryUsage,
    required this.diskUsage,
    required this.memoryUsed,
    required this.memoryTotal,
  });

  factory SystemResources.fromJson(Map<String, dynamic> json) {
    return SystemResources(
      cpuUsage: (json['cpuUsage'] as num?)?.toDouble() ?? 0.0,
      memoryUsage: (json['memoryUsage'] as num?)?.toDouble() ?? 0.0,
      diskUsage: (json['diskUsage'] as num?)?.toDouble() ?? 0.0,
      memoryUsed: json['memoryUsed'] as String? ?? '0 GB',
      memoryTotal: json['memoryTotal'] as String? ?? '0 GB',
    );
  }

  Map<String, dynamic> toJson() => {
        'cpuUsage': cpuUsage,
        'memoryUsage': memoryUsage,
        'diskUsage': diskUsage,
        'memoryUsed': memoryUsed,
        'memoryTotal': memoryTotal,
      };
}