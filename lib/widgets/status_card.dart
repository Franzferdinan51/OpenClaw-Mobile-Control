import 'package:flutter/material.dart';
import 'info_card.dart';

/// Status card for displaying system status (gateway, agents, nodes)
/// 
/// Features:
/// - Animated status indicator
/// - Real-time status updates
/// - Metric display
/// - Quick actions
class StatusCard extends InfoCard {
  final CardState state;
  final String statusText;
  final List<StatusMetric>? metrics;
  final Widget? statusIcon;
  final bool showPulse;
  final Duration pulseDuration;

  const StatusCard({
    super.key,
    super.title,
    super.subtitle,
    super.leading,
    super.trailing,
    super.accentColor,
    super.onTap,
    super.onLongPress,
    super.actions,
    super.isLoading,
    super.errorMessage,
    super.padding,
    super.margin,
    super.enableSwipe,
    super.swipeLeftAction,
    super.swipeRightAction,
    required this.state,
    required this.statusText,
    this.metrics,
    this.statusIcon,
    this.showPulse = true,
    this.pulseDuration = const Duration(seconds: 2),
  });

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status indicator
        _buildStatusIndicator(context),
        
        // Metrics
        if (metrics != null && metrics!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildMetrics(context),
        ],
      ],
    );
  }

  Widget _buildStatusIndicator(BuildContext context) {
    final color = state.color;
    
    return Row(
      children: [
        // Animated status dot
        _AnimatedStatusDot(
          color: color,
          showPulse: showPulse && state == CardState.success,
          pulseDuration: pulseDuration,
        ),
        const SizedBox(width: 12),
        
        // Status text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                state.label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        // Custom icon or state icon
        if (statusIcon != null)
          statusIcon!
        else
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(state.icon, color: color, size: 20),
          ),
      ],
    );
  }

  Widget _buildMetrics(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: metrics!.map((metric) => _MetricChip(metric: metric)).toList(),
    );
  }
}

/// Animated status dot with pulse effect
class _AnimatedStatusDot extends StatefulWidget {
  final Color color;
  final bool showPulse;
  final Duration pulseDuration;

  const _AnimatedStatusDot({
    required this.color,
    required this.showPulse,
    required this.pulseDuration,
  });

  @override
  State<_AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<_AnimatedStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.pulseDuration,
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    if (widget.showPulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AnimatedStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showPulse && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.showPulse && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse ring
          if (widget.showPulse)
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Container(
                  width: 12 * _animation.value,
                  height: 12 * _animation.value,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(
                      0.3 * (1 - (_animation.value - 1)),
                    ),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
          // Solid dot
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Metric chip for displaying status metrics
class _MetricChip extends StatelessWidget {
  final StatusMetric metric;

  const _MetricChip({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (metric.icon != null) ...[
            Icon(metric.icon, size: 16, color: metric.color ?? Colors.grey),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                metric.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: metric.color ?? Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Status metric data class
class StatusMetric {
  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final String? unit;

  const StatusMetric({
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.unit,
  });
}

/// Gateway status card - specialized for gateway display
class GatewayStatusCard extends StatelessWidget {
  final bool isOnline;
  final String? version;
  final int? activeAgents;
  final int? totalSessions;
  final Duration? uptime;
  final VoidCallback? onTap;
  final VoidCallback? onRestart;
  final VoidCallback? onViewLogs;

  const GatewayStatusCard({
    super.key,
    required this.isOnline,
    this.version,
    this.activeAgents,
    this.totalSessions,
    this.uptime,
    this.onTap,
    this.onRestart,
    this.onViewLogs,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = <StatusMetric>[];
    
    if (activeAgents != null) {
      metrics.add(StatusMetric(
        label: 'Agents',
        value: activeAgents.toString(),
        icon: Icons.smart_toy,
        color: const Color(0xFF00D4AA),
      ));
    }
    
    if (totalSessions != null) {
      metrics.add(StatusMetric(
        label: 'Sessions',
        value: totalSessions.toString(),
        icon: Icons.chat,
        color: Colors.blue,
      ));
    }
    
    if (uptime != null) {
      metrics.add(StatusMetric(
        label: 'Uptime',
        value: _formatUptime(uptime!),
        icon: Icons.schedule,
        color: Colors.purple,
      ));
    }

    return StatusCard(
      title: 'Gateway',
      subtitle: version != null ? 'v$version' : null,
      state: isOnline ? CardState.success : CardState.error,
      statusText: isOnline ? 'Online' : 'Offline',
      metrics: metrics,
      onTap: onTap,
      actions: [
        if (onViewLogs != null)
          InfoCardAction(
            icon: Icons.article,
            label: 'View Logs',
            color: Colors.blue,
            onAction: onViewLogs!,
          ),
        if (onRestart != null)
          InfoCardAction(
            icon: Icons.refresh,
            label: 'Restart',
            color: Colors.orange,
            onAction: onRestart!,
          ),
      ],
    );
  }

  String _formatUptime(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}

/// Node status card - specialized for node display
class NodeStatusCard extends StatelessWidget {
  final String nodeName;
  final bool isOnline;
  final String? nodeType;
  final String? ipAddress;
  final int? activeSessions;
  final VoidCallback? onTap;
  final VoidCallback? onDisconnect;

  const NodeStatusCard({
    super.key,
    required this.nodeName,
    required this.isOnline,
    this.nodeType,
    this.ipAddress,
    this.activeSessions,
    this.onTap,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = <StatusMetric>[];
    
    if (nodeType != null) {
      metrics.add(StatusMetric(
        label: 'Type',
        value: nodeType!,
        icon: Icons.devices,
      ));
    }
    
    if (ipAddress != null) {
      metrics.add(StatusMetric(
        label: 'IP',
        value: ipAddress!,
        icon: Icons.wifi,
      ));
    }
    
    if (activeSessions != null) {
      metrics.add(StatusMetric(
        label: 'Sessions',
        value: activeSessions.toString(),
        icon: Icons.chat,
        color: const Color(0xFF00D4AA),
      ));
    }

    return StatusCard(
      title: nodeName,
      state: isOnline ? CardState.success : CardState.idle,
      statusText: isOnline ? 'Connected' : 'Disconnected',
      metrics: metrics,
      onTap: onTap,
      actions: [
        if (onDisconnect != null)
          InfoCardAction(
            icon: Icons.link_off,
            label: 'Disconnect',
            color: Colors.red,
            onAction: onDisconnect!,
          ),
      ],
    );
  }
}