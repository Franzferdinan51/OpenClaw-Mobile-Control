import 'dart:async';
import 'package:flutter/material.dart';
import '../models/agent_personality.dart';
import '../models/inline_widget.dart';
import '../data/agency_agents.dart';
import '../services/gateway_service.dart';
import '../services/chat_service.dart';
import '../services/chat_export_service.dart';
import '../services/prompt_templates_service.dart';
import '../services/agent_chart_tool.dart';
import '../widgets/export_dialog.dart';
import '../widgets/inline_weather_widget.dart';
import '../widgets/inline_chart_widget.dart';
import '../widgets/inline_card_widget.dart';
import 'agent_library_screen.dart';
import 'agent_selector_screen.dart';
import 'agent_detail_screen.dart';
import 'multi_agent_screen.dart';
import 'prompt_templates_screen.dart';

/// Message model for chat UI
class ChatMsg {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final AgentPersonality? agent;
  final bool isError;
  final bool isSending;
  
  /// Weather widget data for inline display
  final WeatherWidgetData? weatherWidget;
  final bool showWeatherForecast;
  final bool isNight;
  
  /// Chart widget data for inline display (from agent_chart_tool.dart)
  final InlineChartData? chartWidget;
  
  /// Info card widget data for inline display
  final InfoCardWidgetData? infoCardWidget;
  
  /// Status widget data for inline display
  final StatusWidgetData? statusWidget;
  
  /// Generic inline widget data
  final InlineWidgetData? inlineWidget;

  ChatMsg({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.agent,
    this.isError = false,
    this.isSending = false,
    this.weatherWidget,
    this.showWeatherForecast = false,
    this.isNight = false,
    this.chartWidget,
    this.infoCardWidget,
    this.statusWidget,
    this.inlineWidget,
  });
  
  /// Check if this message has a weather widget
  bool get hasWeatherWidget => weatherWidget != null;
  
  /// Check if this message has a chart widget
  bool get hasChartWidget => chartWidget != null;
  
  /// Check if this message has an info card widget
  bool get hasInfoCardWidget => infoCardWidget != null;
  
  /// Check if this message has a status widget
  bool get hasStatusWidget => statusWidget != null;
  
  /// Check if this message has any inline widget
  bool get hasInlineWidget => 
      hasWeatherWidget || 
      hasChartWidget || 
      hasInfoCardWidget || 
      hasStatusWidget ||
      inlineWidget != null;
}

/// Chat Screen with real gateway communication
class ChatScreen extends StatefulWidget {
  final GatewayService? gatewayService;

  const ChatScreen({super.key, this.gatewayService});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMsg> _messages = [];
  
  // Chat service
  ChatService? _chatService;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _typingSubscription;
  
  // UI state
  bool _isConnected = false;
  bool _isTyping = false;
  String _connectionError = '';
  
  // Agent state
  AgentPersonality? _activeAgent;
  List<AgentPersonality> _multiAgentTeam = [];
  bool _isMultiAgentMode = false;

  @override
  void initState() {
    super.initState();
    _initChatService();
    _addWelcomeMessage();
  }
  
  void _initChatService() {
    if (widget.gatewayService != null) {
      _chatService = ChatService(gatewayService: widget.gatewayService!);
      
      // Listen for messages
      _messagesSubscription = _chatService!.messagesStream.listen((messages) {
        _syncMessagesFromService(messages);
      });
      
      // Listen for status changes
      _statusSubscription = _chatService!.statusStream.listen((status) {
        setState(() {
          _isConnected = status == ChatStatus.connected;
          if (status == ChatStatus.error) {
            _connectionError = 'Connection error';
          } else {
            _connectionError = '';
          }
        });
      });
      
      // Listen for typing indicator
      _typingSubscription = _chatService!.typingStream.listen((isTyping) {
        setState(() {
          _isTyping = isTyping;
        });
      });
      
      // Connect to gateway
      _connectToGateway();
    }
  }
  
  Future<void> _connectToGateway() async {
    if (_chatService == null) return;
    
    try {
      await _chatService!.connect();
      debugPrint('✅ Connected to gateway');
    } catch (e) {
      debugPrint('❌ Failed to connect: $e');
      setState(() {
        _connectionError = 'Could not connect to gateway: $e';
      });
    }
  }
  
  void _syncMessagesFromService(List<ChatMessageUI> serviceMessages) {
    // Clear and rebuild messages from service
    _messages.clear();
    
    for (final msg in serviceMessages) {
      _messages.add(ChatMsg(
        id: msg.id,
        content: msg.content,
        isUser: msg.isUser,
        timestamp: msg.timestamp,
        isError: msg.status == ChatMessageStatus.error,
        isSending: msg.status == ChatMessageStatus.sending,
        agent: msg.agentName != null ? _getAgentByName(msg.agentName!) : null,
        weatherWidget: msg.weatherWidget,
        showWeatherForecast: msg.showWeatherForecast,
        isNight: msg.isNight,
        chartWidget: msg.chartWidget,
      ));
    }
    
    setState(() {});
    _scrollToBottom();
  }
  
