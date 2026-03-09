/// Quick action model for predefined actions
class QuickAction {
  final String id;
  final String name;
  final String description;
  final String icon;
  final QuickActionCategory category;
  final String command;
  final List<String>? params;
  final bool isFavorite;
  final int useCount;
  final DateTime? lastUsed;

  const QuickAction({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.command,
    this.params,
    this.isFavorite = false,
    this.useCount = 0,
    this.lastUsed,
  });

  factory QuickAction.fromJson(Map<String, dynamic> json) {
    return QuickAction(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Action',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? 'flash_on',
      category: QuickActionCategory.fromString(
        json['category'] as String? ?? 'general',
      ),
      command: json['command'] as String? ?? '',
      params: (json['params'] as List<dynamic>?)?.map((e) => e as String).toList(),
      isFavorite: json['isFavorite'] as bool? ?? false,
      useCount: json['useCount'] as int? ?? 0,
      lastUsed: json['lastUsed'] != null
          ? DateTime.parse(json['lastUsed'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'category': category.name,
        'command': command,
        'params': params,
        'isFavorite': isFavorite,
        'useCount': useCount,
        'lastUsed': lastUsed?.toIso8601String(),
      };

  QuickAction copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    QuickActionCategory? category,
    String? command,
    List<String>? params,
    bool? isFavorite,
    int? useCount,
    DateTime? lastUsed,
  }) {
    return QuickAction(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      category: category ?? this.category,
      command: command ?? this.command,
      params: params ?? this.params,
      isFavorite: isFavorite ?? this.isFavorite,
      useCount: useCount ?? this.useCount,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }
}

enum QuickActionCategory {
  system,
  media,
  network,
  automation,
  communication,
  general;

  static QuickActionCategory fromString(String value) {
    return QuickActionCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => QuickActionCategory.general,
    );
  }
}

/// Quick action execution result
class QuickActionResult {
  final String actionId;
  final bool success;
  final String message;
  final DateTime executedAt;
  final Map<String, dynamic>? data;

  const QuickActionResult({
    required this.actionId,
    required this.success,
    required this.message,
    required this.executedAt,
    this.data,
  });

  factory QuickActionResult.fromJson(Map<String, dynamic> json) {
    return QuickActionResult(
      actionId: json['actionId'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      executedAt: json['executedAt'] != null
          ? DateTime.parse(json['executedAt'] as String)
          : DateTime.now(),
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'actionId': actionId,
        'success': success,
        'message': message,
        'executedAt': executedAt.toIso8601String(),
        'data': data,
      };
}