import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Agents state using AsyncNotifier pattern
class AgentsNotifier extends StateNotifier<AsyncValue<List<Agent>>> {
  final GatewayApiService _apiService;
  final GatewayWebSocketService _webSocketService;

  AgentsNotifier({
    required GatewayApiService apiService,
    required GatewayWebSocketService webSocketService,
  })  : _apiService = apiService,
        _webSocketService = webSocketService,
        super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    // Listen for real-time agent updates
    _webSocketService.events.listen((event) {
      if (event.type == GatewayEventType.agentUpdate) {
        final updatedAgent = event.agentUpdate;
        if (updatedAgent != null) {
          _updateAgentInState(updatedAgent);
        }
      }
    });
  }

  /// Load all agents
  Future<void> loadAgents() async {
    state = const AsyncValue.loading();
    
    try {
      final agents = await _apiService.getAgents();
      state = AsyncValue.data(agents);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Create a new agent
  Future<Agent?> createAgent({
    required String name,
    required String model,
    String? provider,
    List<String>? capabilities,
  }) async {
    try {
      final agent = await _apiService.createAgent(
        name: name,
        model: model,
        provider: provider,
        capabilities: capabilities,
      );
      
      // Add to current state
      final currentAgents = state.valueOrNull ?? [];
      state = AsyncValue.data([...currentAgents, agent]);
      
      return agent;
    } catch (e) {
      return null;
    }
  }

  /// Delete an agent
  Future<bool> deleteAgent(String agentId) async {
    try {
      await _apiService.deleteAgent(agentId);
      
      // Remove from current state
      final currentAgents = state.valueOrNull ?? [];
      state = AsyncValue.data(
        currentAgents.where((a) => a.id != agentId).toList(),
      );
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update agent status
  Future<bool> setAgentStatus(String agentId, AgentStatus status) async {
    try {
      await _apiService.setAgentStatus(agentId, status);
      
      // Update in current state
      final currentAgents = state.valueOrNull ?? [];
      final index = currentAgents.indexWhere((a) => a.id == agentId);
      if (index != -1) {
        currentAgents[index] = currentAgents[index].copyWith(status: status);
        state = AsyncValue.data(List.from(currentAgents));
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update agent in state from WebSocket event
  void _updateAgentInState(Agent updatedAgent) {
    final currentAgents = state.valueOrNull;
    if (currentAgents == null) return;

    final index = currentAgents.indexWhere((a) => a.id == updatedAgent.id);
    if (index != -1) {
      currentAgents[index] = updatedAgent;
    } else {
      currentAgents.add(updatedAgent);
    }
    
    state = AsyncValue.data(List.from(currentAgents));
  }

  /// Get agent by ID
  Agent? getAgent(String agentId) {
    return state.valueOrNull?.firstWhere(
      (a) => a.id == agentId,
      orElse: () => throw StateError('Agent not found'),
    );
  }

  /// Get agents by status
  List<Agent> getAgentsByStatus(AgentStatus status) {
    return state.valueOrNull
            ?.where((a) => a.status == status)
            .toList() ??
        [];
  }

  /// Get active agents
  List<Agent> get activeAgents {
    return state.valueOrNull
            ?.where((a) => 
                a.status == AgentStatus.active || 
                a.status == AgentStatus.busy)
            .toList() ??
        [];
  }
}

/// Provider for agents list
final agentsProvider =
    StateNotifierProvider<AgentsNotifier, AsyncValue<List<Agent>>>((ref) {
  final apiService = ref.watch(gatewayApiServiceProvider);
  final wsService = ref.watch(gatewayWebSocketServiceProvider);
  
  return AgentsNotifier(
    apiService: apiService,
    webSocketService: wsService,
  );
});

/// Provider for a single agent by ID
final agentProvider = Provider.family<Agent?, String>((ref, agentId) {
  final agents = ref.watch(agentsProvider).valueOrNull;
  return agents?.firstWhere(
    (a) => a.id == agentId,
    orElse: () => throw StateError('Agent not found'),
  );
});

/// Provider for active agents count
final activeAgentsCountProvider = Provider<int>((ref) {
  final agents = ref.watch(agentsProvider).valueOrNull;
  return agents?.where((a) => 
      a.status == AgentStatus.active || 
      a.status == AgentStatus.busy).length ?? 0;
});

/// Provider for agents grouped by status
final agentsByStatusProvider = Provider<Map<AgentStatus, List<Agent>>>((ref) {
  final agents = ref.watch(agentsProvider).valueOrNull ?? [];
  
  final map = <AgentStatus, List<Agent>>{};
  for (final status in AgentStatus.values) {
    map[status] = agents.where((a) => a.status == status).toList();
  }
  
  return map;
});

/// Provider for total cost across all agents
final totalCostProvider = Provider<double>((ref) {
  final agents = ref.watch(agentsProvider).valueOrNull ?? [];
  return agents.fold(0.0, (sum, a) => sum + a.totalCost);
});