/// Agent Control WebSocket API
/// 
/// Provides real-time bidirectional communication for:
/// - Live status updates (gateway, agents, nodes)
/// - Log streaming
/// - Chat message events
/// - Agent state changes
/// 
/// Features:
/// - Automatic reconnection
/// - Heartbeat/ping-pong
/// - Event subscription filtering
/// - Message broadcasting

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

/// WebSocket API Server for real-time communication
class WebSocketApi {
  final int port;
  final String? authToken;
  final bool localhostOnly;
  
  HttpServer? _server;
  final Set<WebSocketChannel> _clients = {};
  final Map<WebSocketChannel, Set<String>> _subscriptions = {};
  
  final StreamController<Map<String, dynamic>> _broadcastController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Event sources (connected from REST API)
  Stream<Map<String, dynamic>>? _eventSource;
  
  // Heartbeat
  Timer? _heartbeatTimer;
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  WebSocketApi({
    this.port = 8766,
    this.authToken,
    this.localhostOnly = true,
  });

  /// Connect to an event source (typically from ApiServer)
  void connectEventSource(Stream<Map<String, dynamic>> eventStream) {
    _eventSource = eventStream;
    _eventSource!.listen((event) {
      _broadcast(event);
    });
  }

  /// Start the WebSocket server
  Future<void> start() async {
    if (_server != null) {
      throw StateError('WebSocket server already running');
    }
    
    final address = localhostOnly ? InternetAddress.loopbackIPv4 : InternetAddress.anyIPv4;
    
    _server = await HttpServer.bind(address, port);
    
    _server!.listen((HttpRequest request) async {
      // Handle WebSocket upgrade
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        await _handleConnection(request);
      } else {
        // Return WebSocket info for non-upgrade requests
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
            'ok': true,
            'message': 'OpenClaw Mobile WebSocket API',
            'protocol': 'ws',
            'port': port,
            'timestamp': DateTime.now().toIso8601String(),
          }))
          ..close();
      }
    });
    
    _startHeartbeat();
    
    print('🦆 OpenClaw Mobile WebSocket API running at ws://${localhostOnly ? "localhost" : "0.0.0.0"}:$port');
  }

  /// Stop the WebSocket server
  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    
    // Close all client connections
    for (final client in _clients.toList()) {
      await client.sink.close(1001, 'Server shutting down');
    }
    _clients.clear();
    _subscriptions.clear();
    
    await _server?.close(force: true);
    _server = null;
  }

  /// Check if server is running
  bool get isRunning => _server != null;

  /// Get number of connected clients
  int get clientCount => _clients.length;

  /// Handle new WebSocket connection
  Future<void> _handleConnection(HttpRequest request) async {
    // Auth check
    if (authToken != null && authToken!.isNotEmpty) {
      final token = request.uri.queryParameters['token'];
      if (token != authToken) {
        request.response
          ..statusCode = 401
          ..write('Unauthorized')
          ..close();
        return;
      }
    }
    
    // Localhost check
    if (localhostOnly) {
      final clientIp = request.connectionInfo?.remoteAddress.address;
      if (clientIp != '127.0.0.1' && 
          clientIp != '::1' &&
          !clientIp!.startsWith('192.168.') &&
          !clientIp.startsWith('10.')) {
        request.response
          ..statusCode = 403
          ..write('Access denied')
          ..close();
        return;
      }
    }
    
    // Upgrade to WebSocket
    final socket = await WebSocketTransformer.upgrade(request);
    final channel = IOWebSocketChannel(socket);
    
    _clients.add(channel);
    _subscriptions[channel] = {'*'}; // Default: subscribe to all
    
    print('[WebSocket] Client connected (${_clients.length} total)');
    
    // Send welcome message
    _sendToClient(channel, {
      'type': 'connected',
      'data': {
        'message': 'Connected to OpenClaw Mobile WebSocket API',
        'clientCount': _clients.length,
      },
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Listen for messages
    channel.stream.listen(
      (data) => _handleMessage(channel, data),
      onError: (error) => _handleError(channel, error),
      onDone: () => _handleDisconnect(channel),
    );
  }

  /// Handle incoming message from client
  void _handleMessage(WebSocketChannel client, dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final type = json['type'] as String?;
      final payload = json['data'] as Map<String, dynamic>? ?? {};
      
      switch (type) {
        case 'ping':
          _sendToClient(client, {
            'type': 'pong',
            'data': {'timestamp': DateTime.now().toIso8601String()},
          });
          break;
          
        case 'subscribe':
          _handleSubscribe(client, payload);
          break;
          
        case 'unsubscribe':
          _handleUnsubscribe(client, payload);
          break;
          
        case 'chat':
          _handleChat(client, payload);
          break;
          
        case 'action':
          _handleAction(client, payload);
          break;
          
        case 'control':
          _handleControl(client, payload);
          break;
          
        case 'get_status':
          _handleGetStatus(client);
          break;
          
        default:
          _sendToClient(client, {
            'type': 'error',
            'data': {'message': 'Unknown message type: $type'},
          });
      }
    } catch (e) {
      _sendToClient(client, {
        'type': 'error',
        'data': {'message': 'Invalid message format: $e'},
      });
    }
  }

  /// Handle subscription request
  void _handleSubscribe(WebSocketChannel client, Map<String, dynamic> payload) {
    final events = payload['events'] as List<dynamic>?;
    if (events == null || events.isEmpty) {
      _subscriptions[client] = {'*'};
    } else {
      _subscriptions[client] = events.map((e) => e.toString()).toSet();
    }
    
    _sendToClient(client, {
      'type': 'subscribed',
      'data': {
        'events': _subscriptions[client]!.toList(),
      },
    });
  }

  /// Handle unsubscription request
  void _handleUnsubscribe(WebSocketChannel client, Map<String, dynamic> payload) {
    final events = payload['events'] as List<dynamic>?;
    if (events != null) {
      _subscriptions[client]?.removeAll(events.map((e) => e.toString()));
    }
    
    _sendToClient(client, {
      'type': 'unsubscribed',
      'data': {
        'events': events?.map((e) => e.toString()).toList() ?? [],
      },
    });
  }

  /// Handle chat message
  void _handleChat(WebSocketChannel client, Map<String, dynamic> payload) {
    final message = payload['message'] as String?;
    final sessionKey = payload['session_key'] as String? ?? 'main';
    
    if (message == null || message.isEmpty) {
      _sendToClient(client, {
        'type': 'error',
        'data': {'message': 'Message required'},
      });
      return;
    }
    
    // Broadcast to all clients (and forward to REST API event source)
    _broadcast({
      'type': 'chat.message',
      'data': {
        'session_key': sessionKey,
        'message': message,
        'from': 'websocket',
      },
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Acknowledge to sender
    _sendToClient(client, {
      'type': 'chat.ack',
      'data': {
        'session_key': sessionKey,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      },
    });
  }

  /// Handle action request
  void _handleAction(WebSocketChannel client, Map<String, dynamic> payload) {
    final action = payload['action'] as String?;
    final params = payload['params'] as Map<String, dynamic>? ?? {};
    
    if (action == null || action.isEmpty) {
      _sendToClient(client, {
        'type': 'error',
        'data': {'message': 'Action required'},
      });
      return;
    }
    
    _broadcast({
      'type': 'action.execute',
      'data': {
        'action': action,
        'params': params,
        'from': 'websocket',
      },
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    _sendToClient(client, {
      'type': 'action.ack',
      'data': {
        'action': action,
        'status': 'executed',
      },
    });
  }

  /// Handle control command
  void _handleControl(WebSocketChannel client, Map<String, dynamic> payload) {
    final command = payload['command'] as String?;
    
    if (command == null || command.isEmpty) {
      _sendToClient(client, {
        'type': 'error',
        'data': {'message': 'Command required'},
      });
      return;
    }
    
    _broadcast({
      'type': 'control.$command',
      'data': {
        'params': payload['params'] ?? {},
        'from': 'websocket',
      },
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    _sendToClient(client, {
      'type': 'control.ack',
      'data': {
        'command': command,
        'status': 'executed',
      },
    });
  }

  /// Handle status request
  void _handleGetStatus(WebSocketChannel client) {
    // This would normally fetch from ApiServer state
    _sendToClient(client, {
      'type': 'status',
      'data': {
        'connectedClients': _clients.length,
        'subscriptions': _subscriptions[client]?.toList() ?? ['*'],
      },
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Handle client error
  void _handleError(WebSocketChannel client, dynamic error) {
    print('[WebSocket] Client error: $error');
    _handleDisconnect(client);
  }

  /// Handle client disconnect
  void _handleDisconnect(WebSocketChannel client) {
    _clients.remove(client);
    _subscriptions.remove(client);
    print('[WebSocket] Client disconnected (${_clients.length} remaining)');
  }

  /// Send message to specific client
  void _sendToClient(WebSocketChannel client, Map<String, dynamic> message) {
    try {
      client.sink.add(jsonEncode(message));
    } catch (e) {
      // Client may have disconnected
      _handleDisconnect(client);
    }
  }

  /// Broadcast message to all subscribed clients
  void _broadcast(Map<String, dynamic> message) {
    final json = jsonEncode(message);
    final type = message['type'] as String?;
    
    for (final client in _clients.toList()) {
      final subs = _subscriptions[client];
      if (subs != null && (subs.contains('*') || subs.contains(type))) {
        try {
          client.sink.add(json);
        } catch (e) {
          _handleDisconnect(client);
        }
      }
    }
    
    // Also emit to broadcast stream
    _broadcastController.add(message);
  }

  /// Send log entry to all subscribed clients
  void sendLog(String level, String message, [Map<String, dynamic>? data]) {
    _broadcast({
      'type': 'log',
      'data': {
        'level': level,
        'message': message,
        'data': data,
      },
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Send state update to all subscribed clients
  void sendStateUpdate(String component, Map<String, dynamic> state) {
    _broadcast({
      'type': 'state.$component',
      'data': state,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _broadcast({
        'type': 'heartbeat',
        'data': {
          'clientCount': _clients.length,
          'timestamp': DateTime.now().toIso8601String(),
        },
      });
    });
  }

  /// Broadcast stream for external listeners
  Stream<Map<String, dynamic>> get broadcastStream => _broadcastController.stream;

  /// Dispose of resources
  void dispose() {
    stop();
    _broadcastController.close();
  }
}

/// WebSocket message types
class WsMessageType {
  static const String ping = 'ping';
  static const String pong = 'pong';
  static const String subscribe = 'subscribe';
  static const String unsubscribe = 'unsubscribe';
  static const String chat = 'chat';
  static const String action = 'action';
  static const String control = 'control';
  static const String status = 'status';
  static const String log = 'log';
  static const String error = 'error';
  static const String heartbeat = 'heartbeat';
}

/// Event types for subscriptions
class WsEventType {
  static const String all = '*';
  static const String logs = 'log';
  static const String chat = 'chat.message';
  static const String state = 'state';
  static const String action = 'action.execute';
  static const String control = 'control';
  static const String gateway = 'state.gateway';
  static const String agents = 'state.agents';
  static const String nodes = 'state.nodes';
}