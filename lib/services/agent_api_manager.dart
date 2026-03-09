/// Agent Control API Manager
/// 
/// Manages the REST API and WebSocket API servers.
/// Provides a unified interface for starting, stopping, and interacting
/// with both API servers.

import 'dart:async';

import 'api_server.dart';
import 'websocket_api.dart';
import 'intent_parser.dart';

/// Manager for the Agent Control API
class AgentApiManager {
  final int restPort;
  final int wsPort;
  final String? authToken;
  final bool localhostOnly;
  
  late final ApiServer _apiServer;
  late final WebSocketApi _wsApi;
  late final IntentParser _intentParser;
  
  bool _isRunning = false;
  
  /// Check if the API is running
  bool get isRunning => _isRunning;
  
  /// Get the REST API server
  ApiServer get apiServer => _apiServer;
  
  /// Get the WebSocket API
  WebSocketApi get webSocketApi => _wsApi;
  
  /// Get the intent parser
  IntentParser get intentParser => _intentParser;

  AgentApiManager({
    this.restPort = 8765,
    this.wsPort = 8766,
    this.authToken,
    this.localhostOnly = true,
  }) {
    _apiServer = ApiServer(
      port: restPort,
      authToken: authToken,
      localhostOnly: localhostOnly,
    );
    
    _wsApi = WebSocketApi(
      port: wsPort,
      authToken: authToken,
      localhostOnly: localhostOnly,
    );
    
    _intentParser = IntentParser();
    
    // Connect API server events to WebSocket for broadcasting
    _wsApi.connectEventSource(_apiServer.eventStream);
  }

  /// Start both API servers
  Future<void> start() async {
    if (_isRunning) {
      throw StateError('API already running');
    }
    
    await Future.wait([
      _apiServer.start(),
      _wsApi.start(),
    ]);
    
    _isRunning = true;
    
    _apiServer.addLog('info', 'Agent API Manager started');
  }

  /// Stop both API servers
  Future<void> stop() async {
    if (!_isRunning) return;
    
    await Future.wait([
      _apiServer.stop(),
      _wsApi.stop(),
    ]);
    
    _isRunning = false;
  }

  /// Parse a natural language command
  IntentResult parseIntent(String command) {
    return _intentParser.parse(command);
  }

  /// Execute an intent command
  Future<Map<String, dynamic>> executeIntent(String command) async {
    final result = _intentParser.parse(command);
    
    if (result.isError) {
      return {
        'ok': false,
        'error': result.error,
        'suggestion': result.suggestion,
      };
    }
    
    // Log the intent execution
    _apiServer.addLog('info', 'Intent executed: ${result.action}', result.params);
    
    // Broadcast to WebSocket clients
    _wsApi.sendLog('info', 'Intent: ${result.action}', result.params);
    
    return {
      'ok': true,
      'intent': result.action,
      'endpoint': result.endpoint,
      'method': result.method,
      'params': result.params,
      'confidence': result.confidence,
    };
  }

  /// Update gateway status (called by app)
  void updateGatewayStatus(Map<String, dynamic> status) {
    _apiServer.updateGateway(status);
    _wsApi.sendStateUpdate('gateway', status);
  }

  /// Update agents list (called by app)
  void updateAgents(List<Map<String, dynamic>> agents) {
    _apiServer.updateAgents(agents);
    _wsApi.sendStateUpdate('agents', {'agents': agents});
  }

  /// Update nodes list (called by app)
  void updateNodes(List<Map<String, dynamic>> nodes) {
    _apiServer.updateNodes(nodes);
    _wsApi.sendStateUpdate('nodes', {'nodes': nodes});
  }

  /// Add a log entry (called by app)
  void addLog(String level, String message, [Map<String, dynamic>? data]) {
    _apiServer.addLog(level, message, data);
    _wsApi.sendLog(level, message, data);
  }

  /// Get help text for intent parser
  String getIntentHelp() {
    return IntentParser.getHelpText();
  }

  /// Dispose of all resources
  void dispose() {
    stop();
    _wsApi.dispose();
  }
}