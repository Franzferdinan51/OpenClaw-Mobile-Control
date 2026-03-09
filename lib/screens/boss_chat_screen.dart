import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gateway_service.dart';
import '../models/agent_session.dart';
import '../models/chat_message.dart';

class BossChatScreen extends StatefulWidget {
  final GatewayService? gatewayService;

  const BossChatScreen({super.key, this.gatewayService});

  @override
  State<BossChatScreen> createState() => _BossChatScreenState();
}

class _BossChatScreenState extends State<BossChatScreen> with SingleTickerProviderStateMixin {
  GatewayService? _service;
  List<AgentSession> _agents = [];
  final TextEditingController _broadcastController = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  String? _error;
  TabController? _tabController;
  BossIdentity _bossIdentity = BossIdentity();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadConfig();
    _loadBossIdentity();
  }

  Future<void> _loadConfig() async {
    if (widget.gatewayService != null) {
      setState(() => _service = widget.gatewayService);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final gatewayUrl = prefs.getString('gateway_url') ?? 'http://localhost:18789';
      final token = prefs.getString('gateway_token');
      setState(() => _service = GatewayService(baseUrl: gatewayUrl, token: token));
    }
    await _loadAgents();
  }

  Future<void> _loadBossIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('boss_name') ?? 'Boss';
    final emoji = prefs.getString('boss_emoji') ?? '👔';
    setState(() {
      _bossIdentity = BossIdentity(name: name, emoji: emoji);
    });
  }

  Future<void> _loadAgents() async {
    if (_service == null) return;

    try {
      final agents = await _service!.getAgents();
      if (mounted) {
        setState(() {
          _agents = agents?.where((a) => !a.isSubagent).toList() ?? [];
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendBroadcast() async {
    if (_service == null || _broadcastController.text.trim().isEmpty) return;

    setState(() => _sending = true);

    try {
      final result = await _service!.broadcastToAgents(_broadcastController.text);

      if (mounted) {
        if (result?['ok'] == true) {
          _broadcastController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Broadcast sent to ${_agents.length} agent(s)!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${result?['error'] ?? 'Failed to send'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _broadcastController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boss Chat'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.broadcast_on_personal), text: 'Broadcast'),
            Tab(icon: Icon(Icons.chat), text: 'Direct'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBroadcastTab(),
          _buildDirectTab(),
        ],
      ),
    );
  }

  Widget _buildBroadcastTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Boss identity header
          Card(
            color: const Color(0xFF00D4AA).withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF00D4AA),
                    child: Text(_bossIdentity.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _bossIdentity.displayName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Send to all main agents',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_agents.length} agents',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Message input
          Expanded(
            child: TextField(
              controller: _broadcastController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: 'Type your message to all agents...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[850],
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),

          // Send button
          ElevatedButton.icon(
            onPressed: _sending ? null : _sendBroadcast,
            icon: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_sending ? 'Sending...' : 'Broadcast to All Agents'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4AA),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAgents,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_agents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text('No agents available', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Start an agent to send direct messages'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _agents.length,
      itemBuilder: (context, index) {
        final agent = _agents[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: agent.isActive ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
              child: Text(agent.emoji ?? '🤖', style: const TextStyle(fontSize: 20)),
            ),
            title: Text(agent.name),
            subtitle: Text(agent.model),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: agent.isActive ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _openDirectChat(agent),
          ),
        );
      },
    );
  }

  void _openDirectChat(AgentSession agent) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _DirectChatScreen(
          agent: agent,
          gatewayService: _service,
          bossIdentity: _bossIdentity,
        ),
      ),
    );
  }
}

class _DirectChatScreen extends StatefulWidget {
  final AgentSession agent;
  final GatewayService? gatewayService;
  final BossIdentity bossIdentity;

  const _DirectChatScreen({
    required this.agent,
    this.gatewayService,
    required this.bossIdentity,
  });

  @override
  State<_DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<_DirectChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (widget.gatewayService == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final history = await widget.gatewayService!.getChatHistory(widget.agent.key);
      if (mounted) {
        setState(() {
          _messages.addAll(history ?? []);
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty || widget.gatewayService == null) return;

    final text = _controller.text.trim();
    _controller.clear();

    // Add user message immediately
    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'user',
        content: text,
        timestamp: DateTime.now(),
      ));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final success = await widget.gatewayService!.sendAgentMessage(widget.agent.key, text);

      if (mounted) {
        if (success) {
          // Message sent successfully
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message sent!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.agent.emoji ?? '🤖', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.agent.name, style: const TextStyle(fontSize: 16)),
                  Text(
                    widget.agent.isActive ? 'Active' : 'Idle',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.agent.isActive ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[600]),
                            const SizedBox(height: 16),
                            Text('No messages yet'),
                            const SizedBox(height: 8),
                            Text('Start the conversation!'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isUser = msg.isUser;
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? const Color(0xFF00D4AA)
                                    : Colors.grey[800],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.content,
                                    style: TextStyle(
                                      color: isUser ? Colors.black : Colors.white,
                                    ),
                                  ),
                                  if (msg.timestamp != null)
                                    Text(
                                      _formatTime(msg.timestamp!),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isUser ? Colors.black54 : Colors.white54,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.agent.name}...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF00D4AA),
                    child: IconButton(
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.send, color: Colors.black),
                      onPressed: _sending ? null : _sendMessage,
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

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}