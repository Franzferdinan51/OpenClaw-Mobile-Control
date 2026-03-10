/// Node Connection Model
/// 
/// Represents a connected device in Host Node Mode.

class NodeConnection {
  final String id;
  final String name;
  final String ip;
  final int port;
  final ConnectionStatus status;
  final DateTime connectedAt;
  final DateTime? lastActivity;
  final String? authToken;
  final bool isApproved;
  final bool isWhitelisted;
  final DeviceType deviceType;
  final String? userAgent;
  final Map<String, dynamic> metadata;

  NodeConnection({
    required this.id,
    required this.name,
    required this.ip,
    this.port = 18790,
    this.status = ConnectionStatus.pending,
    DateTime? connectedAt,
    this.lastActivity,
    this.authToken,
    this.isApproved = false,
    this.isWhitelisted = false,
    this.deviceType = DeviceType.unknown,
    this.userAgent,
    this.metadata = const {},
  }) : connectedAt = connectedAt ?? DateTime.now();

  /// Connection duration
  Duration get connectedDuration => DateTime.now().difference(connectedAt);

  /// Is connection active
  bool get isActive => status == ConnectionStatus.connected;

  /// Display name for UI
  String get displayName => name.isNotEmpty ? name : ip;

  /// Status color for UI
  String get statusColor {
    switch (status) {
      case ConnectionStatus.connected:
        return 'green';
      case ConnectionStatus.pending:
        return 'orange';
      case ConnectionStatus.disconnected:
        return 'red';
      case ConnectionStatus.rejected:
        return 'red';
    }
  }

