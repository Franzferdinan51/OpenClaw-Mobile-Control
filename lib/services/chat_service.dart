/// Chat Service
/// 
/// Manages chat state and communication with OpenClaw Gateway.
/// Uses WebSocket for real-time messaging and REST API for history.
///
/// Features:
/// - Real-time chat with OpenClaw agents
/// - Inline chart widget support for data visualization
/// - Inline weather widget support
/// - Intent detection for automatic chart/weather generation
/// - Bar, line, pie, and gauge chart types
///
/// Usage:
/// 1. Initialize with gateway URL
/// 2. Connect to WebSocket
/// 3. Send messages via sendMessage()
/// 4. Listen to messages via messages stream
/// 5. Chart and weather intents are auto-detected and rendered inline

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'gateway_service.dart';
import 'gateway_websocket_client.dart';
import 'agent_chart_tool.dart';
import '../utils/chart_intent_detector.dart';
import '../models/inline_widget.dart';

/// Chat state for the UI
enum ChatStatus {
  disconnected,
  connecting,
  connected,
  sending,
  error,
}

/// A chat message with UI state
class ChatMessageUI {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final ChatMessageStatus status;
  final String? agentName;
  final String? agentEmoji;
  
  /// Chart widget data for inline display
  final InlineChartData? chartWidget;
  
  /// Weather widget data for inline display
  final WeatherWidgetData? weatherWidget;
  
  /// Whether to show forecast in weather widget
  final bool showWeatherForecast;
  
  /// Whether it's nighttime for weather display
  final bool isNight;
  
  /// Whether this is a chart-only message (no text)
  final bool chartOnly;

  ChatMessageUI({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.status = ChatMessageStatus.sent,
    this.agentName,
    this.agentEmoji,
    this.chartWidget,
    this.weatherWidget,
    this.showWeatherForecast = false,
    this.isNight = false,
    this.chartOnly = false,
  });

  ChatMessageUI copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    ChatMessageStatus? status,
    String? agentName,
    String? agentEmoji,
    InlineChartData? chartWidget,
    WeatherWidgetData? weatherWidget,
    bool? showWeatherForecast,
    bool? isNight,
    bool? chartOnly,
  }) {
    return ChatMessageUI(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      agentName: agentName ?? this.agentName,
      agentEmoji: agentEmoji ?? this.agentEmoji,
      chartWidget: chartWidget ?? this.chartWidget,
      weatherWidget: weatherWidget ?? this.weatherWidget,
      showWeatherForecast: showWeatherForecast ?? this.showWeatherForecast,
      chartOnly: chartOnly ?? this.chartOnly,
      isNight: isNight ?? this.isNight,
    );
  }
  
  /// Check if this message has chart widget data
  bool get hasChartWidget => chartWidget != null;
  
  /// Check if this message has weather widget data
  bool get hasWeatherWidget => weatherWidget != null;
  
  /// Check if this message has any inline widget
  bool get hasInlineWidget => hasChartWidget || hasWeatherWidget;
}

enum ChatMessageStatus {
  sending,
  sent,
  delivered,
  error,
}

/// Chat Service - Singleton
class ChatService {
  static ChatService? _instance;

  final GatewayService _gatewayService;
  final GatewayWebSocketClient _wsClient;
  
  // Tools
  late final AgentChartTool _chartTool;
  late final ChartIntentDetector _chartIntentDetector;
  late final ChartDataProvider _chartDataProvider;
  
  // State
  final List<ChatMessageUI> _messages = [];
  final StreamController<List<ChatMessageUI>> _messagesController =
      StreamController<List<ChatMessageUI>>.broadcast();
  final StreamController<ChatStatus> _statusController =
      StreamController<ChatStatus>.broadcast();
  final StreamController<bool> _typingController =
      StreamController<bool>.broadcast();
  
  ChatStatus _status = ChatStatus.disconnected;
  String? _activeSessionId;
  StreamSubscription? _wsSubscription;
  StreamSubscription? _wsStateSubscription;
  Timer? _historyPollTimer;
  DateTime? _lastAssistantTimestamp;

  factory ChatService({
    required GatewayService gatewayService,
  }) {
    _instance ??= ChatService._internal(gatewayService);
    return _instance!;
  }

  ChatService._internal(this._gatewayService) 
      : _wsClient = GatewayWebSocketClient() {
    _chartTool = AgentChartTool();
    _chartIntentDetector = ChartIntentDetector();
    _chartDataProvider = ChartDataProvider();
  }

