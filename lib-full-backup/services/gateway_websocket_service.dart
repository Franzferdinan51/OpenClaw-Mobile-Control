import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/models.dart';

/// WebSocket service for real-time communication with OpenClaw Gateway
class GatewayWebSocketService {
  WebSocketChannel? _channel;
  final String _baseUrl;
  final String? _token;
  
  final StreamController<GatewayEvent> _eventController = 
      StreamController<GatewayEvent>.broadcast();
  final StreamController<ConnectionState> _connectionController = 
      StreamController<ConnectionState>.broadcast();
  
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  GatewayWebSocketService({
    required String baseUrl,
    String? token,
  })  : _baseUrl = baseUrl,
        _token = token;

  Stream<GatewayEvent> get events => _eventController.stream;
  Stream<ConnectionState> get connectionState => _connectionController.stream;
  
  bool get isConnected => _channel != null;
  int get reconnectAttempts => _reconnectAttempts;

  void connect() {
    _updateConnectionState(ConnectionState.connecting);
    
    try {
      final wsUrl = _baseUrl.replaceFirst('http', 'ws');
      final uri = Uri.parse('$wsUrl/ws');
      
      _channel = WebSocketChannel.connect(
        uri,
        protocols: _token != null ? ['bearer.$_token'] : null,
      );

      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _reconnectAttempts = 0;
      _updateConnectionState(ConnectionState.connected);
      _startHeartbeat();
    } catch (e) {
      _handleError(e);
    }
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _updateConnectionState(ConnectionState.disconnected);
  }

  void reconnect() {
    disconnect();
    connect();
  }

  void send(GatewayEvent event) {
    if (_channel == null) {
      throw StateError('WebSocket is not connected');
    }
    _channel!.sink.add(jsonEncode(event.toJson()));
  }

  void sendChatMessage({
    required String conversationId,
    required String content,
    String? agentId,
  }) {
    send(GatewayEvent(
      type: GatewayEventType.chatMessage,
      data: {
        'conversationId': conversationId,
        'content': content,
        if (agentId != null) 'agentId': agentId,
      },
    ));
  }

  void subscribeToAgent(String agentId) {
    send(GatewayEvent(
      type: GatewayEventType.subscribe,
      data: {'type': 'agent', 'id': agentId},
    ));
  }

  void unsubscribeFromAgent(String agentId) {
    send(GatewayEvent(
      type: GatewayEventType.unsubscribe,
      data: {'type': 'agent', 'id': agentId},
    ));
  }

  void subscribeToLogs({List<String>? sources, List<String>? levels}) {
    send(GatewayEvent(
      type: GatewayEventType.subscribe,
      data: {
        'type': 'logs',
        if (sources != null) 'sources': sources,
        if (levels != null) 'levels': levels,
      },
    ));
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final event = GatewayEvent.fromJson(data);
      _eventController.add(event);
    } catch (e) {
      // Ignore malformed messages
    }
  }

  void _handleError(dynamic error) {
    _updateConnectionState(ConnectionState.error);
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    _updateConnectionState(ConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectAttempts++;
      connect();
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      send(GatewayEvent(type: GatewayEventType.ping));
    });
  }

  void _updateConnectionState(ConnectionState state) {
    _connectionController.add(state);
  }

  void dispose() {
    disconnect();
    _eventController.close();
    _connectionController.close();
  }
}

enum ConnectionState {
  connecting,
  connected,
  disconnected,
  error,
}

enum GatewayEventType {
  ping,
  pong,
  subscribe,
  unsubscribe,
  chatMessage,
  agentUpdate,
  nodeUpdate,
  logEntry,
  notification,
  error,
}

class GatewayEvent {
  final GatewayEventType type;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  GatewayEvent({
    required this.type,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory GatewayEvent.fromJson(Map<String, dynamic> json) {
    return GatewayEvent(
      type: GatewayEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => GatewayEventType.error,
      ),
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };

  // Convenience getters for common event types
  ChatMessage? get chatMessage => type == GatewayEventType.chatMessage && data != null
      ? ChatMessage.fromJson(data!)
      : null;

  Agent? get agentUpdate => type == GatewayEventType.agentUpdate && data != null
      ? Agent.fromJson(data!)
      : null;

  Node? get nodeUpdate => type == GatewayEventType.nodeUpdate && data != null
      ? Node.fromJson(data!)
      : null;

  LogEntry? get logEntry => type == GatewayEventType.logEntry && data != null
      ? LogEntry.fromJson(data!)
      : null;
}