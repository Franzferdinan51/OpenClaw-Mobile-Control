/// Node model for paired devices
class Node {
  final String id;
  final String name;
  final String type;
  final NodeStatus status;
  final String ipAddress;
  final int port;
  final DateTime lastSeen;
  final NodeCapabilities capabilities;
  final NodeMetadata metadata;

  const Node({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.ipAddress,
    required this.port,
    required this.lastSeen,
    required this.capabilities,
    required this.metadata,
  });

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Node',
      type: json['type'] as String? ?? 'unknown',
      status: NodeStatus.fromString(json['status'] as String? ?? 'offline'),
      ipAddress: json['ipAddress'] as String? ?? '',
      port: json['port'] as int? ?? 0,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : DateTime.now(),
      capabilities: NodeCapabilities.fromJson(
        json['capabilities'] as Map<String, dynamic>? ?? {},
      ),
      metadata: NodeMetadata.fromJson(
        json['metadata'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'status': status.name,
        'ipAddress': ipAddress,
        'port': port,
        'lastSeen': lastSeen.toIso8601String(),
        'capabilities': capabilities.toJson(),
        'metadata': metadata.toJson(),
      };

  Node copyWith({
    String? id,
    String? name,
    String? type,
    NodeStatus? status,
    String? ipAddress,
    int? port,
    DateTime? lastSeen,
    NodeCapabilities? capabilities,
    NodeMetadata? metadata,
  }) {
    return Node(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
      capabilities: capabilities ?? this.capabilities,
      metadata: metadata ?? this.metadata,
    );
  }
}

enum NodeStatus {
  online,
  offline,
  busy,
  error;

  static NodeStatus fromString(String value) {
    return NodeStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => NodeStatus.offline,
    );
  }
}

class NodeCapabilities {
  final bool hasCamera;
  final bool hasScreen;
  final bool hasLocation;
  final bool hasNotifications;
  final bool hasFiles;
  final bool hasShell;

  const NodeCapabilities({
    required this.hasCamera,
    required this.hasScreen,
    required this.hasLocation,
    required this.hasNotifications,
    required this.hasFiles,
    required this.hasShell,
  });

  factory NodeCapabilities.fromJson(Map<String, dynamic> json) {
    return NodeCapabilities(
      hasCamera: json['hasCamera'] as bool? ?? false,
      hasScreen: json['hasScreen'] as bool? ?? false,
      hasLocation: json['hasLocation'] as bool? ?? false,
      hasNotifications: json['hasNotifications'] as bool? ?? false,
      hasFiles: json['hasFiles'] as bool? ?? false,
      hasShell: json['hasShell'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'hasCamera': hasCamera,
        'hasScreen': hasScreen,
        'hasLocation': hasLocation,
        'hasNotifications': hasNotifications,
        'hasFiles': hasFiles,
        'hasShell': hasShell,
      };
}

class NodeMetadata {
  final String os;
  final String version;
  final String? model;
  final String? manufacturer;

  const NodeMetadata({
    required this.os,
    required this.version,
    this.model,
    this.manufacturer,
  });

  factory NodeMetadata.fromJson(Map<String, dynamic> json) {
    return NodeMetadata(
      os: json['os'] as String? ?? 'unknown',
      version: json['version'] as String? ?? 'unknown',
      model: json['model'] as String?,
      manufacturer: json['manufacturer'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'os': os,
        'version': version,
        'model': model,
        'manufacturer': manufacturer,
      };
}