  // ==================== Getters ====================

  /// Current chat status
  ChatStatus get status => _status;
  
  /// Stream of chat status changes
  Stream<ChatStatus> get statusStream => _statusController.stream;
  
  /// Current messages
  List<ChatMessageUI> get messages => List.unmodifiable(_messages);
  
  /// Stream of message list changes
  Stream<List<ChatMessageUI>> get messagesStream => _messagesController.stream;
  
  /// Stream of typing indicator
  Stream<bool> get typingStream => _typingController.stream;
  
  /// Whether connected and ready
  bool get isConnected => _status == ChatStatus.connected;
  
  /// Active session ID for agent chat
  String? get activeSessionId => _activeSessionId;
  
  /// Chart tool instance
  AgentChartTool get chartTool => _chartTool;

  // ==================== Connection ====================

  /// Initialize chat service and resolve a stable HTTP chat session.
  Future<void> connect() async {
    if (_status == ChatStatus.connecting || _status == ChatStatus.connected) {
      debugPrint('⚠️ Chat already connecting/connected');
      return;
    }

    _updateStatus(ChatStatus.connecting);

    try {
      _activeSessionId ??= await _resolvePrimarySessionKey();
      if (_activeSessionId == null) {
        throw Exception('No active main agent session found');
      }

      _startHistoryPolling();
      _updateStatus(ChatStatus.connected);
      debugPrint('✅ Chat service ready via HTTP session $_activeSessionId');
    } catch (e) {
      debugPrint('❌ Chat service connection failed: $e');
      _updateStatus(ChatStatus.error);
      rethrow;
    }
  }

  /// Disconnect from gateway
  Future<void> disconnect() async {
    _historyPollTimer?.cancel();
    _historyPollTimer = null;

    await _wsSubscription?.cancel();
    _wsSubscription = null;
    
    await _wsStateSubscription?.cancel();
    _wsStateSubscription = null;
    
    await _wsClient.disconnect();
    
    _updateStatus(ChatStatus.disconnected);
    debugPrint('🔌 Chat service disconnected');
  }

  // ==================== Messaging ====================

  /// Send a chat message
  Future<bool> sendMessage(String content, {String? sessionId}) async {
    if (content.trim().isEmpty) return false;

    if (!isConnected || _activeSessionId == null) {
      debugPrint('⚠️ Chat not ready, attempting to initialize...');
      try {
        await connect();
      } catch (e) {
        debugPrint('❌ Failed to connect: $e');
        _addErrorMessage('Failed to connect to gateway');
        return false;
      }
    }

    final targetSession = sessionId ?? _activeSessionId;
    if (targetSession == null) {
      _addErrorMessage('No active agent session available');
      return false;
    }

    final userMessage = ChatMessageUI(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      content: content.trim(),
      isUser: true,
      timestamp: DateTime.now(),
      status: ChatMessageStatus.sending,
    );

    _addMessage(userMessage);

    try {
      final ok = await _gatewayService.sendAgentMessage(targetSession, content.trim());
      if (!ok) {
        throw Exception('Gateway action send returned false');
      }

      _updateMessageStatus(userMessage.id, ChatMessageStatus.sent);
      _setTyping(true);
      _checkForChartIntent(content.trim());
      unawaited(_fetchLatestAssistantMessages());
      return true;
    } catch (e) {
      debugPrint('❌ Failed to send message: $e');
      _updateMessageStatus(userMessage.id, ChatMessageStatus.error);
      _addErrorMessage('Failed to send message');
      return false;
    }
  }

  Future<String?> _resolvePrimarySessionKey() async {
    if (_activeSessionId != null && _activeSessionId!.isNotEmpty) return _activeSessionId;

    final agents = await _gatewayService.getAgents();
    if (agents == null || agents.isEmpty) return null;

    final preferred = agents.firstWhere(
      (a) => !a.isSubagent && (a.name.toLowerCase() == 'main' || a.key.startsWith('agent:main:')),
      orElse: () => agents.firstWhere((a) => !a.isSubagent, orElse: () => agents.first),
    );
    _activeSessionId = preferred.key;
    debugPrint('🎯 Resolved primary session: $_activeSessionId');
    return _activeSessionId;
  }

