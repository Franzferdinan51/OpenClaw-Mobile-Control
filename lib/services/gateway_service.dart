import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/gateway_status.dart';
import '../models/agent_session.dart';
import '../models/autowork_config.dart';
import '../models/chat_message.dart';

class GatewayService {
  String baseUrl;
  String? token;

  GatewayService({this.baseUrl = 'http://localhost:18789', this.token});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<GatewayStatus?> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/mobile/status'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return GatewayStatus.fromJson(json);
      }
    } catch (e) {
      print('Error getting status: $e');
    }
    return null;
  }

  // ============================================================
  // Agent Monitor Dashboard APIs
  // ============================================================

  /// Get all active agents/sessions from the Agent Monitor dashboard
  Future<List<AgentSession>?> getAgents() async {
    try {
      // Try Agent Monitor API first (runs on port 3001 typically)
      var response = await http.get(
        Uri.parse('$baseUrl/api/gateway'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final sessions = json['sessions'] as List? ?? [];
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
      final response = await http.get(
        Uri.parse('$baseUrl/api/gateway'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final sessions = json['sessions'] as List? ?? [];
        
        int totalAgents = sessions.length;
        int activeAgents = sessions.where((s) => s['isActive'] == true).length;
        int totalTokens = 0;
        for (var s in sessions) {
          totalTokens += (s['totalTokens'] ?? 0) as int;
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
      final response = await http.post(
        Uri.parse('$baseUrl/api/gateway/action'),
        headers: _headers,
        body: jsonEncode({
          'action': 'send',
          'sessionKey': sessionKey,
          'message': message,
        }),
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200 && jsonDecode(response.body)['ok'] == true;
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
      if (agents == null || agents.isEmpty) return {'ok': false, 'error': 'No agents found'};

      // Filter for main agents (not subagents)
      final mainAgents = agents.where((a) => !a.isSubagent).toList();
      final sessionKeys = mainAgents.map((a) => a.key).toList();

      if (sessionKeys.isEmpty) return {'ok': false, 'error': 'No main agents found'};

      final response = await http.post(
        Uri.parse('$baseUrl/api/gateway/action'),
        headers: _headers,
        body: jsonEncode({
          'action': 'broadcast',
          'sessionKeys': sessionKeys,
          'message': message,
        }),
      ).timeout(const Duration(seconds: 30));

      return jsonDecode(response.body);
    } catch (e) {
      print('Error broadcasting to agents: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Get chat history for a specific agent
  Future<List<ChatMessage>?> getChatHistory(String sessionKey, {int limit = 20}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/gateway/action'),
        headers: _headers,
        body: jsonEncode({
          'action': 'history',
          'sessionKey': sessionKey,
          'limit': limit,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = json['result'] as Map<String, dynamic>?;
        if (result != null && result['messages'] != null) {
          return (result['messages'] as List)
              .map((m) => ChatMessage.fromJson(m))
              .toList();
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
      final response = await http.get(
        Uri.parse('$baseUrl/api/gateway/autowork'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

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

      final response = await http.post(
        Uri.parse('$baseUrl/api/gateway/autowork'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

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

      final response = await http.put(
        Uri.parse('$baseUrl/api/gateway/autowork'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error running autowork: $e');
    }
    return null;
  }

  /// Get logs from the gateway
  /// Returns a list of log entries or a map with 'logs' key
  Future<dynamic> getLogs({int limit = 100, String? level, String? source}) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        if (level != null) 'level': level,
        if (source != null) 'source': source,
      };
      
      final uri = Uri.parse('$baseUrl/api/logs').replace(queryParameters: queryParams);
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
    try {
      final status = await getStatus();
      return status != null;
    } catch (e) {
      return false;
    }
  }

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

  Future<Map<String, dynamic>?> toggleCron(String cronName, bool enabled) async {
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
  Future<Map<String, dynamic>?> _postControl(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _headers,
        body: jsonEncode(body),
      );

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