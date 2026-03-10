import 'package:flutter/material.dart';
import '../models/agent_personality.dart';
import '../data/agency_agents.dart';
import '../services/chat_export_service.dart';
import '../services/prompt_templates_service.dart';
import '../widgets/export_dialog.dart';
import 'agent_library_screen.dart';
import 'agent_selector_screen.dart';
import 'agent_detail_screen.dart';
import 'multi_agent_screen.dart';
import 'prompt_templates_screen.dart';

/// Simple Message model for chat
class Message {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final AgentPersonality? agent; // Agent that sent the message (for multi-agent)

  Message({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.agent,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  
  // Agent personality state
  AgentPersonality? _activeAgent;
  List<AgentPersonality> _multiAgentTeam = [];
  bool _isMultiAgentMode = false;

  @override
  void initState() {
    super.initState();
    // Add welcome message from assistant
    _messages.add(Message(
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
      _messages.add(Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Add user message
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _messageController.clear();
    });

    // Scroll to bottom
    _scrollToBottom();

    // Generate response based on agent mode
    _generateResponse(text);
  }

  void _generateResponse(String userInput) {
    Future.delayed(const Duration(milliseconds: 800), () {
      // Prevent setState after widget disposed (memory leak fix)
      if (!mounted) return;
      
      String response;
      
      if (_isMultiAgentMode && _multiAgentTeam.isNotEmpty) {
        response = _generateMultiAgentResponse(userInput);
      } else if (_activeAgent != null) {
        response = _generateSingleAgentResponse(_activeAgent!, userInput);
      } else {
        response = _generateDefaultResponse(userInput);
      }
      
      setState(() {
        _messages.add(Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: response,
          isUser: false,
          timestamp: DateTime.now(),
          agent: _isMultiAgentMode ? null : _activeAgent,
        ));
      });

      _scrollToBottom();
    });
  }

  String _generateSingleAgentResponse(AgentPersonality agent, String input) {
    final lowerInput = input.toLowerCase();
    
    // Check for deactivation
    if (lowerInput.contains('deactivate') || lowerInput.contains('stop agent') || lowerInput.contains('exit')) {
      _deactivateAgent();
      return '👋 Agent mode deactivated. Back to default!';
    }
    
    // Check for matching phrases
    for (final entry in agent.examplePhrases.entries) {
      if (lowerInput.contains(entry.key)) {
        return '${agent.emoji} ${entry.value}';
      }
    }

    // Default response based on division
    switch (agent.division) {
      case AgentDivision.engineering:
        return '${agent.emoji} Ready to work on: "$input"\n\nI\'ll analyze the requirements and provide a technical solution. What\'s your priority?';
      case AgentDivision.design:
        return '${agent.emoji} Let\'s create something beautiful for: "$input"\n\nI\'ll focus on the visual and user experience aspects. Any specific style preferences?';
      case AgentDivision.marketing:
        return '${agent.emoji} Marketing strategy for: "$input"\n\nI\'ll develop a growth-focused approach. What\'s your target audience?';
      case AgentDivision.product:
        return '${agent.emoji} Product focus on: "$input"\n\nI\'ll help prioritize and deliver value. What metrics matter most?';
      case AgentDivision.projectManagement:
        return '${agent.emoji} Managing: "$input"\n\nI\'ll keep things on track. What\'s the timeline?';
      case AgentDivision.testing:
        return '${agent.emoji} Testing: "$input"\n\nI\'ll ensure quality and gather evidence. What\'s the acceptance criteria?';
      case AgentDivision.support:
        return '${agent.emoji} Supporting: "$input"\n\nI\'ll help resolve this. Can you provide more details?';
      case AgentDivision.spatialComputing:
        return '${agent.emoji} Building spatial experience: "$input"\n\nI\'ll create an immersive solution. What\'s the target platform?';
      case AgentDivision.specialized:
        return '${agent.emoji} Working on: "$input"\n\nI\'ll leverage specialized expertise. What specific aspect needs attention?';
    }
  }

  String _generateMultiAgentResponse(String input) {
    final lowerInput = input.toLowerCase();
    
    if (lowerInput.contains('deactivate') || lowerInput.contains('stop') || lowerInput.contains('exit')) {
      _deactivateAgent();
      return '👋 Multi-agent mode deactivated. Back to default!';
    }
    
    final agents = _multiAgentTeam.map((a) => a.emoji).join(' ');
    return '$agents Team responding to: "$input"\n\nCoordinating ${_multiAgentTeam.length} agents: ${_multiAgentTeam.map((a) => a.name).join(', ')}.\n\nEach specialist is contributing their expertise to address your request.';
  }

  String _generateDefaultResponse(String input) {
    final lowerInput = input.toLowerCase();
    
    // Handle agent switching commands
    if (lowerInput.contains('activate') || lowerInput.contains('switch')) {
      // Try to find matching agent
      for (final agent in AgencyAgentsData.allAgents) {
        if (lowerInput.contains(agent.name.toLowerCase())) {
          _activateAgent(agent);
          return '🤖 Switching to ${agent.emoji} ${agent.name} mode!';
        }
      }
      // If no specific agent found, open selector
      _showAgentSelector();
      return 'Let me help you find the right agent!';
    }
    
    // Handle multi-agent commands
    if (lowerInput.contains('multi') || lowerInput.contains('team') || lowerInput.contains('orchestrate')) {
      _showMultiAgentScreen();
      return 'Opening multi-agent team selector!';
    }
    
    // Show agent library
    if (lowerInput.contains('agent') && (lowerInput.contains('library') || lowerInput.contains('browse') || lowerInput.contains('show'))) {
      _showAgentLibrary();
      return 'Opening the Agent Library with 61 specialized agents!';
    }
    
    // Standard responses
    if (lowerInput.contains('hello') || lowerInput.contains('hi')) {
      return '👋 Hi there! How can I assist you today?\n\n💡 Say "show agents" to browse 61 specialized agents!';
    } else if (lowerInput.contains('status')) {
      return '📊 The Gateway is online and running. All systems operational!';
    } else if (lowerInput.contains('agent')) {
      return '🤖 I can work in different agent modes!\n\nTry:\n• "show agents" - Browse all 61 agents\n• "activate Frontend Developer" - Switch to specific agent\n• "multi-agent" or "team" - Use multiple agents\n\nOr tap the agent icon below!';
    } else if (lowerInput.contains('node')) {
      return '📱 Nodes are connected and reporting status. Check the dashboard for details.';
    } else if (lowerInput.contains('help')) {
      return '''💡 I can help you with:

• Checking Gateway status
• Managing agents (say "show agents")
• Viewing node information
• Specialized tasks with agent modes

Try: "show agents", "activate AI Engineer", or "multi-agent"''';
    } else if (lowerInput.contains('thank')) {
      return '😊 You\'re welcome! Let me know if you need anything else.';
    } else {
      return '🤔 I received: "$input"\n\n💡 Try "show agents" or tap the agent icon to use specialized agent modes!';
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
            // Insert the filled prompt into the text field
            _messageController.text = filledPrompt;
            
            // Increment usage count
            final service = await PromptTemplatesService.getInstance();
            await service.incrementUsage(template.id);
          },
        ),
      ),
    );
  }

  /// Convert internal messages to export format
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

  /// Show export dialog
  void _showExportDialog() {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No messages to export'),
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => ExportDialog(
        messages: _getExportMessages(),
        title: 'DuckBot Chat',
      ),
    );
  }

  /// Show quick export bottom sheet
  void _showExportSheet() {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No messages to export'),
        ),
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

  /// Build the active agent indicator
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
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
              Icon(
                Icons.close,
                size: 14,
                color: _activeAgent!.division.color,
                semanticLabel: 'Deactivate',
              ),
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
            if (_activeAgent != null || _isMultiAgentMode) 
              _buildAgentIndicator(),
          ],
        ),
        actions: [
          // Export button
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _showExportSheet,
            tooltip: 'Export chat',
          ),
          // Agent mode indicator + buttons
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
                _messages.add(Message(
                  id: 'welcome',
                  content: '👋 Hello! I\'m DuckBot. How can I help you today?',
                  isUser: false,
                  timestamp: DateTime.now(),
                ));
              });
            },
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
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
                  // Voice input button (placeholder)
                  IconButton(
                    icon: const Icon(Icons.mic),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Voice input coming soon!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    tooltip: 'Voice input',
                  ),
                  
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
                  
                  // Attachment button (placeholder)
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('File attachment coming soon!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    tooltip: 'Attach file',
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: null,
                    ),
                  ),
                  
                  // Send button
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _sendMessage,
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isUser = message.isUser;
    final colorScheme = Theme.of(context).colorScheme;
    
    // Show agent indicator for agent responses
    final showAgentBadge = !isUser && message.agent != null;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: message.agent?.division.color ?? const Color(0xFF00D4AA),
              child: Text(
                message.agent?.emoji ?? '🦆',
                style: const TextStyle(fontSize: 16),
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
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      message.agent!.name,
                      style: TextStyle(
                        fontSize: 10,
                        color: message.agent!.division.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isUser 
                        ? colorScheme.primary 
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isUser 
                          ? colorScheme.onPrimary 
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.secondary,
              child: Icon(
                Icons.person,
                size: 18,
                color: colorScheme.onSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}