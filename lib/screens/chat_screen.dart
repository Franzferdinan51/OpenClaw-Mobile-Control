import 'package:flutter/material.dart';

/// Simple Message model for chat
class Message {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
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

  @override
  void initState() {
    super.initState();
    // Add welcome message from assistant
    _messages.add(Message(
      id: 'welcome',
      content: '👋 Hello! I\'m DuckBot. How can I help you today?',
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

    // Simulate bot response after delay
    _simulateBotResponse(text);
  }

  void _simulateBotResponse(String userInput) {
    Future.delayed(const Duration(milliseconds: 800), () {
      final botResponse = _generateMockResponse(userInput);
      
      setState(() {
        _messages.add(Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: botResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });

      _scrollToBottom();
    });
  }

  String _generateMockResponse(String input) {
    final lowerInput = input.toLowerCase();
    
    // Simple mock responses based on keywords
    if (lowerInput.contains('hello') || lowerInput.contains('hi')) {
      return '👋 Hi there! How can I assist you today?';
    } else if (lowerInput.contains('status')) {
      return '📊 The Gateway is online and running. All systems operational!';
    } else if (lowerInput.contains('agent')) {
      return '🤖 I can help you manage agents. You can view active agents on the dashboard.';
    } else if (lowerInput.contains('node')) {
      return '📱 Nodes are connected and reporting status. Check the dashboard for details.';
    } else if (lowerInput.contains('help')) {
      return '💡 I can help you with:\n- Checking Gateway status\n- Managing agents\n- Viewing node information\n- General questions\n\n(More features coming soon!)';
    } else if (lowerInput.contains('thank')) {
      return '😊 You\'re welcome! Let me know if you need anything else.';
    } else {
      return '🤔 I received your message: "$input"\n\nThis is a mock response. In the future, I\'ll be connected to the Gateway API for real responses!\n\nTry typing: "status", "help", "agents", or "nodes"';
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🦆 '),
            Text('DuckBot'),
          ],
        ),
        actions: [
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
                        hintText: 'Type a message...',
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
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF00D4AA),
              child: Text('🦆', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
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