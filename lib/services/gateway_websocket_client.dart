/// Gateway WebSocket Client
/// 
/// Real-time bidirectional communication with OpenClaw Gateway.
/// Connects to ws://GATEWAY_IP:18789/ws for live chat and events.
///
/// Message Format (RPC-style):
/// {
///   "type": "chat" | "chat.response" | "status" | "error",
///   "data": { ... },
///   "timestamp": "ISO8601"
/// }
///
/// Chat Flow:
/// 1. Client sends: { "type": "chat", "data": { "content": "hello" } }
/// 2. Server responds: { "type": "chat.response", "data": { "content": "response", "role": "assistant" } }
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

/// Connection states for WebSocket
enum WebSocketState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// A message received from the gateway
class GatewayMessage {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? id;

  GatewayMessage({
    required this.type,
    required this.data,
    required this.timestamp,
    this.id,
  });

  factory GatewayMessage.fromJson(Map<String, dynamic> json) {
    return GatewayMessage(
      type: json['type'] as String? ?? 'unknown',
      data: json['data'] as Map<String, dynamic>? ?? {},
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      id: json['id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    if (id != null) 'id': id,
  };

  bool get isChatResponse => type == 'chat.response' || type == 'chat';
  bool get isError => type == 'error';
  String? get content => data['content'] as String?;
  String? get errorMessage => data['message'] as String? ?? data['error'] as String?;
}

/// Gateway WebSocket Client
class GatewayWebSocketClient {
  static GatewayWebSocketClient? _instance;

  WebSocketChannel? _channel;
  String? _wsUrl;
  String? _token;
  
  StreamSubscription? _subscription;
  final StreamController<GatewayMessage> _messageController =
      StreamController<GatewayMessage>.broadcast();
  final StreamController<WebSocketState> _stateController =
      StreamController<WebSocketState>.broadcast();

  // Connection state
  WebSocketState _state = WebSocketState.disconnected;
  WebSocketState get state => _state;
  
  // Reconnection with exponential backoff
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 8;
  static const Duration _initialReconnectDelay = Duration(seconds: 2);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);
  bool _isReconnecting = false;
  bool _manualDisconnect = false;
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 5);

  // Message queue (for offline queuing)
  final List<Map<String, dynamic>> _messageQueue = [];
  static const int _maxQueueSize = 50;

  factory GatewayWebSocketClient() {
    _instance ??= GatewayWebSocketClient._internal();
    return _instance!;
  }

  GatewayWebSocketClient._internal();

  // ==================== Streams ====================

  /// Stream of incoming messages
  Stream<GatewayMessage> get messageStream => _messageController.stream;
  
  /// Stream of connection state changes
  Stream<WebSocketState> get stateStream => _stateController.stream;
  
  /// Whether currently connected
  bool get isConnected => _state == WebSocketState.connected;

  // ==================== Configuration ====================

  /// Configure the WebSocket client with gateway URL
  void configure({required String baseUrl, String? token}) {
    // Convert HTTP URL to WebSocket URL
    var wsUrl = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    
    // Append /ws path if not present
    if (!wsUrl.endsWith('/ws')) {
      // Remove trailing slash before adding /ws
      wsUrl = wsUrl.replaceAll(RegExp(r'/$'), '');
      wsUrl = '$wsUrl/ws';
    }
    
    _wsUrl = wsUrl;
    _token = token;
    
    debugPrint('🔗 WebSocket configured: $_wsUrl');
  }

  /// Update the token
  void setToken(String? token) {
    _token = token;
    // Reconnect with new token if currently connected
    if (isConnected && token != null) {
      debugPrint('🔑 Token updated, reconnecting...');
      disconnect().then((_) => connect());
    }
  }

  // ==================== Connection ====================

  /// Connect to the gateway WebSocket
  Future<void> connect() async {
    if (_wsUrl == null || _wsUrl!.isEmpty) {
      debugPrint('❌ WebSocket URL not configured');
      throw Exception('WebSocket URL not configured');
    }

    if (_state == WebSocketState.connecting || 
        _state == WebSocketState.connected) {
      debugPrint('⚠️ Already connecting or connected');
      return;
    }

    _updateState(WebSocketState.connecting);
    debugPrint('🔌 Connecting to $_wsUrl...');

    try {
      // Build URL with optional token
      var connectUrl = _wsUrl!;
      if (_token != null && _token!.isNotEmpty) {
        final separator = connectUrl.contains('?') ? '&' : '?';
        connectUrl = '$connectUrl${separator}token=${Uri.encodeComponent(_token!)}';
      }

      // Connect
      _channel = WebSocketChannel.connect(
        Uri.parse(connectUrl),
      );

      // Wait for connection
      await _channel!.ready;

      _manualDisconnect = false;
      _cancelReconnect();
      _isReconnecting = false;
      _updateState(WebSocketState.connected);
      _reconnectAttempts = 0;
      
      // Start listening
      _startListening();

      // Keep the gateway connection warm on mobile networks / idle timeouts
      _startHeartbeat();
      
      // Flush queued messages
      _flushQueue();
      
      debugPrint('✅ WebSocket connected');
    } catch (e) {
      debugPrint('❌ WebSocket connection failed: $e');
      _updateState(WebSocketState.error);
      _handleDisconnection();
      rethrow;
    }
  }

