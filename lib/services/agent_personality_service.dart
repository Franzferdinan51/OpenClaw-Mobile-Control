import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/agent_personality.dart';
import '../data/agency_agents.dart';

/// Service for managing agent personality modes
class AgentPersonalityService extends ChangeNotifier {
  AgentPersonality? _activeAgent;
  List<AgentPersonality> _activeMultiAgents = [];
  final Set<String> _favoriteAgentIds = {};
  final Map<String, List<String>> _completedTasks = {};
  bool _isMultiAgentMode = false;

  // Storage keys
  static const String _activeAgentKey = 'active_agent';
  static const String _favoritesKey = 'favorite_agents';
  static const String _multiAgentKey = 'multi_agents';
  static const String _completedTasksKey = 'completed_tasks';

  /// Get currently active single agent
  AgentPersonality? get activeAgent => _activeAgent;

  /// Get list of active multiple agents
  List<AgentPersonality> get activeMultiAgents => _activeMultiAgents;

  /// Check if in multi-agent mode
  bool get isMultiAgentMode => _isMultiAgentMode;

  /// Get favorite agent IDs
  Set<String> get favoriteAgentIds => _favoriteAgentIds;

  /// Get favorite agents
  List<AgentPersonality> get favoriteAgents {
    return AgencyAgentsData.allAgents
        .where((agent) => _favoriteAgentIds.contains(agent.id))
        .toList();
  }

  /// Get all agents
  List<AgentPersonality> get allAgents => AgencyAgentsData.allAgents;

  /// Get all templates
  List<AgentTemplate> get templates => AgencyAgentsData.templates;

  /// Get available divisions
  List<AgentDivision> get divisions => AgentDivision.values;

  /// Initialize service (load from storage if needed)
  Future<void> initialize() async {
    // TODO: Load from SharedPreferences or local storage
    // For now, just notify listeners
    notifyListeners();
  }

  /// Activate a single agent
  void activateAgent(AgentPersonality agent) {
    _activeAgent = agent;
    _isMultiAgentMode = false;
    _activeMultiAgents.clear();
    _completedTasks[agent.id] = [];
    notifyListeners();
  }

  /// Deactivate current agent and return to default
  void deactivateAgent() {
    _activeAgent = null;
    _isMultiAgentMode = false;
    _activeMultiAgents.clear();
    notifyListeners();
  }

  /// Start multi-agent orchestration
  void activateMultiAgentMode(List<AgentPersonality> agents) {
    _isMultiAgentMode = true;
    _activeMultiAgents = agents;
    _activeAgent = null;
    for (final agent in agents) {
      _completedTasks[agent.id] = [];
    }
    notifyListeners();
  }

  /// Add agent to multi-agent session
  void addAgentToMultiAgent(AgentPersonality agent) {
    if (!_activeMultiAgents.any((a) => a.id == agent.id)) {
      _activeMultiAgents.add(agent);
      _completedTasks[agent.id] = [];
      notifyListeners();
    }
  }

  /// Remove agent from multi-agent session
  void removeAgentFromMultiAgent(String agentId) {
    _activeMultiAgents.removeWhere((a) => a.id == agentId);
    _completedTasks.remove(agentId);
    if (_activeMultiAgents.isEmpty) {
      _isMultiAgentMode = false;
    }
    notifyListeners();
  }

  /// Toggle multi-agent mode off
  void exitMultiAgentMode() {
    _isMultiAgentMode = false;
    _activeMultiAgents.clear();
    _completedTasks.clear();
    notifyListeners();
  }

  /// Toggle favorite status
  void toggleFavorite(String agentId) {
    if (_favoriteAgentIds.contains(agentId)) {
      _favoriteAgentIds.remove(agentId);
    } else {
      _favoriteAgentIds.add(agentId);
    }
    notifyListeners();
  }

  /// Check if agent is favorite
  bool isFavorite(String agentId) {
    return _favoriteAgentIds.contains(agentId);
  }

  /// Mark task as completed for active agent
  void completeTask(String task) {
    if (_activeAgent != null) {
      _completedTasks[_activeAgent!.id] ??= [];
      _completedTasks[_activeAgent!.id]!.add(task);
      notifyListeners();
    } else if (_isMultiAgentMode) {
      // For multi-agent, tasks are attributed to all or could be agent-specific
      for (final agent in _activeMultiAgents) {
        _completedTasks[agent.id] ??= [];
        _completedTasks[agent.id]!.add(task);
      }
      notifyListeners();
    }
  }

  /// Get completed tasks for an agent
  List<String> getCompletedTasks(String agentId) {
    return _completedTasks[agentId] ?? [];
  }