  AgentPersonality? _getAgentByName(String name) {
    try {
      return AgencyAgentsData.allAgents.firstWhere(
        (a) => a.name == name,
      );
    } catch (e) {
      return null;
    }
  }
  
  void _addWelcomeMessage() {
    _messages.add(ChatMsg(
      id: 'welcome',
      content: '👋 Hello! I\'m DuckBot. How can I help you today?\n\n💡 Tip: Type "agent" or tap the agent icon to switch to a specialized agent mode!',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    _statusSubscription?.cancel();
    _typingSubscription?.cancel();
    _chatService?.dispose();
    super.dispose();
  }

  void _activateAgent(AgentPersonality agent) {
    setState(() {
      _activeAgent = agent;
      _isMultiAgentMode = false;
      _multiAgentTeam.clear();
    });
    
    _addSystemMessage('🤖 Agent activated: ${agent.emoji} ${agent.name}\n${agent.greeting}');
  }

  void _activateMultiAgentMode(List<AgentPersonality> agents) {
    setState(() {
      _isMultiAgentMode = true;
      _multiAgentTeam = agents;
      _activeAgent = null;
    });
    
    final agentNames = agents.map((a) => '${a.emoji} ${a.name}').join(', ');
    _addSystemMessage('🎭 Multi-agent team activated!\n$agentNames\n\nReady to tackle your task with ${agents.length} specialists!');
  }

  void _deactivateAgent() {
    setState(() {
      _activeAgent = null;
      _isMultiAgentMode = false;
      _multiAgentTeam.clear();
    });
    
    _addSystemMessage('👋 Agent mode deactivated. I\'m back to default DuckBot!');
  }

  void _addSystemMessage(String content) {
    setState(() {
      _messages.add(ChatMsg(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  /// Send message to gateway via WebSocket - THIS IS THE FIX
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Clear input immediately
    _messageController.clear();

    // Add user message to UI immediately (optimistic update)
    final userMessage = ChatMsg(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
      isSending: true,
    );

    setState(() {
      _messages.add(userMessage);
    });

    _scrollToBottom();

    // Send via chat service if available
    if (_chatService != null && _isConnected) {
      _chatService!.sendMessage(text).then((success) {
        if (!success) {
          // Show error
          setState(() {
            final index = _messages.indexWhere((m) => m.id == userMessage.id);
            if (index != -1) {
              _messages[index] = ChatMsg(
                id: userMessage.id,
                content: userMessage.content,
                isUser: true,
                timestamp: userMessage.timestamp,
                isError: true,
              );
            }
          });
        }
      });
    } else {
      // No connection - show error after a delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        
        setState(() {
          final index = _messages.indexWhere((m) => m.id == userMessage.id);
          if (index != -1) {
            _messages[index] = ChatMsg(
              id: userMessage.id,
              content: userMessage.content,
              isUser: true,
              timestamp: userMessage.timestamp,
              isError: true,
            );
          }
          
          _messages.add(ChatMsg(
            id: 'error_${DateTime.now().millisecondsSinceEpoch}',
            content: '❌ Not connected to gateway. Please check your connection in Settings.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
        });
        _scrollToBottom();
      });
    }
  }

  void _showAgentLibrary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgentLibraryScreen(
          selectionMode: true,
          onAgentSelected: _activateAgent,
        ),
      ),
    );
  }

  void _showAgentSelector() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgentSelectorScreen(
          onAgentSelected: _activateAgent,
          title: 'Select Agent',
        ),
      ),
    );
  }

