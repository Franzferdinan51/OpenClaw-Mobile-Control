import 'package:flutter/material.dart';

/// Division types for agent organization
enum AgentDivision {
  engineering,
  design,
  marketing,
  product,
  projectManagement,
  testing,
  support,
  spatialComputing,
  specialized,
}

/// Extension to get display properties for divisions
extension AgentDivisionExtension on AgentDivision {
  String get displayName {
    switch (this) {
      case AgentDivision.engineering:
        return 'Engineering';
      case AgentDivision.design:
        return 'Design';
      case AgentDivision.marketing:
        return 'Marketing';
      case AgentDivision.product:
        return 'Product';
      case AgentDivision.projectManagement:
        return 'Project Management';
      case AgentDivision.testing:
        return 'Testing';
      case AgentDivision.support:
        return 'Support';
      case AgentDivision.spatialComputing:
        return 'Spatial Computing';
      case AgentDivision.specialized:
        return 'Specialized';
    }
  }

  String get emoji {
    switch (this) {
      case AgentDivision.engineering:
        return '💻';
      case AgentDivision.design:
        return '🎨';
      case AgentDivision.marketing:
        return '📢';
      case AgentDivision.product:
        return '📊';
      case AgentDivision.projectManagement:
        return '🎬';
      case AgentDivision.testing:
        return '🧪';
      case AgentDivision.support:
        return '🛟';
      case AgentDivision.spatialComputing:
        return '🥽';
      case AgentDivision.specialized:
        return '🎯';
    }
  }

  Color get color {
    switch (this) {
      case AgentDivision.engineering:
        return const Color(0xFF2196F3); // Blue
      case AgentDivision.design:
        return const Color(0xFF9C27B0); // Purple
      case AgentDivision.marketing:
        return const Color(0xFFFF9800); // Orange
      case AgentDivision.product:
        return const Color(0xFF4CAF50); // Green
      case AgentDivision.projectManagement:
        return const Color(0xFFE91E63); // Pink
      case AgentDivision.testing:
        return const Color(0xFF00BCD4); // Cyan
      case AgentDivision.support:
        return const Color(0xFF795548); // Brown
      case AgentDivision.spatialComputing:
        return const Color(0xFF607D8B); // Blue Grey
      case AgentDivision.specialized:
        return const Color(0xFFFFEB3B); // Yellow
    }
  }

  IconData get icon {
    switch (this) {
      case AgentDivision.engineering:
        return Icons.code;
      case AgentDivision.design:
        return Icons.brush;
      case AgentDivision.marketing:
        return Icons.campaign;
      case AgentDivision.product:
        return Icons.inventory_2;
      case AgentDivision.projectManagement:
        return Icons.event_note;
      case AgentDivision.testing:
        return Icons.science;
      case AgentDivision.support:
        return Icons.support_agent;
      case AgentDivision.spatialComputing:
        return Icons.view_in_ar;
      case AgentDivision.specialized:
        return Icons.psychology;
    }
  }
}

/// Model representing an agent personality
class AgentPersonality {
  final String id;
  final String name;
  final String shortDescription; // Mobile-friendly description
  final String fullDescription;
  final AgentDivision division;
  final String emoji;
  final String role;
  final List<String> specialties;
  final List<String> workflows;
  final List<String> deliverables;
  final List<String> successMetrics;
  final String communicationStyle;
  final String greeting;
  final Map<String, String> examplePhrases;

  const AgentPersonality({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.fullDescription,
    required this.division,
    required this.emoji,
    required this.role,
    required this.specialties,
    required this.workflows,
    required this.deliverables,
    required this.successMetrics,
    required this.communicationStyle,
    required this.greeting,
    this.examplePhrases = const {},
  });

  /// Get a color-coded display name
  String get displayName => '$emoji $name';

  /// Create a copy with modifications
  AgentPersonality copyWith({
    String? id,
    String? name,
    String? shortDescription,
    String? fullDescription,
    AgentDivision? division,
    String? emoji,
    String? role,
    List<String>? specialties,
    List<String>? workflows,
    List<String>? deliverables,
    List<String>? successMetrics,
    String? communicationStyle,
    String? greeting,
    Map<String, String>? examplePhrases,
  }) {
    return AgentPersonality(
      id: id ?? this.id,
      name: name ?? this.name,
      shortDescription: shortDescription ?? this.shortDescription,
      fullDescription: fullDescription ?? this.fullDescription,
      division: division ?? this.division,
      emoji: emoji ?? this.emoji,
      role: role ?? this.role,
      specialties: specialties ?? this.specialties,
      workflows: workflows ?? this.workflows,
      deliverables: deliverables ?? this.deliverables,
      successMetrics: successMetrics ?? this.successMetrics,
      communicationStyle: communicationStyle ?? this.communicationStyle,
      greeting: greeting ?? this.greeting,
      examplePhrases: examplePhrases ?? this.examplePhrases,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'shortDescription': shortDescription,
      'fullDescription': fullDescription,
      'division': division.name,
      'emoji': emoji,
      'role': role,
      'specialties': specialties,
      'workflows': workflows,
      'deliverables': deliverables,
      'successMetrics': successMetrics,
      'communicationStyle': communicationStyle,
      'greeting': greeting,
      'examplePhrases': examplePhrases,
    };
  }

  /// Create from JSON map
  factory AgentPersonality.fromJson(Map<String, dynamic> json) {
    return AgentPersonality(
      id: json['id'] as String,
      name: json['name'] as String,
      shortDescription: json['shortDescription'] as String,
      fullDescription: json['fullDescription'] as String,
      division: AgentDivision.values.firstWhere(
        (d) => d.name == json['division'],
        orElse: () => AgentDivision.specialized,
      ),
      emoji: json['emoji'] as String,
      role: json['role'] as String,
      specialties: List<String>.from(json['specialties'] as List),
      workflows: List<String>.from(json['workflows'] as List),
      deliverables: List<String>.from(json['deliverables'] as List),
      successMetrics: List<String>.from(json['successMetrics'] as List),
      communicationStyle: json['communicationStyle'] as String,
      greeting: json['greeting'] as String,
      examplePhrases: Map<String, String>.from(json['examplePhrases'] as Map? ?? {}),
    );
  }
}

/// Model for agent template (pre-built agent combinations)
class AgentTemplate {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final List<String> agentIds;
  final String useCase;

  const AgentTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.agentIds,
    required this.useCase,
  });
}

/// Model for active agent session
class ActiveAgentSession {
  final AgentPersonality agent;
  final DateTime activatedAt;
  final List<String> completedTasks;

  const ActiveAgentSession({
    required this.agent,
    required this.activatedAt,
    this.completedTasks = const [],
  });
}