  void _startHistoryPolling() {
    _historyPollTimer?.cancel();
    _historyPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_fetchLatestAssistantMessages());
    });
  }

  Future<void> _fetchLatestAssistantMessages() async {
    final sessionKey = _activeSessionId;
    if (sessionKey == null || sessionKey.isEmpty) return;

    final history = await _gatewayService.getChatHistory(sessionKey, limit: 20);
    if (history == null || history.isEmpty) return;

    final assistantMessages = history.where((m) => m.isAssistant && m.content.trim().isNotEmpty).toList()
      ..sort((a, b) => (a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0)));

    for (final msg in assistantMessages) {
      final ts = msg.timestamp ?? DateTime.now();
      final alreadyExists = _messages.any((m) => !m.isUser && m.content == msg.content);
      final isNewer = _lastAssistantTimestamp == null || ts.isAfter(_lastAssistantTimestamp!);
      if (!alreadyExists && isNewer) {
        _addMessage(ChatMessageUI(
          id: msg.id.isNotEmpty ? msg.id : 'assistant_${ts.millisecondsSinceEpoch}',
          content: msg.content,
          isUser: false,
          timestamp: ts,
          status: ChatMessageStatus.delivered,
          agentName: 'DuckBot',
          agentEmoji: '🦆',
        ));
        _lastAssistantTimestamp = ts;
        _setTyping(false);
      }
    }
  }

  /// Set the active session for agent-specific chat
  void setActiveSession(String? sessionId) {
    _activeSessionId = sessionId;
    debugPrint('🎯 Active session: $sessionId');
  }

  /// Clear all messages
  void clearMessages() {
    _messages.clear();
    _messagesController.add(List.unmodifiable(_messages));
    
    // Add welcome message
    _addMessage(ChatMessageUI(
      id: 'welcome',
      content: "👋 Hello! I'm DuckBot. How can I help you today?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  // ==================== Chart Integration ====================

  /// Check for chart intent in user message
  void _checkForChartIntent(String message) {
    final intent = _chartIntentDetector.detect(message);
    
    if (intent.isValid) {
      debugPrint('📊 Chart intent detected: ${intent.dataType}');
      _handleChartIntent(intent);
    }
  }

  /// Handle detected chart intent
  Future<void> _handleChartIntent(ChartIntent intent) async {
    try {
      // Get data for the chart
      final data = await _chartDataProvider.getDataForIntent(intent);
      
      if (data == null || data.isEmpty) {
        debugPrint('⚠️ No data available for chart');
        return;
      }
      
      // Determine chart type
      InlineChartType chartType;
      switch (intent.chartType) {
        case 'bar':
          chartType = InlineChartType.bar;
          break;
        case 'line':
          chartType = InlineChartType.line;
          break;
        case 'pie':
          chartType = InlineChartType.pie;
          break;
        case 'gauge':
          chartType = InlineChartType.gauge;
          break;
        default:
          // Auto-detect best chart type
          chartType = _chartTool.createFromData(
            title: intent.title ?? 'Data Overview',
            data: data,
          ).type;
      }
      
      // Create chart
      final chartData = _chartTool.createFromData(
        title: intent.title ?? 'Data Overview',
        data: data,
        preferredType: chartType,
        unit: _getUnitForDataType(intent.dataType),
      );
      
      // Add chart message
      _addMessage(ChatMessageUI(
        id: 'chart_${DateTime.now().millisecondsSinceEpoch}',
        content: '',
        isUser: false,
        timestamp: DateTime.now(),
        status: ChatMessageStatus.delivered,
        chartWidget: chartData,
        chartOnly: true,
        agentName: 'DuckBot',
        agentEmoji: '🦆',
      ));
      
    } catch (e) {
      debugPrint('❌ Error creating chart: $e');
    }
  }

  /// Get unit for data type
  String? _getUnitForDataType(String? dataType) {
    switch (dataType) {
      case 'tokens':
        return 'tokens';
      case 'messages':
        return 'msgs';
      case 'activity':
        return 'actions';
      case 'cost':
        return '\$';
      default:
        return null;
    }
  }

  /// Create and add a chart message manually
  void addChartMessage(InlineChartData chartData, {String? text}) {
    _addMessage(ChatMessageUI(
      id: 'chart_${DateTime.now().millisecondsSinceEpoch}',
      content: text ?? '',
      isUser: false,
      timestamp: DateTime.now(),
      status: ChatMessageStatus.delivered,
      chartWidget: chartData,
      chartOnly: text == null || text.isEmpty,
      agentName: 'DuckBot',
      agentEmoji: '🦆',
    ));
  }

  /// Create a bar chart message
  void addBarChart({
    required String title,
    required Map<String, double> data,
    String? unit,
    String? subtitle,
  }) {
    final chartData = _chartTool.createBarChart(
      title: title,
      data: data,
      unit: unit,
      subtitle: subtitle,
    );
    addChartMessage(chartData);
  }

  /// Create a line chart message
  void addLineChart({
    required String title,
    required Map<String, double> data,
    String? unit,
    String? subtitle,
  }) {
    final chartData = _chartTool.createLineChart(
      title: title,
      data: data,
      unit: unit,
      subtitle: subtitle,
    );
    addChartMessage(chartData);
  }

  /// Create a pie chart message
  void addPieChart({
    required String title,
    required Map<String, double> data,
    String? unit,
    String? subtitle,
  }) {
    final chartData = _chartTool.createPieChart(
      title: title,
      data: data,
      unit: unit,
      subtitle: subtitle,
    );
    addChartMessage(chartData);
  }

  /// Create a gauge chart message
  void addGaugeChart({
    required String title,
    required double value,
    required double maxValue,
    String? unit,
    String? subtitle,
  }) {
    final chartData = _chartTool.createGaugeChart(
      title: title,
      value: value,
      maxValue: maxValue,
      unit: unit,
      subtitle: subtitle,
    );
    addChartMessage(chartData);
  }

  // ==================== Internal ====================

  void _handleIncomingMessage(GatewayMessage message) {
    debugPrint('📨 Handling message: ${message.type}');
    
    // Stop typing indicator
    _setTyping(false);

    if (message.isChatResponse) {
      // Handle chat response
      final content = message.content;
      if (content != null && content.isNotEmpty) {
        // Check if response contains chart data
        final chartData = _extractChartFromResponse(message.data);
        
        final agentMessage = ChatMessageUI(
          id: message.id ?? 'agent_${DateTime.now().millisecondsSinceEpoch}',
          content: content,
          isUser: false,
          timestamp: message.timestamp,
          status: ChatMessageStatus.delivered,
          agentName: message.data['agentName'] as String?,
          agentEmoji: message.data['agentEmoji'] as String?,
          chartWidget: chartData,
        );
        _addMessage(agentMessage);
      }
    } else if (message.isError) {
      // Handle error
      _addErrorMessage(message.errorMessage ?? 'An error occurred');
    } else {
      // Handle other message types (status, system, etc.)
      final content = message.content;
      if (content != null && content.isNotEmpty) {
        _addMessage(ChatMessageUI(
          id: message.id ?? 'system_${DateTime.now().millisecondsSinceEpoch}',
          content: content,
          isUser: false,
          timestamp: message.timestamp,
          status: ChatMessageStatus.delivered,
        ));
      }
    }
  }

  /// Extract chart data from agent response if present
  InlineChartData? _extractChartFromResponse(Map<String, dynamic> data) {
    if (data.containsKey('chart')) {
      try {
        final chartJson = data['chart'];
        if (chartJson is Map<String, dynamic>) {
          return InlineChartData.fromJson(chartJson);
        }
      } catch (e) {
        debugPrint('Error parsing chart from response: $e');
      }
    }
    return null;
  }

  void _addMessage(ChatMessageUI message) {
    _messages.add(message);
    _messagesController.add(List.unmodifiable(_messages));
  }

  void _updateMessageStatus(String id, ChatMessageStatus status) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(status: status);
      _messagesController.add(List.unmodifiable(_messages));
    }
  }

  void _addErrorMessage(String error) {
    _addMessage(ChatMessageUI(
      id: 'error_${DateTime.now().millisecondsSinceEpoch}',
      content: '❌ $error',
      isUser: false,
      timestamp: DateTime.now(),
      status: ChatMessageStatus.error,
    ));
  }

  void _updateStatus(ChatStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
    }
  }

  void _setTyping(bool isTyping) {
    if (!_typingController.isClosed) {
      _typingController.add(isTyping);
    }
  }

  /// Dispose of resources
  void dispose() {
    disconnect();
    _messagesController.close();
    _statusController.close();
    _typingController.close();
    _instance = null;
  }
}