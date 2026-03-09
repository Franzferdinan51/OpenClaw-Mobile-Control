/// Stub StorageService - placeholder for storage functionality
class StorageService {
  Future<void> initialize() async {}

  Future<String?> getString(String key) async {
    return null;
  }

  Future<void> setString(String key, String value) async {}

  Future<bool?> getBool(String key) async {
    return false;
  }

  Future<void> setBool(String key, bool value) async {}

  Future<void> remove(String key) async {}

  Future<void> clear() async {}
}

/// Connection profile model (for compatibility)
class ConnectionProfile {
  final String id;
  final String name;
  final String url;
  final String? token;

  ConnectionProfile({
    required this.id,
    required this.name,
    required this.url,
    this.token,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'token': token,
  };

  factory ConnectionProfile.fromJson(Map<String, dynamic> json) {
    return ConnectionProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      token: json['token'],
    );
  }

  ConnectionProfile copyWith({String? id, String? name, String? url, String? token}) {
    return ConnectionProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      token: token ?? this.token,
    );
  }
}

/// Cached gateway state for offline mode
class CachedGatewayState {
  final String version;
  final int uptime;
  final Map<String, dynamic>? agents;

  CachedGatewayState({
    required this.version,
    required this.uptime,
    this.agents,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'uptime': uptime,
    'agents': agents,
  };

  factory CachedGatewayState.fromJson(Map<String, dynamic> json) {
    return CachedGatewayState(
      version: json['version'] ?? 'unknown',
      uptime: json['uptime'] ?? 0,
      agents: json['agents'],
    );
  }
}

/// Queued action for offline mode
class QueuedAction {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  QueuedAction({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
  };

  factory QueuedAction.fromJson(Map<String, dynamic> json) {
    return QueuedAction(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      data: json['data'] ?? {},
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}