  /// Disconnect from the gateway
  Future<void> disconnect() async {
    debugPrint('🔌 Disconnecting...');
    
    _manualDisconnect = true;
    _stopHeartbeat();
    _cancelReconnect();
    _isReconnecting = false;
    _reconnectAttempts = 0;
    
    await _subscription?.cancel();
    _subscription = null;
    
    await _channel?.sink.close(ws_status.goingAway);
    _channel = null;
    
    _updateState(WebSocketState.disconnected);
    debugPrint('🔌 Disconnected');
  }

  // ==================== Messaging ====================

  /// Send a chat message to the gateway
  void sendChatMessage(String content, {String? sessionId}) {
    final message = {
      'type': 'chat',
      'data': {
        'content': content,
        if (sessionId != null) 'sessionId': sessionId,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _send(message);
  }

  /// Send a raw message
  void _send(Map<String, dynamic> message) {
    if (!isConnected) {
      debugPrint('⚠️ Not connected, queuing message');
      _queueMessage(message);
      return;
    }

    try {
      final json = jsonEncode(message);
      _channel!.sink.add(json);
      debugPrint('📤 Sent: ${message['type']}');
    } catch (e) {
      debugPrint('❌ Failed to send: $e');
      _queueMessage(message);
    }
  }

  // ==================== Internal ====================

  void _startListening() {
    _subscription = _channel!.stream.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDisconnection,
    );
  }

  void _handleMessage(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final message = GatewayMessage.fromJson(json);
      
      debugPrint('📥 Received: ${message.type}');
      
      // Emit to stream
      if (!_messageController.isClosed) {
        _messageController.add(message);
      }
    } catch (e) {
      debugPrint('❌ Failed to parse message: $e');
    }
  }

  void _handleError(dynamic error) {
    debugPrint('❌ WebSocket error: $error');
    _handleDisconnection(markError: true);
  }

  void _handleDisconnection({bool markError = false}) {
    if (_manualDisconnect) {
      debugPrint('🔌 Ignoring disconnect callback after manual disconnect');
      _updateState(WebSocketState.disconnected);
      return;
    }

    if (_state == WebSocketState.disconnected && _reconnectTimer == null) {
      return;
    }

    final shouldReconnect = _state == WebSocketState.connected || _state == WebSocketState.reconnecting;
    _stopHeartbeat();
    _channel = null;

    _updateState(markError ? WebSocketState.error : WebSocketState.disconnected);
    debugPrint('⚠️ Connection lost (reconnect: $shouldReconnect)');

    if (shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_manualDisconnect) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('❌ Max reconnect attempts reached');
      _isReconnecting = false;
      _updateState(WebSocketState.error);
      return;
    }

    if (_isReconnecting || _reconnectTimer != null) {
      debugPrint('⚠️ Reconnect already scheduled');
      return;
    }

    _updateState(WebSocketState.reconnecting);
    _isReconnecting = true;

    final exponent = _reconnectAttempts.clamp(0, 4);
    final baseDelaySeconds = (_initialReconnectDelay.inSeconds * (1 << exponent))
        .clamp(_initialReconnectDelay.inSeconds, _maxReconnectDelay.inSeconds);
    final jitterMs = DateTime.now().millisecondsSinceEpoch % 750;
    final delay = Duration(seconds: baseDelaySeconds, milliseconds: jitterMs);

    debugPrint('🔄 Scheduling reconnect in ${delay.inSeconds}s (attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;
      _reconnectAttempts++;

      try {
        await connect();
      } catch (e) {
        debugPrint('❌ Reconnect failed: $e');
        _isReconnecting = false;
        _scheduleReconnect();
        return;
      }

      _isReconnecting = false;
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (!isConnected || _channel == null) return;
      try {
        _channel!.sink.add(jsonEncode({
          'type': 'ping',
          'data': {'ts': DateTime.now().toIso8601String()},
          'timestamp': DateTime.now().toIso8601String(),
        }));
      } catch (_) {
        // Let normal disconnect handling take over if the socket is bad.
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _queueMessage(Map<String, dynamic> message) {
    if (_messageQueue.length >= _maxQueueSize) {
      _messageQueue.removeAt(0);
    }
    _messageQueue.add(message);
  }

  void _flushQueue() {
    if (_messageQueue.isEmpty) return;
    
    debugPrint('📤 Sending ${_messageQueue.length} queued messages');
    
    final messages = List<Map<String, dynamic>>.from(_messageQueue);
    _messageQueue.clear();
    
    for (final message in messages) {
      _send(message);
    }
  }

  void _updateState(WebSocketState newState) {
    if (_state != newState) {
      _state = newState;
      if (!_stateController.isClosed) {
        _stateController.add(newState);
      }
    }
  }

  /// Dispose of resources
  void dispose() {
    disconnect();
    _messageController.close();
    _stateController.close();
    _instance = null;
  }
}