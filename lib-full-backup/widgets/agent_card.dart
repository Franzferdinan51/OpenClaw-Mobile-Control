import 'package:flutter/material.dart';
import 'status_indicator.dart';

/// Represents an agent's state and metadata
class AgentData {
  final String id;
  final String name;
  final String? description;
  final StatusType status;
  final String? model;
  final String? provider;
  final int? contextSize;
  final int? messagesCount;
  final DateTime? lastActive;
  final String? avatarUrl;
  final bool isFavorite;
  final List<String>? capabilities;

  const AgentData({
    required this.id,
    required this.name,
    this.description,
    this.status = StatusType.unknown,
    this.model,
    this.provider,
    this.contextSize,
    this.messagesCount,
    this.lastActive,
    this.avatarUrl,
    this.isFavorite = false,
    this.capabilities,
  });
}

/// A Material 3 card widget for displaying agent information.
/// 
/// Shows agent status, name, model, provider, and quick actions.
/// 
/// Usage:
/// ```dart
/// AgentCard(
///   agent: AgentData(
///     id: 'agent-1',
///     name: 'DuckBot',
///     status: StatusType.online,
///     model: 'bailian/qwen3.5-plus',
///   ),
///   onTap: () => _showAgentDetails(agent),
/// )
/// ```
class AgentCard extends StatelessWidget {
  /// The agent data to display
  final AgentData agent;
  
  /// Callback when card is tapped
  final VoidCallback? onTap;
  
  /// Callback when favorite button is pressed
  final VoidCallback? onFavoriteToggle;
  
  /// Callback when chat action is pressed
  final VoidCallback? onChat;
  
  /// Whether to show compact view
  final bool compact;
  
  /// Whether to show status indicator
  final bool showStatus;
  
  /// Whether to show model info
  final bool showModel;

  const AgentCard({
    super.key,
    required this.agent,
    this.onTap,
    this.onFavoriteToggle,
    this.onChat,
    this.compact = false,
    this.showStatus = true,
    this.showModel = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (compact) {
      return _buildCompactCard(context, theme, colorScheme);
    }
    
    return _buildFullCard(context, theme, colorScheme);
  }

  Widget _buildCompactCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _buildAvatar(theme, 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      agent.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showModel && agent.model != null)
                      Text(
                        _formatModel(agent.model!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (showStatus)
                StatusIndicator(status: agent.status, size: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullCard(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildAvatar(theme, 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                agent.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (showStatus)
                              StatusIndicator(status: agent.status),
                          ],
                        ),
                        if (agent.description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            agent.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  _buildFavoriteButton(colorScheme),
                ],
              ),
              if (showModel && agent.model != null) ...[
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  icon: Icons.psychology_outlined,
                  label: 'Model',
                  value: agent.model!,
                ),
              ],
              if (agent.provider != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  context,
                  icon: Icons.cloud_outlined,
                  label: 'Provider',
                  value: agent.provider!,
                ),
              ],
              if (agent.contextSize != null || agent.messagesCount != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (agent.contextSize != null)
                      Expanded(
                        child: _buildStatChip(
                          context,
                          icon: Icons.memory_outlined,
                          value: '${agent.contextSize}k',
                          label: 'Context',
                        ),
                      ),
                    if (agent.contextSize != null && agent.messagesCount != null)
                      const SizedBox(width: 8),
                    if (agent.messagesCount != null)
                      Expanded(
                        child: _buildStatChip(
                          context,
                          icon: Icons.chat_bubble_outline,
                          value: '${agent.messagesCount}',
                          label: 'Messages',
                        ),
                      ),
                  ],
                ),
              ],
              if (agent.capabilities?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: agent.capabilities!.take(4).map((cap) {
                    return _buildCapabilityChip(context, cap);
                  }).toList(),
                ),
              ],
              if (onChat != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: onChat,
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('Chat'),
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

  Widget _buildAvatar(ThemeData theme, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primaryContainer,
      ),
      child: agent.avatarUrl != null
          ? ClipOval(
              child: Image.network(
                agent.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildDefaultIcon(theme, size),
              ),
            )
          : _buildDefaultIcon(theme, size),
    );
  }

  Widget _buildDefaultIcon(ThemeData theme, double size) {
    return Icon(
      Icons.smart_toy_outlined,
      size: size * 0.5,
      color: theme.colorScheme.onPrimaryContainer,
    );
  }

  Widget _buildFavoriteButton(ColorScheme colorScheme) {
    return IconButton(
      onPressed: onFavoriteToggle,
      icon: Icon(
        agent.isFavorite ? Icons.star : Icons.star_outline,
        color: agent.isFavorite ? colorScheme.primary : null,
      ),
      tooltip: agent.isFavorite ? 'Remove from favorites' : 'Add to favorites',
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilityChip(BuildContext context, String capability) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        capability,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  String _formatModel(String model) {
    // Simplify model name for display
    final parts = model.split('/');
    if (parts.length > 1) {
      return parts.last;
    }
    return model;
  }
}