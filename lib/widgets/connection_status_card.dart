import 'package:flutter/material.dart';
import '../services/connection_monitor_service.dart';

/// Connection status card for dashboard
class ConnectionStatusCard extends StatefulWidget {
  final VoidCallback? onTap;
  final VoidCallback? onRetry;

  const ConnectionStatusCard({
    super.key,
    this.onTap,
    this.onRetry,
  });

  @override
  State<ConnectionStatusCard> createState() => _ConnectionStatusCardState();
}

class _ConnectionStatusCardState extends State<ConnectionStatusCard> {
  late final ConnectionMonitorService _monitor;

  @override
  void initState() {
    super.initState();
    _monitor = connectionMonitor;
    _monitor.addListener(_onConnectionChanged);
  }

  @override
  void dispose() {
    _monitor.removeListener(_onConnectionChanged);
    super.dispose();
  }

  void _onConnectionChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = _monitor.state;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(state.status).withOpacity(0.5),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: widget.onTap ?? () => _showConnectionDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(state.status).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getStatusIcon(state.status),
                      color: _getStatusColor(state.status),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Status text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              state.statusText,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(state.status),
                                  ),
                            ),
                            if (state.retryCountdown > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Retry in ${state.retryCountdown}s',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getSubtitle(state),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  // Arrow or action
                  if (state.isDisconnected || state.hasError)
                    TextButton(
                      onPressed: widget.onRetry ?? () => _monitor.reconnect(),
                      child: const Text('Reconnect'),
                    )
                  else
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                ],
              ),

              // Connection details (when connected)
              if (state.isConnected && state.gatewayInfo != null) ...[
                const Divider(height: 24),
                _buildConnectionDetails(context, state),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionDetails(
      BuildContext context, AppConnectionState state) {
    final info = state.gatewayInfo!;
    final agentCount = info.agents?.length ?? 0;
    final activeAgents = info.agents
            ?.where((agent) => agent.isActive || agent.status == 'active')
            .length ??
        0;
    final nodeCount = info.nodes?.length ?? 0;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                context,
                'Sessions',
                '$agentCount total • $activeAgents active',
                Icons.people_alt_outlined,
              ),
              const SizedBox(height: 4),
              _buildDetailRow(
                context,
                'Nodes',
                '$nodeCount connected',
                Icons.hub_outlined,
              ),
            ],
          ),
        ),

        // Latency
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getLatencyColor(state.latencyMs).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                '${state.latencyMs}ms',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getLatencyColor(state.latencyMs),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Latency',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
      BuildContext context, String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }

  String _getSubtitle(AppConnectionState state) {
    if (state.gatewayName != null && state.gatewayName!.isNotEmpty) {
      return state.gatewayName!;
    }
    if (state.gatewayUrl != null) {
      return state.gatewayUrl!;
    }
    return 'No gateway configured';
  }

  Color _getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.disconnected:
        return Colors.red;
      case ConnectionStatus.connecting:
        return Colors.orange;
      case ConnectionStatus.error:
        return Colors.red.shade800;
    }
  }

  IconData _getStatusIcon(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Icons.check_circle;
      case ConnectionStatus.disconnected:
        return Icons.cancel;
      case ConnectionStatus.connecting:
        return Icons.sync;
      case ConnectionStatus.error:
        return Icons.error;
    }
  }

  Color _getLatencyColor(int latencyMs) {
    if (latencyMs < 100) return Colors.green;
    if (latencyMs < 300) return Colors.orange;
    return Colors.red;
  }

  void _showConnectionDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _ConnectionDetailsSheet(
        state: _monitor.state,
        onRetry: widget.onRetry,
      ),
      isScrollControlled: true,
    );
  }
}

/// Connection details bottom sheet
class _ConnectionDetailsSheet extends StatelessWidget {
  final AppConnectionState state;
  final VoidCallback? onRetry;

  const _ConnectionDetailsSheet({
    required this.state,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Row(
            children: [
              Icon(
                Icons.router,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'Gateway Connection',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Status
          _buildDetailTile(
            context,
            'Status',
            state.statusText,
            Icons.circle,
            _getStatusColor(state.status),
          ),

          // Gateway URL
          if (state.gatewayUrl != null)
            _buildDetailTile(
              context,
              'Gateway URL',
              state.gatewayUrl!,
              Icons.link,
              null,
            ),

          // Gateway Name
          if (state.gatewayName != null)
            _buildDetailTile(
              context,
              'Gateway Name',
              state.gatewayName!,
              Icons.label,
              null,
            ),

          if (state.gatewayInfo != null)
            _buildDetailTile(
              context,
              'Sessions',
              '${state.gatewayInfo!.agents?.length ?? 0} total',
              Icons.people_alt_outlined,
              null,
            ),

          if (state.gatewayInfo != null)
            _buildDetailTile(
              context,
              'Nodes',
              '${state.gatewayInfo!.nodes?.length ?? 0} connected',
              Icons.hub_outlined,
              null,
            ),

          if (state.gatewayInfo?.isPaused == true)
            _buildDetailTile(
              context,
              'Mode',
              'Paused',
              Icons.pause_circle_outline,
              Colors.orange,
            ),

          // Latency
          if (state.lastPing != null)
            _buildDetailTile(
              context,
              'Latency',
              '${state.latencyMs}ms',
              Icons.speed,
              null,
            ),

          // Last Ping
          if (state.lastPing != null)
            _buildDetailTile(
              context,
              'Last Ping',
              _formatTime(state.lastPing!),
              Icons.access_time,
              null,
            ),

          // Error message
          if (state.errorMessage != null)
            _buildDetailTile(
              context,
              'Error',
              state.errorMessage!,
              Icons.error_outline,
              Colors.red,
            ),

          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    if (onRetry != null) {
                      onRetry!();
                    } else {
                      connectionMonitor.reconnect();
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(state.isConnected ? 'Test' : 'Reconnect'),
                ),
              ),
            ],
          ),

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildDetailTile(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color? color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color ?? Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.disconnected:
        return Colors.red;
      case ConnectionStatus.connecting:
        return Colors.orange;
      case ConnectionStatus.error:
        return Colors.red.shade800;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    return '${diff.inHours}h ago';
  }
}
