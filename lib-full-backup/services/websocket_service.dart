import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

/// WebSocket Service - Real-time communication with OpenClaw Gateway
/// 
/// Provides bidirectional WebSocket connection with:
/// - Automatic reconnection with exponential backoff
/// - Heartbeat/ping-pong for connection health
/// - Message queuing when disconnected
/// - Stream-based message handling
class WebSocketService {
  static WebSocketService? _instance;

  final void Function(String level, String message, [dynamic data])? onLog;

  WebSocketChannel? _channel;
  String? _wsUrl;
  String? _jwtToken;
  
  StreamSubscription? _subscription;
  final StreamController<WebSocketMessage> _messageController =
      StreamController<WebSocketMessage>.broadcast();
  
  final List<WebSocketMessage> _messageQueue = [];
  static const int _maxQueueSize = 100;

  // Connection state
  WebSocketConnectionState _state = WebSocketConnectionState.disconnected;
  final _stateController = StreamController<WebSocketConnectionState>.broadcast();
  
  // Reconnection
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);
  
  // Heartbeat
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  DateTime? _lastPong;

  factory WebSocketService() {
    _instance ??= WebSocketService._internal();
    return _instance!;
  }

  WebSocketService._internal();

  // ==================== Getters ====================

  /// Current connection state
  WebSocketConnectionState get state => _state;
  
  /// Stream of connection state changes
  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;
  
  /// Stream of incoming messages
  Stream<WebSocketMessage> get messageStream => _messageController.stream;
  
  /// Whether currently connected
  bool get isConnected => _state == WebSocketConnectionState.connected;
  
  /// Number of queued messages waiting to be sent
  int get queuedMessageCount => _messageQueue.length;

  // ==================== Configuration ====================

  /// Configure WebSocket connection
  void configure({
    required String baseUrl,
    String? jwtToken,
  }) {
    // Convert HTTP URL to WebSocket URL
    var wsUrl = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    
    // Append WebSocket path
    if (!wsUrl.contains('/ws')) {
      wsUrl = '$wsUrl/ws';
    }
    
    _wsUrl = wsUrl;
    _jwtToken = jwtToken;
    
    _log('info', 'WebSocket configured: $_wsUrl');
  }

  /// Update JWT token (called by AuthService)
  void setToken(String? token) {
    _jwtToken = token;
    // Reconnect with new token if currently connected
    if (isConnected && token != null) {
      _log('info', 'Token updated, reconnecting...');
      disconnect();
      connect();
    }
  }

  // ==================== Connection Management ====================

  /// Connect to WebSocket server
  Future<void> connect() async {
    if (_wsUrl == null || _wsUrl!.isEmpty) {
      throw WebSocketException('WebSocket URL not configured');
    }

    if (_state == WebSocketConnectionState.connecting ||
        _state == WebSocketConnectionState.connected) {
      _log('warn', 'Already connecting or connected');
      return;
    }

    _updateState(WebSocketConnectionState.connecting);
    _log('info', 'Connecting to $_wsUrl...');

    try {
      // Build URL with token if available
      var connectUrl = _wsUrl!;
      if (_jwtToken != null && _jwtToken!.isNotEmpty) {
        final separator = connectUrl.contains('?') ? '&' : '?';
        connectUrl = '$connectUrl${separator}token=${Uri.encodeComponent(_jwtToken!)}';
      }

      _channel = WebSocketChannel.connect(
        Uri.parse(connectUrl),
      );

      // Wait for connection
      await _channel!.ready;

      _updateState(WebSocketConnectionState.connected);
      _reconnectAttempts = 0;
      
      // Start listening
      _startListening();
      
      // Start heartbeat
      _startHeartbeat();
      
      // Send queued messages
      _flushQueue();
      
      _log('info', 'WebSocket connected successfully');
    } catch (e) {
      _log('error', 'Connection failed', e);
      _handleDisconnection();
      rethrow;
    }
  }

  /// Disconnect from WebSocket server
  Future<void> disconnect() async {
    _log('info', 'Disconnecting...');
    
    _stopHeartbeat();
    _cancelReconnect();
    
    await _subscription?.cancel();
    _subscription = null;
    
    await _channel?.sink.close(ws_status.goingAway);
    _channel = null;
    
    _updateState(WebSocketConnectionState.disconnected);
    _log('info', 'Disconnected');
  }

  // ==================== Message Handling ====================

  /// Send a message through WebSocket
  void send(WebSocketMessage message) {
    if (!isConnected) {
      _log('warn', 'Not connected, queuing message');
      _queueMessage(message);
      return;
    }

    try {
      final json = jsonEncode(message.toJson());
      _channel!.sink.add(json);
      _log('debug', 'Sent: ${message.type}');
    } catch (e) {
      _log('error', 'Failed to send message', e);
      _queueMessage(message);
    }
  }

  /// Send a chat message
  void sendChatMessage(String content, {String? sessionId}) {
    send(WebSocketMessage(
      type: 'chat',
      data: {
        'content': content,
        if (sessionId != null) 'sessionId': sessionId,
      },
    ));
  }

  /// Send a ping (keep-alive)
  void sendPing() {
    send(WebSocketMessage(type: 'ping', data: {'timestamp': DateTime.now().toIso8601String()}));
  }

  // ==================== Private Methods ====================

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
      final message = WebSocketMessage.fromJson(json);
      
      // Handle pong responses
      if (message.type == 'pong') {
        _lastPong = DateTime.now();
        _log('debug', 'Received pong');
        return;
      }
      
      // Emit to stream
      _messageController.add(message);
      _log('debug', 'Received: ${message.type}');
    } catch (e) {
      _log('error', 'Failed to parse message', e);
    }
  }

  void _handleError(dynamic error) {
    _log('error', 'WebSocket error', error);
    _handleDisconnection();
  }

  void _handleDisconnection() {
    if (_state == WebSocketConnectionState.disconnected) return;
    
    _stopHeartbeat();
    _updateState(WebSocketConnectionState.disconnected);
    
    _log('warn', 'Connection lost');
    
    // Attempt reconnection
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _log('error', 'Max reconnect attempts reached');
      return;
    }

    _cancelReconnect();
    _updateState(WebSocketConnectionState.reconnecting);

    final delay = _calculateReconnectDelay();
    _log('info', 'Reconnecting in ${delay.inSeconds}s (attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(delay, () async {
      _reconnectAttempts++;
      try {
        await connect();
      } catch (e) {
        _log('error', 'Reconnect failed', e);
        _scheduleReconnect();
      }
    });
  }

  Duration _calculateReconnectDelay() {
    // Exponential backoff with jitter
    final delay = Duration(
      seconds: _initialReconnectDelay.inSeconds *
          (1 << _reconnectAttempts.clamp(0, 5)),
    );
    
    // Cap at max delay
    if (delay > _maxReconnectDelay) {
      return _maxReconnectDelay;
    }
    
    return delay;
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (isConnected) {
        sendPing();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _queueMessage(WebSocketMessage message) {
    if (_messageQueue.length >= _maxQueueSize) {
      _messageQueue.removeAt(0);
      _log('warn', 'Message queue full, dropped oldest message');
    }
    _messageQueue.add(message);
  }

  void _flushQueue() {
    if (_messageQueue.isEmpty) return;
    
    _log('info', 'Sending ${_messageQueue.length} queued messages');
    
    final messages = List<WebSocketMessage>.from(_messageQueue);
    _messageQueue.clear();
    
    for (final message in messages) {
      send(message);
    }
  }

  void _updateState(WebSocketConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      _log('debug', 'State changed to: $newState');
    }
  }

  void _log(String level, String message, [dynamic data]) {
    if (onLog != null) {
      onLog!(level, message, data);
    } else if (kDebugMode) {
      debugPrint('[WebSocketService][$level] $message ${data ?? ''}');
    }
  }

  // ==================== Cleanup ====================

  /// Dispose of resources
  void dispose() {
    disconnect();
    _messageController.close();
    _stateController.close();
    _instance = null;
  }
}

// ==================== Models ====================

/// WebSocket connection states
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// WebSocket message model
class WebSocketMessage {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String? id;

  WebSocketMessage({
    required this.type,
    required this.data,
    DateTime? timestamp,
    this.id,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] as String? ?? 'unknown',
      data: json['data'] as Map<String, dynamic>? ?? {},
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      id: json['id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      if (id != null) 'id': id,
    };
  }

  /// Check if this is an error message
  bool get isError => type == 'error';

  /// Check if this is a chat message
  bool get isChat => type == 'chat' || type == 'chat.response';

  /// Check if this is a system message
  bool get isSystem => type == 'system';

  /// Get error message if this is an error
  String? get errorMessage => isError ? data['message'] as String? : null;
}

/// WebSocket exception
class WebSocketException implements Exception {
  final String message;

  WebSocketException(this.message);

  @override
  String toString() => 'WebSocketException: $message';
}