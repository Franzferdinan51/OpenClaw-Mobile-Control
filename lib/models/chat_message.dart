/// Chat message model for Boss Chat
class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime? timestamp;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.timestamp,
    this.metadata,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? json['messageId'] ?? '',
      role: json['role'] ?? 'user',
      content: json['content'] ?? json['text'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : json['time'] != null
              ? DateTime.tryParse(json['time'].toString())
              : null,
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'content': content,
    'timestamp': timestamp?.toIso8601String(),
    'metadata': metadata,
  };

  bool get isUser => role == 'user' || role == 'human';
  bool get isAssistant => role == 'assistant' || role == 'agent';
  bool get isSystem => role == 'system';

  /// Get display role
  String get displayRole {
    switch (role) {
      case 'user':
      case 'human':
        return 'You';
      case 'assistant':
      case 'agent':
        return 'Agent';
      case 'system':
        return 'System';
      default:
        return role;
    }
  }
}

/// Boss identity configuration
class BossIdentity {
  final String name;
  final String emoji;
  final String? avatarUrl;

  BossIdentity({
    this.name = 'Boss',
    this.emoji = '👔',
    this.avatarUrl,
  });

  factory BossIdentity.fromJson(Map<String, dynamic> json) {
    return BossIdentity(
      name: json['name'] ?? 'Boss',
      emoji: json['emoji'] ?? '👔',
      avatarUrl: json['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'emoji': emoji,
    'avatarUrl': avatarUrl,
  };

  String get displayName => '$emoji $name';
}