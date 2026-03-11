import 'package:flutter/material.dart';
import '../models/agent_session.dart';
import 'pixel_agent_avatar.dart';

/// Mobile-optimized agent card for dashboard
///
/// Features:
/// - Compact card layout for vertical scrolling
/// - Animated token bar with color thresholds
/// - Status badge with behavior icons
/// - Quick actions via long-press
/// - Swipe gestures for chat/restart
class AgentCardMobile extends StatefulWidget {
  final AgentSession agent;
  final VoidCallback? onTap;
  final VoidCallback? onChat;
  final VoidCallback? onRestart;
  final Function(String name, String emoji, String color)? onUpdate;

  const AgentCardMobile({
    super.key,
    required this.agent,
    this.onTap,
    this.onChat,
    this.onRestart,
    this.onUpdate,
  });

  @override
  State<AgentCardMobile> createState() => _AgentCardMobileState();
}

class _AgentCardMobileState extends State<AgentCardMobile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _getBehaviorColor().withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: _showQuickActions,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 12),
                _buildInfoSection(context),
                const SizedBox(height: 12),
                _buildTokenBar(context),
                if (_expanded) ...[
                  const SizedBox(height: 12),
                  _buildExpandedInfo(context),
                ],
                const SizedBox(height: 8),
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // Avatar
        _buildAvatar(),
        const SizedBox(width: 12),
        // Name and status
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.agent.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.agent.emoji != null) ...[
                    const SizedBox(width: 4),
                    Text(widget.agent.emoji!,
                        style: const TextStyle(fontSize: 16)),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              StatusBadge(behavior: _getBehavior()),
            ],
          ),
        ),
        // Badges
        if (widget.agent.isSubagent)
          _buildBadge('SUB', Colors.purple)
        else if (widget.agent.subagentIds?.isNotEmpty == true)
          _buildBadge('+${widget.agent.subagentIds!.length}', Colors.teal),
      ],
    );
  }

  Widget _buildAvatar() {
    final color = _getBehaviorColor();
    return PixelAgentAvatar(
      seed: widget.agent.name,
      emoji: widget.agent.emoji,
      model: widget.agent.model,
      kind: widget.agent.kind,
      identityTheme: widget.agent.identityTheme,
      isActive: widget.agent.isActive,
      isSubagent: widget.agent.isSubagent,
      status: widget.agent.agentStatus ?? widget.agent.statusSummary,
      statusColor: color,
      size: 48,
      showEmojiBadge: true,
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Model info
        Text(
          widget.agent.model,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[400],
              ),
        ),
        // Current tool (if active)
        if (widget.agent.currentToolName != null &&
            widget.agent.currentToolName!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.build, size: 12, color: Colors.orange[400]),
              const SizedBox(width: 4),
              Text(
                widget.agent.currentToolName!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange[400],
                ),
              ),
              if (widget.agent.currentToolPhase != null)
                Text(
                  ' (${widget.agent.currentToolPhase})',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange[300],
                  ),
                ),
            ],
          ),
        ],
        // Status summary
        if (widget.agent.statusSummary != null &&
            widget.agent.statusSummary!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.agent.statusSummary!,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildTokenBar(BuildContext context) {
    if (!widget.agent.usageKnown) {
      return Text(
        'Tokens not reported',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
      );
    }

    final usage = widget.agent.totalTokens;
    final limit =
        widget.agent.contextTokens > 0 ? widget.agent.contextTokens : 128000;
    final percentage = (usage / limit * 100).clamp(0.0, 100.0);
    final color = _getTokenColor(percentage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Tokens',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                  ),
            ),
            const Spacer(),
            Text(
              _formatTokens(usage),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              ' / ${_formatTokens(limit)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Session Key', widget.agent.key),
          _buildDetailRow('Channel', widget.agent.channel),
          _buildDetailRow('Kind', widget.agent.kind),
          if (widget.agent.label != null)
            _buildDetailRow('Label', widget.agent.label!),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildUsageItem('Input', widget.agent.inputTokens, Colors.blue),
              _buildUsageItem(
                  'Output', widget.agent.outputTokens, Colors.orange),
              _buildUsageItem(
                  'Context', widget.agent.contextTokens, Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageItem(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          _formatTokens(value),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Last activity
        Text(
          'Last: ${_formatRelativeTime(widget.agent.lastActivity)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
              ),
        ),
        // Action buttons
        Row(
          children: [
            if (widget.onRestart != null)
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: widget.onRestart,
                tooltip: 'Restart agent',
                color: Colors.grey[400],
              ),
            if (widget.onChat != null)
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                onPressed: widget.onChat,
                tooltip: 'Chat with agent',
                color: const Color(0xFF00D4AA),
              ),
            IconButton(
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
              ),
              onPressed: () {
                setState(() => _expanded = !_expanded);
              },
              color: Colors.grey[400],
            ),
          ],
        ),
      ],
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4AA).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat, color: Color(0xFF00D4AA)),
                ),
                title: const Text('Chat'),
                subtitle: Text('Send message to ${widget.agent.name}'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onChat?.call();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.refresh, color: Colors.orange),
                ),
                title: const Text('Restart'),
                subtitle: const Text('Reset session'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onRestart?.call();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit, color: Colors.blue),
                ),
                title: const Text('Edit'),
                subtitle: const Text('Customize agent'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog() {
    // TODO: Implement edit dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit feature coming soon!')),
    );
  }

  String _getBehavior() {
    // Map status to behavior
    if (widget.agent.isActive) {
      if (widget.agent.currentToolName != null) return 'working';
      return 'thinking';
    }
    if (widget.agent.aborted) return 'dead';
    return 'idle';
  }

  Color _getBehaviorColor() {
    final behavior = _getBehavior();
    switch (behavior) {
      case 'working':
      case 'thinking':
        return Colors.green;
      case 'dead':
      case 'panicking':
        return Colors.red;
      case 'idle':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Color _getTokenColor(double percentage) {
    if (percentage > 80) return Colors.red;
    if (percentage > 50) return Colors.orange;
    return Colors.green;
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    }
    return tokens.toString();
  }

  String _formatRelativeTime(DateTime? time) {
    if (time == null) return 'unknown';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Status badge widget for agent cards
class StatusBadge extends StatelessWidget {
  final String behavior;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.behavior,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = _getBehaviorStyle(behavior);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(compact ? 4 : 6),
        border: Border.all(
          color: style.color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            style.icon,
            style: TextStyle(fontSize: compact ? 10 : 12),
          ),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text(
              style.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: style.color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  _BehaviorStyle _getBehaviorStyle(String behavior) {
    switch (behavior) {
      case 'working':
        return _BehaviorStyle('⚡', 'Working', Colors.green);
      case 'thinking':
        return _BehaviorStyle('🧠', 'Thinking', Colors.blue);
      case 'researching':
        return _BehaviorStyle('🔍', 'Researching', Colors.indigo);
      case 'meeting':
        return _BehaviorStyle('👥', 'Meeting', Colors.purple);
      case 'deploying':
        return _BehaviorStyle('🚀', 'Deploying', Colors.teal);
      case 'debugging':
        return _BehaviorStyle('🐛', 'Debugging', Colors.orange);
      case 'idle':
        return _BehaviorStyle('💤', 'Idle', Colors.grey);
      case 'coffee':
        return _BehaviorStyle('☕', 'Coffee', Colors.brown);
      case 'panicking':
        return _BehaviorStyle('😱', 'Panicking', Colors.red);
      case 'dead':
        return _BehaviorStyle('💀', 'Dead', Colors.red);
      default:
        return _BehaviorStyle('❓', behavior, Colors.grey);
    }
  }
}

class _BehaviorStyle {
  final String icon;
  final String label;
  final Color color;

  _BehaviorStyle(this.icon, this.label, this.color);
}
