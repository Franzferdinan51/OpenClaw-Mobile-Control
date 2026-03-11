import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/agent_personality.dart';
import '../models/agent_session.dart';
import '../models/chat_message.dart';
import '../services/gateway_service.dart';

/// Detail screen for a single agent or live session.
class AgentDetailScreen extends StatefulWidget {
  final AgentPersonality? agent;
  final AgentSession? session;
  final GatewayService? gatewayService;
  final VoidCallback? onActivate;

  const AgentDetailScreen({
    super.key,
    this.agent,
    this.session,
    this.gatewayService,
    this.onActivate,
  }) : assert(
          agent != null || session != null,
          'Must provide either agent or session',
        );

  @override
  State<AgentDetailScreen> createState() => _AgentDetailScreenState();
}

class _AgentDetailScreenState extends State<AgentDetailScreen> {
  List<ChatMessage> _recentMessages = [];
  bool _historyLoading = false;
  String? _historyError;

  String get _name => widget.agent?.name ?? widget.session?.name ?? 'Unknown';
  String get _emoji => widget.agent?.emoji ?? widget.session?.emoji ?? '🤖';
  String get _description =>
      widget.agent?.shortDescription ??
      widget.session?.statusSummary ??
      'Agent session';
  String get _role =>
      widget.agent?.role ??
      (widget.session?.isSubagent == true ? 'Subagent' : 'Agent');
  Color get _color => widget.agent?.division.color ?? const Color(0xFF00D4AA);
  String get _divisionName =>
      widget.agent?.division.displayName ??
      (widget.session?.isSubagent == true ? 'Subagent' : 'Primary Agent');
  String get _divisionEmoji =>
      widget.agent?.division.emoji ??
      (widget.session?.isSubagent == true ? '👥' : '🤖');

  @override
  void initState() {
    super.initState();
    _loadSessionHistory();
  }

  @override
  void didUpdateWidget(covariant AgentDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final sessionChanged = oldWidget.session?.key != widget.session?.key;
    final gatewayChanged =
        oldWidget.gatewayService?.baseUrl != widget.gatewayService?.baseUrl ||
            oldWidget.gatewayService?.token != widget.gatewayService?.token;

    if (sessionChanged || gatewayChanged) {
      _loadSessionHistory();
    }
  }

  Future<void> _loadSessionHistory() async {
    final session = widget.session;
    final gateway = widget.gatewayService;
    if (session == null || gateway == null) {
      if (mounted) {
        setState(() {
          _recentMessages = [];
          _historyError = null;
          _historyLoading = false;
        });
      }
      return;
    }

    setState(() {
      _historyLoading = true;
      _historyError = null;
    });

    try {
      final history = await gateway.getChatHistory(session.key, limit: 10);
      if (!mounted) return;

      setState(() {
        _recentMessages = history ?? [];
        _historyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _historyError = e.toString();
        _historyLoading = false;
      });
    }
  }

  Future<void> _copySessionKey() async {
    final sessionKey = widget.session?.key;
    if (sessionKey == null || sessionKey.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: sessionKey));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session key copied')),
    );
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return 'Unknown';
    final local = timestamp.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isSession = widget.session != null;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(_emoji),
            const SizedBox(width: 8),
            Expanded(child: Text(_name)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: _color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              _emoji,
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _role,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$_divisionEmoji $_divisionName',
                                  style: TextStyle(
                                    color: _color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isSession && widget.session != null) ...[
              _buildSessionInfoCard(context, widget.session!),
              const SizedBox(height: 16),
              _buildRecentHistoryCard(context),
              const SizedBox(height: 16),
            ],
            if (widget.agent != null) ...[
              _buildSection(
                context,
                'Communication Style',
                widget.agent!.communicationStyle,
              ),
              _buildSection(
                context,
                'Specialties',
                widget.agent!.specialties.map((s) => '- $s').join('\n'),
              ),
              _buildSection(
                context,
                'Workflow',
                widget.agent!.workflows.join('\n'),
              ),
              _buildSection(
                context,
                'Deliverables',
                widget.agent!.deliverables.map((d) => '- $d').join('\n'),
              ),
              _buildSection(
                context,
                'Success Metrics',
                widget.agent!.successMetrics.map((m) => '- $m').join('\n'),
              ),
            ],
            const SizedBox(height: 24),
            if (isSession)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copySessionKey,
                      icon: const Icon(Icons.copy_all),
                      label: const Text('Copy Session Key'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _loadSessionHistory,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh History'),
                      style: FilledButton.styleFrom(backgroundColor: _color),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    if (widget.onActivate != null) {
                      widget.onActivate!();
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$_name activated'),
                        backgroundColor: _color,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Activate Agent'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: _color,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionInfoCard(BuildContext context, AgentSession session) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Info',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Session Key', session.key),
            _buildInfoRow('Model', session.model),
            _buildInfoRow('Channel', session.channel),
            _buildInfoRow('Kind', session.kind),
            _buildInfoRow('Active', session.isActive ? 'Yes' : 'No'),
            if (session.currentToolName != null)
              _buildInfoRow(
                'Current Tool',
                session.currentToolPhase != null &&
                        session.currentToolPhase!.isNotEmpty
                    ? '${session.currentToolName} (${session.currentToolPhase})'
                    : session.currentToolName!,
              ),
            if (session.statusSummary != null)
              _buildInfoRow('Status', session.statusSummary!),
            if (session.lastMessagePreview != null)
              _buildInfoRow('Last Message', session.lastMessagePreview!),
            if (session.lastActivity != null)
              _buildInfoRow(
                'Last Activity',
                _formatTimestamp(session.lastActivity),
              ),
            if (session.usageKnown) ...[
              const SizedBox(height: 8),
              _buildInfoRow('Input Tokens', '${session.inputTokens}'),
              _buildInfoRow('Output Tokens', '${session.outputTokens}'),
              _buildInfoRow('Context Tokens', '${session.contextTokens}'),
              _buildInfoRow('Total Tokens', '${session.totalTokens}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentHistoryCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent History',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_historyLoading)
              const Center(child: CircularProgressIndicator())
            else if (_historyError != null)
              Text(
                _historyError!,
                style: TextStyle(color: Colors.red[700]),
              )
            else if (_recentMessages.isEmpty)
              Text(
                'No recent messages loaded for this session.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ..._recentMessages.map((message) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message.isUser
                            ? _color.withValues(alpha: 0.12)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                message.displayRole,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Text(
                                _formatTimestamp(message.timestamp),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(message.content),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
