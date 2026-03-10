import 'package:flutter/material.dart';
import '../services/connection_monitor_service.dart';

/// Connection status icon for app bar
class ConnectionStatusIcon extends StatefulWidget {
  final VoidCallback? onTap;

  const ConnectionStatusIcon({
    super.key,
    this.onTap,
  });

  @override
  State<ConnectionStatusIcon> createState() => _ConnectionStatusIconState();
}

class _ConnectionStatusIconState extends State<ConnectionStatusIcon> {
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
    
    return GestureDetector(
      onTap: widget.onTap ?? () => _showQuickStatus(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Main icon
            Icon(
              Icons.router,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            
            // Status dot (positioned at top-right)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _getStatusColor(state.status),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            
            // Connecting animation
            if (state.isConnecting)
              Positioned(
                top: 0,
                right: 0,
                child: SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getStatusColor(state.status),
                    ),
                  ),
                ),
              ),
          ],
        ),
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

  void _showQuickStatus(BuildContext context) {
    final state = _monitor.state;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getStatusColor(state.status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(state.statusText),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.gatewayUrl != null) ...[
              Text(
                'Gateway:',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                state.gatewayUrl!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
            ],
            if (state.gatewayInfo != null) ...[
              Text(
                'Version: ${state.gatewayInfo!.version}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Latency: ${state.latencyMs}ms',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (state.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error:',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.red,
                ),
              ),
              Text(
                state.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.red,
                ),
              ),
            ],
            if (state.retryCountdown > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Retrying in ${state.retryCountdown}s...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.orange,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!state.isConnected)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _monitor.reconnect();
              },
              child: const Text('Reconnect'),
            ),
        ],
      ),
    );
  }
}

/// Connection status dot only (for inline use)
class ConnectionStatusDot extends StatefulWidget {
  final double size;
  final bool showLabel;
  final VoidCallback? onTap;

  const ConnectionStatusDot({
    super.key,
    this.size = 10,
    this.showLabel = false,
    this.onTap,
  });

  @override
  State<ConnectionStatusDot> createState() => _ConnectionStatusDotState();
}

class _ConnectionStatusDotState extends State<ConnectionStatusDot> {
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
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: _getStatusColor(state.status),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getStatusColor(state.status).withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          if (widget.showLabel) ...[
            const SizedBox(width: 6),
            Text(
              state.statusText,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: _getStatusColor(state.status),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
}

/// Connection status banner for lost connection warnings
class ConnectionLostBanner extends StatefulWidget {
  final VoidCallback? onRetry;

  const ConnectionLostBanner({
    super.key,
    this.onRetry,
  });

  @override
  State<ConnectionLostBanner> createState() => _ConnectionLostBannerState();
}

class _ConnectionLostBannerState extends State<ConnectionLostBanner> {
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
    
    // Only show when disconnected or error
    if (state.isConnected || state.isConnecting) {
      return const SizedBox.shrink();
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Gateway Connection Lost',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (state.retryCountdown > 0)
                  Text(
                    'Retrying in ${state.retryCountdown}s...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: widget.onRetry ?? () => _monitor.reconnect(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            child: const Text('Reconnect'),
          ),
        ],
      ),
    );
  }
}