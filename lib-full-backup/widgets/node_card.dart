import 'package:flutter/material.dart';
import 'status_indicator.dart';

/// Represents a node's state and metadata
class NodeData {
  final String id;
  final String name;
  final String? hostname;
  final String? ipAddress;
  final StatusType status;
  final String? os;
  final double? cpuUsage;
  final double? memoryUsage;
  final double? diskUsage;
  final int? uptimeSeconds;
  final DateTime? lastSeen;
  final bool isPrimary;
  final String? nodeType;
  final List<String>? services;

  const NodeData({
    required this.id,
    required this.name,
    this.hostname,
    this.ipAddress,
    this.status = StatusType.unknown,
    this.os,
    this.cpuUsage,
    this.memoryUsage,
    this.diskUsage,
    this.uptimeSeconds,
    this.lastSeen,
    this.isPrimary = false,
    this.nodeType,
    this.services,
  });

  String get displayAddress => hostname ?? ipAddress ?? 'Unknown';
  
  String get uptimeFormatted {
    if (uptimeSeconds == null) return 'Unknown';
    final hours = uptimeSeconds! ~/ 3600;
    final days = hours ~/ 24;
    if (days > 0) return '${days}d ${hours % 24}h';
    return '${hours}h';
  }
}

/// A Material 3 card widget for displaying node/server information.
/// 
/// Shows node status, resource usage, uptime, and quick actions.
/// 
/// Usage:
/// ```dart
/// NodeCard(
///   node: NodeData(
///     id: 'node-1',
///     name: 'Main Server',
///     status: StatusType.online,
///     cpuUsage: 45.2,
///     memoryUsage: 62.8,
///   ),
///   onTap: () => _showNodeDetails(node),
/// )
/// ```
class NodeCard extends StatelessWidget {
  /// The node data to display
  final NodeData node;
  
  /// Callback when card is tapped
  final VoidCallback? onTap;
  
  /// Callback when terminal action is pressed
  final VoidCallback? onTerminal;
  
  /// Callback when restart action is pressed
  final VoidCallback? onRestart;
  
  /// Callback when shutdown action is pressed
  final VoidCallback? onShutdown;
  
  /// Whether to show compact view
  final bool compact;
  
  /// Whether to show resource gauges
  final bool showResources;
  
  /// Whether to show services list
  final bool showServices;

  const NodeCard({
    super.key,
    required this.node,
    this.onTap,
    this.onTerminal,
    this.onRestart,
    this.onShutdown,
    this.compact = false,
    this.showResources = true,
    this.showServices = true,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _buildNodeIcon(theme, 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (node.isPrimary)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.star,
                              size: 14,
                              color: colorScheme.primary,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            node.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      node.displayAddress,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StatusIndicator(status: node.status, size: 10),
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
                  _buildNodeIcon(theme, 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (node.isPrimary)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.star,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                node.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            StatusIndicator(status: node.status),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          node.displayAddress,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (node.os != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            node.os!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (showResources && _hasResourceData()) ...[
                const SizedBox(height: 16),
                _buildResourceSection(context, theme, colorScheme),
              ],
              if (node.uptimeSeconds != null) ...[
                const SizedBox(height: 12),
                _buildUptimeRow(context, theme),
              ],
              if (showServices && node.services?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                _buildServicesSection(context, theme, colorScheme),
              ],
              if (onTerminal != null || onRestart != null || onShutdown != null) ...[
                const SizedBox(height: 12),
                _buildActionButtons(context, colorScheme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNodeIcon(ThemeData theme, double size) {
    final icon = _getNodeIcon();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primaryContainer,
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }

  IconData _getNodeIcon() {
    switch (node.nodeType?.toLowerCase()) {
      case 'desktop':
      case 'workstation':
        return Icons.computer;
      case 'server':
        return Icons.dns;
      case 'laptop':
        return Icons.laptop;
      case 'mobile':
      case 'phone':
        return Icons.phone_android;
      case 'iot':
      case 'embedded':
        return Icons.developer_board;
      case 'vm':
      case 'virtual':
        return Icons.cloud_queue;
      default:
        return Icons.devices;
    }
  }

  bool _hasResourceData() {
    return node.cpuUsage != null ||
        node.memoryUsage != null ||
        node.diskUsage != null;
  }

  Widget _buildResourceSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resources',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (node.cpuUsage != null)
              Expanded(
                child: _ResourceGauge(
                  label: 'CPU',
                  value: node.cpuUsage!,
                  color: _getResourceColor(node.cpuUsage!),
                ),
              ),
            if (node.cpuUsage != null && node.memoryUsage != null)
              const SizedBox(width: 12),
            if (node.memoryUsage != null)
              Expanded(
                child: _ResourceGauge(
                  label: 'Memory',
                  value: node.memoryUsage!,
                  color: _getResourceColor(node.memoryUsage!),
                ),
              ),
            if ((node.cpuUsage != null || node.memoryUsage != null) &&
                node.diskUsage != null)
              const SizedBox(width: 12),
            if (node.diskUsage != null)
              Expanded(
                child: _ResourceGauge(
                  label: 'Disk',
                  value: node.diskUsage!,
                  color: _getResourceColor(node.diskUsage!),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _getResourceColor(double value) {
    if (value < 50) return Colors.green;
    if (value < 75) return Colors.orange;
    return Colors.red;
  }

  Widget _buildUptimeRow(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.schedule,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          'Uptime: ${node.uptimeFormatted}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildServicesSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Services',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: node.services!.take(5).map((service) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                service,
                style: theme.textTheme.labelSmall,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (onTerminal != null)
          TextButton.icon(
            onPressed: onTerminal,
            icon: const Icon(Icons.terminal, size: 18),
            label: const Text('Terminal'),
          ),
        if (onRestart != null)
          TextButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Restart'),
          ),
        if (onShutdown != null)
          TextButton.icon(
            onPressed: onShutdown,
            icon: Icon(Icons.power_settings_new, size: 18, color: colorScheme.error),
            label: Text('Shutdown', style: TextStyle(color: colorScheme.error)),
          ),
      ],
    );
  }
}

/// A circular progress gauge for resource display
class _ResourceGauge extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ResourceGauge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            value: value / 100,
            strokeWidth: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          '${value.toStringAsFixed(1)}%',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}