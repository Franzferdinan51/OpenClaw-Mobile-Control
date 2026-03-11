/// Agent Visualization Widget
/// 
/// Provides a visually rich display of agent activity and status
/// for the dashboard and agent monitor screens.

import 'package:flutter/material.dart';
import 'dart:async';
import '../models/gateway_status.dart';
import '../services/gateway_service.dart';

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
  State<AgentVisualizationWidget> createState() => _AgentVisualizationWidgetState();
}

class _AgentVisualizationWidgetState extends State<AgentVisualizationWidget> {
  List<dynamic> _agents = [];
  Map<String, dynamic>? _stats;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshAgents();
    _startAutoRefresh();
  }

  @override
  void didUpdateWidget(AgentVisualizationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh if gateway status changed
    if (widget.gatewayStatus != oldWidget.gatewayStatus) {
      _updateFromGatewayStatus();
    }
  }

  void _updateFromGatewayStatus() {
    if (widget.gatewayStatus != null && widget.gatewayStatus!.agents != null) {
      setState(() {
        _agents = widget.gatewayStatus!.agents!;
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshAgents());
  }

  Future<void> _refreshAgents() async {
    if (widget.gatewayService == null) return;

    try {
      final agentsResult = await widget.gatewayService!.getAgents();
      final stats = await widget.gatewayService!.getAgentStats();

      if (mounted) {
        setState(() {
          _agents = agentsResult ?? [];
          _stats = stats;
        });
      }
    } catch (e) {
      // Silently fail - we'll use gateway status data if available
      if (mounted) {
        setState(() {
          // Keep existing data or use empty list
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use gateway status data if we don't have live agent data
    final displayAgents = _agents.isNotEmpty ? _agents : (widget.gatewayStatus?.agents ?? []);
    final displayStats = _stats ?? {};

    if (widget.compact) {
      return _buildCompactView(displayAgents, displayStats);
    }

    return _buildFullView(displayAgents, displayStats);
  }

  Widget _buildCompactView(List<dynamic> agents, Map<String, dynamic> stats) {
    final totalAgents = agents.length;
    final activeAgents = agents.where((a) {
      final isActive = a.isActive ?? false;
      final status = a.status ?? 'unknown';
      return isActive || status == 'active';
    }).length;

    return Card(
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Agent icon with count badge
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.people,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  if (totalAgents > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: activeAgents > 0 ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$totalAgents',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agents',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildCompactStat(
                          'Active',
                          '$activeAgents',
                          activeAgents > 0 ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        if (stats['totalTokens'] != null)
                          _buildCompactStat(
                            'Tokens',
                            _formatTokens(stats['totalTokens']),
                            Colors.blue,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStat(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $value',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFullView(List<dynamic> agents, Map<String, dynamic> stats) {
    return Card(
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.people,
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
                          'Agent Activity',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${agents.length} agents • ${_formatStats(stats)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[600],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Agent list
              if (agents.isEmpty)
                _buildEmptyState()
              else
                ...agents.take(3).map((agent) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildAgentRow(agent),
                )),
              
              // Show more indicator
              if (agents.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '+${agents.length - 3} more agents',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_downward,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
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

  String _formatStats(Map<String, dynamic> stats) {
    final tokens = stats['totalTokens'] ?? 0;
    if (tokens > 0) {
      return '${_formatTokens(tokens)} tokens';
    }
    return 'Monitoring...';
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            color: Colors.grey[600],
            size: 32,
          ),
          const SizedBox(width: 8),
          Text(
            'No active agents',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentRow(dynamic agent) {
    final isActive = (agent.isActive ?? false) || (agent.status ?? 'unknown') == 'active';
    final statusColor = isActive ? Colors.green : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100]!,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Agent info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent.name ?? 'Unknown',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (agent.currentTask != null && (agent.currentTask as String).isNotEmpty)
                  Text(
                    agent.currentTask!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Model badge
          if (agent.model != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _shortenModel(agent.model!),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.purple[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _shortenModel(String model) {
    // Shorten long model names
    if (model.contains('/')) {
      final parts = model.split('/');
      return parts.last;
    }
    if (model.length > 20) {
      return '${model.substring(0, 17)}...';
    }
    return model;
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    }
    return tokens.toString();
  }
}
