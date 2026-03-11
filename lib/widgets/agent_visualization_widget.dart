import 'dart:async';
import 'package:flutter/material.dart';
import '../models/agent_session.dart';
import '../models/gateway_status.dart';
import '../services/gateway_service.dart';
import 'agent_card_widget.dart';
import 'pixel_agent_avatar.dart';

class AgentVisualizationWidget extends StatefulWidget {
  final GatewayService? gatewayService;
  final GatewayStatus? gatewayStatus;
  final bool compact;
  final VoidCallback? onTap;

  const AgentVisualizationWidget({
    super.key,
    this.gatewayService,
    this.gatewayStatus,
    this.compact = false,
    this.onTap,
  });

  @override
  State<AgentVisualizationWidget> createState() =>
      _AgentVisualizationWidgetState();
}

class _AgentVisualizationWidgetState extends State<AgentVisualizationWidget> {
  List<dynamic> _agents = [];
  Map<String, dynamic>? _stats;
  Timer? _refreshTimer;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _refreshAgents();
    _startAutoRefresh();
  }

  @override
  void didUpdateWidget(covariant AgentVisualizationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.gatewayStatus != oldWidget.gatewayStatus) {
      _syncFromGatewayStatus();
    }

    final gatewayChanged =
        oldWidget.gatewayService?.baseUrl != widget.gatewayService?.baseUrl ||
            oldWidget.gatewayService?.token != widget.gatewayService?.token;

    if (gatewayChanged) {
      unawaited(_refreshAgents());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _refreshAgents());
  }

  void _syncFromGatewayStatus() {
    if (widget.gatewayStatus?.agents != null &&
        widget.gatewayStatus!.agents!.isNotEmpty) {
      setState(() {
        _agents = widget.gatewayStatus!.agents!;
      });
    }
  }

  Future<void> _refreshAgents() async {
    if (widget.gatewayService == null) {
      _syncFromGatewayStatus();
      return;
    }

    try {
      final agentsResult = await widget.gatewayService!.getAgents();
      final stats = await widget.gatewayService!.getAgentStats();

      if (!mounted) return;
      setState(() {
        _agents = agentsResult?.isNotEmpty == true
            ? agentsResult!
            : (widget.gatewayStatus?.agents ?? []);
        _stats = stats;
      });
    } catch (_) {
      _syncFromGatewayStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayAgents =
        _agents.isNotEmpty ? _agents : (widget.gatewayStatus?.agents ?? []);
    final filteredAgents = _applyFilter(displayAgents);

    return widget.compact
        ? _buildCompactView(context, displayAgents)
        : _buildFullView(context, displayAgents, filteredAgents);
  }

  Widget _buildCompactView(BuildContext context, List<dynamic> agents) {
    final totalAgents = agents.length;
    final activeAgents = agents.where(_isAgentActive).length;
    final subagents = agents.where(_isSubagent).length;
    final toolsInFlight = agents.where((agent) {
      final tool = _toolName(agent);
      return tool != null && tool.isNotEmpty;
    }).length;
    final activeNames = agents
        .where(_isAgentActive)
        .take(3)
        .map(_agentName)
        .where((name) => name.isNotEmpty)
        .join(' • ');

    return Card(
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.bubble_chart_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agent Work Map',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          activeNames.isNotEmpty
                              ? activeNames
                              : 'No active sessions yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[600]),
                ],
              ),
              const SizedBox(height: 14),
              if (agents.isNotEmpty) ...[
                _buildAvatarStrip(context, agents),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Expanded(
                    child: _buildCompactStat(
                      context,
                      'Sessions',
                      '$totalAgents',
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildCompactStat(
                      context,
                      'Busy',
                      '$activeAgents',
                      activeAgents > 0 ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildCompactStat(
                      context,
                      'Subagents',
                      '$subagents',
                      subagents > 0 ? Colors.orange : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildCompactStat(
                      context,
                      'Tools',
                      '$toolsInFlight',
                      toolsInFlight > 0 ? Colors.deepPurple : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStat(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _buildFullView(
    BuildContext context,
    List<dynamic> agents,
    List<dynamic> filteredAgents,
  ) {
    final activeAgents = agents.where(_isAgentActive).length;
    final subagents = agents.where(_isSubagent).length;
    final toolsInFlight = agents.where((agent) {
      final tool = _toolName(agent);
      return tool != null && tool.isNotEmpty;
    }).length;
    final totalTokens = _stats?['totalTokens'] as int? ?? _sumTokens(agents);
    final workLanes = agents
        .where((agent) => _isAgentActive(agent) || _toolName(agent) != null)
        .toList()
      ..sort((a, b) {
        final aActive = _isAgentActive(a) ? 1 : 0;
        final bActive = _isAgentActive(b) ? 1 : 0;
        return bActive.compareTo(aActive);
      });

    return Card(
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_tree_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Agent Visualization',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          '${agents.length} sessions • $activeAgents active • $toolsInFlight tools in flight',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[600]),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSummaryChip(
                    context,
                    'Sessions ${agents.length}',
                    Colors.blue,
                  ),
                  _buildSummaryChip(
                    context,
                    'Active $activeAgents',
                    activeAgents > 0 ? Colors.green : Colors.grey,
                  ),
                  _buildSummaryChip(
                    context,
                    'Subagents $subagents',
                    subagents > 0 ? Colors.orange : Colors.grey,
                  ),
                  _buildSummaryChip(
                    context,
                    'Tokens ${_formatTokens(totalTokens)}',
                    totalTokens > 0 ? Colors.deepOrange : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (agents.isNotEmpty) ...[
                _buildAvatarStrip(context,
                    filteredAgents.isNotEmpty ? filteredAgents : agents),
                const SizedBox(height: 14),
              ],
              _buildFilterChips(),
              const SizedBox(height: 14),
              if (workLanes.isNotEmpty) ...[
                Text(
                  'Live lanes',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                ...workLanes.take(4).map(
                      (agent) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildLaneRow(context, agent),
                      ),
                    ),
                const SizedBox(height: 8),
              ],
              if (filteredAgents.isEmpty)
                _buildEmptyState(context)
              else
                ...filteredAgents.take(3).map(
                      (agent) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AgentCardWidget(
                          agent: agent,
                          compact: true,
                          onTap: widget.onTap,
                        ),
                      ),
                    ),
              if (filteredAgents.length > 3)
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    '+${filteredAgents.length - 3} more sessions',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _buildAvatarStrip(BuildContext context, List<dynamic> agents) {
    final previewAgents = agents.take(6).toList();
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: previewAgents.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final agent = previewAgents[index];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PixelAgentAvatar(
                seed: _agentName(agent),
                emoji: _agentEmoji(agent),
                model: _agentModel(agent),
                kind: _agentKind(agent),
                identityTheme: _identityTheme(agent),
                isActive: _isAgentActive(agent),
                isSubagent: _isSubagent(agent),
                status: _statusSummary(agent),
                size: 42,
                showEmojiBadge: true,
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 56,
                child: Text(
                  _agentName(agent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    const filters = [
      {'value': 'all', 'label': 'All'},
      {'value': 'active', 'label': 'Active'},
      {'value': 'main', 'label': 'Primary'},
      {'value': 'subagent', 'label': 'Subagents'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = _filter == filter['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter['label']!),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _filter = filter['value']!;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLaneRow(BuildContext context, dynamic agent) {
    final color = _isAgentActive(agent) ? Colors.green : Colors.blueGrey;
    final tool = _toolName(agent);
    final phase = _toolPhase(agent);
    final statusText = tool != null && tool.isNotEmpty
        ? phase != null && phase.isNotEmpty
            ? '$tool · $phase'
            : tool
        : _statusSummary(agent);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          PixelAgentAvatar(
            seed: _agentName(agent),
            emoji: _agentEmoji(agent),
            model: _agentModel(agent),
            kind: _agentKind(agent),
            identityTheme: _identityTheme(agent),
            isActive: _isAgentActive(agent),
            isSubagent: _isSubagent(agent),
            status: _statusSummary(agent),
            statusColor: color,
            size: 34,
            showEmojiBadge: true,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _agentName(agent),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (_isSubagent(agent))
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.call_split, size: 16, color: Colors.orange),
            ),
          Text(
            _formatTokens(_tokenCount(agent)),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, color: Colors.grey[600], size: 32),
          const SizedBox(width: 8),
          Text(
            'No sessions in this filter',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _applyFilter(List<dynamic> agents) {
    switch (_filter) {
      case 'active':
        return agents.where(_isAgentActive).toList();
      case 'main':
        return agents.where((agent) => !_isSubagent(agent)).toList();
      case 'subagent':
        return agents.where(_isSubagent).toList();
      default:
        return agents;
    }
  }

  bool _isAgentActive(dynamic agent) {
    if (agent is AgentSession) return agent.isActive;
    if (agent is AgentInfo) return agent.isActive || agent.status == 'active';
    return false;
  }

  bool _isSubagent(dynamic agent) {
    if (agent is AgentSession) return agent.isSubagent;
    return false;
  }

  String _agentName(dynamic agent) {
    if (agent is AgentSession) return agent.name;
    if (agent is AgentInfo) return agent.name;
    return 'Unknown';
  }

  String? _agentEmoji(dynamic agent) {
    if (agent is AgentSession) return agent.emoji;
    return null;
  }

  String? _agentModel(dynamic agent) {
    if (agent is AgentSession) return agent.model;
    if (agent is AgentInfo) return agent.model;
    return null;
  }

  String? _agentKind(dynamic agent) {
    if (agent is AgentSession) return agent.kind;
    return null;
  }

  String? _identityTheme(dynamic agent) {
    if (agent is AgentSession) return agent.identityTheme;
    return null;
  }

  String? _toolName(dynamic agent) {
    if (agent is AgentSession) return agent.currentToolName;
    return agent is AgentInfo ? agent.currentTask : null;
  }

  String? _toolPhase(dynamic agent) {
    if (agent is AgentSession) return agent.currentToolPhase;
    return null;
  }

  String _statusSummary(dynamic agent) {
    if (agent is AgentSession) return agent.statusDisplay;
    if (agent is AgentInfo) return agent.status;
    return 'Idle';
  }

  int _tokenCount(dynamic agent) {
    if (agent is AgentSession) return agent.totalTokens;
    if (agent is AgentInfo) return agent.totalTokens ?? 0;
    return 0;
  }

  int _sumTokens(List<dynamic> agents) {
    return agents.fold<int>(0, (sum, agent) => sum + _tokenCount(agent));
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    }
    if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    }
    return tokens.toString();
  }
}
