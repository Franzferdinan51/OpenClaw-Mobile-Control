/// Enhanced Gateway Status Card
/// 
/// Displays gateway health metrics with improved accuracy and visual design.
/// Shows version, uptime, CPU, memory with proper handling of unavailable data.

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
            
            // CPU Usage
            _buildProgressBar(
              context,
              'CPU Usage',
              status!.cpuPercent,
              status!.cpuPercent != null ? '${status!.cpuPercent!.toStringAsFixed(1)}%' : 'Unavailable',
              Colors.green,
              Colors.orange,
              Colors.red,
              icon: Icons.memory,
            ),
            const SizedBox(height: 12),
            
            // Memory Usage
            _buildProgressBar(
              context,
              'Memory',
              status!.memoryPercent,
              status!.formattedMemory ?? 'Unavailable',
              Colors.green,
              Colors.orange,
              Colors.red,
              icon: Icons.storage,
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

  Widget _buildProgressBar(
    BuildContext context,
    String label,
    double? percent,
    String detail,
    Color goodColor,
    Color warnColor,
    Color errorColor,
    {IconData? icon}
  ) {
    final hasData = percent != null;
    final clampedPercent = hasData ? percent!.clamp(0.0, 100.0) : 0.0;
    
    Color barColor;
    if (!hasData) {
      barColor = Colors.grey;
    } else if (clampedPercent < 70) {
      barColor = goodColor;
    } else if (clampedPercent < 90) {
      barColor = warnColor;
    } else {
      barColor = errorColor;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: Colors.grey[700]),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              detail,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: barColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: hasData ? clampedPercent / 100 : 0,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 8,
          ),
        ),
        if (!hasData) ...[
          const SizedBox(height: 8),
          Text(
            'This gateway does not expose live metrics',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
