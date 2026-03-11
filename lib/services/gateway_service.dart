import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/gateway_status.dart';
import '../models/agent_session.dart';
import '../models/autowork_config.dart';
import '../models/chat_message.dart';

/// Service for communicating with OpenClaw Gateway
///
/// IMPLEMENTATION NOTES (from studying reference repos):
/// - Gateway typically runs on localhost (127.0.0.1:18789) when on device
/// - Or on local network (192.168.x.x:18789) when remote
/// - Supports Tailscale IPs (100.x.x.x:18789)
/// - All connections use HTTP (not HTTPS) for local networks
/// - Timeout handling is critical for mobile networks
///
/// OPENCLAW GATEWAY REST API ENDPOINTS:
/// - GET /api/gateway - Gateway status, sessions, nodes
/// - GET /api/status - Alternative status endpoint
/// - GET /health - Health check
/// - POST /api/gateway/action - Send message to agent, broadcast, get history
/// - GET /api/gateway/autowork - Get autowork config
/// - POST /api/gateway/autowork - Update autowork config
/// - PUT /api/gateway/autowork - Trigger autowork
/// - GET /api/logs - Get gateway logs
///
/// CONTROL ENDPOINTS (POST with confirm: true):
/// - POST /api/mobile/control/gateway/restart - Restart gateway
/// - POST /api/mobile/control/gateway/stop - Stop gateway
/// - POST /api/mobile/control/agent/{sessionKey}/kill - Kill agent
/// - POST /api/mobile/control/node/{nodeName}/reconnect - Reconnect node
/// - POST /api/mobile/control/cron/{cronName}/run - Run cron
/// - POST /api/mobile/control/cron/{cronName}/toggle - Toggle cron
/// - POST /api/mobile/control/pause-all - Pause all agents
/// - POST /api/mobile/control/resume-all - Resume all agents
class GatewayService {
  String baseUrl;
  String? token;

  // Timeout configurations
  static const Duration _defaultTimeout = Duration(seconds: 15);
  static const Duration _shortTimeout = Duration(seconds: 5);
  static const Duration _longTimeout = Duration(seconds: 30);

  GatewayService({this.baseUrl = 'http://127.0.0.1:18789', this.token});

  /// Build request headers with optional auth token
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Validate and normalize gateway URL
  ///
  /// Handles common URL issues:
  /// - Adds http:// if missing
  /// - Removes trailing slashes
  /// - Validates IP format
  static String? validateUrl(String url) {
    if (url.isEmpty) return null;

    String normalized = url.trim();

    // Add protocol if missing
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'http://$normalized';
    }

    // Remove trailing slash
    normalized = normalized.replaceAll(RegExp(r'/$'), '');

