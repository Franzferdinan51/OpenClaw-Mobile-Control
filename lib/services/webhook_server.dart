import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/event_bus.dart';

/// Webhook configuration model
class WebhookConfig {
  final String id;
  final String name;
  final String url;
  final String? secret;
  final bool enabled;
  final List<String> events;
  final DateTime? lastTriggered;

  WebhookConfig({
    required this.id,
    required this.name,
    required this.url,
    this.secret,
    this.enabled = true,
    this.events = const ['*'],
    this.lastTriggered,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'secret': secret,
    'enabled': enabled,
    'events': events,
    'lastTriggered': lastTriggered?.toIso8601String(),
  };

  factory WebhookConfig.fromJson(Map<String, dynamic> json) => WebhookConfig(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    url: json['url'] ?? '',
    secret: json['secret'],
    enabled: json['enabled'] ?? true,
    events: List<String>.from(json['events'] ?? ['*']),
    lastTriggered: json['lastTriggered'] != null 
      ? DateTime.tryParse(json['lastTriggered']) 
      : null,
  );

  WebhookConfig copyWith({
    String? id,
    String? name,
    String? url,
    String? secret,
    bool? enabled,
    List<String>? events,
    DateTime? lastTriggered,
  }) => WebhookConfig(
    id: id ?? this.id,
    name: name ?? this.name,
    url: url ?? this.url,
    secret: secret ?? this.secret,
    enabled: enabled ?? this.enabled,
    events: events ?? this.events,
    lastTriggered: lastTriggered ?? this.lastTriggered,
  );
}

/// Webhook request models
class WebhookActionRequest {
  final String actionId;
  final Map<String, dynamic>? parameters;

  WebhookActionRequest({required this.actionId, this.parameters});

  factory WebhookActionRequest.fromJson(Map<String, dynamic> json) => WebhookActionRequest(
    actionId: json['actionId'] ?? json['action_id'] ?? '',
    parameters: json['parameters'],
  );
}

class WebhookChatRequest {
  final String message;
  final String? sessionId;
  final Map<String, dynamic>? metadata;

  WebhookChatRequest({required this.message, this.sessionId, this.metadata});

  factory WebhookChatRequest.fromJson(Map<String, dynamic> json) => WebhookChatRequest(
    message: json['message'] ?? '',
    sessionId: json['sessionId'] ?? json['session_id'],
    metadata: json['metadata'],
  );
}

class WebhookControlRequest {
  final String command;
  final Map<String, dynamic>? parameters;

  WebhookControlRequest({required this.command, this.parameters});

  factory WebhookControlRequest.fromJson(Map<String, dynamic> json) => WebhookControlRequest(
    command: json['command'] ?? '',
    parameters: json['parameters'],
  );
}

/// Webhook server - handles incoming webhook requests
class WebhookServer {
  static final WebhookServer _instance = WebhookServer._internal();
  factory WebhookServer() => _instance;
  WebhookServer._internal();

  final EventBus _eventBus = EventBus();
  
  /// Registered outgoing webhooks
  List<WebhookConfig> _webhooks = [];
  
  /// Secret for authenticating incoming webhooks
  String? _incomingSecret;
  
  /// Callback for action triggers
  Function(String actionId, Map<String, dynamic>? params)? onActionTrigger;
  
  /// Callback for chat messages
  Function(String message, String? sessionId)? onChatMessage;
  
  /// Callback for control commands
  Function(String command, Map<String, dynamic>? params)? onControlCommand;

  List<WebhookConfig> get webhooks => _webhooks;
  String? get incomingSecret => _incomingSecret;

  /// Initialize webhook server
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final secret = prefs.getString('webhook_secret');
    if (secret != null) {
      _incomingSecret = secret;
    }
    
    // Load saved webhooks
    final webhooksJson = prefs.getString('webhooks');
    if (webhooksJson != null) {
      try {
        final List<dynamic> list = jsonDecode(webhooksJson);
        _webhooks = list.map((e) => WebhookConfig.fromJson(e)).toList();
      } catch (e) {
        print('Error loading webhooks: $e');
      }
    }
  }

  /// Configure incoming webhook secret
  Future<void> setSecret(String secret) async {
    _incomingSecret = secret;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webhook_secret', secret);
  }

  /// Add outgoing webhook
  Future<void> addWebhook(WebhookConfig webhook) async {
    _webhooks.add(webhook);
    await _saveWebhooks();
  }

  /// Update webhook
  Future<void> updateWebhook(WebhookConfig webhook) async {
    final index = _webhooks.indexWhere((w) => w.id == webhook.id);
    if (index >= 0) {
      _webhooks[index] = webhook;
      await _saveWebhooks();
    }
  }

  /// Remove webhook
  Future<void> removeWebhook(String id) async {
    _webhooks.removeWhere((w) => w.id == id);
    await _saveWebhooks();
  }

