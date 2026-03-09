import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Generic MCP (Model Context Protocol) client for communicating with MCP servers
/// Supports both HTTP transport and JSON-RPC messaging
class McpClient {
  final String baseUrl;
  final String? authToken;
  final http.Client _httpClient;
  final Uuid _uuid = const Uuid();

  bool _connected = false;
  String? _serverInfo;

  McpClient({
    required this.baseUrl,
    this.authToken,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  bool get isConnected => _connected;
  String? get serverInfo => _serverInfo;

  /// Connect to the MCP server and initialize
  Future<bool> connect() async {
    try {
      // Send initialize request
      final response = await _sendRequest('initialize', {
        'protocolVersion': '2024-11-05',
        'capabilities': {
          'tools': {},
          'resources': {},
          'prompts': {},
        },
        'clientInfo': {
          'name': 'openclaw_mobile',
          'version': '1.0.0',
        },
      });

      _serverInfo = response['serverInfo']?.toString();
      _connected = true;
      return true;
    } catch (e) {
      print('MCP connection failed: $e');
      _connected = false;
      return false;
    }
  }

  /// List available tools from the MCP server
  Future<List<McpTool>> listTools() async {
    if (!_connected) {
      await connect();
    }

    try {
      final response = await _sendRequest('tools/list', {});
      final tools = response['tools'] as List<dynamic>? ?? [];
      return tools.map((t) => McpTool.fromJson(t as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Failed to list tools: $e');
      return [];
    }
  }

  /// Call a specific tool with arguments
  Future<McpToolResult> callTool(String toolName, Map<String, dynamic> arguments) async {
    if (!_connected) {
      await connect();
    }

    try {
      final response = await _sendRequest('tools/call', {
        'name': toolName,
        'arguments': arguments,
      });

      return McpToolResult(
        success: true,
        content: response['content'] ?? response.toString(),
        result: response,
      );
    } catch (e) {
      return McpToolResult(
        success: false,
        content: 'Error: $e',
        error: e.toString(),
      );
    }
  }

  /// Send a JSON-RPC request to the MCP server via HTTP
  Future<Map<String, dynamic>> _sendRequest(String method, Map<String, dynamic> params) async {
    final id = _uuid.v4();
    
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    });

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json, text/event-stream',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    };

    // Handle both direct MCP URL and /mcp endpoint
    String url = baseUrl;
    if (!url.contains('/mcp')) {
      url = url.endsWith('/') ? '${url}mcp' : '$url/mcp';
    }

    final response = await _httpClient
        .post(Uri.parse(url), headers: headers, body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      // Handle both single response and SSE stream
      final body = response.body;
      if (body.contains('event:')) {
        // SSE stream - parse events
        return _parseSseResponse(body);
      }
      
      final data = jsonDecode(body) as Map<String, dynamic>;
      
      if (data.containsKey('error')) {
        throw Exception('MCP error: ${data['error']}');
      }
      
      return data['result'] as Map<String, dynamic>? ?? data;
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Parse SSE (Server-Sent Events) response
  Map<String, dynamic> _parseSseResponse(String body) {
    final lines = body.split('\n');
    String? lastEvent;
    final Map<String, dynamic> result = {};

    for (final line in lines) {
      if (line.startsWith('event:')) {
        lastEvent = line.substring(6).trim();
      } else if (line.startsWith('data:') && lastEvent == 'result') {
        final data = line.substring(5).trim();
        if (data.isNotEmpty && data != '[DONE]') {
          return jsonDecode(data) as Map<String, dynamic>;
        }
      }
    }

    return result;
  }

  /// Test connection to MCP server
  Future<bool> testConnection() async {
    try {
      final url = baseUrl.contains('/mcp') ? baseUrl : '$baseUrl/mcp';
      final response = await _httpClient
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'id': 'test',
              'method': 'tools/list',
              'params': {},
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('MCP connection test failed: $e');
      return false;
    }
  }

  /// Disconnect and cleanup
  void dispose() {
    _httpClient.close();
    _connected = false;
  }
}

/// Represents an MCP tool definition
class McpTool {
  final String name;
  final String? description;
  final Map<String, dynamic>? inputSchema;
  final String? id;

  McpTool({
    required this.name,
    this.description,
    this.inputSchema,
    this.id,
  });

  factory McpTool.fromJson(Map<String, dynamic> json) {
    return McpTool(
      name: json['name'] as String? ?? json['id'] as String? ?? 'unknown',
      description: json['description'] as String?,
      inputSchema: json['inputSchema'] as Map<String, dynamic>? ?? json['inputSchema'] as Map<String, dynamic>?,
      id: json['id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
        'id': id,
      };
}

/// Result from an MCP tool call
class McpToolResult {
  final bool success;
  final dynamic content;
  final Map<String, dynamic>? result;
  final String? error;

  McpToolResult({
    required this.success,
    this.content,
    this.result,
    this.error,
  });

  @override
  String toString() {
    if (!success) return 'Error: $error';
    return content?.toString() ?? 'Success';
  }
}