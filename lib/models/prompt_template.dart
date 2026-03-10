import 'package:flutter/material.dart';

/// Category enum for organizing templates
enum PromptCategory {
  coding,
  writing,
  analysis,
  research,
  creative,
  productivity,
  communication,
  learning,
  debugging,
  architecture,
  testing,
  documentation,
  custom,
}

/// Extension for PromptCategory display properties
extension PromptCategoryExtension on PromptCategory {
  String get displayName {
    switch (this) {
      case PromptCategory.coding:
        return 'Coding';
      case PromptCategory.writing:
        return 'Writing';
      case PromptCategory.analysis:
        return 'Analysis';
      case PromptCategory.research:
        return 'Research';
      case PromptCategory.creative:
        return 'Creative';
      case PromptCategory.productivity:
        return 'Productivity';
      case PromptCategory.communication:
        return 'Communication';
      case PromptCategory.learning:
        return 'Learning';
      case PromptCategory.debugging:
        return 'Debugging';
      case PromptCategory.architecture:
        return 'Architecture';
      case PromptCategory.testing:
        return 'Testing';
      case PromptCategory.documentation:
        return 'Documentation';
      case PromptCategory.custom:
        return 'Custom';
    }
  }

  String get emoji {
    switch (this) {
      case PromptCategory.coding:
        return '💻';
      case PromptCategory.writing:
        return '✍️';
      case PromptCategory.analysis:
        return '📊';
      case PromptCategory.research:
        return '🔍';
      case PromptCategory.creative:
        return '🎨';
      case PromptCategory.productivity:
        return '⚡';
      case PromptCategory.communication:
        return '💬';
      case PromptCategory.learning:
        return '📚';
      case PromptCategory.debugging:
        return '🐛';
      case PromptCategory.architecture:
        return '🏗️';
      case PromptCategory.testing:
        return '🧪';
      case PromptCategory.documentation:
        return '📄';
      case PromptCategory.custom:
        return '⭐';
    }
  }

  Color get color {
    switch (this) {
      case PromptCategory.coding:
        return const Color(0xFF2196F3); // Blue
      case PromptCategory.writing:
        return const Color(0xFF9C27B0); // Purple
      case PromptCategory.analysis:
        return const Color(0xFF4CAF50); // Green
      case PromptCategory.research:
        return const Color(0xFFFF9800); // Orange
      case PromptCategory.creative:
        return const Color(0xFFE91E63); // Pink
      case PromptCategory.productivity:
        return const Color(0xFF00BCD4); // Cyan
      case PromptCategory.communication:
        return const Color(0xFF3F51B5); // Indigo
      case PromptCategory.learning:
        return const Color(0xFF8BC34A); // Light Green
      case PromptCategory.debugging:
        return const Color(0xFFF44336); // Red
      case PromptCategory.architecture:
        return const Color(0xFF607D8B); // Blue Grey
      case PromptCategory.testing:
        return const Color(0xFFFFEB3B); // Yellow
      case PromptCategory.documentation:
        return const Color(0xFF795548); // Brown
      case PromptCategory.custom:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  IconData get icon {
    switch (this) {
      case PromptCategory.coding:
        return Icons.code;
      case PromptCategory.writing:
        return Icons.edit;
      case PromptCategory.analysis:
        return Icons.analytics;
      case PromptCategory.research:
        return Icons.search;
      case PromptCategory.creative:
        return Icons.palette;
      case PromptCategory.productivity:
        return Icons.bolt;
      case PromptCategory.communication:
        return Icons.chat;
      case PromptCategory.learning:
        return Icons.school;
      case PromptCategory.debugging:
        return Icons.bug_report;
      case PromptCategory.architecture:
        return Icons.account_tree;
      case PromptCategory.testing:
        return Icons.science;
      case PromptCategory.documentation:
        return Icons.description;
      case PromptCategory.custom:
        return Icons.star;
    }
  }

  static PromptCategory fromString(String value) {
    return PromptCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => PromptCategory.custom,
    );
  }
}

/// Model representing a variable in a prompt template
class PromptVariable {
  final String name;
  final String description;
  final String? defaultValue;
  final bool required;

  const PromptVariable({
    required this.name,
    required this.description,
    this.defaultValue,
    this.required = true,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'defaultValue': defaultValue,
    'required': required,
  };

  factory PromptVariable.fromJson(Map<String, dynamic> json) {
    return PromptVariable(
      name: json['name'] as String,
      description: json['description'] as String,
      defaultValue: json['defaultValue'] as String?,
      required: json['required'] as bool? ?? true,
    );
  }

  PromptVariable copyWith({
    String? name,
    String? description,
    String? defaultValue,
    bool? required,
  }) {
    return PromptVariable(
      name: name ?? this.name,
      description: description ?? this.description,
      defaultValue: defaultValue ?? this.defaultValue,
      required: required ?? this.required,
    );
  }
}

/// Model representing a prompt template
class PromptTemplate {
  final String id;
  final String title;
  final String prompt;
  final PromptCategory category;
  final String? description;
  final List<PromptVariable> variables;
  final String? author;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int? usageCount;
  final bool isFavorite;
  final bool isDefault; // Can't be deleted if true

  const PromptTemplate({
    required this.id,
    required this.title,
    required this.prompt,
    required this.category,
    this.description,
    this.variables = const [],
    this.author,
    required this.createdAt,
    this.updatedAt,
    this.usageCount = 0,
    this.isFavorite = false,
    this.isDefault = false,
  });

  /// Get display name with emoji
  String get displayName => '${category.emoji} $title';

  /// Check if template has variables
  bool get hasVariables => variables.isNotEmpty;

  /// Get variable placeholders from prompt (e.g., {{variable_name}})
  List<String> extractVariablePlaceholders() {
    final regex = RegExp(r'\{\{(\w+)\}\}');
    return regex.allMatches(prompt).map((m) => m.group(1)!).toList();
  }

  /// Fill template with variable values
  String fillVariables(Map<String, String> values) {
    String filled = prompt;
    for (final entry in values.entries) {
      filled = filled.replaceAll('{{${entry.key}}}', entry.value);
    }
    return filled;
  }

  /// Create a copy with modifications
  PromptTemplate copyWith({
    String? id,
    String? title,
    String? prompt,
    PromptCategory? category,
    String? description,
    List<PromptVariable>? variables,
    String? author,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? usageCount,
    bool? isFavorite,
    bool? isDefault,
  }) {
    return PromptTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      category: category ?? this.category,
      description: description ?? this.description,
      variables: variables ?? this.variables,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      usageCount: usageCount ?? this.usageCount,
      isFavorite: isFavorite ?? this.isFavorite,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'prompt': prompt,
    'category': category.name,
    'description': description,
    'variables': variables.map((v) => v.toJson()).toList(),
    'author': author,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'usageCount': usageCount,
    'isFavorite': isFavorite,
    'isDefault': isDefault,
  };

  /// Create from JSON map
  factory PromptTemplate.fromJson(Map<String, dynamic> json) {
    return PromptTemplate(
      id: json['id'] as String,
      title: json['title'] as String,
      prompt: json['prompt'] as String,
      category: PromptCategoryExtension.fromString(json['category'] as String),
      description: json['description'] as String?,
      variables: (json['variables'] as List<dynamic>?)
          ?.map((v) => PromptVariable.fromJson(v as Map<String, dynamic>))
          .toList() ?? [],
      author: json['author'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt'] as String) 
          : null,
      usageCount: json['usageCount'] as int? ?? 0,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}