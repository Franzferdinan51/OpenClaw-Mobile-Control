/// Agent Session model for Agent Monitor Dashboard
class AgentSession {
  final String id;
  final String key;
  final String name;
  final String? emoji;
  final String? modelProvider;
  final String model;
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  final bool usageKnown;
  final int contextTokens;
  final String channel;
  final String kind;
  final String? label;
  final String? displayName;
  final String? derivedTitle;
  final String? lastMessagePreview;
  final String? chatStatus;
  final String? agentStatus;
  final dynamic agentEventData;
  final String? currentToolName;
  final String? currentToolPhase;
  final String? statusSummary;
  final bool isActive;
  final bool isSubagent;
  final DateTime? lastActivity;
  final DateTime? updatedAt;
  final bool aborted;
  final String? avatarUrl;
  final String? identityTheme;

  AgentSession({
    required this.id,
    required this.key,
    required this.name,
    this.emoji,
    this.modelProvider,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
    this.usageKnown = false,
    this.contextTokens = 0,
    required this.channel,
    required this.kind,
    this.label,
    this.displayName,
    this.derivedTitle,
    this.lastMessagePreview,
    this.chatStatus,
    this.agentStatus,
    this.agentEventData,
    this.currentToolName,
    this.currentToolPhase,
    this.statusSummary,
    this.isActive = false,
    this.isSubagent = false,
    this.lastActivity,
    this.updatedAt,
    this.aborted = false,
    this.avatarUrl,
    this.identityTheme,
  });

  factory AgentSession.fromJson(Map<String, dynamic> json) {
    return AgentSession(
      id: json['id'] ?? json['sessionId'] ?? '',
      key: json['key'] ?? '',
      name: json['name'] ?? 'Unknown',
      emoji: json['emoji'],
      modelProvider: json['modelProvider'],
      model: json['model'] ?? 'unknown',
      inputTokens: json['inputTokens'] ?? 0,
      outputTokens: json['outputTokens'] ?? 0,
      totalTokens: json['totalTokens'] ?? 0,
      usageKnown: json['usageKnown'] ?? false,
      contextTokens: json['contextTokens'] ?? 0,
      channel: json['channel'] ?? 'default',
      kind: json['kind'] ?? 'unknown',
      label: json['label'],
      displayName: json['displayName'],
      derivedTitle: json['derivedTitle'],
      lastMessagePreview: json['lastMessagePreview'],
      chatStatus: json['chatStatus'],
      agentStatus: json['agentStatus'],
      agentEventData: json['agentEventData'],
      currentToolName: json['currentToolName'],
      currentToolPhase: json['currentToolPhase'],
      statusSummary: json['statusSummary'],
      isActive: json['isActive'] ?? false,
      isSubagent: json['isSubagent'] ?? false,
      lastActivity: json['lastActivity'] != null
          ? DateTime.tryParse(json['lastActivity'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      aborted: json['aborted'] ?? false,
      avatarUrl: json['avatarUrl'],
      identityTheme: json['identityTheme'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'key': key,
    'name': name,
    'emoji': emoji,
    'modelProvider': modelProvider,
    'model': model,
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'totalTokens': totalTokens,
    'usageKnown': usageKnown,
    'contextTokens': contextTokens,
    'channel': channel,
    'kind': kind,
    'label': label,
    'displayName': displayName,
    'derivedTitle': derivedTitle,
    'lastMessagePreview': lastMessagePreview,
    'chatStatus': chatStatus,
    'agentStatus': agentStatus,
    'agentEventData': agentEventData,
    'currentToolName': currentToolName,
    'currentToolPhase': currentToolPhase,
    'statusSummary': statusSummary,
    'isActive': isActive,
    'isSubagent': isSubagent,
    'lastActivity': lastActivity?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'aborted': aborted,
    'avatarUrl': avatarUrl,
    'identityTheme': identityTheme,
  };

  /// Get status display text
  String get statusDisplay {
    if (isActive) {
      if (currentToolName != null && currentToolName!.isNotEmpty) {
        return 'Using $currentToolName';
      }
      return statusSummary ?? 'Active';
    }
    if (aborted) return 'Aborted';
    return statusSummary ?? 'Idle';
  }

  /// Get status color
  String get statusColor {
    if (isActive) return 'green';
    if (aborted) return 'red';
    return 'grey';
  }
}