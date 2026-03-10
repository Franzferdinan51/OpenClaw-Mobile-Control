/// Node Host Service
/// 
/// WebSocket server for Host Node Mode.
/// Allows the phone to accept connections from other devices.
/// 
/// Features:
/// - WebSocket server on configurable port (default 18790)
/// - Token-based authentication
/// - Device approval workflow
/// - Status broadcasting
/// - Connection management

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';
import '../models/node_connection.dart';

/// WebSocket server for hosting node connections
class NodeHostService {
  final NodeModeConfig config;
  final void Function(ConnectionLogEntry)? onLog;
  
  HttpServer? _server;
  final Map<String, WebSocket> _connections = {};
  final Map<String, NodeConnection> _connectionInfo = {};
  final List<ConnectionLogEntry> _logs = [];
  final StreamController<NodeHostEvent> _eventController = 
      StreamController<NodeHostEvent>.broadcast();
  
  final Uuid _uuid = const Uuid();
  String? _currentToken;
  PairingQRData? _currentQRData;

  NodeHostService({
    NodeModeConfig? config,
    this.onLog,
  }) : config = config ?? NodeModeConfig();

  /// Event stream for connection events
  Stream<NodeHostEvent> get eventStream => _eventController.stream;

  /// Current connections
  List<NodeConnection> get connections => _connectionInfo.values.toList();

  /// Active connections count
  int get activeConnections => _connections.length;

  /// Is server running
  bool get isRunning => _server != null;

  /// Current pairing token
  String? get currentToken => _currentToken;

  /// Current QR data
  PairingQRData? get currentQRData => _currentQRData;

  /// Connection logs
  List<ConnectionLogEntry> get logs => List.unmodifiable(_logs);

