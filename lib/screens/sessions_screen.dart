import 'package:flutter/material.dart';
import '../services/gateway_service.dart';
import '../models/agent_session.dart';

/// Sessions Screen - Manage active agent sessions
/// Shows list of active sessions with ability to view history and send messages
class SessionsScreen extends StatefulWidget {
  final GatewayService? gatewayService;

  const SessionsScreen({super.key, this.gatewayService});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<AgentSession> _sessions = [];
  List<AgentSession> _history = [];
  bool _isLoading = true;
  String? _error;
  int _selectedTab = 0;
  String? _selectedSessionId;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // In production, this would fetch from gateway API
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _sessions = [
          AgentSession(
            id: 'session-main-001',
            key: 'agent:main:telegram:direct:588090613',
            name: 'DuckBot Main',
            emoji: '🦆',
            modelProvider: 'bailian',
            model: 'qwen3.5-plus',
            inputTokens: 12500,
            outputTokens: 3420,
            totalTokens: 15920,
            usageKnown: true,
            contextTokens: 8500,
            channel: 'telegram',
            kind: 'direct',
            label: 'Main Agent',
            displayName: 'DuckBot',
            derivedTitle: 'Telegram Chat',
            lastMessagePreview: 'Let me check the weather forecast...',
            chatStatus: 'active',
            agentStatus: 'processing',
            currentToolName: 'weather',
            currentToolPhase: 'executing',
            statusSummary: 'Getting weather data',
            isActive: true,
            isSubagent: false,
            lastActivity: DateTime.now().subtract(const Duration(minutes: 2)),
            updatedAt: DateTime.now(),
          ),
          AgentSession(
            id: 'session-cron-001',
            key: 'agent:cron:heartbeat',
            name: 'Heartbeat Monitor',
            emoji: '💓',
            modelProvider: 'bailian',
            model: 'MiniMax-M2.5',
            inputTokens: 450,
            outputTokens: 120,
            totalTokens: 570,
            usageKnown: true,
            contextTokens: 200,
            channel: 'cron',
            kind: 'heartbeat',
            label: 'Cron Agent',
            displayName: 'Heartbeat',
            lastMessagePreview: 'System check complete - all OK',
            chatStatus: 'idle',
            agentStatus: 'waiting',
            statusSummary: 'Waiting for next schedule',
            isActive: false,
            isSubagent: false,
            lastActivity: DateTime.now().subtract(const Duration(hours: 1)),
            updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
          AgentSession(
            id: 'session-sub-001',
            key: 'agent:main:subagent:300e0703-5c23-40bf-aa33-57fecdb0c170',
            name: 'Android Engineer',
            emoji: '📱',
            modelProvider: 'bailian',
            model: 'kimi-k2.5',
            inputTokens: 2100,
            outputTokens: 890,
            totalTokens: 2990,
            usageKnown: true,
            contextTokens: 1500,
            channel: 'subagent',
            kind: 'android',
            label: 'Sub-agent',
            displayName: 'Android Control',
            derivedTitle: 'Screen Analysis',
            lastMessagePreview: 'Detected button at coordinates (500, 300)',
            chatStatus: 'active',
            agentStatus: 'processing',
            currentToolName: 'adb',
            currentToolPhase: 'waiting',
            statusSummary: 'Analyzing screen',
            isActive: true,
            isSubagent: true,
            lastActivity: DateTime.now().subtract(const Duration(minutes: 5)),
            updatedAt: DateTime.now(),
          ),
          AgentSession(
            id: 'session-discord-001',
            key: 'agent:main:discord:guild:123456789:channel:987654321',
            name: 'Discord Bot',
            emoji: '🎮',
            modelProvider: 'bailian',
            model: 'glm-5',
            inputTokens: 3200,
            outputTokens: 1500,
            totalTokens: 4700,
            usageKnown: true,
            contextTokens: 2800,
            channel: 'discord',
            kind: 'guild',
            label: 'Discord Agent',
            displayName: 'AI Council',
            derivedTitle: 'AI Council Chamber',
            lastMessagePreview: 'The council has reached consensus...',
            chatStatus: 'active',
            agentStatus: 'processing',
            currentToolName: 'web_search',
            currentToolPhase: 'executing',
            statusSummary: 'Searching for information',
            isActive: true,
            isSubagent: false,
            lastActivity: DateTime.now().subtract(const Duration(minutes: 15)),
            updatedAt: DateTime.now(),
          ),
        ];

        _history = [
          AgentSession(
            id: 'session-old-001',
            key: 'agent:main:telegram:direct:588090613:old',
            name: 'Research Task',
            emoji: '🔬',
            modelProvider: 'bailian',
            model: 'MiniMax-M2.5',
            inputTokens: 8500,
            outputTokens: 4200,
            totalTokens: 12700,
            usageKnown: true,
            channel: 'telegram',
            kind: 'direct',
            label: 'Completed',
            lastMessagePreview: 'Research complete - see summary above',
            statusSummary: 'Session ended',
            isActive: false,
            isSubagent: false,
            lastActivity: DateTime.now().subtract(const Duration(hours: 3)),
            updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
            aborted: false,
          ),
          AgentSession(
            id: 'session-old-002',
            key: 'agent:main:subagent:aborted-session',
            name: 'Coding Task (Aborted)',
            emoji: '💻',
            modelProvider: 'bailian',
            model: 'glm-5',
            inputTokens: 1500,
            outputTokens: 200,
            totalTokens: 1700,
            usageKnown: true,
            channel: 'subagent',
            kind: 'coding',
            label: 'Aborted',
            lastMessagePreview: 'Session cancelled by user',
            statusSummary: 'Aborted',
            isActive: false,
            isSubagent: true,
            lastActivity: DateTime.now().subtract(const Duration(hours: 5)),
            updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
            aborted: true,
          ),
          AgentSession(
            id: 'session-old-003',
            key: 'agent:cron:daily-brief',
            name: 'Daily Brief Generator',
            emoji: '📰',
            modelProvider: 'bailian',
            model: 'qwen3.5-plus',
            inputTokens: 4200,
            outputTokens: 3800,
            totalTokens: 8000,
            usageKnown: true,
            channel: 'cron',
            kind: 'scheduled',
            label: 'Completed',
            lastMessagePreview: 'Daily brief sent to Telegram',
            statusSummary: 'Completed',
            isActive: false,
            isSubagent: false,
            lastActivity: DateTime.now().subtract(const Duration(days: 1)),
            updatedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showSessionDetails(AgentSession session) {
    setState(() {
      _selectedSessionId = session.id;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SessionDetailSheet(
        session: session,
        onClose: () => Navigator.pop(context),
        onSendMessage: (message) {
          Navigator.pop(context);
          _sendMessageToSession(session, message);
        },
        onViewHistory: () {
          Navigator.pop(context);
          _viewSessionHistory(session);
        },
        onEndSession: () {
          Navigator.pop(context);
          _endSession(session);
        },
      ),
    );
  }

  void _sendMessageToSession(AgentSession session, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Message sent to ${session.name}: $message'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _viewSessionHistory(AgentSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _SessionHistoryScreen(session: session),
      ),
    );
  }

  void _endSession(AgentSession session) {
    setState(() {
      _sessions.removeWhere((s) => s.id == session.id);
      _history.add(session);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${session.name} session ended'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _spawnNewSession() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.blue),
              title: const Text('Chat Session'),
              subtitle: const Text('Start a new chat with the agent'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Opening new chat session...'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bolt, color: Colors.orange),
              title: const Text('Quick Task'),
              subtitle: const Text('Spawn a sub-agent for a specific task'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Opening task creator...'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.code, color: Colors.purple),
              title: const Text('Coding Agent'),
              subtitle: const Text('Spawn a coding sub-agent'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Spawning coding agent...'),
                    backgroundColor: Colors.purple,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
          ),
        ],
        bottom: TabBar(
          onTap: (index) => setState(() => _selectedTab = index),
          tabs: [
            Tab(text: 'Active (${_sessions.where((s) => s.isActive).length})'),
            Tab(text: 'History (${_history.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadSessions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  children: [
                    _buildSessionList(_sessions),
                    _buildSessionList(_history),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _spawnNewSession,
        icon: const Icon(Icons.add),
        label: const Text('New Session'),
      ),
    );
  }

  Widget _buildSessionList(List<AgentSession> sessions) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No sessions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _SessionCard(
          session: session,
          onTap: () => _showSessionDetails(session),
          isSelected: _selectedSessionId == session.id,
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  final AgentSession session;
  final VoidCallback onTap;
  final bool isSelected;

  const _SessionCard({
    required this.session,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: session.isActive
                      ? Border.all(color: _getStatusColor(), width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    session.emoji ?? '🤖',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (session.isActive)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getModelColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            session.model,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _getModelColor(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _getChannelIcon(),
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          session.channel,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        if (session.isSubagent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SUB',
                              style: TextStyle(fontSize: 9, color: Colors.purple, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (session.currentToolName != null && session.isActive) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _getStatusColor(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${session.currentToolPhase}: ${session.currentToolName}',
                            style: TextStyle(
                              fontSize: 11,
                              color: _getStatusColor(),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (session.lastMessagePreview != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        session.lastMessagePreview!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _formatTimestamp(session.lastActivity),
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.input, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          _formatTokens(session.inputTokens),
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.output, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          _formatTokens(session.outputTokens),
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (session.isActive) return Colors.green;
    if (session.aborted) return Colors.red;
    return Colors.grey;
  }

  Color _getModelColor() {
    if (session.model.contains('qwen')) return Colors.blue;
    if (session.model.contains('MiniMax')) return Colors.green;
    if (session.model.contains('kimi')) return Colors.orange;
    if (session.model.contains('glm')) return Colors.purple;
    return Colors.grey;
  }

  IconData _getChannelIcon() {
    switch (session.channel) {
      case 'telegram':
        return Icons.send;
      case 'discord':
        return Icons.discord;
      case 'cron':
        return Icons.schedule;
      case 'subagent':
        return Icons.call_split;
      default:
        return Icons.chat;
    }
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return 'Unknown';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return tokens.toString();
  }
}

class _SessionDetailSheet extends StatelessWidget {
  final AgentSession session;
  final VoidCallback onClose;
  final Function(String) onSendMessage;
  final VoidCallback onViewHistory;
  final VoidCallback onEndSession;

  const _SessionDetailSheet({
    required this.session,
    required this.onClose,
    required this.onSendMessage,
    required this.onViewHistory,
    required this.onEndSession,
  });

  @override
  Widget build(BuildContext context) {
    final messageController = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(session.emoji ?? '🤖', style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      session.key,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Session Info
          _buildInfoRow(context, 'Model', session.model, _getModelColor()),
          const SizedBox(height: 12),
          _buildInfoRow(context, 'Channel', session.channel, Colors.blue),
          const SizedBox(height: 12),
          _buildInfoRow(context, 'Status', session.statusDisplay, _getStatusColor()),
          const SizedBox(height: 12),
          _buildInfoRow(context, 'Tokens', '${session.totalTokens} total', Colors.grey),
          const SizedBox(height: 24),

          // Send Message
          if (session.isActive) ...[
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                labelText: 'Send message to session',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (messageController.text.isNotEmpty) {
                      onSendMessage(messageController.text);
                    }
                  },
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  onSendMessage(value);
                }
              },
            ),
            const SizedBox(height: 24),
          ],

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewHistory,
                  icon: const Icon(Icons.history),
                  label: const Text('View History'),
                ),
              ),
              const SizedBox(width: 8),
              if (session.isActive)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEndSession,
                    icon: const Icon(Icons.stop),
                    label: const Text('End Session'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor() {
    if (session.isActive) return Colors.green;
    if (session.aborted) return Colors.red;
    return Colors.grey;
  }

  Color _getModelColor() {
    if (session.model.contains('qwen')) return Colors.blue;
    if (session.model.contains('MiniMax')) return Colors.green;
    if (session.model.contains('kimi')) return Colors.orange;
    if (session.model.contains('glm')) return Colors.purple;
    return Colors.grey;
  }
}

class _SessionHistoryScreen extends StatelessWidget {
  final AgentSession session;

  const _SessionHistoryScreen({required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${session.name} History'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Text(session.emoji ?? '🤖', style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  'Session History',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Full message history would be displayed here',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Session Info', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Text('ID: ${session.id}'),
                        Text('Key: ${session.key}'),
                        Text('Model: ${session.model}'),
                        Text('Channel: ${session.channel}'),
                        Text('Total Tokens: ${session.totalTokens}'),
                        Text('Input Tokens: ${session.inputTokens}'),
                        Text('Output Tokens: ${session.outputTokens}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}