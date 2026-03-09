import 'package:flutter/material.dart';

/// Status types for the indicator
enum StatusType {
  online,
  offline,
  busy,
  error,
  warning,
  success,
  idle,
  unknown,
}

/// A reusable status indicator widget that displays a colored dot with optional label.
/// 
/// Follows Material 3 design with semantic colors and smooth animations.
/// 
/// Usage:
/// ```dart
/// StatusIndicator(
///   status: StatusType.online,
///   label: 'Connected',
///   showLabel: true,
/// )
/// ```
class StatusIndicator extends StatelessWidget {
  /// The status type to display
  final StatusType status;
  
  /// Optional label text next to the indicator
  final String? label;
  
  /// Whether to show the label
  final bool showLabel;
  
  /// Size of the indicator dot
  final double size;
  
  /// Whether to animate status changes
  final bool animate;
  
  /// Custom colors for each status type (overrides defaults)
  final Map<StatusType, Color>? customColors;

  const StatusIndicator({
    super.key,
    required this.status,
    this.label,
    this.showLabel = false,
    this.size = 12.0,
    this.animate = true,
    this.customColors,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(context);
    final statusText = _getStatusText();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        animate
            ? _AnimatedDot(color: color, size: size)
            : _StaticDot(color: color, size: size),
        if (showLabel && label != null) ...[
          const SizedBox(width: 8),
          Text(
            label!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ] else if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            statusText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ],
    );
  }

  Color _getStatusColor(BuildContext context) {
    if (customColors != null && customColors!.containsKey(status)) {
      return customColors![status]!;
    }
    
    final colorScheme = Theme.of(context).colorScheme;
    
    switch (status) {
      case StatusType.online:
        return Colors.green;
      case StatusType.offline:
        return Colors.grey;
      case StatusType.busy:
        return Colors.orange;
      case StatusType.error:
        return colorScheme.error;
      case StatusType.warning:
        return Colors.amber;
      case StatusType.success:
        return Colors.green;
      case StatusType.idle:
        return Colors.blueGrey;
      case StatusType.unknown:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (status) {
      case StatusType.online:
        return 'Online';
      case StatusType.offline:
        return 'Offline';
      case StatusType.busy:
        return 'Busy';
      case StatusType.error:
        return 'Error';
      case StatusType.warning:
        return 'Warning';
      case StatusType.success:
        return 'Success';
      case StatusType.idle:
        return 'Idle';
      case StatusType.unknown:
        return 'Unknown';
    }
  }
}

/// Animated pulsing dot for status indicators
class _AnimatedDot extends StatefulWidget {
  final Color color;
  final double size;

  const _AnimatedDot({
    required this.color,
    required this.size,
  });

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(_animation.value),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4),
                blurRadius: widget.size / 2,
                spreadRadius: widget.size / 4,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Static dot for status indicators (no animation)
class _StaticDot extends StatelessWidget {
  final Color color;
  final double size;

  const _StaticDot({
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: size / 3,
            spreadRadius: size / 6,
          ),
        ],
      ),
    );
  }
}

/// Extension to convert string to StatusType
extension StatusTypeExtension on String {
  StatusType toStatusType() {
    switch (toLowerCase()) {
      case 'online':
      case 'connected':
      case 'active':
        return StatusType.online;
      case 'offline':
      case 'disconnected':
      case 'inactive':
        return StatusType.offline;
      case 'busy':
      case 'working':
      case 'processing':
        return StatusType.busy;
      case 'error':
      case 'failed':
        return StatusType.error;
      case 'warning':
      case 'warn':
        return StatusType.warning;
      case 'success':
      case 'completed':
        return StatusType.success;
      case 'idle':
      case 'waiting':
        return StatusType.idle;
      default:
        return StatusType.unknown;
    }
  }
}