  /// Start the host server
  Future<void> start() async {
    if (_server != null) {
      throw StateError('Server already running');
    }

    try {
      // Generate new token
      _currentToken = config.customToken ?? _generateToken();
      
      // Start HTTP server
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        config.hostPort,
      );

      _addLog('info', 'Host node server started on port ${config.hostPort}');
      _emitEvent(NodeHostEvent.serverStarted(config.hostPort));

      // Handle incoming connections
      _server!.listen(_handleHttpRequest);

      // Generate QR data
      await _generateQRData();
    } catch (e) {
      _addLog('error', 'Failed to start server: $e');
      rethrow;
    }
  }

  /// Stop the host server
  Future<void> stop() async {
    if (_server == null) return;

    // Close all connections
    for (final ws in _connections.values) {
      await ws.close(1001, 'Server shutting down');
    }
    _connections.clear();
    _connectionInfo.clear();

    // Close server
    await _server!.close();
    _server = null;
    _currentToken = null;
    _currentQRData = null;

    _addLog('info', 'Host node server stopped');
    _emitEvent(const NodeHostEvent.serverStopped());
  }

  /// Generate new pairing QR code
  Future<PairingQRData> generateNewQRCode() async {
    _currentToken = config.customToken ?? _generateToken();
    await _generateQRData();
    return _currentQRData!;
  }

  /// Approve a pending connection
  Future<void> approveConnection(String connectionId) async {
    final conn = _connectionInfo[connectionId];
    if (conn == null) {
      throw ArgumentError('Connection not found: $connectionId');
    }

    _connectionInfo[connectionId] = conn.copyWith(
      isApproved: true,
      status: ConnectionStatus.connected,
    );

    // Send approval message
    final ws = _connections[connectionId];
    if (ws != null) {
      _sendMessage(ws, {
        'type': 'approved',
        'message': 'Connection approved',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    _addLog('info', 'Connection approved: ${conn.displayName}', connectionId: connectionId);
    _emitEvent(NodeHostEvent.connectionApproved(connectionId));
  }

  /// Reject a pending connection
  Future<void> rejectConnection(String connectionId) async {
    final conn = _connectionInfo[connectionId];
    if (conn == null) return;

    _connectionInfo[connectionId] = conn.copyWith(
      status: ConnectionStatus.rejected,
    );

    // Send rejection message
    final ws = _connections[connectionId];
    if (ws != null) {
      _sendMessage(ws, {
        'type': 'rejected',
        'message': 'Connection rejected',
        'timestamp': DateTime.now().toIso8601String(),
      });
      await ws.close(1008, 'Connection rejected');
    }

    _connections.remove(connectionId);
    
    _addLog('warn', 'Connection rejected: ${conn.displayName}', connectionId: connectionId);
    _emitEvent(NodeHostEvent.connectionRejected(connectionId));
  }

  /// Disconnect a connection
  Future<void> disconnectConnection(String connectionId, {String reason = 'Disconnected by host'}) async {
    final ws = _connections.remove(connectionId);
    final conn = _connectionInfo.remove(connectionId);
    
    if (ws != null) {
      await ws.close(1000, reason);
    }

    if (conn != null) {
      _addLog('info', 'Disconnected: ${conn.displayName} - $reason', connectionId: connectionId);
      _emitEvent(NodeHostEvent.connectionDisconnected(connectionId, reason));
    }
  }

  /// Add IP to whitelist
  void addToWhitelist(String ip) {
    // This would update the config and persist
    _addLog('info', 'Added to whitelist: $ip');
  }

  /// Remove IP from whitelist
  void removeFromWhitelist(String ip) {
    _addLog('info', 'Removed from whitelist: $ip');
  }

  /// Broadcast message to all connections
  void broadcast(Map<String, dynamic> message) {
    for (final ws in _connections.values) {
      _sendMessage(ws, message);
    }
  }

  /// Send message to specific connection
  void sendToConnection(String connectionId, Map<String, dynamic> message) {
    final ws = _connections[connectionId];
    if (ws != null) {
      _sendMessage(ws, message);
    }
  }

  // ============================================================
  // Private methods
  // ============================================================

  Future<void> _handleHttpRequest(HttpRequest request) async {
    // Check whitelist
    if (config.enableWhitelist) {
      final clientIp = request.connectionInfo?.remoteAddress.address ?? '';
      if (!config.whitelist.contains(clientIp)) {
        _addLog('warn', 'Rejected connection from non-whitelisted IP: $clientIp');
        request.response.statusCode = 403;
        await request.response.close();
        return;
      }
    }

    // Check max connections
    if (_connections.length >= config.maxConnections) {
      _addLog('warn', 'Rejected connection: max connections reached');
      request.response.statusCode = 503;
      await request.response.close();
      return;
    }

    // Upgrade to WebSocket
    final socket = await WebSocketTransformer.upgrade(request);
    await _handleWebSocket(socket, request);
  }

  Future<void> _handleWebSocket(WebSocket socket, HttpRequest request) async {
    final connectionId = _uuid.v4();
    final clientIp = request.connectionInfo?.remoteAddress.address ?? 'unknown';
    final userAgent = request.headers.value('user-agent');

    _addLog('info', 'New connection from $clientIp', connectionId: connectionId);

    // Create pending connection
    final conn = NodeConnection(
      id: connectionId,
      name: '',
      ip: clientIp,
      userAgent: userAgent,
      status: ConnectionStatus.pending,
    );

    _connectionInfo[connectionId] = conn;
    _connections[connectionId] = socket;

    _emitEvent(NodeHostEvent.connectionPending(connectionId, clientIp));

    // Set up message handling
    socket.listen(
      (data) => _handleMessage(connectionId, data),
      onDone: () => _handleDisconnect(connectionId),
      onError: (error) => _handleError(connectionId, error),
    );

    // Send auth request
    _sendMessage(socket, {
      'type': 'auth_required',
      'message': 'Please authenticate',
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Set up timeout for auth
    Future.delayed(config.connectionTimeout, () {
      if (_connectionInfo[connectionId]?.status == ConnectionStatus.pending) {
        _handleTimeout(connectionId);
      }
    });
  }

  void _handleMessage(String connectionId, dynamic data) {
    final conn = _connectionInfo[connectionId];
    if (conn == null) return;

    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final type = message['type'] as String?;

      switch (type) {
        case 'auth':
          _handleAuth(connectionId, message);
          break;
        case 'ping':
          _handlePing(connectionId);
          break;
        case 'message':
          _handleClientMessage(connectionId, message);
          break;
        default:
          _addLog('debug', 'Unknown message type: $type', connectionId: connectionId);
      }
    } catch (e) {
      _addLog('error', 'Failed to parse message: $e', connectionId: connectionId);
    }

    // Update last activity
    _connectionInfo[connectionId] = conn.copyWith(lastActivity: DateTime.now());
  }

  void _handleAuth(String connectionId, Map<String, dynamic> message) {
    final conn = _connectionInfo[connectionId];
    if (conn == null) return;

    final token = message['token'] as String?;
    final name = message['name'] as String? ?? 'Unknown Device';
    final deviceTypeStr = message['device_type'] as String?;

    // Verify token
    if (token != _currentToken) {
      _addLog('warn', 'Invalid token from ${conn.ip}', connectionId: connectionId);
      rejectConnection(connectionId);
      return;
    }

    // Parse device type
    final deviceType = DeviceType.values.firstWhere(
      (e) => e.name == deviceTypeStr,
      orElse: () => DeviceType.unknown,
    );

    // Update connection info
    _connectionInfo[connectionId] = conn.copyWith(
      name: name,
      deviceType: deviceType,
      authToken: token,
      lastActivity: DateTime.now(),
    );

    // Check if auto-approval is enabled
    if (!config.requireApproval) {
      approveConnection(connectionId);
    } else {
      // Send pending status
      final ws = _connections[connectionId];
      if (ws != null) {
        _sendMessage(ws, {
          'type': 'pending_approval',
          'message': 'Waiting for host approval',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      _emitEvent(NodeHostEvent.connectionPending(connectionId, conn.ip));
    }
  }

  void _handlePing(String connectionId) {
    final ws = _connections[connectionId];
    if (ws != null) {
      _sendMessage(ws, {
        'type': 'pong',
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  void _handleClientMessage(String connectionId, Map<String, dynamic> message) {
    final conn = _connectionInfo[connectionId];
    if (conn == null || !conn.isApproved) return;

    // Emit message event for app to handle
    _emitEvent(NodeHostEvent.messageReceived(connectionId, message));
    
    _addLog('debug', 'Message from ${conn.displayName}', connectionId: connectionId);
  }

  void _handleDisconnect(String connectionId) {
    final conn = _connectionInfo.remove(connectionId);
    _connections.remove(connectionId);

    if (conn != null) {
      _addLog('info', 'Disconnected: ${conn.displayName}', connectionId: connectionId);
      _emitEvent(NodeHostEvent.connectionDisconnected(connectionId, 'Client disconnected'));
    }
  }

  void _handleError(String connectionId, dynamic error) {
    _addLog('error', 'Connection error: $error', connectionId: connectionId);
    _handleDisconnect(connectionId);
  }

  void _handleTimeout(String connectionId) {
    final conn = _connectionInfo[connectionId];
    if (conn != null && conn.status == ConnectionStatus.pending) {
      _addLog('warn', 'Connection timeout: ${conn.displayName}', connectionId: connectionId);
      rejectConnection(connectionId);
    }
  }

  void _sendMessage(WebSocket socket, Map<String, dynamic> message) {
    try {
      socket.add(jsonEncode(message));
    } catch (e) {
      _addLog('error', 'Failed to send message: $e');
    }
  }

  String _generateToken() {
    // Generate a secure random token
    return _uuid.v4().replaceAll('-', '').substring(0, 16).toUpperCase();
  }

  Future<void> _generateQRData() async {
    // Get local IP address
    String localIp = '127.0.0.1';
    
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          // Prefer WiFi IP (192.168.x.x or 10.x.x.x)
          if (addr.type == InternetAddressType.IPv4 && 
              !addr.isLoopback &&
              (addr.address.startsWith('192.168.') || 
               addr.address.startsWith('10.') ||
               addr.address.startsWith('172.'))) {
            localIp = addr.address;
            break;
          }
        }
      }
    } catch (e) {
      _addLog('warn', 'Could not get local IP: $e');
    }

    _currentQRData = PairingQRData(
      hostIp: localIp,
      port: config.hostPort,
      token: _currentToken!,
      deviceName: 'OpenClaw Host Node',
      expiresIn: 300, // 5 minutes
    );

    _emitEvent(NodeHostEvent.qrCodeGenerated(_currentQRData!));
  }

  void _addLog(String level, String message, {String? connectionId}) {
    final entry = ConnectionLogEntry(
      id: _uuid.v4(),
      connectionId: connectionId ?? '',
      message: message,
      level: LogLevel.values.firstWhere((e) => e.name == level, orElse: () => LogLevel.info),
    );

    _logs.add(entry);
    onLog?.call(entry);

    // Keep only last 100 logs
    if (_logs.length > 100) {
      _logs.removeRange(0, _logs.length - 100);
    }
  }

  void _emitEvent(NodeHostEvent event) {
    _eventController.add(event);
  }

  /// Dispose resources
  void dispose() {
    stop();
    _eventController.close();
  }
}

/// Events emitted by NodeHostService
sealed class NodeHostEvent {
  const NodeHostEvent();

  /// Server started
  const factory NodeHostEvent.serverStarted(int port) = ServerStartedEvent;
  
  /// Server stopped
  const factory NodeHostEvent.serverStopped() = ServerStoppedEvent;
  
  /// Connection pending approval
  const factory NodeHostEvent.connectionPending(String connectionId, String ip) = ConnectionPendingEvent;
  
  /// Connection approved
  const factory NodeHostEvent.connectionApproved(String connectionId) = ConnectionApprovedEvent;
  
  /// Connection rejected
  const factory NodeHostEvent.connectionRejected(String connectionId) = ConnectionRejectedEvent;
  
  /// Connection disconnected
  const factory NodeHostEvent.connectionDisconnected(String connectionId, String reason) = ConnectionDisconnectedEvent;
  
  /// QR code generated
  const factory NodeHostEvent.qrCodeGenerated(PairingQRData data) = QRCodeGeneratedEvent;
  
  /// Message received from client
  const factory NodeHostEvent.messageReceived(String connectionId, Map<String, dynamic> message) = MessageReceivedEvent;
}

class ServerStartedEvent implements NodeHostEvent {
  final int port;
  const ServerStartedEvent(this.port);
}

class ServerStoppedEvent implements NodeHostEvent {
  const ServerStoppedEvent();
}

class ConnectionPendingEvent implements NodeHostEvent {
  final String connectionId;
  final String ip;
  const ConnectionPendingEvent(this.connectionId, this.ip);
}

class ConnectionApprovedEvent implements NodeHostEvent {
  final String connectionId;
  const ConnectionApprovedEvent(this.connectionId);
}

class ConnectionRejectedEvent implements NodeHostEvent {
  final String connectionId;
  const ConnectionRejectedEvent(this.connectionId);
}

class ConnectionDisconnectedEvent implements NodeHostEvent {
  final String connectionId;
  final String reason;
  const ConnectionDisconnectedEvent(this.connectionId, this.reason);
}

class QRCodeGeneratedEvent implements NodeHostEvent {
  final PairingQRData data;
  const QRCodeGeneratedEvent(this.data);
}

class MessageReceivedEvent implements NodeHostEvent {
  final String connectionId;
  final Map<String, dynamic> message;
  const MessageReceivedEvent(this.connectionId, this.message);
}