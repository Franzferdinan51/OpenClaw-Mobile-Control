/// Agent Control REST API Server
/// 
/// Provides HTTP endpoints for controlling OpenClaw from the mobile app.
/// Runs on port 8765 by default, localhost-only for security.
/// 
/// Features:
/// - Token-based authentication (optional)
/// - CORS support for web access
/// - JSON request/response
/// - Gateway/agent/node status
/// - Chat messaging
/// - Quick actions
/// - Gateway control (restart, kill-agent)
/// - Log retrieval
/// - Settings management

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';

/// REST API Server for Agent Control
class ApiServer {
  final int port;
  final String? authToken;
  final bool localhostOnly;
  
  HttpServer? _server;
  final Router _router;
  final StreamController<Map<String, dynamic>> _eventController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // State storage (in-memory, persisted by app)
  final Map<String, dynamic> _state = {
    'gateway': null,
    'agents': <Map<String, dynamic>>[],
    'nodes': <Map<String, dynamic>>[],
    'logs': <Map<String, dynamic>>[],
    'settings': <String, dynamic>{
      'autoStart': true,
      'notifications': true,
      'theme': 'system',
      'gatewayUrl': 'http://localhost:18789',
    },
  };
  
  final List<String> _connectedClients = [];
  
  /// Event stream for WebSocket broadcasting
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  ApiServer({
    this.port = 8765,
    this.authToken,
    this.localhostOnly = true,
  }) : _router = Router() {
    _setupRoutes();
  }

  void _setupRoutes() {
    // ==================== Status ====================
    _router.get('/status', _handleStatus);
    
    // ==================== Chat ====================
    _router.post('/chat/send', _handleChatSend);
    _router.get('/chat/history', _handleChatHistory);
    
    // ==================== Actions ====================
    _router.get('/action/list', _handleActionList);
    _router.post('/action/execute', _handleActionExecute);
    
    // ==================== Control ====================
    _router.post('/control/restart', _handleControlRestart);
    _router.post('/control/stop', _handleControlStop);
    _router.post('/control/kill-agent', _handleControlKillAgent);
    _router.post('/control/pause-all', _handleControlPauseAll);
    _router.post('/control/resume-all', _handleControlResumeAll);
    
    // ==================== Logs ====================
    _router.get('/logs', _handleLogs);
    _router.post('/logs/clear', _handleLogsClear);
    
    // ==================== Settings ====================
    _router.get('/settings', _handleSettingsGet);
    _router.post('/settings/update', _handleSettingsUpdate);
    
    // ==================== Gateway ====================
    _router.get('/gateway/status', _handleGatewayStatus);
    _router.post('/gateway/connect', _handleGatewayConnect);
    _router.post('/gateway/disconnect', _handleGatewayDisconnect);
    
    // ==================== Agents ====================
    _router.get('/agents', _handleAgentsList);
    _router.get('/agents/<id>', _handleAgentGet);
    
    // ==================== Nodes ====================
    _router.get('/nodes', _handleNodesList);
    
    // ==================== Health ====================
    _router.get('/health', _handleHealth);
  }

  // ==================== Middleware ====================
  
