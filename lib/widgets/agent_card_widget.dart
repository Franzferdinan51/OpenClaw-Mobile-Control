/// Agent Card Widget
///
/// Individual agent status card inspired by agent-monitor-openclaw-dashboard
/// Shows agent status, model, current task, and token usage with visual flair

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/agent_session.dart';
import '../models/gateway_status.dart';

class AgentCardWidget extends StatelessWidget {
  final dynamic agent;
  final VoidCallback? onTap;
  final VoidCallback? onChatClick;
  final bool compact;

  const AgentCardWidget({
    super.key,
    required this.agent,
    this.onTap,
    this.onChatClick,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final data = _AgentCardData.fromDynamic(agent);
    final statusColor = _getStatusColor(data.status);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with avatar and status
              Row(
                children: [
                  // Pixel-art style avatar
                  _buildAgentAvatar(data.name, data.emoji, statusColor),
                  const SizedBox(width: 12),
                  // Agent info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Status badge
                            _buildStatusBadge(
                              data.isActive,
                              statusColor,
                              _formatStatusLabel(data.status, data.isActive),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Model badge
                        _buildModelBadge(data.model),
                        if (data.hasMetadataChips) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (data.isSubagent)
                                _buildMetadataChip(
                                  'Subagent',
                                  Colors.orange,
                                ),
                              if (data.sessionKind != null &&
                                  data.sessionKind!.isNotEmpty &&
                                  data.sessionKind != 'unknown')
                                _buildMetadataChip(
                                  data.sessionKind!,
                                  Colors.blueGrey,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Current task
              if (data.task.isNotEmpty && data.task != 'Idle') ...[
                Row(
                  children: [
                    Icon(
                      Icons.task_alt,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data.task,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[700],
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              if (data.currentToolName != null &&
                  data.currentToolName!.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.build_circle_outlined,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data.currentToolPhase != null &&
                                data.currentToolPhase!.isNotEmpty
                            ? '${data.currentToolName} · ${data.currentToolPhase}'
                            : data.currentToolName!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              if (data.lastActivity != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Last activity ${_formatRelativeTime(data.lastActivity!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[700],
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Token usage bar
              if (data.tokens > 0) _buildTokenBar(context, data.tokens),

              // Action buttons
              if (!compact && onChatClick != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onChatClick,
                        icon: const Icon(Icons.chat, size: 16),
                        label: const Text('Chat'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentAvatar(String name, String emoji, Color statusColor) {
    // Generate a deterministic color based on agent name
    final hash = name.hashCode;
    final hue = (hash % 360).toDouble();
    final avatarColor = HSLColor.fromAHSL(1.0, hue, 0.7, 0.6).toColor();

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: avatarColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: avatarColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Pixel-art style emoji/icon
          Center(
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          // Status indicator
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.4),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive, Color statusColor, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildModelBadge(String model) {
    final shortModel = _shortenModel(model);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        shortModel,
        style: TextStyle(
          fontSize: 9,
          color: Colors.purple[700],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTokenBar(BuildContext context, int tokens) {
    // Assume max tokens context window (e.g., 128K for most models)
    const maxTokens = 128000;
    final pct = math.min(100.0, (tokens / maxTokens) * 100);

    Color barColor;
    if (pct < 50) {
      barColor = Colors.green;
    } else if (pct < 80) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.red;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.token_outlined,
                  size: 12,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Tokens',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            Text(
              _formatTokens(tokens),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: barColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  String _formatStatusLabel(String status, bool isActive) {
    switch (status.toLowerCase()) {
      case 'busy':
      case 'working':
      case 'running':
        return 'Busy';
      case 'error':
      case 'failed':
      case 'aborted':
        return 'Error';
      case 'idle':
      case 'waiting':
        return 'Idle';
      case 'active':
        return 'Active';
      default:
        return isActive ? 'Active' : 'Idle';
    }
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _shortenModel(String model) {
    if (model.contains('/')) {
      final parts = model.split('/');
      return parts.last;
    }
    if (model.length > 15) {
      return '${model.substring(0, 12)}...';
    }
    return model;
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(0)}K';
    }
    return tokens.toString();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'running':
      case 'working':
        return Colors.green;
      case 'idle':
      case 'waiting':
        return Colors.orange;
      case 'error':
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _AgentCardData {
  final String name;
  final String emoji;
  final String status;
  final String model;
  final String task;
  final int tokens;
  final bool isActive;
  final bool isSubagent;
  final String? sessionKind;
  final String? currentToolName;
  final String? currentToolPhase;
  final DateTime? lastActivity;

  const _AgentCardData({
    required this.name,
    required this.emoji,
    required this.status,
    required this.model,
    required this.task,
    required this.tokens,
    required this.isActive,
    required this.isSubagent,
    this.sessionKind,
    this.currentToolName,
    this.currentToolPhase,
    this.lastActivity,
  });

  bool get hasMetadataChips =>
      isSubagent ||
      (sessionKind != null &&
          sessionKind!.isNotEmpty &&
          sessionKind != 'unknown');

  factory _AgentCardData.fromDynamic(dynamic agent) {
    if (agent is AgentSession) {
      final status = agent.aborted
          ? 'aborted'
          : agent.agentStatus ?? (agent.isActive ? 'active' : 'idle');
      final task = agent.statusSummary ?? agent.currentToolName ?? 'Idle';
      return _AgentCardData(
        name: agent.name,
        emoji: agent.emoji ?? _fallbackEmoji(agent.name),
        status: status,
        model: agent.model,
        task: task,
        tokens: agent.totalTokens,
        isActive: agent.isActive,
        isSubagent: agent.isSubagent,
        sessionKind: agent.kind,
        currentToolName: agent.currentToolName,
        currentToolPhase: agent.currentToolPhase,
        lastActivity: agent.lastActivity ?? agent.updatedAt,
      );
    }

    if (agent is AgentInfo) {
      return _AgentCardData(
        name: agent.name,
        emoji: _fallbackEmoji(agent.name),
        status: agent.status,
        model: agent.model ?? 'unknown',
        task: agent.currentTask ?? 'Idle',
        tokens: agent.totalTokens ?? 0,
        isActive: agent.isActive,
        isSubagent: false,
        lastActivity: null,
      );
    }

    if (agent is Map<String, dynamic>) {
      final name =
          (agent['name'] ?? agent['agentName'] ?? 'Unknown Agent').toString();
      return _AgentCardData(
        name: name,
        emoji: (agent['emoji'] ?? _fallbackEmoji(name)).toString(),
        status: (agent['status'] ?? 'unknown').toString(),
        model: (agent['model'] ?? 'unknown').toString(),
        task: (agent['currentTask'] ??
                agent['current_task'] ??
                agent['statusSummary'] ??
                'Idle')
            .toString(),
        tokens: _asInt(agent['totalTokens'] ?? agent['total_tokens']),
        isActive: agent['isActive'] == true ||
            agent['status'] == 'active' ||
            agent['status'] == 'busy',
        isSubagent: agent['isSubagent'] == true,
        sessionKind: agent['kind']?.toString(),
        currentToolName: agent['currentToolName']?.toString(),
        currentToolPhase: agent['currentToolPhase']?.toString(),
        lastActivity: _asDateTime(agent['lastActivity'] ?? agent['updatedAt']),
      );
    }

    final name = 'Unknown Agent';
    return _AgentCardData(
      name: name,
      emoji: _fallbackEmoji(name),
      status: 'unknown',
      model: 'unknown',
      task: 'Idle',
      tokens: 0,
      isActive: false,
      isSubagent: false,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _fallbackEmoji(String name) {
    final emojis = ['🤖', '🦆', '🐙', '🦊', '🐱', '🐶', '🦉', '🐼', '🦁', '🐸'];
    final index = name.hashCode.abs() % emojis.length;
    return emojis[index];
  }
}
