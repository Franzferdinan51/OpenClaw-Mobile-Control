class GatewayStatus {
  final bool online;
  final String version;
  final int uptime;
  final double? cpuPercent;
  final int? memoryUsed;
  final int? memoryTotal;
  final List<AgentInfo>? agents;
  final List<NodeInfo>? nodes;

  GatewayStatus({
    required this.online,
    required this.version,
    required this.uptime,
    this.cpuPercent,
    this.memoryUsed,
    this.memoryTotal,
    this.agents,
    this.nodes,
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
    );
  }
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
}
