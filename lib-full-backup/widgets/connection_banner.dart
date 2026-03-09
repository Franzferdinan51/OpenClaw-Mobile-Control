import 'package:flutter/material.dart';
import 'status_indicator.dart';

/// Connection state for the banner
enum WidgetConnectionState {
  connected,
  disconnected,
  connecting,
  reconnecting,
  error,
}

/// A Material 3 styled banner for displaying connection status.
/// 
/// Features:
/// - Animated state transitions
/// - Different colors for each state
/// - Optional retry button
/// - Collapsible design
/// 
/// Usage:
/// ```dart
/// ConnectionBanner(
///   state: ConnectionState.connected,
///   serverName: 'DuckBot Server',
///   onRetry: () => _reconnect(),
/// )
/// ```
class ConnectionBanner extends StatefulWidget {
  /// Current connection state
  final WidgetConnectionState? state;
  
  /// Server/connection name to display
  final String? serverName;
  
  /// Whether to show the retry button
  final bool showRetry;
  
  /// Callback when retry is pressed
  final VoidCallback? onRetry;
  
  /// Whether to auto-hide when connected
  final bool autoHideConnected;
  
  /// Duration before auto-hiding
  final Duration autoHideDelay;
  
  /// Whether the banner is collapsible
  final bool collapsible;
  
  /// Error message to display
  final String? errorMessage;

