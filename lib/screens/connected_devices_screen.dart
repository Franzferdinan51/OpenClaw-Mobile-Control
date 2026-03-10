/// Connected Devices Screen
/// 
/// Dashboard showing all connected devices in Host Node Mode.

import 'package:flutter/material.dart';
import '../models/node_connection.dart';

class ConnectedDevicesScreen extends StatelessWidget {
  final List<NodeConnection> connections;
  final Function(String)? onApprove;
  final Function(String)? onReject;
  final Function(String)? onDisconnect;
  final Function(String)? onViewDetails;

  const ConnectedDevicesScreen({
    super.key,
    required this.connections,
    this.onApprove,
    this.onReject,
    this.onDisconnect,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    // Separate connections by status
    final pending = connections.where((c) => c.status == ConnectionStatus.pending).toList();
    final connected = connections.where((c) => c.status == ConnectionStatus.connected).toList();
    final others = connections.where((c) => 
        c.status != ConnectionStatus.pending && c.status != ConnectionStatus.connected).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh would be handled by parent
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: connections.isEmpty
          ? _buildEmptyState(context)
          : _buildDeviceList(context, pending, connected, others),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.devices_other,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Connected Devices',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start Host Node Mode to accept connections',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'When devices connect, they will appear here',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Orange = Pending approval', style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Green = Connected', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(
    BuildContext context,
    List<NodeConnection> pending,
    List<NodeConnection> connected,
    List<NodeConnection> others,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pending connections
        if (pending.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            'Pending Approval',
            pending.length,
            Colors.orange,
          ),
          ...pending.map((c) => _DeviceCard(
            connection: c,
            onApprove: onApprove,
            onReject: onReject,
            onDisconnect: onDisconnect,
            onViewDetails: onViewDetails,
          )),
          const SizedBox(height: 24),
        ],

        // Connected devices
        if (connected.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            'Connected',
            connected.length,
            Colors.green,
          ),
          ...connected.map((c) => _DeviceCard(
            connection: c,
            onApprove: onApprove,
            onReject: onReject,
            onDisconnect: onDisconnect,
            onViewDetails: onViewDetails,
          )),
          const SizedBox(height: 24),
        ],

        // Other (disconnected, rejected)
        if (others.isNotEmpty) ...[
          _buildSectionHeader(
            context,
            'Recent',
            others.length,
            Colors.grey,
          ),
          ...others.map((c) => _DeviceCard(
            connection: c,
            onApprove: onApprove,
            onReject: onReject,
            onDisconnect: onDisconnect,
            onViewDetails: onViewDetails,
          )),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Device Card Widget
class _DeviceCard extends StatelessWidget {
  final NodeConnection connection;
  final Function(String)? onApprove;
  final Function(String)? onReject;
  final Function(String)? onDisconnect;
  final Function(String)? onViewDetails;

  const _DeviceCard({
    required this.connection,
    this.onApprove,
    this.onReject,
    this.onDisconnect,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onViewDetails != null ? () => onViewDetails!(connection.id) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  _buildStatusIndicator(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connection.displayName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          connection.ip,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildDeviceTypeIcon(),
                ],
              ),

              const SizedBox(height: 12),

              // Info chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    Icons.access_time,
                    _formatDuration(connection.connectedDuration),
                  ),
                  _buildInfoChip(
                    Icons.devices,
                    connection.deviceType.displayName,
                  ),
                  if (connection.userAgent != null)
                    _buildInfoChip(
                      Icons.info_outline,
                      _truncateUserAgent(connection.userAgent!),
                    ),
                ],
              ),

              // Action buttons for pending
              if (connection.status == ConnectionStatus.pending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove != null
                            ? () => onApprove!(connection.id)
                            : null,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject != null
                            ? () => onReject!(connection.id)
                            : null,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Action buttons for connected
              if (connection.status == ConnectionStatus.connected) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDisconnect != null
                            ? () => _showDisconnectDialog(context)
                            : null,
                        icon: const Icon(Icons.link_off, size: 18),
                        label: const Text('Disconnect'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDeviceDetails(context),
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Details'),
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

  Widget _buildStatusIndicator() {
    Color color;
    switch (connection.status) {
      case ConnectionStatus.connected:
        color = Colors.green;
        break;
      case ConnectionStatus.pending:
        color = Colors.orange;
        break;
      case ConnectionStatus.disconnected:
        color = Colors.grey;
        break;
      case ConnectionStatus.rejected:
        color = Colors.red;
        break;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTypeIcon() {
    IconData iconData;
    Color iconColor;

    switch (connection.deviceType) {
      case DeviceType.android:
        iconData = Icons.phone_android;
        iconColor = Colors.green;
        break;
      case DeviceType.ios:
        iconData = Icons.phone_iphone;
        iconColor = Colors.blue;
        break;
      case DeviceType.desktop:
        iconData = Icons.computer;
        iconColor = Colors.purple;
        break;
      case DeviceType.server:
        iconData = Icons.dns;
        iconColor = Colors.orange;
        break;
      case DeviceType.iot:
        iconData = Icons.router;
        iconColor = Colors.teal;
        break;
      case DeviceType.unknown:
        iconData = Icons.device_unknown;
        iconColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: iconColor, size: 24),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _truncateUserAgent(String userAgent) {
    if (userAgent.length > 20) {
      return '${userAgent.substring(0, 20)}...';
    }
    return userAgent;
  }

  void _showDisconnectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Device?'),
        content: Text(
          'Are you sure you want to disconnect ${connection.displayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDisconnect?.call(connection.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  void _showDeviceDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DeviceDetailsSheet(connection: connection),
    );
  }
}

/// Device Details Bottom Sheet
class _DeviceDetailsSheet extends StatelessWidget {
  final NodeConnection connection;

  const _DeviceDetailsSheet({required this.connection});

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
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Row(
            children: [
              const Icon(Icons.devices, color: Colors.blue),
              const SizedBox(width: 12),
              Text(
                'Device Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Details
          _buildDetailRow('Name', connection.displayName),
          _buildDetailRow('IP Address', connection.ip),
          _buildDetailRow('Port', connection.port.toString()),
          _buildDetailRow('Status', connection.status.name.toUpperCase()),
          _buildDetailRow('Device Type', connection.deviceType.displayName),
          _buildDetailRow(
            'Connected',
            _formatDateTime(connection.connectedAt),
          ),
          if (connection.lastActivity != null)
            _buildDetailRow(
              'Last Activity',
              _formatDateTime(connection.lastActivity!),
            ),
          if (connection.userAgent != null)
            _buildDetailRow('User Agent', connection.userAgent!),

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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}