  void _showMultiAgentScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiAgentScreen(
          onTeamActivated: _activateMultiAgentMode,
        ),
      ),
    );
  }

  void _showAgentDetail(AgentPersonality agent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgentDetailScreen(
          agent: agent,
          onActivate: () => _activateAgent(agent),
        ),
      ),
    );
  }
  
  void _showTemplates() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PromptTemplatesScreen(
          selectionMode: true,
          onTemplateSelected: (template, filledPrompt) async {
            _messageController.text = filledPrompt;
            final service = await PromptTemplatesService.getInstance();
            await service.incrementUsage(template.id);
          },
        ),
      ),
    );
  }

  List<ExportMessage> _getExportMessages() {
    return _messages.map((m) => ExportMessage(
      id: m.id,
      content: m.content,
      isUser: m.isUser,
      timestamp: m.timestamp,
      agentName: m.agent?.name,
      agentEmoji: m.agent?.emoji,
    )).toList();
  }

  void _showExportSheet() {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messages to export')),
      );
      return;
    }
    
    ExportBottomSheet.show(
      context,
      messages: _getExportMessages(),
      title: 'DuckBot Chat',
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildConnectionStatus() {
    if (_connectionError.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border(
            bottom: BorderSide(color: Colors.red.shade200, width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connection Error',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _connectionError,
                    style: TextStyle(color: Colors.red.shade600, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _connectToGateway,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (!_isConnected) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border(
            bottom: BorderSide(color: Colors.orange.shade200, width: 1),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connecting to gateway...',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Establishing WebSocket connection',
                    style: TextStyle(color: Colors.orange.shade600, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    // Connected - show subtle success indicator
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.green.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
          const SizedBox(width: 6),
          Text(
            'Connected to gateway',
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentIndicator() {
    if (_isMultiAgentMode && _multiAgentTeam.isNotEmpty) {
      return GestureDetector(
        onTap: _showMultiAgentScreen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎭', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                '${_multiAgentTeam.length} agents',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 16),
            ],
          ),
        ),
      );
    }
    
    if (_activeAgent != null) {
      return GestureDetector(
        onTap: () => _showAgentDetail(_activeAgent!),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _activeAgent!.division.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_activeAgent!.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                _activeAgent!.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: _activeAgent!.division.color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.close, size: 14, color: _activeAgent!.division.color),
            ],
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🦆 '),
            const Text('DuckBot'),
            const SizedBox(width: 8),
            if (_activeAgent != null || _isMultiAgentMode) _buildAgentIndicator(),
            const Spacer(),
            // Connection indicator
            Icon(
              _isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isConnected ? Colors.green : Colors.grey,
              size: 20,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _showExportSheet,
            tooltip: 'Export chat',
          ),
          if (_activeAgent != null)
            IconButton(
              icon: const Icon(Icons.person_remove),
              onPressed: _deactivateAgent,
              tooltip: 'Deactivate agent',
            ),
          IconButton(
            icon: const Icon(Icons.psychology),
            onPressed: _showAgentLibrary,
            tooltip: 'Agent Library',
          ),
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: _showMultiAgentScreen,
            tooltip: 'Multi-Agent Team',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() {
                _messages.clear();
                _addWelcomeMessage();
                _chatService?.clearMessages();
              });
            },
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status
          _buildConnectionStatus(),
          
          // Active agent banner
          if (_activeAgent != null || _isMultiAgentMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _activeAgent?.division.color.withValues(alpha: 0.1) ?? 
                     Colors.purple.withValues(alpha: 0.1),
              child: Row(
                children: [
                  if (_isMultiAgentMode) ...[
                    const Text('🎭', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Multi-Agent Mode: ${_multiAgentTeam.map((a) => a.name).join(", ")}',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else if (_activeAgent != null) ...[
                    Text(_activeAgent!.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _activeAgent!.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _activeAgent!.division.color,
                            ),
                          ),
                          Text(
                            _activeAgent!.shortDescription,
                            style: const TextStyle(fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _deactivateAgent,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          
          // Typing indicator
          if (_isTyping)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _activeAgent != null 
                        ? '${_activeAgent!.name} is typing...'
                        : 'DuckBot is typing...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          
          // Input area
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: SafeArea(
              child: Row(
                children: [
                  // Agent selector button
                  IconButton(
                    icon: const Icon(Icons.psychology),
                    onPressed: _showAgentSelector,
                    tooltip: 'Select Agent',
                    color: _activeAgent != null ? _activeAgent!.division.color : null,
                  ),
                  
                  // Prompt templates button
                  IconButton(
                    icon: const Icon(Icons.description_outlined),
                    onPressed: _showTemplates,
                    tooltip: 'Prompt Templates',
                  ),
                  
                  // Text input field
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: _activeAgent != null 
                            ? 'Chat with ${_activeAgent!.name}...'
                            : _isMultiAgentMode
                                ? 'Chat with ${_multiAgentTeam.length} agents...'
                                : 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: _isConnected ? Colors.transparent : Colors.orange.shade300,
                            width: _isConnected ? 0 : 2,
                          ),
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: null,
                      enabled: _isConnected,
                    ),
                  ),
                  
                  // Send button with state management
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: _isConnected 
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade400,
                      shape: BoxShape.circle,
                      boxShadow: _isConnected ? [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isConnected ? Icons.send : Icons.cloud_off,
                        color: Colors.white,
                      ),
                      onPressed: _isConnected ? _sendMessage : null,
                      tooltip: _isConnected ? 'Send' : 'Not connected',
                      iconSize: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMsg message) {
    final isUser = message.isUser;
    final colorScheme = Theme.of(context).colorScheme;
    
    final showAgentBadge = !isUser && message.agent != null;
    final hasInlineWidget = message.hasInlineWidget;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: message.agent?.division.color ?? const Color(0xFF00D4AA),
              child: Text(
                message.agent?.emoji ?? '🦆',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showAgentBadge)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      message.agent!.name,
                      style: TextStyle(
                        fontSize: 11,
                        color: message.agent!.division.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: hasInlineWidget 
                        ? MediaQuery.of(context).size.width * 0.85
                        : MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: message.isError
                        ? Colors.red.shade100
                        : isUser 
                            ? colorScheme.primary 
                            : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Text content
                      if (message.content.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                message.content,
                                style: TextStyle(
                                  color: message.isError
                                      ? Colors.red.shade900
                                      : isUser 
                                          ? colorScheme.onPrimary 
                                          : colorScheme.onSurface,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            if (message.isSending) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ],
                          ],
                        ),
                      
                      // Inline weather widget
                      if (message.hasWeatherWidget) ...[
                        if (message.content.isNotEmpty) const SizedBox(height: 10),
                        InlineWeatherWidget(
                          data: message.weatherWidget!,
                          showForecast: message.showWeatherForecast,
                          isNight: message.isNight,
                        ),
                      ],
                      
                      // Inline chart widget
                      if (message.hasChartWidget) ...[
                        if (message.content.isNotEmpty) const SizedBox(height: 10),
                        InlineChartWidget(
                          chartData: message.chartWidget!,
                        ),
                      ],
                      
                      // Inline info card widget
                      if (message.hasInfoCardWidget) ...[
                        if (message.content.isNotEmpty) const SizedBox(height: 10),
                        InlineCardWidget(
                          data: message.infoCardWidget!,
                        ),
                      ],
                      
                      // Inline status widget
                      if (message.hasStatusWidget) ...[
                        if (message.content.isNotEmpty) const SizedBox(height: 10),
                        InlineStatusWidget(
                          data: message.statusWidget!,
                        ),
                      ],
                      
                      // Generic inline widget fallback
                      if (message.inlineWidget != null && 
                          !message.hasWeatherWidget &&
                          !message.hasChartWidget &&
                          !message.hasInfoCardWidget &&
                          !message.hasStatusWidget) ...[
                        if (message.content.isNotEmpty) const SizedBox(height: 10),
                        _buildGenericInlineWidget(message.inlineWidget!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.secondary,
              child: Icon(
                Icons.person,
                size: 20,
                color: colorScheme.onSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  /// Build generic inline widget based on type
  Widget _buildGenericInlineWidget(InlineWidgetData inlineWidget) {
    switch (inlineWidget.type) {
      case InlineWidgetType.weather:
      case InlineWidgetType.forecast:
        return InlineWeatherWidget(
          data: WeatherWidgetData.fromMap(inlineWidget.data),
        );
        
      case InlineWidgetType.chart:
      case InlineWidgetType.data:
        // Use InlineChartData from agent_chart_tool for charts
        return InlineChartWidget(
          chartData: InlineChartData(
            id: 'inline_chart_${DateTime.now().millisecondsSinceEpoch}',
            title: inlineWidget.title ?? 'Chart',
            type: InlineChartType.bar,
            data: Map<String, double>.from(inlineWidget.data['data'] ?? {}),
            createdAt: DateTime.now(),
          ),
        );
        
      case InlineWidgetType.card:
        return InlineCardWidget(
          data: InfoCardWidgetData.fromMap(inlineWidget.data),
        );
        
      case InlineWidgetType.status:
        return InlineStatusWidget(
          data: StatusWidgetData.fromMap(inlineWidget.data),
        );
        
      case InlineWidgetType.code:
        return InlineCardWidget(
          data: InfoCardWidgetData(
            title: 'Code',
            description: inlineWidget.data['code']?.toString() ?? '',
            icon: '💻',
          ),
        );
        
      case InlineWidgetType.link:
        return InlineCardWidget(
          data: InfoCardWidgetData(
            title: inlineWidget.data['title']?.toString() ?? 'Link',
            description: inlineWidget.data['url']?.toString() ?? '',
            icon: '🔗',
          ),
        );
        
      case InlineWidgetType.image:
        return InlineCardWidget(
          data: InfoCardWidgetData(
            title: 'Image',
            description: inlineWidget.data['url']?.toString() ?? 'Image',
            icon: '🖼️',
          ),
        );
        
      case InlineWidgetType.map:
        return InlineCardWidget(
          data: InfoCardWidgetData(
            title: 'Location',
            description: inlineWidget.data['address']?.toString() ?? '',
            icon: '📍',
          ),
        );
        
      case InlineWidgetType.action:
        return InlineCardWidget(
          data: InfoCardWidgetData.fromMap(inlineWidget.data),
        );
    }
  }
}