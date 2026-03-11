/// Enhanced Gateway Status Card
///
/// Displays gateway overview metrics with improved accuracy and visual design.
/// Shows version, uptime, and topology counts without duplicating home health data.

import 'package:flutter/material.dart';
import '../models/gateway_status.dart';

class GatewayStatusCard extends StatelessWidget {
  final GatewayStatus? status;
  final DateTime? lastRefresh;
  final VoidCallback? onRefresh;

  const GatewayStatusCard({
    super.key,
    this.status,
    this.lastRefresh,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return _buildUnavailableCard(context);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.dns,
                  color: status!.online ? Colors.green : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gateway',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        status!.online ? 'Online' : 'Offline',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: status!.online ? Colors.green : Colors.red,
                            ),
                      ),
                    ],
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: onRefresh,
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Version and Uptime
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Version',
                    status!.version == 'unknown' ? 'N/A' : status!.version,
                    Icons.tag,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Uptime',
                    status!.formattedUptime,
                    Icons.timer,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Agent and node counts
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Agents',
                    '${status!.agents?.length ?? 0}',
                    Icons.smart_toy_outlined,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Nodes',
                    '${status!.nodes?.length ?? 0}',
                    Icons.devices_outlined,
                    Colors.teal,
                  ),
                ),
              ],
            ),

            // Last updated
            if (lastRefresh != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Updated ${_getTimeAgo(lastRefresh!)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
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
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Gateway Status Unavailable',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to a gateway to see status',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
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
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