  shelf.Handler _authMiddleware(shelf.Handler handler) {
    return (shelf.Request request) async {
      // Skip auth for health endpoint
      if (request.url.path == 'health') {
        return handler(request);
      }
      
      // Check localhost if restricted
      if (localhostOnly) {
        final clientIp = request.headers['x-forwarded-for'] ?? 
                         request.requestedUri.host;
        if (clientIp != 'localhost' && 
            clientIp != '127.0.0.1' && 
            clientIp != '::1' &&
            !clientIp.toString().startsWith('192.168.') &&
            !clientIp.toString().startsWith('10.')) {
          return _jsonResponse({'error': 'Access denied'}, status: 403);
        }
      }
      
      // Check auth token if configured
      if (authToken != null && authToken!.isNotEmpty) {
        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return _jsonResponse({'error': 'Missing authorization header'}, status: 401);
        }
        final token = authHeader.substring(7);
        if (token != authToken) {
          return _jsonResponse({'error': 'Invalid token'}, status: 401);
        }
      }
      
      return handler(request);
    };
  }

  // ==================== Handlers ====================

  /// GET /status - Get full system status
  Future<shelf.Response> _handleStatus(shelf.Request request) async {
    return _jsonResponse({
      'ok': true,
      'timestamp': DateTime.now().toIso8601String(),
      'gateway': _state['gateway'],
      'agents': _state['agents'],
      'nodes': _state['nodes'],
      'settings': _state['settings'],
      'connectedClients': _connectedClients.length,
    });
  }

  /// POST /chat/send - Send chat message
  Future<shelf.Response> _handleChatSend(shelf.Request request) async {
    try {
      final body = await _parseJsonBody(request);
      final sessionKey = body['session_key'] as String? ?? 'main';
      final message = body['message'] as String?;
      
      if (message == null || message.isEmpty) {
        return _jsonResponse({'error': 'Message required'}, status: 400);
      }
      
      // Emit event for WebSocket subscribers
      _emitEvent('chat.message', {
        'session_key': sessionKey,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Log the action
      _addLog('info', 'Chat message sent to session $sessionKey: ${message.length > 50 ? '${message.substring(0, 50)}...' : message}');
      
      return _jsonResponse({
        'ok': true,
        'message': 'Message sent',
        'session_key': sessionKey,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return _jsonResponse({'error': e.toString()}, status: 400);
    }
  }

  /// GET /chat/history - Get chat history
  Future<shelf.Response> _handleChatHistory(shelf.Request request) async {
    final sessionKey = request.url.queryParameters['session_key'] ?? 'main';
    final limit = int.tryParse(request.url.queryParameters['limit'] ?? '50') ?? 50;
    
    // Return placeholder - actual history would come from storage
    return _jsonResponse({
      'ok': true,
      'session_key': sessionKey,
      'messages': <Map<String, dynamic>>[],
      'limit': limit,
    });
  }

  /// GET /action/list - List available quick actions
  Future<shelf.Response> _handleActionList(shelf.Request request) async {
    return _jsonResponse({
      'ok': true,
      'actions': [
        {'id': 'grow-status', 'name': 'Grow Status', 'description': 'Check grow room status'},
        {'id': 'weather-check', 'name': 'Weather Check', 'description': 'Get current weather'},
        {'id': 'news-brief', 'name': 'News Brief', 'description': 'Get latest news summary'},
        {'id': 'system-health', 'name': 'System Health', 'description': 'Check system health'},
        {'id': 'backup-now', 'name': 'Backup Now', 'description': 'Trigger immediate backup'},
        {'id': 'restart-gateway', 'name': 'Restart Gateway', 'description': 'Restart OpenClaw gateway'},
        {'id': 'kill-all-agents', 'name': 'Kill All Agents', 'description': 'Stop all running agents'},
        {'id': 'pause-all', 'name': 'Pause All', 'description': 'Pause all agents'},
        {'id': 'resume-all', 'name': 'Resume All', 'description': 'Resume all agents'},
      ],
    });
  }

  /// POST /action/execute - Execute a quick action
  Future<shelf.Response> _handleActionExecute(shelf.Request request) async {
    try {
      final body = await _parseJsonBody(request);
      final action = body['action'] as String?;
      final params = body['params'] as Map<String, dynamic>? ?? {};
      
      if (action == null || action.isEmpty) {
        return _jsonResponse({'error': 'Action required'}, status: 400);
      }
      
      // Emit event for action execution
      _emitEvent('action.execute', {
        'action': action,
        'params': params,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      _addLog('info', 'Action executed: $action');
      
      return _jsonResponse({
        'ok': true,
        'action': action,
        'status': 'executed',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return _jsonResponse({'error': e.toString()}, status: 400);
    }
  }

  /// POST /control/restart - Restart gateway
  Future<shelf.Response> _handleControlRestart(shelf.Request request) async {
    try {
      final body = await _parseJsonBody(request);
      final reason = body['reason'] as String? ?? 'API request';
      
      _emitEvent('control.restart', {
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      _addLog('warn', 'Gateway restart requested: $reason');
      
      return _jsonResponse({
        'ok': true,
        'message': 'Restart command sent',
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      return _jsonResponse({'error': e.toString()}, status: 400);
    }
  }

  /// POST /control/stop - Stop gateway
  Future<shelf.Response> _handleControlStop(shelf.Request request) async {
    try {
      final body = await _parseJsonBody(request);
      final reason = body['reason'] as String? ?? 'API request';
      
      _emitEvent('control.stop', {
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      _addLog('warn', 'Gateway stop requested: $reason');
      
      return _jsonResponse({
        'ok': true,
        'message': 'Stop command sent',
        'reason': reason,
      });
    } catch (e) {
      return _jsonResponse({'error': e.toString()}, status: 400);
    }
  }

  /// POST /control/kill-agent - Kill a specific agent
  Future<shelf.Response> _handleControlKillAgent(shelf.Request request) async {
    try {
      final body = await _parseJsonBody(request);
      final sessionKey = body['session_key'] as String?;
      
      if (sessionKey == null || sessionKey.isEmpty) {
        return _jsonResponse({'error': 'session_key required'}, status: 400);
      }
      
      _emitEvent('control.kill-agent', {
        'session_key': sessionKey,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      _addLog('warn', 'Kill agent requested: $sessionKey');
      
      return _jsonResponse({
        'ok': true,
        'message': 'Kill command sent',
        'session_key': sessionKey,
      });
    } catch (e) {
      return _jsonResponse({'error': e.toString()}, status: 400);
    }
  }

  /// POST /control/pause-all - Pause all agents
  Future<shelf.Response> _handleControlPauseAll(shelf.Request request) async {
    try {
      final body = await _parseJsonBody(request);
      final holdSeconds = body['hold_seconds'] as int? ?? 60;
      
      _emitEvent('control.pause-all', {
        'hold_seconds': holdSeconds,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      _addLog('info', 'Pause all agents requested for ${holdSeconds}s');
      
      return _jsonResponse({
        'ok': true,
        'message': 'Pause command sent',
        'hold_seconds': holdSeconds,
      });
    } catch (e) {
      return _jsonResponse({'error': e.toString()}, status: 400);
    }
  }

  /// POST /control/resume-all - Resume all agents
  Future<shelf.Response> _handleControlResumeAll(shelf.Request request) async {
    _emitEvent('control.resume-all', {
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    _addLog('info', 'Resume all agents requested');
    
    return _jsonResponse({
      'ok': true,
      'message': 'Resume command sent',
    });
  }

  /// GET /logs - Get recent logs
  Future<shelf.Response> _handleLogs(shelf.Request request) async {
    final limit = int.tryParse(request.url.queryParameters['limit'] ?? '100') ?? 100;
    final level = request.url.queryParameters['level'];
    
    var logs = _state['logs'] as List<Map<String, dynamic>>;
    
    if (level != null) {
      logs = logs.where((log) => log['level'] == level).toList();
    }
    
    // Return most recent logs
    final result = logs.length > limit ? logs.sublist(logs.length - limit) : logs;
    
    return _jsonResponse({
      'ok': true,
      'logs': result,
      'total': logs.length,
      'limit': limit,
    });
  }

  /// POST /logs/clear - Clear logs
  Future<shelf.Response> _handleLogsClear(shelf.Request request) async {
    _state['logs'] = <Map<String, dynamic>>[];
    _addLog('info', 'Logs cleared');
    
    return _jsonResponse({
      'ok': true,
      'message': 'Logs cleared',
    });
  }

  /// GET /settings - Get current settings
  Future<shelf.Response> _handleSettingsGet(shelf.Request request) async {
    return _jsonResponse({
      'ok': true,
      'settings': _state['settings'],
    });
  }

  /// POST /settings/update - Update settings
  Future<shelf.Response> _handleSettingsUpdate(shelf.Request request) async {
    try {
      final body = await _parseJsonBody(request);
      
      // Merge with existing settings
      final settings = Map<String, dynamic>.from(_state['settings'] as Map);
      settings.addAll(body);
      _state['settings'] = settings;
      
      _emitEvent('settings.updated', {
        'settings': settings,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      _addLog('info', 'Settings updated');
      
      return _jsonResponse({
        'ok': true,
        'message': 'Settings updated',
        'settings': settings,
      });
    } catch (e) {
      return _jsonResponse({'error': e.toString()}, status: 400);
    }
  }

  /// GET /gateway/status - Get gateway status
  Future<shelf.Response> _handleGatewayStatus(shelf.Request request) async {
    return _jsonResponse({
      'ok': true,
      'gateway': _state['gateway'] ?? {
        'isOnline': false,
        'version': 'unknown',
        'uptime': '0',
        'activeConnections': 0,
      },
    });
  }

  /// POST /gateway/connect - Connect to gateway
  Future<shelf.Response> _handleGatewayConnect(shelf.Request request) async {
    try {
      final body = await _parseJsonBody(request);
      final url = body['url'] as String?;
      
      if (url != null) {
        (_state['settings'] as Map)['gatewayUrl'] = url;
      }
      
      _emitEvent('gateway.connect', {
        'url': url,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      _addLog('info', 'Gateway connect requested: ${url ?? 'default'}');
      
      return _jsonResponse({
        'ok': true,
        'message': 'Connect command sent',
        'url': url,
      });
    } catch (e) {
      return _jsonResponse({'error': e.toString()}, status: 400);
    }
  }

  /// POST /gateway/disconnect - Disconnect from gateway
  Future<shelf.Response> _handleGatewayDisconnect(shelf.Request request) async {
    _emitEvent('gateway.disconnect', {
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    _addLog('info', 'Gateway disconnect requested');
    
    return _jsonResponse({
      'ok': true,
      'message': 'Disconnect command sent',
    });
  }

  /// GET /agents - List all agents
  Future<shelf.Response> _handleAgentsList(shelf.Request request) async {
    return _jsonResponse({
      'ok': true,
      'agents': _state['agents'],
      'total': (_state['agents'] as List).length,
    });
  }

  /// GET /agents/<id> - Get specific agent
  Future<shelf.Response> _handleAgentGet(shelf.Request request, String id) async {
    final agents = _state['agents'] as List<Map<String, dynamic>>;
    final agent = agents.firstWhere(
      (a) => a['id'] == id || a['session_key'] == id,
      orElse: () => <String, dynamic>{},
    );
    
    if (agent.isEmpty) {
      return _jsonResponse({'error': 'Agent not found'}, status: 404);
    }
    
    return _jsonResponse({
      'ok': true,
      'agent': agent,
    });
  }

  /// GET /nodes - List all nodes
  Future<shelf.Response> _handleNodesList(shelf.Request request) async {
    return _jsonResponse({
      'ok': true,
      'nodes': _state['nodes'],
      'total': (_state['nodes'] as List).length,
    });
  }

  /// GET /health - Health check
  Future<shelf.Response> _handleHealth(shelf.Request request) async {
    return _jsonResponse({
      'ok': true,
      'status': 'healthy',
      'uptime': _server != null ? DateTime.now().difference(_server!.started).inSeconds : 0,
      'port': port,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ==================== State Management ====================

  /// Update gateway state
  void updateGateway(Map<String, dynamic> gateway) {
    _state['gateway'] = gateway;
    _emitEvent('state.gateway', gateway);
  }

  /// Update agents state
  void updateAgents(List<Map<String, dynamic>> agents) {
    _state['agents'] = agents;
    _emitEvent('state.agents', {'agents': agents});
  }

  /// Update nodes state
  void updateNodes(List<Map<String, dynamic>> nodes) {
    _state['nodes'] = nodes;
    _emitEvent('state.nodes', {'nodes': nodes});
  }

  /// Add a log entry
  void _addLog(String level, String message, [Map<String, dynamic>? data]) {
    final logs = _state['logs'] as List<Map<String, dynamic>>;
    logs.add({
      'level': level,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
    
    // Keep only last 1000 logs
    if (logs.length > 1000) {
      logs.removeRange(0, logs.length - 1000);
    }
    
    _emitEvent('log', {
      'level': level,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Add external log (for app integration)
  void addLog(String level, String message, [Map<String, dynamic>? data]) {
    _addLog(level, message, data);
  }

  /// Emit event to WebSocket subscribers
  void _emitEvent(String type, Map<String, dynamic> data) {
    _eventController.add({
      'type': type,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ==================== Server Management ====================

  /// Start the API server
  Future<void> start() async {
    if (_server != null) {
      throw StateError('Server already running');
    }
    
    final handler = const shelf.Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_authMiddleware)
        .addHandler(_router);
    
    final address = localhostOnly ? InternetAddress.loopbackIPv4 : InternetAddress.anyIPv4;
    
    _server = await shelf.serve(handler, address, port);
    
    _addLog('info', 'API server started on port $port');
    print('🦆 OpenClaw Mobile API server running at http://${localhostOnly ? "localhost" : "0.0.0.0"}:$port');
  }

  /// Stop the API server
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _addLog('info', 'API server stopped');
  }

  /// Check if server is running
  bool get isRunning => _server != null;

  // ==================== Utilities ====================

  Future<Map<String, dynamic>> _parseJsonBody(shelf.Request request) async {
    final body = await request.readAsString();
    if (body.isEmpty) return {};
    return jsonDecode(body) as Map<String, dynamic>;
  }

  shelf.Response _jsonResponse(dynamic data, {int status = 200}) {
    return shelf.Response(
      status,
      body: jsonEncode(data),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }

  shelf.Middleware _corsMiddleware() {
    return (shelf.Handler handler) {
      return (shelf.Request request) async {
        // Handle preflight requests
        if (request.method == 'OPTIONS') {
          return shelf.Response(200, headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
            'Access-Control-Max-Age': '86400',
          });
        }
        
        final response = await handler(request);
        return response;
      };
    };
  }
}