import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/gateway_status.dart';

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
