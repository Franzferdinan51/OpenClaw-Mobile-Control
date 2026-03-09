/// Agent model for OpenClaw agent instances
class Agent {
  final String id;
  final String name;
  final String model;
  final AgentStatus status;
  final String provider;
  final DateTime createdAt;
  final DateTime? lastActive;
  final int messageCount;
  final double totalCost;
  final List<String> capabilities;

  const Agent({
    required this.id,
    required this.name,
    required this.model,
    required this.status,
    required this.provider,
    required this.createdAt,
    this.lastActive,
    required this.messageCount,
    required this.totalCost,
    required this.capabilities,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Agent',
      model: json['model'] as String? ?? 'unknown',
      status: AgentStatus.fromString(json['status'] as String? ?? 'idle'),
      provider: json['provider'] as String? ?? 'unknown',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastActive: json['lastActive'] != null
          ? DateTime.parse(json['lastActive'] as String)
          : null,
      messageCount: json['messageCount'] as int? ?? 0,
      totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0.0,
      capabilities: (json['capabilities'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'model': model,
        'status': status.name,
        'provider': provider,
        'createdAt': createdAt.toIso8601String(),
        'lastActive': lastActive?.toIso8601String(),
        'messageCount': messageCount,
        'totalCost': totalCost,
        'capabilities': capabilities,
      };

  Agent copyWith({
    String? id,
    String? name,
    String? model,
    AgentStatus? status,
    String? provider,
    DateTime? createdAt,
    DateTime? lastActive,
    int? messageCount,
    double? totalCost,
    List<String>? capabilities,
  }) {
    return Agent(
      id: id ?? this.id,
      name: name ?? this.name,
      model: model ?? this.model,
      status: status ?? this.status,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      messageCount: messageCount ?? this.messageCount,
      totalCost: totalCost ?? this.totalCost,
      capabilities: capabilities ?? this.capabilities,
    );
  }
}

enum AgentStatus {
  idle,
  active,
  busy,
  error,
  offline;

  static AgentStatus fromString(String value) {
    return AgentStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AgentStatus.idle,
    );
  }
}