  factory NodeConnection.fromJson(Map<String, dynamic> json) {
    return NodeConnection(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      ip: json['ip'] ?? '',
      port: json['port'] ?? 18790,
      status: ConnectionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ConnectionStatus.pending,
      ),
      connectedAt: json['connected_at'] != null
          ? DateTime.tryParse(json['connected_at']) ?? DateTime.now()
          : DateTime.now(),
      lastActivity: json['last_activity'] != null
          ? DateTime.tryParse(json['last_activity'])
          : null,
      authToken: json['auth_token'],
      isApproved: json['is_approved'] ?? false,
      isWhitelisted: json['is_whitelisted'] ?? false,
      deviceType: DeviceType.values.firstWhere(
        (e) => e.name == json['device_type'],
        orElse: () => DeviceType.unknown,
      ),
      userAgent: json['user_agent'],
      metadata: json['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ip': ip,
    'port': port,
    'status': status.name,
    'connected_at': connectedAt.toIso8601String(),
    'last_activity': lastActivity?.toIso8601String(),
    'auth_token': authToken,
    'is_approved': isApproved,
    'is_whitelisted': isWhitelisted,
    'device_type': deviceType.name,
    'user_agent': userAgent,
    'metadata': metadata,
  };

  NodeConnection copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    ConnectionStatus? status,
    DateTime? connectedAt,
    DateTime? lastActivity,
    String? authToken,
    bool? isApproved,
    bool? isWhitelisted,
    DeviceType? deviceType,
    String? userAgent,
    Map<String, dynamic>? metadata,
  }) {
    return NodeConnection(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      status: status ?? this.status,
      connectedAt: connectedAt ?? this.connectedAt,
      lastActivity: lastActivity ?? this.lastActivity,
      authToken: authToken ?? this.authToken,
      isApproved: isApproved ?? this.isApproved,
      isWhitelisted: isWhitelisted ?? this.isWhitelisted,
      deviceType: deviceType ?? this.deviceType,
      userAgent: userAgent ?? this.userAgent,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() => 'NodeConnection($displayName, $ip:$port, ${status.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeConnection && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Connection status
enum ConnectionStatus {
  pending,
  connected,
  disconnected,
  rejected,
}

/// Device type
enum DeviceType {
  android,
  ios,
  desktop,
  server,
  iot,
  unknown,
}

extension DeviceTypeExtension on DeviceType {
  String get displayName {
    switch (this) {
      case DeviceType.android:
        return 'Android';
      case DeviceType.ios:
        return 'iOS';
      case DeviceType.desktop:
        return 'Desktop';
      case DeviceType.server:
        return 'Server';
      case DeviceType.iot:
        return 'IoT';
      case DeviceType.unknown:
        return 'Unknown';
    }
  }

  String get icon {
    switch (this) {
      case DeviceType.android:
        return 'phone_android';
      case DeviceType.ios:
        return 'phone_iphone';
      case DeviceType.desktop:
        return 'computer';
      case DeviceType.server:
        return 'dns';
      case DeviceType.iot:
        return 'router';
      case DeviceType.unknown:
        return 'device_unknown';
    }
  }
}

/// Connection log entry
class ConnectionLogEntry {
  final String id;
  final String connectionId;
  final String message;
  final LogLevel level;
  final DateTime timestamp;
  final Map<String, dynamic>? details;

  ConnectionLogEntry({
    required this.id,
    required this.connectionId,
    required this.message,
    this.level = LogLevel.info,
    DateTime? timestamp,
    this.details,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ConnectionLogEntry.fromJson(Map<String, dynamic> json) {
    return ConnectionLogEntry(
      id: json['id'] ?? '',
      connectionId: json['connection_id'] ?? '',
      message: json['message'] ?? '',
      level: LogLevel.values.firstWhere(
        (e) => e.name == json['level'],
        orElse: () => LogLevel.info,
      ),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      details: json['details'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'connection_id': connectionId,
    'message': message,
    'level': level.name,
    'timestamp': timestamp.toIso8601String(),
    'details': details,
  };
}

enum LogLevel {
  debug,
  info,
  warn,
  error,
}

/// Node mode configuration
class NodeModeConfig {
  final NodeMode mode;
  final int hostPort;
  final bool requireApproval;
  final bool enableEncryption;
  final bool enableWhitelist;
  final List<String> whitelist;
  final int maxConnections;
  final Duration connectionTimeout;
  final String? customToken;

  NodeModeConfig({
    this.mode = NodeMode.client,
    this.hostPort = 18790,
    this.requireApproval = true,
    this.enableEncryption = true,
    this.enableWhitelist = false,
    this.whitelist = const [],
    this.maxConnections = 10,
    this.connectionTimeout = const Duration(seconds: 30),
    this.customToken,
  });

  factory NodeModeConfig.fromJson(Map<String, dynamic> json) {
    return NodeModeConfig(
      mode: NodeMode.values.firstWhere(
        (e) => e.name == json['mode'],
        orElse: () => NodeMode.client,
      ),
      hostPort: json['host_port'] ?? 18790,
      requireApproval: json['require_approval'] ?? true,
      enableEncryption: json['enable_encryption'] ?? true,
      enableWhitelist: json['enable_whitelist'] ?? false,
      whitelist: (json['whitelist'] as List?)?.map((e) => e.toString()).toList() ?? [],
      maxConnections: json['max_connections'] ?? 10,
      connectionTimeout: Duration(seconds: json['connection_timeout_seconds'] ?? 30),
      customToken: json['custom_token'],
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'host_port': hostPort,
    'require_approval': requireApproval,
    'enable_encryption': enableEncryption,
    'enable_whitelist': enableWhitelist,
    'whitelist': whitelist,
    'max_connections': maxConnections,
    'connection_timeout_seconds': connectionTimeout.inSeconds,
    'custom_token': customToken,
  };

  NodeModeConfig copyWith({
    NodeMode? mode,
    int? hostPort,
    bool? requireApproval,
    bool? enableEncryption,
    bool? enableWhitelist,
    List<String>? whitelist,
    int? maxConnections,
    Duration? connectionTimeout,
    String? customToken,
  }) {
    return NodeModeConfig(
      mode: mode ?? this.mode,
      hostPort: hostPort ?? this.hostPort,
      requireApproval: requireApproval ?? this.requireApproval,
      enableEncryption: enableEncryption ?? this.enableEncryption,
      enableWhitelist: enableWhitelist ?? this.enableWhitelist,
      whitelist: whitelist ?? this.whitelist,
      maxConnections: maxConnections ?? this.maxConnections,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      customToken: customToken ?? this.customToken,
    );
  }
}

/// Node mode
enum NodeMode {
  client,  // Connect to gateway
  host,    // Accept connections from other devices
  bridge,  // Both client and host
}

extension NodeModeExtension on NodeMode {
  String get displayName {
    switch (this) {
      case NodeMode.client:
        return 'Client Node';
      case NodeMode.host:
        return 'Host Node';
      case NodeMode.bridge:
        return 'Bridge Node';
    }
  }

  String get description {
    switch (this) {
      case NodeMode.client:
        return 'Connect to a gateway server';
      case NodeMode.host:
        return 'Accept connections from other devices';
      case NodeMode.bridge:
        return 'Connect to gateway AND accept device connections';
    }
  }

  String get icon {
    switch (this) {
      case NodeMode.client:
        return 'phone_android';
      case NodeMode.host:
        return 'router';
      case NodeMode.bridge:
        return 'hub';
    }
  }
}

/// Pairing QR code data
class PairingQRData {
  final String hostIp;
  final int port;
  final String token;
  final String deviceName;
  final DateTime createdAt;
  final int expiresIn;

  PairingQRData({
    required this.hostIp,
    required this.port,
    required this.token,
    required this.deviceName,
    DateTime? createdAt,
    this.expiresIn = 300, // 5 minutes
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpired => DateTime.now().difference(createdAt).inSeconds > expiresIn;

  /// Generate QR code string (JSON format for parsing)
  String toQRString() {
    return toJsonString();
  }

  String toJsonString() {
    return '{"type":"openclaw_node","ip":"$hostIp","port":$port,"token":"$token","name":"$deviceName","expires":${createdAt.add(Duration(seconds: expiresIn)).millisecondsSinceEpoch}}';
  }

  factory PairingQRData.fromJson(Map<String, dynamic> json) {
    return PairingQRData(
      hostIp: json['ip'] ?? '',
      port: json['port'] ?? 18790,
      token: json['token'] ?? '',
      deviceName: json['name'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      expiresIn: json['expires_in'] ?? 300,
    );
  }

  Map<String, dynamic> toJson() => {
    'ip': hostIp,
    'port': port,
    'token': token,
    'name': deviceName,
    'created_at': createdAt.toIso8601String(),
    'expires_in': expiresIn,
  };

  /// Parse from QR string
  static PairingQRData? fromQRString(String qrString) {
    try {
      final json = _parseQRJson(qrString);
      if (json == null) return null;
      
      return PairingQRData(
        hostIp: json['ip'] ?? '',
        port: json['port'] ?? 18790,
        token: json['token'] ?? '',
        deviceName: json['name'] ?? '',
        createdAt: json['expires'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['expires'] - 300000)
            : DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  static Map<String, dynamic>? _parseQRJson(String qrString) {
    try {
      // Try to parse as JSON
      if (qrString.startsWith('{')) {
        return Map<String, dynamic>.from(
          // ignore: avoid_dynamic_calls
          Uri.decodeComponent(qrString).replaceAll(RegExp(r'^{|}$'), '').split(',').fold<Map<String, dynamic>>({}, (map, pair) {
            final kv = pair.split(':');
            if (kv.length == 2) {
              final key = kv[0].replaceAll('"', '').trim();
              var value = kv[1].replaceAll('"', '').trim();
              // Handle numeric values
              if (int.tryParse(value) != null) {
                map[key] = int.parse(value);
              } else {
                map[key] = value;
              }
            }
            return map;
          }),
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}