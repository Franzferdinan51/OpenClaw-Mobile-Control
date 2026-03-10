/// Node Request Card Widget
/// 
/// Displays a pending node pairing request with approve/reject actions.

import 'package:flutter/material.dart';
import '../models/node_connection.dart';
import '../services/node_approval_service.dart';

class NodeRequestCard extends StatelessWidget {
  final PendingNodeRequest request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool isLoading;

  const NodeRequestCard({
    super.key,
    required this.request,
    this.onApprove,
    this.onReject,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with device info
            Row(
              children: [
                // Device icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getDeviceColor(request.deviceType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    request.deviceIcon,
                    color: _getDeviceColor(request.deviceType),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Device info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.displayName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getDeviceColor(request.deviceType).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              request.deviceTypeLabel,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: _getDeviceColor(request.deviceType),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            request.timeAgo,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Pending badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pending',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Details section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    context,
                    icon: Icons.fingerprint,
                    label: 'ID',
                    value: request.id.substring(0, 8).toUpperCase(),
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    context,
                    icon: Icons.wifi,
                    label: 'IP Address',
                    value: request.ip,
                  ),
                  if (request.userAgent != null) ...[
                    const Divider(height: 16),
                    _buildDetailRow(
                      context,
                      icon: Icons.info_outline,
                      label: 'User Agent',
                      value: request.userAgent!,
                      isMonospace: true,
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                // Reject button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : onReject,
                    icon: isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Approve button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : onApprove,
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isMonospace = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: isMonospace ? 'monospace' : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getDeviceColor(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.android:
        return Colors.green;
      case DeviceType.ios:
        return Colors.blue;
      case DeviceType.desktop:
        return Colors.purple;
      case DeviceType.server:
        return Colors.teal;
      case DeviceType.iot:
        return Colors.orange;
      case DeviceType.unknown:
        return Colors.grey;
    }
  }
}

/// Compact version for use in lists
class NodeRequestCardCompact extends StatelessWidget {
  final PendingNodeRequest request;
  final VoidCallback? onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool isLoading;

  const NodeRequestCardCompact({
    super.key,
    required this.request,
    this.onTap,
    this.onApprove,
    this.onReject,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getDeviceColor(request.deviceType).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          request.deviceIcon,
          color: _getDeviceColor(request.deviceType),
          size: 20,
        ),
      ),
      title: Text(request.displayName),
      subtitle: Text('${request.deviceTypeLabel} • ${request.ip}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reject button
          IconButton(
            onPressed: isLoading ? null : onReject,
            icon: const Icon(Icons.close),
            color: Colors.red,
            tooltip: 'Reject',
          ),
          // Approve button
          IconButton(
            onPressed: isLoading ? null : onApprove,
            icon: const Icon(Icons.check),
            color: Colors.green,
            tooltip: 'Approve',
          ),
        ],
      ),
    );
  }

  Color _getDeviceColor(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.android:
        return Colors.green;
      case DeviceType.ios:
        return Colors.blue;
      case DeviceType.desktop:
        return Colors.purple;
      case DeviceType.server:
        return Colors.teal;
      case DeviceType.iot:
        return Colors.orange;
      case DeviceType.unknown:
        return Colors.grey;
    }
  }
}

/// Approved node card for displaying in approved list
class ApprovedNodeCard extends StatelessWidget {
  final ApprovedNode node;
  final VoidCallback? onRemove;
  final VoidCallback? onToggleWhitelist;
  final bool isLoading;

  const ApprovedNodeCard({
    super.key,
    required this.node,
    this.onRemove,
    this.onToggleWhitelist,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getDeviceColor(node.deviceType).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getDeviceIcon(node.deviceType),
            color: _getDeviceColor(node.deviceType),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Text(node.displayName),
            if (node.isWhitelisted) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.verified,
                size: 16,
                color: Colors.green,
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${_getDeviceTypeLabel(node.deviceType)} • ${node.ip}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'whitelist':
                onToggleWhitelist?.call();
                break;
              case 'remove':
                onRemove?.call();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'whitelist',
              child: Row(
                children: [
                  Icon(
                    node.isWhitelisted ? Icons.remove_moderator : Icons.verified_user,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(node.isWhitelisted ? 'Remove from Whitelist' : 'Add to Whitelist'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remove', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.android:
        return Icons.phone_android;
      case DeviceType.ios:
        return Icons.phone_iphone;
      case DeviceType.desktop:
        return Icons.computer;
      case DeviceType.server:
        return Icons.dns;
      case DeviceType.iot:
        return Icons.router;
      case DeviceType.unknown:
        return Icons.device_unknown;
    }
  }

  String _getDeviceTypeLabel(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.android:
        return 'Android';
      case DeviceType.ios:
        return 'iOS';
      case DeviceType.desktop:
        return 'Desktop';
      case DeviceType.server:
        return 'Server';
      case DeviceType.iot:
        return 'IoT';
      case DeviceType.unknown:
        return 'Unknown';
    }
  }

  Color _getDeviceColor(DeviceType deviceType) {
    switch (deviceType) {
      case DeviceType.android:
        return Colors.green;
      case DeviceType.ios:
        return Colors.blue;
      case DeviceType.desktop:
        return Colors.purple;
      case DeviceType.server:
        return Colors.teal;
      case DeviceType.iot:
        return Colors.orange;
      case DeviceType.unknown:
        return Colors.grey;
    }
  }
}