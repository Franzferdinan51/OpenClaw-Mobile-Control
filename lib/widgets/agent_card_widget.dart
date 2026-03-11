/// Agent Card Widget
/// 
/// Individual agent status card inspired by agent-monitor-openclaw-dashboard
/// Shows agent status, model, current task, and token usage with visual flair

import 'package:flutter/material.dart';
import 'dart:math' as math;

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
    final isActive = (agent.isActive ?? false) || (agent.status ?? 'unknown') == 'active';
    final statusColor = _getStatusColor(agent.status ?? 'unknown');
    final model = agent.model ?? 'unknown';
    final task = agent.currentTask ?? agent.current_task ?? 'Idle';
    final tokens = agent.totalTokens ?? agent.total_tokens ?? 0;

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
                  _buildAgentAvatar(agent.name ?? 'Unknown', statusColor),
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
                                agent.name ?? 'Unknown Agent',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Status badge
                            _buildStatusBadge(isActive, statusColor),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Model badge
                        _buildModelBadge(model),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Current task
              if (task.isNotEmpty && task != 'Idle') ...[
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
                        task,
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
              
              // Token usage bar
              if (tokens > 0)
                _buildTokenBar(context, tokens),
              
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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

  Widget _buildAgentAvatar(String name, Color statusColor) {
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
              _getAgentEmoji(name),
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

  Widget _buildStatusBadge(bool isActive, Color statusColor) {
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
            isActive ? 'Active' : 'Idle',
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

  String _getAgentEmoji(String name) {
    // Deterministic emoji selection based on name hash
    final emojis = ['🤖', '🦆', '🐙', '🦊', '🐱', '🐶', '🦉', '🐼', '🦁', '🐸'];
    final index = name.hashCode.abs() % emojis.length;
    return emojis[index];
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
