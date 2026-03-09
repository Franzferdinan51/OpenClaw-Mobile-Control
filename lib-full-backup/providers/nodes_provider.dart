import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Nodes state using AsyncNotifier pattern
class NodesNotifier extends StateNotifier<AsyncValue<List<Node>>> {
  final GatewayApiService _apiService;
  final GatewayWebSocketService _webSocketService;

  NodesNotifier({
    required GatewayApiService apiService,
    required GatewayWebSocketService webSocketService,
  })  : _apiService = apiService,
        _webSocketService = webSocketService,
        super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    // Listen for real-time node updates
    _webSocketService.events.listen((event) {
      if (event.type == GatewayEventType.nodeUpdate) {
        final updatedNode = event.nodeUpdate;
        if (updatedNode != null) {
          _updateNodeInState(updatedNode);
        }
      }
    });
  }

  /// Load all nodes
  Future<void> loadNodes() async {
    state = const AsyncValue.loading();
    
    try {
      final nodes = await _apiService.getNodes();
      state = AsyncValue.data(nodes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Pair a new node
  Future<bool> pairNode({
    required String code,
    String? name,
  }) async {
    try {
      await _apiService.pairNode(code: code, name: name);
      await loadNodes(); // Refresh list
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Unpair a node
  Future<bool> unpairNode(String nodeId) async {
    try {
      await _apiService.unpairNode(nodeId);
      
      // Remove from current state
      final currentNodes = state.valueOrNull ?? [];
      state = AsyncValue.data(
        currentNodes.where((n) => n.id != nodeId).toList(),
      );
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Send notification to node
  Future<bool> sendNotification({
    required String nodeId,
    required String title,
    required String message,
  }) async {
    try {
      await _apiService.sendNodeNotification(
        nodeId: nodeId,
        title: title,
        message: message,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update node in state from WebSocket event
  void _updateNodeInState(Node updatedNode) {
    final currentNodes = state.valueOrNull;
    if (currentNodes == null) return;

    final index = currentNodes.indexWhere((n) => n.id == updatedNode.id);
    if (index != -1) {
      currentNodes[index] = updatedNode;
    } else {
      currentNodes.add(updatedNode);
    }
    
    state = AsyncValue.data(List.from(currentNodes));
  }

  /// Get node by ID
  Node? getNode(String nodeId) {
    return state.valueOrNull?.firstWhere(
      (n) => n.id == nodeId,
      orElse: () => throw StateError('Node not found'),
    );
  }

  /// Get nodes by status
  List<Node> getNodesByStatus(NodeStatus status) {
    return state.valueOrNull
            ?.where((n) => n.status == status)
            .toList() ??
        [];
  }

  /// Get online nodes
  List<Node> get onlineNodes {
    return state.valueOrNull
            ?.where((n) => n.status == NodeStatus.online)
            .toList() ??
        [];
  }

  /// Get nodes with specific capability
  List<Node> getNodesWithCapability(String capability) {
    return state.valueOrNull?.where((n) {
      switch (capability) {
        case 'camera':
          return n.capabilities.hasCamera;
        case 'screen':
          return n.capabilities.hasScreen;
        case 'location':
          return n.capabilities.hasLocation;
        case 'notifications':
          return n.capabilities.hasNotifications;
        case 'files':
          return n.capabilities.hasFiles;
        case 'shell':
          return n.capabilities.hasShell;
        default:
          return false;
      }
    }).toList() ?? [];
  }
}

/// Provider for nodes list
final nodesProvider =
    StateNotifierProvider<NodesNotifier, AsyncValue<List<Node>>>((ref) {
  final apiService = ref.watch(gatewayApiServiceProvider);
  final wsService = ref.watch(gatewayWebSocketServiceProvider);
  
  return NodesNotifier(
    apiService: apiService,
    webSocketService: wsService,
  );
});

/// Provider for a single node by ID
final nodeProvider = Provider.family<Node?, String>((ref, nodeId) {
  final nodes = ref.watch(nodesProvider).valueOrNull;
  return nodes?.firstWhere(
    (n) => n.id == nodeId,
    orElse: () => throw StateError('Node not found'),
  );
});

/// Provider for online nodes count
final onlineNodesCountProvider = Provider<int>((ref) {
  final nodes = ref.watch(nodesProvider).valueOrNull;
  return nodes?.where((n) => n.status == NodeStatus.online).length ?? 0;
});

/// Provider for nodes grouped by status
final nodesByStatusProvider = Provider<Map<NodeStatus, List<Node>>>((ref) {
  final nodes = ref.watch(nodesProvider).valueOrNull ?? [];
  
  final map = <NodeStatus, List<Node>>{};
  for (final status in NodeStatus.values) {
    map[status] = nodes.where((n) => n.status == status).toList();
  }
  
  return map;
});

/// Provider for nodes grouped by type
final nodesByTypeProvider = Provider<Map<String, List<Node>>>((ref) {
  final nodes = ref.watch(nodesProvider).valueOrNull ?? [];
  
  final map = <String, List<Node>>{};
  for (final node in nodes) {
    final type = node.type;
    map.putIfAbsent(type, () => []);
    map[type]!.add(node);
  }
  
  return map;
});

/// Provider for nodes with camera capability
final nodesWithCameraProvider = Provider<List<Node>>((ref) {
  return ref.watch(nodesProvider).valueOrNull
          ?.where((n) => n.capabilities.hasCamera)
          .toList() ??
      [];
});

/// Provider for nodes with screen capability
final nodesWithScreenProvider = Provider<List<Node>>((ref) {
  return ref.watch(nodesProvider).valueOrNull
          ?.where((n) => n.capabilities.hasScreen)
          .toList() ??
      [];
});