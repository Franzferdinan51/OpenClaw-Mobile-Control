/// Chat message model for conversation history
class ChatMessage {
  final String id;
  final String conversationId;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final MessageStatus status;
  final List<Attachment>? attachments;
  final MessageMetadata? metadata;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.role,
    required this.timestamp,
    required this.status,
    this.attachments,
    this.metadata,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      role: MessageRole.fromString(json['role'] as String? ?? 'user'),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      status: MessageStatus.fromString(json['status'] as String? ?? 'sent'),
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] != null
          ? MessageMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'content': content,
        'role': role.name,
        'timestamp': timestamp.toIso8601String(),
        'status': status.name,
        'attachments': attachments?.map((e) => e.toJson()).toList(),
        'metadata': metadata?.toJson(),
      };

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    String? content,
    MessageRole? role,
    DateTime? timestamp,
    MessageStatus? status,
    List<Attachment>? attachments,
    MessageMetadata? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      metadata: metadata ?? this.metadata,
    );
  }
}

enum MessageRole {
  user,
  assistant,
  system;

  static MessageRole fromString(String value) {
    return MessageRole.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => MessageRole.user,
    );
  }
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  error;

  static MessageStatus fromString(String value) {
    return MessageStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => MessageStatus.sent,
    );
  }
}

class Attachment {
  final String id;
  final String type;
  final String name;
  final String url;
  final int? size;

  const Attachment({
    required this.id,
    required this.type,
    required this.name,
    required this.url,
    this.size,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'unknown',
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      size: json['size'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        'url': url,
        'size': size,
      };
}

class MessageMetadata {
  final String? model;
  final int? tokensUsed;
  final double? cost;
  final Duration? responseTime;

  const MessageMetadata({
    this.model,
    this.tokensUsed,
    this.cost,
    this.responseTime,
  });

  factory MessageMetadata.fromJson(Map<String, dynamic> json) {
    return MessageMetadata(
      model: json['model'] as String?,
      tokensUsed: json['tokensUsed'] as int?,
      cost: (json['cost'] as num?)?.toDouble(),
      responseTime: json['responseTime'] != null
          ? Duration(milliseconds: json['responseTime'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'model': model,
        'tokensUsed': tokensUsed,
        'cost': cost,
        'responseTime': responseTime?.inMilliseconds,
      };
}

/// Conversation model for grouping messages
class Conversation {
  final String id;
  final String title;
  final String? agentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;
  final String? lastMessage;

  const Conversation({
    required this.id,
    required this.title,
    this.agentId,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
    this.lastMessage,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'New Chat',
      agentId: json['agentId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      messageCount: json['messageCount'] as int? ?? 0,
      lastMessage: json['lastMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'agentId': agentId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messageCount': messageCount,
        'lastMessage': lastMessage,
      };

  Conversation copyWith({
    String? id,
    String? title,
    String? agentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? messageCount,
    String? lastMessage,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      agentId: agentId ?? this.agentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messageCount: messageCount ?? this.messageCount,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }
}