  /// Get agents by division
  List<AgentPersonality> getAgentsByDivision(AgentDivision division) {
    return AgencyAgentsData.getByDivision(division);
  }

  /// Get agent by ID
  AgentPersonality? getAgentById(String id) {
    return AgencyAgentsData.getById(id);
  }

  /// Search agents
  List<AgentPersonality> searchAgents(String query) {
    return AgencyAgentsData.search(query);
  }

  /// Get agents from a template
  List<AgentPersonality> getAgentsFromTemplate(AgentTemplate template) {
    return template.agentIds
        .map((id) => AgencyAgentsData.getById(id))
        .where((agent) => agent != null)
        .cast<AgentPersonality>()
        .toList();
  }

  /// Get agents by IDs
  List<AgentPersonality> getAgentsByIds(List<String> ids) {
    return ids
        .map((id) => AgencyAgentsData.getById(id))
        .where((agent) => agent != null)
        .cast<AgentPersonality>()
        .toList();
  }

  /// Get division counts
  Map<AgentDivision, int> getDivisionCounts() {
    return AgencyAgentsData.getDivisionCounts();
  }

  /// Generate agent response based on current agent mode
  String generateAgentResponse(String userInput) {
    if (_activeAgent != null) {
      return _generateSingleAgentResponse(_activeAgent!, userInput);
    } else if (_isMultiAgentMode && _activeMultiAgents.isNotEmpty) {
      return _generateMultiAgentResponse(userInput);
    }
    return _generateDefaultResponse(userInput);
  }

  String _generateSingleAgentResponse(AgentPersonality agent, String userInput) {
    final lowerInput = userInput.toLowerCase();
    
    // Check for matching phrases
    for (final entry in agent.examplePhrases.entries) {
      if (lowerInput.contains(entry.key)) {
        return '${agent.emoji} ${entry.value}';
      }
    }

    // Default response based on division
    switch (agent.division) {
      case AgentDivision.engineering:
        return '${agent.emoji} Ready to work on: "$userInput"\n\nI\'ll analyze the requirements and provide a technical solution. What\'s your priority?';
      case AgentDivision.design:
        return '${agent.emoji} Let\'s create something beautiful for: "$userInput"\n\nI\'ll focus on the visual and user experience aspects. Any specific style preferences?';
      case AgentDivision.marketing:
        return '${agent.emoji} Marketing strategy for: "$userInput"\n\nI\'ll develop a growth-focused approach. What\'s your target audience?';
      case AgentDivision.product:
        return '${agent.emoji} Product focus on: "$userInput"\n\nI\'ll help prioritize and deliver value. What metrics matter most?';
      case AgentDivision.projectManagement:
        return '${agent.emoji} Managing: "$userInput"\n\nI\'ll keep things on track. What\'s the timeline?';
      case AgentDivision.testing:
        return '${agent.emoji} Testing: "$userInput"\n\nI\'ll ensure quality and gather evidence. What\'s the acceptance criteria?';
      case AgentDivision.support:
        return '${agent.emoji} Supporting: "$userInput"\n\nI\'ll help resolve this. Can you provide more details?';
      case AgentDivision.spatialComputing:
        return '${agent.emoji} Building spatial experience: "$userInput"\n\nI\'ll create an immersive solution. What\'s the target platform?';
      case AgentDivision.specialized:
        return '${agent.emoji} Working on: "$userInput"\n\nI\'ll leverage specialized expertise. What specific aspect needs attention?';
    }
  }

  String _generateMultiAgentResponse(String userInput) {
    final agents = _activeMultiAgents.map((a) => a.emoji).join(' ');
    return '$agents Team responding to: "$userInput"\n\nCoordinating ${_activeMultiAgents.length} agents to address your request. Each specialist is contributing their expertise.';
  }

  String _generateDefaultResponse(String userInput) {
    final lowerInput = userInput.toLowerCase();
    
    if (lowerInput.contains('agent')) {
      return '🤖 I have access to 61 specialized agents!\n\nSay "activate [agent name]" to switch to a specific agent mode, or browse the Agent Library to see all available agents.';
    } else if (lowerInput.contains('help')) {
      return '💡 I can work in different agent modes:\n\n• Say "activate [agent]" to use a specific specialist\n• Browse Agent Library to see all 61 agents\n• Use Multi-Agent mode for complex projects\n• Try templates like "App Launch Team" or "Marketing Campaign"';
    }
    return '🦆 $userInput\n\nTip: Activate an agent mode for specialized help! Say "help agents" to learn more.';
  }
}