  const ConnectionBanner({
    super.key,
    this.state,
    this.serverName,
    this.showRetry = true,
    this.onRetry,
    this.autoHideConnected = true,
    this.autoHideDelay = const Duration(seconds: 3),
    this.collapsible = false,
    this.errorMessage,
  });

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isVisible = true;
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _controller.forward();
    _handleStateChange();
  }

  @override
  void didUpdateWidget(ConnectionBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.state != widget.state) {
      _handleStateChange();
    }
  }

  void _handleStateChange() {
    // Reset collapsed state on state change
    setState(() => _isCollapsed = false);
    
    if (widget.autoHideConnected && widget.state == WidgetConnectionState.connected) {
      Future.delayed(widget.autoHideDelay, () {
        if (mounted && widget.state == ConnectionState.connected) {
          _hide();
        }
      });
    } else {
      _show();
    }
  }

  void _show() {
    setState(() => _isVisible = true);
    _controller.forward();
  }

  void _hide() {
    _controller.reverse().then((_) {
      if (mounted) {
        setState(() => _isVisible = false);
      }
    });
  }

  void _toggleCollapse() {
    setState(() => _isCollapsed = !_isCollapsed);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible && widget.state == WidgetConnectionState.connected) {
      return const SizedBox.shrink();
    }
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = _getBackgroundColor(colorScheme);
    final foregroundColor = _getForegroundColor(colorScheme);
    
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: backgroundColor,
          elevation: 2,
          child: SafeArea(
            bottom: false,
            child: AnimatedCrossFade(
              firstChild: _buildExpandedBanner(theme, foregroundColor),
              secondChild: _buildCollapsedBanner(theme, foregroundColor),
              crossFadeState: _isCollapsed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedBanner(ThemeData theme, Color foregroundColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildStatusIcon(foregroundColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getStatusMessage(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.errorMessage != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foregroundColor.withOpacity(0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (widget.showRetry && _shouldShowRetry()) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: widget.onRetry,
              style: TextButton.styleFrom(
                foregroundColor: foregroundColor,
                backgroundColor: foregroundColor.withOpacity(0.2),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Retry'),
            ),
          ],
          if (widget.collapsible) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: _toggleCollapse,
              icon: Icon(
                Icons.keyboard_arrow_up,
                color: foregroundColor,
              ),
              tooltip: 'Collapse',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollapsedBanner(ThemeData theme, Color foregroundColor) {
    return GestureDetector(
      onTap: _toggleCollapse,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: foregroundColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _getShortStatus(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down,
              color: foregroundColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(Color foregroundColor) {
    switch (widget.state) {
      case WidgetConnectionState.connected:
        return Icon(Icons.check_circle, color: foregroundColor);
      case WidgetConnectionState.disconnected:
        return Icon(Icons.cancel_outlined, color: foregroundColor);
      case WidgetConnectionState.connecting:
      case WidgetConnectionState.reconnecting:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: foregroundColor,
          ),
        );
      case WidgetConnectionState.error:
        return Icon(Icons.error, color: foregroundColor);
    }
  }

  Color _getBackgroundColor(ColorScheme colorScheme) {
    switch (widget.state) {
      case WidgetConnectionState.connected:
        return Colors.green;
      case WidgetConnectionState.disconnected:
        return colorScheme.surfaceContainerHighest;
      case WidgetConnectionState.connecting:
        return colorScheme.primaryContainer;
      case WidgetConnectionState.reconnecting:
        return Colors.orange;
      case WidgetConnectionState.error:
        return colorScheme.error;
    }
  }

  Color _getForegroundColor(ColorScheme colorScheme) {
    switch (widget.state) {
      case WidgetConnectionState.connected:
        return Colors.white;
      case WidgetConnectionState.disconnected:
        return colorScheme.onSurface;
      case WidgetConnectionState.connecting:
        return colorScheme.onPrimaryContainer;
      case WidgetConnectionState.reconnecting:
        return Colors.white;
      case WidgetConnectionState.error:
        return colorScheme.onError;
    }
  }

  String _getStatusMessage() {
    final serverName = widget.serverName ?? 'Server';
    
    switch (widget.state) {
      case WidgetConnectionState.connected:
        return 'Connected to $serverName';
      case WidgetConnectionState.disconnected:
        return 'Disconnected from $serverName';
      case WidgetConnectionState.connecting:
        return 'Connecting to $serverName...';
      case WidgetConnectionState.reconnecting:
        return 'Reconnecting to $serverName...';
      case WidgetConnectionState.error:
        return 'Connection error';
    }
  }

  String _getShortStatus() {
    switch (widget.state) {
      case WidgetConnectionState.connected:
        return 'Connected';
      case WidgetConnectionState.disconnected:
        return 'Disconnected';
      case WidgetConnectionState.connecting:
        return 'Connecting...';
      case WidgetConnectionState.reconnecting:
        return 'Reconnecting...';
      case WidgetConnectionState.error:
        return 'Error';
    }
  }

  bool _shouldShowRetry() {
    return widget.state == WidgetConnectionState.disconnected ||
        widget.state == WidgetConnectionState.error;
  }
}

/// A minimal inline connection indicator for compact UIs
class ConnectionIndicator extends StatelessWidget {
  /// Current connection state
  final WidgetConnectionState? state;
  
  /// Size of the indicator
  final double size;
  
  /// Whether to show a label
  final bool showLabel;
  
  /// Callback when tapped
  final VoidCallback? onTap;

  const ConnectionIndicator({
    super.key,
    this.state,
    this.size = 12,
    this.showLabel = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getColor(theme.colorScheme);
    
    Widget indicator = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: size / 2,
                spreadRadius: size / 4,
              ),
            ],
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            _getLabel(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
    
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: indicator,
        ),
      );
    }
    
    return indicator;
  }

  Color _getColor(ColorScheme colorScheme) {
    switch (state) {
      case WidgetConnectionState.connected:
        return Colors.green;
      case WidgetConnectionState.disconnected:
        return colorScheme.onSurfaceVariant;
      case WidgetConnectionState.connecting:
        return colorScheme.primary;
      case WidgetConnectionState.reconnecting:
        return Colors.orange;
      case WidgetConnectionState.error:
        return colorScheme.error;
    }
  }

  String _getLabel() {
    switch (state) {
      case WidgetConnectionState.connected:
        return 'Connected';
      case WidgetConnectionState.disconnected:
        return 'Offline';
      case WidgetConnectionState.connecting:
        return 'Connecting...';
      case WidgetConnectionState.reconnecting:
        return 'Reconnecting...';
      case WidgetConnectionState.error:
        return 'Error';
    }
  }
}

/// Extension to convert ConnectionState to StatusType
extension ConnectionStateExtension on WidgetConnectionState {
  StatusType toStatusType() {
    switch (this) {
      case WidgetConnectionState.connected:
        return StatusType.online;
      case WidgetConnectionState.disconnected:
        return StatusType.offline;
      case WidgetConnectionState.connecting:
      case WidgetConnectionState.reconnecting:
        return StatusType.busy;
      case WidgetConnectionState.error:
        return StatusType.error;
    }
  }
}