    // Basic validation
    try {
      final uri = Uri.parse(normalized);
      if (uri.host.isEmpty) return null;
      return normalized;
    } catch (e) {
      return null;
    }
  }

  /// Get gateway status with timeout
  ///
  /// Combines richer agent/session data from /api/gateway or /api/status
  /// with version/uptime/system fields from /health when available.
  Future<GatewayStatus?> getStatus({Duration? timeout}) async {
    GatewayStatus? primaryStatus;
    GatewayStatus? healthStatus;

    // Try /api/gateway first
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/gateway'),
            headers: _headers,
          )
          .timeout(timeout ?? _shortTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        primaryStatus = GatewayStatus.fromJson(json);
      }
    } on TimeoutException {
      print('⏱️ Gateway /api/gateway request timed out');
    } on SocketException catch (e) {
      print('❌ Connection refused: $e');
    } catch (e) {
      print('❌ Error getting status from /api/gateway: $e');
    }

    // Fallback to /api/status if needed
    if (primaryStatus == null) {
      try {
        final response = await http
            .get(
              Uri.parse('$baseUrl/api/status'),
              headers: _headers,
            )
            .timeout(timeout ?? _shortTimeout);

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          primaryStatus = GatewayStatus.fromJson(json);
        }
      } on TimeoutException {
        print('⏱️ Gateway /api/status request timed out');
      } on SocketException catch (e) {
        print('❌ Connection refused: $e');
      } catch (e) {
        print('❌ Error getting status from /api/status: $e');
      }
    }

    // Always try /health too because it often carries version/uptime/system metrics
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/health'),
            headers: _headers,
          )
          .timeout(timeout ?? _shortTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        healthStatus = GatewayStatus.fromHealthJson(json);
      } else {
        print('⚠️ Gateway returned status ${response.statusCode} from /health');
      }
    } on TimeoutException {
      print('⏱️ Gateway /health request timed out');
    } on SocketException catch (e) {
      print('❌ Connection refused: $e');
    } catch (e) {
      print('❌ Error getting status from /health: $e');
    }

    if (primaryStatus != null && healthStatus != null) {
      return GatewayStatus(
        online: primaryStatus.online || healthStatus.online,
        version: primaryStatus.version != 'unknown'
            ? primaryStatus.version
            : healthStatus.version,
        uptime: primaryStatus.uptime > 0
            ? primaryStatus.uptime
            : healthStatus.uptime,
        cpuPercent: primaryStatus.cpuPercent ?? healthStatus.cpuPercent,
        memoryUsed: primaryStatus.memoryUsed ?? healthStatus.memoryUsed,
        memoryTotal: primaryStatus.memoryTotal ?? healthStatus.memoryTotal,
        agents: primaryStatus.agents,
        nodes: primaryStatus.nodes,
        crons: primaryStatus.crons,
        isPaused: primaryStatus.isPaused || healthStatus.isPaused,
        rawData: primaryStatus.rawData ?? healthStatus.rawData,
      );
    }

    return primaryStatus ?? healthStatus;
  }

  /// Check if gateway is reachable
  ///
  /// Quick check for connectivity - tries all endpoints
  Future<bool> isReachable() async {
    final endpoints = ['/api/gateway', '/api/status', '/health'];

    for (final endpoint in endpoints) {
      try {
        final response = await http
            .get(
              Uri.parse('$baseUrl$endpoint'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        // Try next endpoint
      }
    }
    return false;
  }

  /// Check if gateway is reachable with detailed error
  ///
  /// Returns a map with success status and error message if failed
  Future<Map<String, dynamic>> checkConnection() async {
    final endpoints = [
      {'path': '/api/gateway', 'name': 'Gateway API'},
      {'path': '/api/status', 'name': 'Status API'},
      {'path': '/health', 'name': 'Health Check'},
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http
            .get(
              Uri.parse('$baseUrl${endpoint['path']}'),
              headers: _headers,
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          return {
            'success': true,
            'status': response.statusCode,
            'endpoint': endpoint['name'],
          };
        } else {
          return {
            'success': false,
            'error': 'HTTP ${response.statusCode}',
            'status': response.statusCode,
            'endpoint': endpoint['name'],
          };
        }
      } on TimeoutException {
        // Try next endpoint
      } on SocketException catch (e) {
        return {
          'success': false,
          'error': 'Connection refused: ${e.message}',
          'endpoint': endpoint['name'],
        };
      } on FormatException {
        return {'success': false, 'error': 'Invalid URL format'};
      } catch (e) {
        // Try next endpoint
      }
    }

    return {'success': false, 'error': 'All endpoints failed'};
  }

  // ============================================================
  // Agent Monitor Dashboard APIs
  // ============================================================

  /// Get all active agents/sessions from the Agent Monitor dashboard
  Future<List<AgentSession>?> getAgents() async {
    try {
      // Try Agent Monitor API first (runs on port 3001 typically)
      var response = await http
          .get(
            Uri.parse('$baseUrl/api/gateway'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = json['result'] as Map<String, dynamic>?;
        final sessions = (json['sessions'] as List?) ??
            (json['agents'] as List?) ??
            result?['sessions'] as List? ??
            result?['agents'] as List? ??
            [];
        return sessions.map((s) => AgentSession.fromJson(s)).toList();
      }
    } catch (e) {
      // Fallback to mobile status API
      print('Agent Monitor API not available, falling back to mobile status');
    }
    return null;
  }

  /// Get agent statistics (total, active, tokens, etc.)
  Future<Map<String, dynamic>?> getAgentStats() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/gateway'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = json['result'] as Map<String, dynamic>?;
        final sessions = (json['sessions'] as List?) ??
            (json['agents'] as List?) ??
            result?['sessions'] as List? ??
            result?['agents'] as List? ??
            [];

        int totalAgents = sessions.length;
        int activeAgents = sessions.where((s) {
          final session = s as Map<String, dynamic>;
          return session['isActive'] == true || session['status'] == 'active';
        }).length;
        int totalTokens = 0;
        for (var s in sessions) {
          final session = s as Map<String, dynamic>;
          totalTokens +=
              (session['totalTokens'] ?? session['total_tokens'] ?? 0) as int;
        }

        return {
          'totalAgents': totalAgents,
          'activeAgents': activeAgents,
          'totalTokens': totalTokens,
          'timestamp': json['timestamp'],
        };
      }
    } catch (e) {
      print('Error getting agent stats: $e');
    }
    return null;
  }

  // ============================================================
  // Boss Chat APIs
  // ============================================================

  /// Send a message to a specific agent session
  Future<bool> sendAgentMessage(String sessionKey, String message) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/gateway/action'),
            headers: _headers,
            body: jsonEncode({
              'action': 'send',
              'sessionKey': sessionKey,
              'message': message,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return false;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['ok'] == true || json['success'] == true;
    } catch (e) {
      print('Error sending agent message: $e');
      return false;
    }
  }

  /// Broadcast a message to all main agents
  Future<Map<String, dynamic>?> broadcastToAgents(String message) async {
    try {
      // Get all agent sessions first
      final agents = await getAgents();
      if (agents == null || agents.isEmpty)
        return {'ok': false, 'error': 'No agents found'};

      // Filter for main agents (not subagents)
      final mainAgents = agents.where((a) => !a.isSubagent).toList();
      final sessionKeys = mainAgents.map((a) => a.key).toList();

      if (sessionKeys.isEmpty)
        return {'ok': false, 'error': 'No main agents found'};

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/gateway/action'),
            headers: _headers,
            body: jsonEncode({
              'action': 'broadcast',
              'sessionKeys': sessionKeys,
              'message': message,
            }),
          )
          .timeout(const Duration(seconds: 30));

      return jsonDecode(response.body);
    } catch (e) {
      print('Error broadcasting to agents: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Get chat history for a specific agent
  Future<List<ChatMessage>?> getChatHistory(String sessionKey,
      {int limit = 20}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/gateway/action'),
            headers: _headers,
            body: jsonEncode({
              'action': 'history',
              'sessionKey': sessionKey,
              'limit': limit,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = json['result'] as Map<String, dynamic>?;
        final messages = (result != null && result['messages'] is List)
            ? result!['messages'] as List
            : (json['messages'] as List?) ?? (json['history'] as List?) ?? [];

        if (messages.isNotEmpty) {
          return messages.map((m) => ChatMessage.fromJson(m)).toList();
        }
      }
    } catch (e) {
      print('Error getting chat history: $e');
    }
    return [];
  }

  // ============================================================
  // Autowork APIs
  // ============================================================

  /// Get autowork configuration and targets
  Future<AutoworkConfig?> getAutoworkConfig() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/gateway/autowork'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['ok'] == true) {
          return AutoworkConfig.fromJson(json);
        }
      }
    } catch (e) {
      print('Error getting autowork config: $e');
    }
    return null;
  }

  /// Update autowork configuration (global or per-session)
  Future<AutoworkConfig?> updateAutoworkConfig({
    String? sessionKey,
    bool? enabled,
    int? intervalMs,
    String? directive,
    int? maxSendsPerTick,
    String? defaultDirective,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (sessionKey != null) body['sessionKey'] = sessionKey;
      if (enabled != null) body['enabled'] = enabled;
      if (intervalMs != null) body['intervalMs'] = intervalMs;
      if (directive != null) body['directive'] = directive;
      if (maxSendsPerTick != null) body['maxSendsPerTick'] = maxSendsPerTick;
      if (defaultDirective != null) body['defaultDirective'] = defaultDirective;

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/gateway/autowork'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['ok'] == true && json['config'] != null) {
          return AutoworkConfig.fromJson(json['config']);
        }
      }
    } catch (e) {
      print('Error updating autowork config: $e');
    }
    return null;
  }

  /// Manually trigger autowork (run now)
  Future<Map<String, dynamic>?> runAutowork({String? sessionKey}) async {
    try {
      final body = <String, dynamic>{};
      if (sessionKey != null) body['sessionKey'] = sessionKey;

      final response = await http
          .put(
            Uri.parse('$baseUrl/api/gateway/autowork'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error running autowork: $e');
    }
    return null;
  }

  /// Get logs from the gateway
  Future<dynamic> getLogs(
      {int limit = 100, String? level, String? source}) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (level != null) 'level': level,
        if (source != null) 'source': source,
      };

      final uri =
          Uri.parse('$baseUrl/api/logs').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error getting logs: $e');
    }
    return [];
  }

  /// Test connection to the gateway
  Future<bool> testConnection() async {
    return await isReachable();
  }

  /// Update the base URL
  void setBaseUrl(String url) {
    // Validate and normalize
    final normalized = validateUrl(url);
    if (normalized != null) {
      baseUrl = normalized;
      print('🔄 Gateway URL updated to: $baseUrl');
    } else {
      print('⚠️ Invalid URL format: $url');
    }
  }

  /// Update the token
  void setToken(String? newToken) {
    token = newToken;
    print(newToken != null ? '🔐 Token updated' : '🔓 Token cleared');
  }

  // ============================================================
  // Control APIs
  // ============================================================

  // Gateway Controls
  Future<Map<String, dynamic>?> restartGateway(String reason) async {
    return _postControl('/api/mobile/control/gateway/restart', {
      'confirm': true,
      'reason': reason,
    });
  }

  Future<Map<String, dynamic>?> stopGateway(String reason) async {
    return _postControl('/api/mobile/control/gateway/stop', {
      'confirm': true,
      'reason': reason,
    });
  }

  // Agent Controls
  Future<Map<String, dynamic>?> killAgent(String sessionKey) async {
    return _postControl('/api/mobile/control/agent/$sessionKey/kill', {
      'confirm': true,
    });
  }

  // Node Controls
  Future<Map<String, dynamic>?> reconnectNode(String nodeName) async {
    return _postControl('/api/mobile/control/node/$nodeName/reconnect', {});
  }

  // Cron Controls
  Future<Map<String, dynamic>?> runCron(String cronName) async {
    return _postControl('/api/mobile/control/cron/$cronName/run', {});
  }

  Future<Map<String, dynamic>?> toggleCron(
      String cronName, bool enabled) async {
    return _postControl('/api/mobile/control/cron/$cronName/toggle', {
      'enabled': enabled,
    });
  }

  // Emergency Controls
  Future<Map<String, dynamic>?> pauseAll(int holdSeconds) async {
    return _postControl('/api/mobile/control/pause-all', {
      'confirm': true,
      'hold_seconds': holdSeconds,
    });
  }

  Future<Map<String, dynamic>?> resumeAll() async {
    return _postControl('/api/mobile/control/resume-all', {});
  }

  // Helper for control endpoints
  Future<Map<String, dynamic>?> _postControl(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      print('Control error: ${response.statusCode} - ${response.body}');
    } catch (e) {
      print('Error calling $endpoint: $e');
    }
    return null;
  }
}
