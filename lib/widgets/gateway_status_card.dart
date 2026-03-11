import 'package:flutter/material.dart';
import '../models/gateway_status.dart';

class GatewayStatusCard extends StatelessWidget {
  final GatewayStatus? status;
  final Map<String, dynamic>? liveStats;
  final DateTime? lastRefresh;
  final VoidCallback? onRefresh;

  const GatewayStatusCard({
    super.key,
    this.status,
    this.liveStats,
    this.lastRefresh,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return _buildUnavailableCard(context);
    }

    final totalAgents =
        (liveStats?['totalAgents'] as int?) ?? status!.agents?.length ?? 0;
    final activeAgents = (liveStats?['activeAgents'] as int?) ??
        status!.agents
            ?.where((agent) => agent.isActive || agent.status == 'active')
            .length ??
        0;
    final totalTokens = (liveStats?['totalTokens'] as int?) ?? 0;
    final nodeCount = status!.nodes?.length ?? 0;

    return Card(
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
                    color: status!.online
                        ? Colors.green.withValues(alpha: 0.10)
                        : Colors.red.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    status!.online ? Icons.wifi_tethering : Icons.wifi_off,
                    color: status!.online ? Colors.green : Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gateway Pulse',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        status!.isPaused
                            ? 'Connected, but work is paused'
                            : status!.online
                                ? 'Live session topology'
                                : 'Gateway is not responding',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: status!.online
                                  ? Colors.grey[700]
                                  : Colors.red.shade700,
                            ),
                      ),
                    ],
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: 'Sessions',
                    value: '$totalAgents',
                    subtitle: '$activeAgents active',
                    icon: Icons.people_alt_outlined,
                    color: activeAgents > 0 ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: 'Nodes',
                    value: '$nodeCount',
                    subtitle: nodeCount > 0 ? 'connected' : 'waiting',
                    icon: Icons.hub_outlined,
                    color: nodeCount > 0 ? Colors.blue : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: 'Traffic',
                    value:
                        totalTokens > 0 ? _formatTokens(totalTokens) : 'Idle',
                    subtitle: totalTokens > 0 ? 'token flow' : 'no token data',
                    icon: Icons.local_fire_department_outlined,
                    color: totalTokens > 0 ? Colors.deepOrange : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: 'Mode',
                    value: status!.isPaused ? 'Paused' : 'Live',
                    subtitle:
                        status!.online ? 'ready for chat/tools' : 'offline',
                    icon: status!.isPaused
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    color: status!.isPaused ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
            if (lastRefresh != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Updated ${_getTimeAgo(lastRefresh!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailableCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off,
              size: 44,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 12),
            Text(
              'Gateway Pulse Unavailable',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect a local or remote OpenClaw gateway to see live work.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                ),
          ),
        ],
      ),
    );
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return tokens.toString();
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
