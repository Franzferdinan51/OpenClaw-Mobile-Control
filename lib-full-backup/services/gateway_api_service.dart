import 'package:dio/dio.dart';
import '../models/models.dart';

/// API service for OpenClaw Gateway communication
class GatewayApiService {
  final Dio _dio;
  String _baseUrl;

  GatewayApiService({
    required String baseUrl,
    String? token,
  })  : _baseUrl = baseUrl,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ));

  void updateBaseUrl(String url) {
    _baseUrl = url;
  }

  void updateToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  String get baseUrl => _baseUrl;

  // Gateway Status
  Future<GatewayStatus> getGatewayStatus() async {
    final response = await _dio.get('$_baseUrl/api/status');
    return GatewayStatus.fromJson(response.data);
  }

  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('$_baseUrl/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Agents
  Future<List<Agent>> getAgents() async {
    final response = await _dio.get('$_baseUrl/api/agents');
    final List<dynamic> data = response.data['agents'] ?? response.data;
    return data.map((e) => Agent.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Agent> getAgent(String agentId) async {
    final response = await _dio.get('$_baseUrl/api/agents/$agentId');
    return Agent.fromJson(response.data);
  }

  Future<Agent> createAgent({
    required String name,
    required String model,
    String? provider,
    List<String>? capabilities,
  }) async {
    final response = await _dio.post(
      '$_baseUrl/api/agents',
      data: {
        'name': name,
        'model': model,
        if (provider != null) 'provider': provider,
        if (capabilities != null) 'capabilities': capabilities,
      },
    );
    return Agent.fromJson(response.data);
  }

  Future<void> deleteAgent(String agentId) async {
    await _dio.delete('$_baseUrl/api/agents/$agentId');
  }

  Future<void> setAgentStatus(String agentId, AgentStatus status) async {
    await _dio.patch(
      '$_baseUrl/api/agents/$agentId/status',
      data: {'status': status.name},
    );
  }

  // Nodes
  Future<List<Node>> getNodes() async {
    final response = await _dio.get('$_baseUrl/api/nodes');
    final List<dynamic> data = response.data['nodes'] ?? response.data;
    return data.map((e) => Node.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Node> getNode(String nodeId) async {
    final response = await _dio.get('$_baseUrl/api/nodes/$nodeId');
    return Node.fromJson(response.data);
  }

  Future<void> pairNode({
    required String code,
    String? name,
  }) async {
    await _dio.post(
      '$_baseUrl/api/nodes/pair',
      data: {
        'code': code,
        if (name != null) 'name': name,
      },
    );
  }

  Future<void> unpairNode(String nodeId) async {
    await _dio.delete('$_baseUrl/api/nodes/$nodeId');
  }

  Future<void> sendNodeNotification({
    required String nodeId,
    required String title,
    required String message,
  }) async {
    await _dio.post(
      '$_baseUrl/api/nodes/$nodeId/notify',
      data: {
        'title': title,
        'message': message,
      },
    );
  }

  // Chat
  Future<List<Conversation>> getConversations() async {
    final response = await _dio.get('$_baseUrl/api/conversations');
    final List<dynamic> data = response.data['conversations'] ?? response.data;
    return data
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Conversation> createConversation({
    String? title,
    String? agentId,
  }) async {
    final response = await _dio.post(
      '$_baseUrl/api/conversations',
      data: {
        if (title != null) 'title': title,
        if (agentId != null) 'agentId': agentId,
      },
    );
    return Conversation.fromJson(response.data);
  }

  Future<void> deleteConversation(String conversationId) async {
    await _dio.delete('$_baseUrl/api/conversations/$conversationId');
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final response = await _dio.get(
      '$_baseUrl/api/conversations/$conversationId/messages',
    );
    final List<dynamic> data = response.data['messages'] ?? response.data;
    return data
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String content,
    String? agentId,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final response = await _dio.post(
      '$_baseUrl/api/conversations/$conversationId/messages',
      data: {
        'content': content,
        if (agentId != null) 'agentId': agentId,
        if (attachments != null) 'attachments': attachments,
      },
    );
    return ChatMessage.fromJson(response.data);
  }

  // Quick Actions
  Future<List<QuickAction>> getQuickActions() async {
    final response = await _dio.get('$_baseUrl/api/quick-actions');
    final List<dynamic> data = response.data['actions'] ?? response.data;
    return data
        .map((e) => QuickAction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<QuickActionResult> executeQuickAction(String actionId) async {
    final response = await _dio.post(
      '$_baseUrl/api/quick-actions/$actionId/execute',
    );
    return QuickActionResult.fromJson(response.data);
  }

  Future<QuickAction> createQuickAction({
    required String name,
    required String description,
    required String icon,
    required QuickActionCategory category,
    required String command,
    List<String>? params,
  }) async {
    final response = await _dio.post(
      '$_baseUrl/api/quick-actions',
      data: {
        'name': name,
        'description': description,
        'icon': icon,
        'category': category.name,
        'command': command,
        if (params != null) 'params': params,
      },
    );
    return QuickAction.fromJson(response.data);
  }

  Future<void> deleteQuickAction(String actionId) async {
    await _dio.delete('$_baseUrl/api/quick-actions/$actionId');
  }

  Future<void> toggleFavorite(String actionId, bool isFavorite) async {
    await _dio.patch(
      '$_baseUrl/api/quick-actions/$actionId/favorite',
      data: {'isFavorite': isFavorite},
    );
  }

  // Logs
  Future<List<LogEntry>> getLogs({
    LogFilter? filter,
  }) async {
    final response = await _dio.get(
      '$_baseUrl/api/logs',
      queryParameters: filter?.toJson(),
    );
    final List<dynamic> data = response.data['logs'] ?? response.data;
    return data.map((e) => LogEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> clearLogs() async {
    await _dio.delete('$_baseUrl/api/logs');
  }
}