  Future<void> _saveWebhooks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webhooks', jsonEncode(_webhooks.map((e) => e.toJson()).toList()));
  }

  /// Verify incoming webhook secret
  bool verifySecret(String? providedSecret) {
    if (_incomingSecret == null) return true; // No secret configured
    return providedSecret == _incomingSecret;
  }

  /// Handle incoming action webhook
  /// POST /webhook/action/{actionId}
  Future<Map<String, dynamic>> handleAction(
    String actionId, 
    Map<String, dynamic>? body,
    String? signature,
  ) async {
    if (!verifySecret(signature)) {
      return {'error': 'Unauthorized', 'code': 401};
    }

    final request = body != null 
      ? WebhookActionRequest.fromJson(body) 
      : WebhookActionRequest(actionId: actionId);

    _eventBus.emitWebhookReceived('/webhook/action/$actionId', {
      'actionId': request.actionId,
      'parameters': request.parameters,
    });

    // Execute action callback if set
    if (onActionTrigger != null) {
      onActionTrigger!(request.actionId, request.parameters);
    }

    _eventBus.emitActionExecuted(request.actionId, request.parameters);

    return {
      'success': true,
      'actionId': request.actionId,
      'executedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Handle incoming chat webhook
  /// POST /webhook/chat/{message}
  Future<Map<String, dynamic>> handleChat(
    String message, 
    Map<String, dynamic>? body,
    String? signature,
  ) async {
    if (!verifySecret(signature)) {
      return {'error': 'Unauthorized', 'code': 401};
    }

    // Can receive message in path or body
    final chatMessage = body != null 
      ? WebhookChatRequest.fromJson(body).message
      : Uri.decodeComponent(message);

    _eventBus.emitWebhookReceived('/webhook/chat', {
      'message': chatMessage,
    });

    // Execute chat callback if set
    if (onChatMessage != null) {
      onChatMessage!(chatMessage, body?['sessionId']);
    }

    return {
      'success': true,
      'message': chatMessage,
      'receivedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Handle incoming control webhook
  /// POST /webhook/control/{command}
  Future<Map<String, dynamic>> handleControl(
    String command, 
    Map<String, dynamic>? body,
    String? signature,
  ) async {
    if (!verifySecret(signature)) {
      return {'error': 'Unauthorized', 'code': 401};
    }

    final controlRequest = body != null 
      ? WebhookControlRequest.fromJson(body)
      : WebhookControlRequest(command: command);

    _eventBus.emitWebhookReceived('/webhook/control/${controlRequest.command}', {
      'command': controlRequest.command,
      'parameters': controlRequest.parameters,
    });

    // Execute control callback if set
    if (onControlCommand != null) {
      onControlCommand!(controlRequest.command, controlRequest.parameters);
    }

    return {
      'success': true,
      'command': controlRequest.command,
      'executedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Trigger outgoing webhook
  Future<bool> triggerWebhook(WebhookConfig webhook, Map<String, dynamic> payload) async {
    if (!webhook.enabled) return false;

    try {
      final response = await http.post(
        Uri.parse(webhook.url),
        headers: {
          'Content-Type': 'application/json',
          if (webhook.secret != null) 'X-Webhook-Secret': webhook.secret!,
        },
        body: jsonEncode({
          'event': 'app_event',
          'timestamp': DateTime.now().toIso8601String(),
          'data': payload,
        }),
      ).timeout(const Duration(seconds: 10));

      // Update last triggered
      final updated = webhook.copyWith(lastTriggered: DateTime.now());
      await updateWebhook(updated);

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print('Webhook trigger failed: $e');
      return false;
    }
  }

  /// Trigger all webhooks for an event
  Future<void> notifyEvent(AppEvent event) async {
    for (final webhook in _webhooks) {
      if (!webhook.enabled) continue;
      
      // Check if webhook subscribes to this event type
      if (webhook.events.contains('*') || 
          webhook.events.contains(event.type.name)) {
        await triggerWebhook(webhook, event.toJson());
      }
    }
  }

  /// Get webhook URL for incoming requests
  /// This would typically be ngrok or similar for mobile
  String? getIncomingWebhookUrl() {
    // In a real app, this would return the public URL
    // For now, return null as mobile can't host servers directly
    return null;
  }

  /// Generate webhook endpoints info
  Map<String, dynamic> getEndpoints() => {
    'baseUrl': 'https://your-ngrok-url.io',
    'endpoints': {
      'action': '/webhook/action/{actionId}',
      'chat': '/webhook/chat/{message}',
      'control': '/webhook/control/{command}',
    },
    'auth': 'X-Webhook-Secret header',
    'example': {
      'action': 'curl -X POST https://url/webhook/action/send_notification '
        '-H "X-Webhook-Secret: your-secret" -d \'{"parameters": {"msg": "Hello"}}\'',
      'chat': 'curl -X POST https://url/webhook/chat/Hello '
        '-H "X-Webhook-Secret: your-secret"',
      'control': 'curl -X POST https://url/webhook/control/restart '
        '-H "X-Webhook-Secret: your-secret"',
    },
  };
}