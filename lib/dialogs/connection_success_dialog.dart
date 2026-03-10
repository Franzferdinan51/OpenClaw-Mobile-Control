import 'package:flutter/material.dart';

/// Dialog shown when gateway connection is successful during setup
class ConnectionSuccessDialog extends StatelessWidget {
  final String gatewayName;
  final String gatewayUrl;
  final String version;
  final int uptime;
  final VoidCallback onStartUsing;
  final VoidCallback? onTestConnection;

  const ConnectionSuccessDialog({
    super.key,
    required this.gatewayName,
    required this.gatewayUrl,
    required this.version,
    required this.uptime,
    required this.onStartUsing,
    this.onTestConnection,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon with animation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              '✅ Successfully Connected!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // Gateway name
            Text(
              gatewayName.isNotEmpty ? gatewayName : 'Gateway',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Connection details card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    context,
                    Icons.link,
                    'URL',
                    gatewayUrl,
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    context,
                    Icons.info_outline,
                    'Version',
                    version,
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    context,
                    Icons.timer_outlined,
                    'Uptime',
                    _formatUptime(uptime),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Actions
            Row(
              children: [
                if (onTestConnection != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTestConnection,
                      icon: const Icon(Icons.network_check),
                      label: const Text('Test Connection'),
                    ),
                  ),
                if (onTestConnection != null)
                  const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onStartUsing,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Start Using App'),
                    style: ElevatedButton.styleFrom(
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
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
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
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  String _formatUptime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 24) {
      final days = hours ~/ 24;
      return '${days}d ${hours % 24}h ${minutes}m';
    }
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}

/// Show connection success dialog and return whether user wants to start using
Future<bool> showConnectionSuccessDialog({
  required BuildContext context,
  required String gatewayName,
  required String gatewayUrl,
  required String version,
  required int uptime,
  VoidCallback? onTestConnection,
}) async {
  bool startUsing = false;
  
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ConnectionSuccessDialog(
      gatewayName: gatewayName,
      gatewayUrl: gatewayUrl,
      version: version,
      uptime: uptime,
      onTestConnection: onTestConnection,
      onStartUsing: () {
        startUsing = true;
        Navigator.of(context).pop();
      },
    ),
  );
  
  return startUsing;
}

/// Connection error dialog for setup failures
class ConnectionErrorDialog extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback? onManualSetup;

  const ConnectionErrorDialog({
    super.key,
    this.error,
    required this.onRetry,
    this.onManualSetup,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              'Connection Failed',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Error message
            if (error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
            
            // Help text
            Text(
              'Please check that:\n'
              '• The gateway is running\n'
              '• You\'re on the same network\n'
              '• The URL is correct',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Actions
            Row(
              children: [
                if (onManualSetup != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onManualSetup,
                      icon: const Icon(Icons.edit),
                      label: const Text('Manual Setup'),
                    ),
                  ),
                if (onManualSetup != null)
                  const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
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
}

/// Show connection error dialog
Future<void> showConnectionErrorDialog({
  required BuildContext context,
  String? error,
  required VoidCallback onRetry,
  VoidCallback? onManualSetup,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ConnectionErrorDialog(
      error: error,
      onRetry: onRetry,
      onManualSetup: onManualSetup,
    ),
  );
}