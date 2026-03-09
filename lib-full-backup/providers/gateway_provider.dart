import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Gateway status state
class GatewayState {
  final GatewayStatus? status;
  final bool isConnected;
  final bool isConnecting;
  final String? error;
  final DateTime? lastUpdated;

  const GatewayState({
    this.status,
    this.isConnected = false,
    this.isConnecting = false,
    this.error,
    this.lastUpdated,
  });

  GatewayState copyWith({
    GatewayStatus? status,
    bool? isConnected,
    bool? isConnecting,
    String? error,
    DateTime? lastUpdated,
  }) {
    return GatewayState(
      status: status ?? this.status,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Gateway provider using AsyncNotifier pattern
class GatewayNotifier extends StateNotifier<GatewayState> {
  final GatewayApiService _apiService;
  final GatewayWebSocketService _webSocketService;

  GatewayNotifier({
    required GatewayApiService apiService,
    required GatewayWebSocketService webSocketService,
  })  : _apiService = apiService,
        _webSocketService = webSocketService,
        super(const GatewayState()) {
    _init();
  }

  void _init() {
    // Listen to WebSocket connection state
    _webSocketService.connectionState.listen((connectionState) {
      switch (connectionState) {
        case ConnectionState.connecting:
          state = state.copyWith(isConnecting: true, error: null);
          break;
        case ConnectionState.connected:
          state = state.copyWith(
            isConnected: true,
            isConnecting: false,
            error: null,
          );
          break;
        case ConnectionState.disconnected:
          state = state.copyWith(
            isConnected: false,
            isConnecting: false,
          );
          break;
        case ConnectionState.error:
          state = state.copyWith(
            isConnected: false,
            isConnecting: false,
            error: 'Connection error',
          );
          break;
      }
    });

    // Listen for gateway events
    _webSocketService.events.listen((event) {
      if (event.type == GatewayEventType.agentUpdate) {
        // Refresh status on agent updates
        refreshStatus();
      }
    });
  }

  /// Connect to the gateway
  Future<void> connect() async {
    state = state.copyWith(isConnecting: true, error: null);
    
    try {
      // Test API connection
      final isHealthy = await _apiService.healthCheck();
      if (!isHealthy) {
        throw Exception('Gateway health check failed');
      }

      // Connect WebSocket
      _webSocketService.connect();

      // Fetch initial status
      await refreshStatus();
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        error: e.toString(),
      );
    }
  }

  /// Disconnect from the gateway
  void disconnect() {
    _webSocketService.disconnect();
    state = const GatewayState();
  }

  /// Refresh gateway status
  Future<void> refreshStatus() async {
    try {
      final status = await _apiService.getGatewayStatus();
      state = state.copyWith(
        status: status,
        lastUpdated: DateTime.now(),
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Reconnect to the gateway
  Future<void> reconnect() async {
    disconnect();
    await connect();
  }

  /// Update gateway URL
  void updateUrl(String url) {
    _apiService.updateBaseUrl(url);
  }

  /// Update authentication token
  void updateToken(String? token) {
    _apiService.updateToken(token);
  }
}

/// Provider for the API service
final gatewayApiServiceProvider = Provider<GatewayApiService>((ref) {
  // These will be populated from settings
  return GatewayApiService(
    baseUrl: 'http://localhost:18789',
    token: null,
  );
});

/// Provider for the WebSocket service
final gatewayWebSocketServiceProvider = Provider<GatewayWebSocketService>((ref) {
  return GatewayWebSocketService(
    baseUrl: 'http://localhost:18789',
    token: null,
  );
});

/// Provider for gateway state
final gatewayProvider =
    StateNotifierProvider<GatewayNotifier, GatewayState>((ref) {
  final apiService = ref.watch(gatewayApiServiceProvider);
  final wsService = ref.watch(gatewayWebSocketServiceProvider);
  
  return GatewayNotifier(
    apiService: apiService,
    webSocketService: wsService,
  );
});

/// Convenience providers for specific gateway data
final gatewayStatusProvider = Provider<GatewayStatus?>((ref) {
  return ref.watch(gatewayProvider).status;
});

final gatewayConnectionProvider = Provider<bool>((ref) {
  return ref.watch(gatewayProvider).isConnected;
});

final gatewaySystemResourcesProvider = Provider<SystemResources?>((ref) {
  return ref.watch(gatewayProvider).status?.resources;
});