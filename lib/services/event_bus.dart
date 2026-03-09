import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

/// Event types supported by the app
enum AppEventType {
  gatewayOnline,
  gatewayOffline,
  agentStarted,
  agentStopped,
  actionExecuted,
  messageReceived,
  webhookReceived,
  automationTriggered,
  scheduleTriggered,
  conditionMet,
}

/// Event data class
class AppEvent {
  final AppEventType type;
  final String? data;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  AppEvent({
    required this.type,
    this.data,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata ?? {},
  };
}

/// Event Bus - central event system for the app
class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final _controller = StreamController<AppEvent>.broadcast();
  
  /// Stream of all events
  Stream<AppEvent> get events => _controller.stream;

  /// Subscribe to specific event type
  Stream<AppEvent> on(AppEventType type) => 
    events.where((e) => e.type == type);

  /// Emit an event
  void emit(AppEvent event) {
    _controller.add(event);
  }

  /// Convenience methods for common events
  void emitGatewayOnline(String gatewayUrl) => emit(AppEvent(
    type: AppEventType.gatewayOnline,
    data: gatewayUrl,
  ));

  void emitGatewayOffline(String? reason) => emit(AppEvent(
    type: AppEventType.gatewayOffline,
    data: reason,
  ));

  void emitAgentStarted(String agentId) => emit(AppEvent(
    type: AppEventType.agentStarted,
    data: agentId,
  ));

  void emitAgentStopped(String agentId) => emit(AppEvent(
    type: AppEventType.agentStopped,
    data: agentId,
  ));

  void emitActionExecuted(String actionId, Map<String, dynamic>? result) => emit(AppEvent(
    type: AppEventType.actionExecuted,
    data: actionId,
    metadata: result,
  ));

  void emitWebhookReceived(String endpoint, Map<String, dynamic> payload) => emit(AppEvent(
    type: AppEventType.webhookReceived,
    data: endpoint,
    metadata: payload,
  ));

  void emitAutomationTriggered(String automationId) => emit(AppEvent(
    type: AppEventType.automationTriggered,
    data: automationId,
  ));

  void emitScheduleTriggered(String scheduleId) => emit(AppEvent(
    type: AppEventType.scheduleTriggered,
    data: scheduleId,
  ));

  void emitConditionMet(String conditionId, bool result) => emit(AppEvent(
    type: AppEventType.conditionMet,
    data: conditionId,
    metadata: {'result': result},
  ));

  /// Clean up
  void dispose() {
    _controller.close();
  }
}

/// WebSocket event subscriber - for external event listening
class WebSocketEventSubscriber {
  final String? webhookUrl;
  final String? secret;
  WebSocketChannel? _channel;
  bool _isConnected = false;
  final EventBus _eventBus = EventBus();

  WebSocketEventSubscriber({this.webhookUrl, this.secret});

  bool get isConnected => _isConnected;

  /// Start WebSocket server/connection for events
  /// Note: In mobile, this connects to an external WS server
  Future<bool> connect() async {
    if (webhookUrl == null) return false;
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(webhookUrl!));
      await _channel!.ready;
      _isConnected = true;
      
      _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) {
          _isConnected = false;
          print('WebSocket error: $error');
        },
        onDone: () {
          _isConnected = false;
        },
      );
      
      return true;
    } catch (e) {
      print('WebSocket connection failed: $e');
      return false;
    }
  }

  void _handleMessage(dynamic message) {
    try {
      // Parse and re-emit events
      // This is for forwarding events to external systems
      if (message is String && message.startsWith('{')) {
        // Event received from external system
      }
    } catch (e) {
      print('Error handling WebSocket message: $e');
    }
  }

  /// Forward events to webhook URL
  Future<void> forwardEvent(AppEvent event) async {
    if (webhookUrl == null || !_isConnected) return;
    
    try {
      await http.post(
        Uri.parse(webhookUrl!),
        headers: {
          'Content-Type': 'application/json',
          if (secret != null) 'X-Webhook-Secret': secret!,
        },
        body: event.toJson().toString(),
      );
    } catch (e) {
      print('Error forwarding event: $e');
    }
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _isConnected = false;
  }
}

/// Local WebSocket server for in-app subscriptions
/// This allows other apps on the same device to subscribe
class LocalEventServer {
  static final LocalEventServer _instance = LocalEventServer._internal();
  factory LocalEventServer() => _instance;
  LocalEventServer._internal();

  final EventBus _eventBus = EventBus();
  final List<WebSocketChannel> _clients = [];

  /// Broadcast event to all connected local clients
  void broadcast(AppEvent event) {
    for (final client in _clients) {
      try {
        client.sink.add(event.toJson());
      } catch (e) {
        // Client disconnected, remove it
        _clients.remove(client);
      }
    }
  }

  /// Start listening to events and broadcast
  void start() {
    _eventBus.events.listen(broadcast);
  }

  void addClient(WebSocketChannel client) {
    _clients.add(client);
  }

  void removeClient(WebSocketChannel client) {
    _clients.remove(client);
  }
}