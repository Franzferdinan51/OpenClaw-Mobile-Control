import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Quick actions state using AsyncNotifier pattern
class QuickActionsNotifier extends StateNotifier<AsyncValue<List<QuickAction>>> {
  final GatewayApiService _apiService;
  final StorageService _storageService;

  QuickActionsNotifier({
    required GatewayApiService apiService,
    required StorageService storageService,
  })  : _apiService = apiService,
        _storageService = storageService,
        super(const AsyncValue.loading());

  /// Load all quick actions
  Future<void> loadActions() async {
    state = const AsyncValue.loading();
    
    try {
      final actions = await _apiService.getQuickActions();
      state = AsyncValue.data(actions);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Create a new quick action
  Future<QuickAction?> createAction({
    required String name,
    required String description,
    required String icon,
    required QuickActionCategory category,
    required String command,
    List<String>? params,
  }) async {
    try {
      final action = await _apiService.createQuickAction(
        name: name,
        description: description,
        icon: icon,
        category: category,
        command: command,
        params: params,
      );
      
      // Add to current state
      final currentActions = state.valueOrNull ?? [];
      state = AsyncValue.data([...currentActions, action]);
      
      return action;
    } catch (e) {
      return null;
    }
  }

  /// Delete a quick action
  Future<bool> deleteAction(String actionId) async {
    try {
      await _apiService.deleteQuickAction(actionId);
      
      // Remove from current state
      final currentActions = state.valueOrNull ?? [];
      state = AsyncValue.data(
        currentActions.where((a) => a.id != actionId).toList(),
      );
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Execute a quick action
  Future<QuickActionResult?> executeAction(String actionId) async {
    try {
      // Update use count locally
      final currentActions = state.valueOrNull;
      if (currentActions != null) {
        final index = currentActions.indexWhere((a) => a.id == actionId);
        if (index != -1) {
          currentActions[index] = currentActions[index].copyWith(
            useCount: currentActions[index].useCount + 1,
            lastUsed: DateTime.now(),
          );
          state = AsyncValue.data(List.from(currentActions));
        }
      }

      // Execute via API
      final result = await _apiService.executeQuickAction(actionId);
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Toggle favorite status
  Future<bool> toggleFavorite(String actionId, bool isFavorite) async {
    try {
      await _apiService.toggleFavorite(actionId, isFavorite);
      
      // Update in current state
      final currentActions = state.valueOrNull;
      if (currentActions != null) {
        final index = currentActions.indexWhere((a) => a.id == actionId);
        if (index != -1) {
          currentActions[index] = currentActions[index].copyWith(
            isFavorite: isFavorite,
          );
          state = AsyncValue.data(List.from(currentActions));
        }
      }

      // Update local favorites
      await _storageService.toggleFavoriteAction(actionId, isFavorite);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get action by ID
  QuickAction? getAction(String actionId) {
    return state.valueOrNull?.firstWhere(
      (a) => a.id == actionId,
      orElse: () => throw StateError('Action not found'),
    );
  }

  /// Get actions by category
  List<QuickAction> getActionsByCategory(QuickActionCategory category) {
    return state.valueOrNull
            ?.where((a) => a.category == category)
            .toList() ??
        [];
  }

  /// Get favorite actions
  List<QuickAction> get favoriteActions {
    return state.valueOrNull
            ?.where((a) => a.isFavorite)
            .toList() ??
        [];
  }

  /// Get most used actions
  List<QuickAction> getMostUsedActions({int limit = 5}) {
    final actions = state.valueOrNull ?? [];
    final sorted = List<QuickAction>.from(actions)
      ..sort((a, b) => b.useCount.compareTo(a.useCount));
    return sorted.take(limit).toList();
  }

  /// Get recently used actions
  List<QuickAction> getRecentlyUsedActions({int limit = 5}) {
    final actions = state.valueOrNull ?? [];
    final sorted = List<QuickAction>.from(actions)
      ..sort((a, b) {
        if (a.lastUsed == null && b.lastUsed == null) return 0;
        if (a.lastUsed == null) return 1;
        if (b.lastUsed == null) return -1;
        return b.lastUsed!.compareTo(a.lastUsed!);
      });
    return sorted.take(limit).toList();
  }
}

/// Currently executing action state
class ExecutingActionNotifier extends StateNotifier<String?> {
  ExecutingActionNotifier() : super(null);

  void setExecuting(String? actionId) {
    state = actionId;
  }

  void clear() {
    state = null;
  }
}

/// Provider for quick actions list
final quickActionsProvider =
    StateNotifierProvider<QuickActionsNotifier, AsyncValue<List<QuickAction>>>((ref) {
  final apiService = ref.watch(gatewayApiServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  
  return QuickActionsNotifier(
    apiService: apiService,
    storageService: storageService,
  );
});

/// Provider for a single action by ID
final quickActionProvider = Provider.family<QuickAction?, String>((ref, actionId) {
  final actions = ref.watch(quickActionsProvider).valueOrNull;
  return actions?.firstWhere(
    (a) => a.id == actionId,
    orElse: () => throw StateError('Action not found'),
  );
});

/// Provider for favorite actions
final favoriteActionsProvider = Provider<List<QuickAction>>((ref) {
  final actions = ref.watch(quickActionsProvider).valueOrNull ?? [];
  return actions.where((a) => a.isFavorite).toList();
});

/// Provider for actions grouped by category
final actionsByCategoryProvider = Provider<Map<QuickActionCategory, List<QuickAction>>>((ref) {
  final actions = ref.watch(quickActionsProvider).valueOrNull ?? [];
  
  final map = <QuickActionCategory, List<QuickAction>>{};
  for (final category in QuickActionCategory.values) {
    map[category] = actions.where((a) => a.category == category).toList();
  }
  
  return map;
});

/// Provider for most used actions
final mostUsedActionsProvider = Provider<List<QuickAction>>((ref) {
  final actions = ref.watch(quickActionsProvider).valueOrNull ?? [];
  final sorted = List<QuickAction>.from(actions)
    ..sort((a, b) => b.useCount.compareTo(a.useCount));
  return sorted.take(5).toList();
});

/// Provider for recently used actions
final recentlyUsedActionsProvider = Provider<List<QuickAction>>((ref) {
  final actions = ref.watch(quickActionsProvider).valueOrNull ?? [];
  final sorted = List<QuickAction>.from(actions)
    ..sort((a, b) {
      if (a.lastUsed == null && b.lastUsed == null) return 0;
      if (a.lastUsed == null) return 1;
      if (b.lastUsed == null) return -1;
      return b.lastUsed!.compareTo(a.lastUsed!);
    });
  return sorted.take(5).toList();
});

/// Provider for currently executing action
final executingActionProvider =
    StateNotifierProvider<ExecutingActionNotifier, String?>((ref) {
  return ExecutingActionNotifier();
});