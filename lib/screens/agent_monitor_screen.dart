import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gateway_service.dart';
import '../models/agent_session.dart';
import '../models/gateway_status.dart';
import '../widgets/agent_visualization_widget.dart';
import '../widgets/activity_feed_mobile.dart';
import '../widgets/gateway_status_card.dart';
import '../widgets/connection_status_icon.dart';
import 'agent_detail_screen.dart';
import 'boss_chat_screen.dart';

class AgentMonitorScreen extends StatefulWidget {
  final GatewayService? gatewayService;

  const AgentMonitorScreen({super.key, this.gatewayService});

  @override
  State<AgentMonitorScreen> createState() => _AgentMonitorScreenState();
}

class _AgentMonitorScreenState extends State<AgentMonitorScreen> {
  GatewayService? _service;
  GatewayStatus? _gatewayStatus;
  List<AgentSession> _agents = [];
  List<ActivityEvent> _activityEvents = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    if (widget.gatewayService != null) {
      setState(() => _service = widget.gatewayService);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final gatewayUrl =
          prefs.getString('gateway_url') ?? 'http://localhost:18789';
      final token = prefs.getString('gateway_token');
      setState(
          () => _service = GatewayService(baseUrl: gatewayUrl, token: token));
    }
    await _refreshAgents();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _refreshAgents());
  }

  Future<void> _refreshAgents() async {
    if (_service == null) return;

    try {
      final gatewayStatus = await _service!.getStatus();
      final agents = await _service!.getAgents() ?? [];
      final stats = await _service!.getAgentStats();
      final activityEvents = _buildActivityEvents(_agents, agents);

      if (mounted) {
        setState(() {
          _gatewayStatus = gatewayStatus;
          _agents = agents;
          _activityEvents = [
            ...activityEvents,
            ..._activityEvents,
          ].take(60).toList();
          _stats = stats;
          _loading = false;
          _error = null;
          _lastRefresh = DateTime.now();
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

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      BossChatScreen(gatewayService: _service),
                ),
              );
            },
            tooltip: 'Boss Chat',
          ),
          const ConnectionStatusIcon(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAgents,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _refreshAgents,
                  child: _buildContent(),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Connection Error',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(_error!, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshAgents,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Gateway Status
        GatewayStatusCard(
          status: _gatewayStatus,
          lastRefresh: _lastRefresh,
          onRefresh: _refreshAgents,
        ),
        const SizedBox(height: 16),

        // Quick Stats
        _buildStatsCard(),
        const SizedBox(height: 16),

        // Agent Visualization Widget (compact mode for list integration)
        AgentVisualizationWidget(
          gatewayService: _service,
          gatewayStatus: _gatewayStatus,
          compact: true,
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 340,
          child: ActivityFeedMobile(
            events: _activityEvents,
            loading: _loading,
            error: _error,
            onRefresh: _refreshAgents,
          ),
        ),
        const SizedBox(height: 16),

        // Agents Header
        _buildAgentsHeader(),
        const SizedBox(height: 8),

        // Agent List
        if (_agents.isEmpty)
          _buildEmptyState()
        else
          ..._agents.map((agent) => _buildAgentCard(agent)),
      ],
    );
  }

  Widget _buildStatsCard() {
    final stats = _stats ?? {};
    final total = stats['totalAgents'] ?? 0;
    final active = stats['activeAgents'] ?? 0;
    final tokens = stats['totalTokens'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Color(0xFF00D4AA)),
                const SizedBox(width: 8),
                Text('System Stats',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total Agents', total.toString(), Icons.people),
                _buildStatItem('Active', active.toString(), Icons.play_circle,
                    color: Colors.green),
                _buildStatItem('Tokens', _formatTokens(tokens), Icons.token),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon,
      {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.grey, size: 28),
        const SizedBox(height: 8),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildAgentsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Agents', style: Theme.of(context).textTheme.titleLarge),
        Text('${_agents.length} total',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  List<ActivityEvent> _buildActivityEvents(
    List<AgentSession> previous,
    List<AgentSession> next,
  ) {
    final now = DateTime.now();
    final previousByKey = {
      for (final agent in previous)
        if (agent.key.isNotEmpty) agent.key: agent,
    };
    final nextByKey = {
      for (final agent in next)
        if (agent.key.isNotEmpty) agent.key: agent,
    };
    final events = <ActivityEvent>[];

    for (final agent in next) {
      final prior = previousByKey[agent.key];
      if (prior == null) {
        events.add(
          _createActivityEvent(
            agent,
            type: 'system',
            message: 'Session connected',
            timestamp: now,
          ),
        );
        continue;
      }

      if (!prior.isActive && agent.isActive) {
        events.add(
          _createActivityEvent(
            agent,
            type: 'task_start',
            message: agent.statusSummary ?? 'Agent became active',
            timestamp: now,
          ),
        );
      } else if (prior.isActive && !agent.isActive) {
        events.add(
          _createActivityEvent(
            agent,
            type: 'task_complete',
            message: agent.statusSummary ?? 'Agent is now idle',
            timestamp: now,
          ),
        );
      }

      if (prior.currentToolName != agent.currentToolName &&
          agent.currentToolName != null &&
          agent.currentToolName!.isNotEmpty) {
        final detail =
            agent.currentToolPhase != null && agent.currentToolPhase!.isNotEmpty
                ? '${agent.currentToolName} (${agent.currentToolPhase})'
                : agent.currentToolName!;
        events.add(
          _createActivityEvent(
            agent,
            type: 'tool_call',
            message: 'Using $detail',
            timestamp: now,
          ),
        );
      }

      if (prior.statusSummary != agent.statusSummary &&
          agent.statusSummary != null &&
          agent.statusSummary!.isNotEmpty) {
        events.add(
          _createActivityEvent(
            agent,
            type: 'state_change',
            message: agent.statusSummary!,
            timestamp: now,
          ),
        );
      }

      if (!prior.aborted && agent.aborted) {
        events.add(
          _createActivityEvent(
            agent,
            type: 'error',
            message: 'Session aborted',
            timestamp: now,
          ),
        );
      }
    }

    for (final prior in previous) {
      if (!nextByKey.containsKey(prior.key)) {
        events.add(
          _createActivityEvent(
            prior,
            type: 'system',
            message: 'Session disconnected',
            timestamp: now,
          ),
        );
      }
    }

    return events;
  }

  ActivityEvent _createActivityEvent(
    AgentSession agent, {
    required String type,
    required String message,
    required DateTime timestamp,
  }) {
    return ActivityEvent(
      id: '${agent.key}-$type-${timestamp.millisecondsSinceEpoch}',
      agentId: agent.id,
      agentName: agent.name,
      agentEmoji: agent.emoji ?? '🤖',
      type: type,
      message: message,
      timestamp: timestamp,
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text('No agents active',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Start a session to see agents here',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentCard(AgentSession agent) {
    final isActive = agent.isActive;
    final statusColor = _getStatusColor(agent.statusColor);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showAgentDetails(agent),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Agent avatar/emoji
                  CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.2),
                    child: Text(agent.emoji ?? '🤖',
                        style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  // Agent name and status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                agent.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            if (agent.isSubagent)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Sub',
                                    style: TextStyle(fontSize: 10)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isActive ? Icons.play_circle : Icons.pause_circle,
                              size: 14,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                agent.statusDisplay,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: statusColor,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              // Token usage
              if (agent.usageKnown) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildTokenBadge('In', agent.inputTokens, Colors.blue),
                    const SizedBox(width: 8),
                    _buildTokenBadge('Out', agent.outputTokens, Colors.orange),
                    const SizedBox(width: 8),
                    _buildTokenBadge('Total', agent.totalTokens, Colors.green),
                  ],
                ),
              ],
              // Current tool
              if (agent.currentToolName != null &&
                  agent.currentToolName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.build, size: 12, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        agent.currentToolName!,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenBadge(String label, int tokens, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: color)),
          Text(
            _formatTokens(tokens),
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String statusColor) {
    switch (statusColor) {
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'yellow':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    }
    return tokens.toString();
  }

  void _showAgentDetails(AgentSession agent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgentDetailScreen(
          session: agent,
          gatewayService: _service,
        ),
      ),
    );
  }
}
