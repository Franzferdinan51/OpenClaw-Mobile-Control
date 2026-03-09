/// Autowork configuration and policy models
class AutoworkConfig {
  final int maxSendsPerTick;
  final String defaultDirective;
  final Map<String, AutoworkPolicy> policies;
  final List<AutoworkTarget> targets;

  AutoworkConfig({
    this.maxSendsPerTick = 0,
    this.defaultDirective = '',
    Map<String, AutoworkPolicy>? policies,
    this.targets = const [],
  }) : policies = policies ?? {};

  factory AutoworkConfig.fromJson(Map<String, dynamic> json) {
    final policiesJson = json['policies'] as Map<String, dynamic>? ?? {};
    final policies = <String, AutoworkPolicy>{};
    policiesJson.forEach((key, value) {
      policies[key] = AutoworkPolicy.fromJson(value);
    });

    final targetsJson = json['targets'] as List? ?? [];
    final targets = targetsJson.map((t) => AutoworkTarget.fromJson(t)).toList();

    return AutoworkConfig(
      maxSendsPerTick: json['maxSendsPerTick'] ?? 0,
      defaultDirective: json['defaultDirective'] ?? '',
      policies: policies,
      targets: targets,
    );
  }

  Map<String, dynamic> toJson() => {
    'maxSendsPerTick': maxSendsPerTick,
    'defaultDirective': defaultDirective,
    'policies': policies.map((k, v) => MapEntry(k, v.toJson())),
    'targets': targets.map((t) => t.toJson()).toList(),
  };

  /// Check if autowork is enabled globally
  bool get isEnabled => maxSendsPerTick > 0;

  /// Get policy for a specific session
  AutoworkPolicy? getPolicy(String sessionKey) => policies[sessionKey];

  /// Check if a session has autowork enabled
  bool isSessionEnabled(String sessionKey) {
    return policies[sessionKey]?.enabled ?? false;
  }
}

class AutoworkPolicy {
  final bool enabled;
  final int intervalMs;
  final String directive;
  final int lastSentAt;

  AutoworkPolicy({
    this.enabled = false,
    this.intervalMs = 600000, // 10 minutes default
    this.directive = '',
    this.lastSentAt = 0,
  });

  factory AutoworkPolicy.fromJson(Map<String, dynamic> json) {
    return AutoworkPolicy(
      enabled: json['enabled'] ?? false,
      intervalMs: json['intervalMs'] ?? 600000,
      directive: json['directive'] ?? '',
      lastSentAt: json['lastSentAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'intervalMs': intervalMs,
    'directive': directive,
    'lastSentAt': lastSentAt,
  };

  /// Get interval display text
  String get intervalDisplay {
    final minutes = intervalMs ~/ 60000;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      return '${hours}h';
    }
    return '${minutes}m';
  }

  /// Get last sent display text
  String get lastSentDisplay {
    if (lastSentAt == 0) return 'Never';
    final diff = DateTime.now().millisecondsSinceEpoch - lastSentAt;
    final minutes = diff ~/ 60000;
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return '${minutes}m ago';
    final hours = minutes ~/ 60;
    if (hours < 24) return '${hours}h ago';
    return '${hours ~/ 24}d ago';
  }
}

class AutoworkTarget {
  final String sessionId;
  final String sessionKey;
  final String agentId;
  final String name;
  final String sendPolicy;
  final int updatedAt;

  AutoworkTarget({
    required this.sessionId,
    required this.sessionKey,
    required this.agentId,
    required this.name,
    this.sendPolicy = 'unknown',
    this.updatedAt = 0,
  });

  factory AutoworkTarget.fromJson(Map<String, dynamic> json) {
    return AutoworkTarget(
      sessionId: json['sessionId'] ?? '',
      sessionKey: json['sessionKey'] ?? '',
      agentId: json['agentId'] ?? '',
      name: json['name'] ?? 'Unknown',
      sendPolicy: json['sendPolicy'] ?? 'unknown',
      updatedAt: json['updatedAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'sessionKey': sessionKey,
    'agentId': agentId,
    'name': name,
    'sendPolicy': sendPolicy,
    'updatedAt': updatedAt,
  };

  bool get canSend => sendPolicy == 'allow';
}