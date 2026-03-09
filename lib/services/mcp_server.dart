import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'gateway_service.dart';
import 'intent_parser.dart';

/// MCP (Model Context Protocol) Server Mode
/// 
/// Exposes all app functions as MCP tools that can be called by
/// any MCP client (Claude Code, OpenAI agents, etc.)
/// 
/// Tools:
/// - get_status: Get gateway status
/// - send_chat: Send chat message to agent
/// - execute_action: Execute a control action
/// - restart_gateway: Restart the gateway
/// - kill_agent: Kill an agent session
/// - get_logs: Get recent logs
/// - update_settings: Update app settings
/// - parse_intent: Parse natural language command
class McpServer {
  final GatewayService _gatewayService;
  final IntentParser _intentParser;
  final int port;
  
  HttpServer? _server;
  bool _isRunning = false;
  
  // Request handler
  Function(Map<String, dynamic>)? onToolCall;

  McpServer({
    GatewayService? gatewayService,
    IntentParser? intentParser,
    this.port = 8767,
  }) : _gatewayService = gatewayService ?? GatewayService(),
       _intentParser = intentParser ?? IntentParser(gatewayService: gatewayService);

  bool get isRunning => _isRunning;
  int get serverPort => port;

  /// Start the MCP server
  Future<bool> start() async {
    if (_isRunning) {
      print('MCP Server already running on port $port');
      return true;
    }

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      _isRunning = true;
      
      print('MCP Server started on port $port');
      
      _server!.listen(_handleRequest);
      
      return true;
    } catch (e) {
      print('Failed to start MCP Server: $e');
      return false;
    }
  }

  /// Stop the MCP server
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      _isRunning = false;
      print('MCP Server stopped');
    }
  }

  /// Handle incoming MCP request
  Future<void> _handleRequest(HttpRequest request) async {
    if (request.method != 'POST') {
      request.response.statusCode = 405;
      request.response.writeln('Method not allowed');
      await request.response.close();
      return;
    }

    try {
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      
      final response = await _handleToolCall(json);
      
      request.response.headers.contentType = ContentType.json;
      request.response.writeln(jsonEncode(response));
      await request.response.close();
    } catch (e) {
      request.response.statusCode = 500;
      request.response.headers.contentType = ContentType.json;
      request.response.writeln(jsonEncode({
        'error': e.toString(),
      }));
      await request.response.close();
    }
  }

  /// Handle tool call
  Future<Map<String, dynamic>> _handleToolCall(Map<String, dynamic> request) async {
    final tool = request['tool'] as String?;
    final args = request['arguments'] as Map<String, dynamic>? ?? {};

    onToolCall?.call({'tool': tool, 'args': args});

    switch (tool) {
      // Status tools
      case 'get_status':
        return _toolGetStatus(args);
      case 'get_gateway_status':
        return _toolGetGatewayStatus(args);
      case 'get_agents':
        return _toolGetAgents(args);
      case 'get_nodes':
        return _toolGetNodes(args);
      case 'get_agent_stats':
        return _toolGetAgentStats(args);
      
      // Chat tools
      case 'send_chat':
        return _toolSendChat(args);
      case 'broadcast_message':
        return _toolBroadcast(args);
      case 'get_chat_history':
        return _toolGetChatHistory(args);
      
      // Control tools
      case 'restart_gateway':
        return _toolRestartGateway(args);
      case 'stop_gateway':
        return _toolStopGateway(args);
      case 'kill_agent':
        return _toolKillAgent(args);
      case 'pause_all':
        return _toolPauseAll(args);
      case 'resume_all':
        return _toolResumeAll(args);
      
      // Action tools
      case 'execute_action':
        return _toolExecuteAction(args);
      
      // Node tools
      case 'reconnect_node':
        return _toolReconnectNode(args);
      
      // Cron tools
      case 'run_cron':
        return _toolRunCron(args);
      case 'toggle_cron':
        return _toolToggleCron(args);
      
      // Logs tools
      case 'get_logs':
        return _toolGetLogs(args);
      
      // Settings tools
      case 'get_settings':
        return _toolGetSettings(args);
      case 'update_settings':
        return _toolUpdateSettings(args);
      
      // Intent tools
      case 'parse_intent':
        return _toolParseIntent(args);
      
      // Meta tools
      case 'list_tools':
        return _toolListTools(args);
      case 'tool_call':
        return _toolCall(args);
      
      default:
        return {
          'error': 'Unknown tool: $tool',
          'available_tools': _getToolList(),
        };
    }
  }

  // ============================================================
  // Status Tools
  // ============================================================

  Future<Map<String, dynamic>> _toolGetStatus(Map<String, dynamic> args) async {
    final status = await _gatewayService.getStatus();
    final agents = await _gatewayService.getAgents();
    final stats = await _gatewayService.getAgentStats();
    
    return {
      'success': true,
      'status': status?.toJson() ?? {'online': false},
      'agents': agents?.map((a) => a.toJson()).toList() ?? [],
      'agent_stats': stats,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _toolGetGatewayStatus(Map<String, dynamic> args) async {
    final status = await _gatewayService.getStatus();
    
    if (status == null) {
      return {
        'success': false,
        'error': 'Gateway not connected',
        'online': false,
      };
    }

    return {
      'success': true,
      'online': status.online,
      'version': status.version,
      'uptime': status.uptime,
      'cpu_percent': status.cpuPercent,
      'memory_used': status.memoryUsed,
      'memory_total': status.memoryTotal,
      'is_paused': status.isPaused,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _toolGetAgents(Map<String, dynamic> args) async {
    final agents = await _gatewayService.getAgents();
    
    return {
      'success': true,
      'agents': agents?.map((a) => a.toJson()).toList() ?? [],
      'total': agents?.length ?? 0,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _toolGetNodes(Map<String, dynamic> args) async {
    final status = await _gatewayService.getStatus();
    
    return {
      'success': true,
      'nodes': status?.nodes?.map((n) => n.toJson()).toList() ?? [],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _toolGetAgentStats(Map<String, dynamic> args) async {
    final stats = await _gatewayService.getAgentStats();
    
    return {
      'success': true,
      'stats': stats,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // ============================================================
  // Chat Tools
  // ============================================================

  Future<Map<String, dynamic>> _toolSendChat(Map<String, dynamic> args) async {
    final sessionKey = args['session_key'] as String?;
    final message = args['message'] as String?;

    if (sessionKey == null || message == null) {
      return {
        'success': false,
        'error': 'Missing required parameters: session_key, message',
      };
    }

    final result = await _gatewayService.sendAgentMessage(sessionKey, message);
    
    return {
      'success': result,
      'session_key': sessionKey,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _toolBroadcast(Map<String, dynamic> args) async {
    final message = args['message'] as String?;

    if (message == null) {
      return {
        'success': false,
        'error': 'Missing required parameter: message',
      };
    }

    final result = await _gatewayService.broadcastToAgents(message);
    
    return {
      'success': result?['ok'] ?? false,
      'message': message,
      'result': result,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _toolGetChatHistory(Map<String, dynamic> args) async {
    final sessionKey = args['session_key'] as String?;
    final limit = args['limit'] as int? ?? 20;

    if (sessionKey == null) {
      return {
        'success': false,
        'error': 'Missing required parameter: session_key',
      };
    }

    final history = await _gatewayService.getChatHistory(sessionKey, limit: limit);
    
    return {
      'success': true,
      'session_key': sessionKey,
      'messages': history?.map((m) => m.toJson()).toList() ?? [],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // ============================================================
  // Control Tools
  // ============================================================

  Future<Map<String, dynamic>> _toolRestartGateway(Map<String, dynamic> args) async {
    final reason = args['reason'] as String? ?? 'MCP tool request';
    
    final result = await _gatewayService.restartGateway(reason);
    
    return {
      'success': result?['ok'] ?? false,
      'result': result,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _toolStopGateway(Map<String, dynamic> args) async {
    final reason = args['reason'] as String? ?? 'MCP tool request';
    
    final result = await _gatewayService.stopGateway(reason);
    
    return {
      'success': result?['ok'] ?? false,
      'result': result,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _toolKillAgent(Map<String, dynamic> args) async {
    final sessionKey = args['session_key'] as String?;

    if (sessionKey == null) {
      return {
        'success': false,
        'error': 'Missing required parameter: session_key',
      };
    }

    final result = await _gatewayService.killAgent(sessionKey);
    
    return {
      'success': result?['ok'] ?? false,
      'session_key': sessionKey,
      'result': result,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _toolPauseAll(Map<String, dynamic> args) async {
    final holdSeconds = args['hold_seconds'] as int? ?? 60;
    
    final result = await _gatewayService.pauseAll(holdSeconds);
    
    return {
      'success': result?['ok'] ?? false,
      'hold_seconds': holdSeconds,
      'result': result,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _toolResumeAll(Map<String, dynamic> args) async {
    final result = await _gatewayService.resumeAll();
    
    return {
      'success': result?['ok'] ?? false,
      'result': result,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // ============================================================
  // Action Tools
  // ============================================================

  Future<Map<String, dynamic>> _toolExecuteAction(Map<String, dynamic> args) async {
    final action = args['action'] as String?;
    final params = args['params'] as Map<String, dynamic>? ?? {};

    if (action == null) {
      return {
        'success': false,
        'error': 'Missing required parameter: action',
      };
    }

    dynamic result;
    
    switch (action) {
      case 'restart-gateway':
        result = await _gatewayService.restartGateway(params['reason'] ?? 'MCP request');
        break;
      case 'stop-gateway':
        result = await _gatewayService.stopGateway(params['reason'] ?? 'MCP request');
        break;
      case 'pause-all':
        result = await _gatewayService.pauseAll(params['hold_seconds'] ?? 60);
        break;
      case 'resume-all':
        result = await _gatewayService.resumeAll();
        break;
      case 'kill-agent':
        if (params['session_key'] == null) {
          return {'success': false, 'error': 'Missing session_key parameter'};
        }
        result = await _gatewayService.killAgent(params['session_key']);
        break;
      case 'reconnect-node':
        if (params['node_name'] == null) {
          return {'success': false, 'error': 'Missing node_name parameter'};
        }
        result = await _gatewayService.reconnectNode(params['node_name']);
        break;
      case 'run-cron':
        if (params['cron_name'] == null) {
          return {'success': false, 'error': 'Missing cron_name parameter'};
        }
        result = await _gatewayService.runCron(params['cron_name']);
        break;
      default:
        return {
          'success': false,
          'error': 'Unknown action: $action',
          'available_actions': [
            'restart-gateway', 'stop-gateway', 'pause-all', 'resume-all',
            'kill-agent', 'reconnect-node', 'run-cron',
          ],
        };
    }

    return {
      'success': result?['ok'] ?? true,
      'action': action,
      'result': result,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // ============================================================
  // Node Tools
  // ============================================================

  Future<Map<String, dynamic>> _toolReconnectNode(Map<String, dynamic> args) async {
    final nodeName = args['node_name'] as String?;

    if (nodeName == null) {
      return {
        'success': false,
        'error': 'Missing required parameter: node_name',
      };
    }

    final result = await _gatewayService.reconnectNode(nodeName);
    
    return {
      'success': result?['ok'] ?? false,
      'node_name': nodeName,
      'result': result,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // ============================================================
  // Cron Tools
  // ============================================================

  Future<Map<String, dynamic>> _toolRunCron(Map<String, dynamic> args) async {
    final cronName = args['cron_name'] as String?;

    if (cronName == null) {
      return {
        'success': false,
        'error': 'Missing required parameter: cron_name',
      };
    }

    final result = await _gatewayService.runCron(cronName);
    
    return {
      'success': result?['ok'] ?? false,
      'cron_name': cronName,
      'result': result,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _toolToggleCron(Map<String, dynamic> args) async {
    final cronName = args['cron_name'] as String?;
    final enabled = args['enabled'] as bool? ?? true;

    if (cronName == null) {
      return {
        'success': false,
        'error': 'Missing required parameter: cron_name',
      };
    }

    final result = await _gatewayService.toggleCron(cronName, enabled);
    
    return {
      'success': result?['ok'] ?? false,
      'cron_name': cronName,
      'enabled': enabled,
      'result': result,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // ============================================================
  // Logs Tools
  // ============================================================

  Future<Map<String, dynamic>> _toolGetLogs(Map<String, dynamic> args) async {
    final limit = args['limit'] as int? ?? 100;
    final level = args['level'] as String?;
    final source = args['source'] as String?;

    final logs = await _gatewayService.getLogs(
      limit: limit,
      level: level,
      source: source,
    );

    return {
      'success': true,
      'logs': logs,
      'limit': limit,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // ============================================================
  // Settings Tools
  // ============================================================

  Future<Map<String, dynamic>> _toolGetSettings(Map<String, dynamic> args) async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'success': true,
      'settings': {
        'gateway_url': prefs.getString('gateway_url') ?? 'http://localhost:18789',
        'gateway_token': prefs.getString('gateway_token') ?? '',
        'auto_connect': prefs.getBool('auto_connect') ?? true,
        'theme': prefs.getString('theme') ?? 'dark',
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _toolUpdateSettings(Map<String, dynamic> args) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (args.containsKey('gateway_url')) {
      await prefs.setString('gateway_url', args['gateway_url']);
      _gatewayService.baseUrl = args['gateway_url'];
    }
    if (args.containsKey('gateway_token')) {
      await prefs.setString('gateway_token', args['gateway_token']);
      _gatewayService.token = args['gateway_token'];
    }
    if (args.containsKey('auto_connect')) {
      await prefs.setBool('auto_connect', args['auto_connect']);
    }
    if (args.containsKey('theme')) {
      await prefs.setString('theme', args['theme']);
    }

    return {
      'success': true,
      'message': 'Settings updated',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // ============================================================
  // Intent Tools
  // ============================================================

  Future<Map<String, dynamic>> _toolParseIntent(Map<String, dynamic> args) async {
    final command = args['command'] as String?;

    if (command == null) {
      return {
        'success': false,
        'error': 'Missing required parameter: command',
      };
    }

    final intent = _intentParser.parse(command);
    
    return {
      'success': intent.success,
      'intent': intent.intent,
      'api_endpoint': intent.apiEndpoint,
      'api_method': intent.apiMethod,
      'params': intent.params,
      'error': intent.error,
      'suggestions': intent.suggestions,
    };
  }

  // ============================================================
  // Meta Tools
  // ============================================================

  Future<Map<String, dynamic>> _toolListTools(Map<String, dynamic> args) async {
    return {
      'success': true,
      'tools': _getToolList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _toolCall(Map<String, dynamic> args) async {
    final toolName = args['tool'] as String?;
    final toolArgs = args['arguments'] as Map<String, dynamic>? ?? {};

    if (toolName == null) {
      return {
        'success': false,
        'error': 'Missing required parameter: tool',
      };
    }

    return _handleToolCall({
      'tool': toolName,
      'arguments': toolArgs,
    });
  }

  /// Get list of all available MCP tools
  List<Map<String, dynamic>> _getToolList() {
    return [
      // Status
      {'name': 'get_status', 'description': 'Get complete gateway and agent status'},
      {'name': 'get_gateway_status', 'description': 'Get gateway status only'},
      {'name': 'get_agents', 'description': 'List all active agents'},
      {'name': 'get_nodes', 'description': 'List all connected nodes'},
      {'name': 'get_agent_stats', 'description': 'Get agent statistics'},
      
      // Chat
      {'name': 'send_chat', 'description': 'Send message to specific agent', 'params': ['session_key', 'message']},
      {'name': 'broadcast_message', 'description': 'Broadcast message to all agents', 'params': ['message']},
      {'name': 'get_chat_history', 'description': 'Get chat history for agent', 'params': ['session_key', 'limit']},
      
      // Control
      {'name': 'restart_gateway', 'description': 'Restart the gateway', 'params': ['reason']},
      {'name': 'stop_gateway', 'description': 'Stop the gateway', 'params': ['reason']},
      {'name': 'kill_agent', 'description': 'Kill specific agent', 'params': ['session_key']},
      {'name': 'pause_all', 'description': 'Pause all agents', 'params': ['hold_seconds']},
      {'name': 'resume_all', 'description': 'Resume all paused agents'},
      
      // Actions
      {'name': 'execute_action', 'description': 'Execute various actions', 'params': ['action', 'params']},
      
      // Node
      {'name': 'reconnect_node', 'description': 'Reconnect a node', 'params': ['node_name']},
      
      // Cron
      {'name': 'run_cron', 'description': 'Manually trigger a cron job', 'params': ['cron_name']},
      {'name': 'toggle_cron', 'description': 'Enable/disable a cron job', 'params': ['cron_name', 'enabled']},
      
      // Logs
      {'name': 'get_logs', 'description': 'Get recent logs', 'params': ['limit', 'level', 'source']},
      
      // Settings
      {'name': 'get_settings', 'description': 'Get current settings'},
      {'name': 'update_settings', 'description': 'Update settings', 'params': ['gateway_url', 'gateway_token', 'auto_connect', 'theme']},
      
      // Intent
      {'name': 'parse_intent', 'description': 'Parse natural language command', 'params': ['command']},
      
      // Meta
      {'name': 'list_tools', 'description': 'List all available MCP tools'},
      {'name': 'tool_call', 'description': 'Generic tool call', 'params': ['tool', 'arguments']},
    ];
  }

  /// Get server info
  Map<String, dynamic> getServerInfo() {
    return {
      'running': _isRunning,
      'port': port,
      'tools_count': _getToolList().length,
      'version': '1.5.0',
    };
  }
}