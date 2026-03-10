import 'dart:async';
import 'package:flutter/material.dart';

/// Agent status enumeration
enum AgentStatus {
  idle,
  thinking,
  working,
  error,
  waiting,
}

/// Extension for agent status helpers
extension AgentStatusExtension on AgentStatus {
  String get label {
    switch (this) {
      case AgentStatus.idle:
        return 'Idle';
      case AgentStatus.thinking:
        return 'Thinking...';
      case AgentStatus.working:
        return 'Working...';
      case AgentStatus.error:
        return 'Error';
      case AgentStatus.waiting:
        return 'Waiting...';
    }
  }

  IconData get icon {
    switch (this) {
      case AgentStatus.idle:
        return Icons.circle_outlined;
      case AgentStatus.thinking:
        return Icons.psychology;
      case AgentStatus.working:
        return Icons.build;
      case AgentStatus.error:
        return Icons.error_outline;
      case AgentStatus.waiting:
        return Icons.hourglass_empty;
    }
  }

  Color get color {
    switch (this) {
      case AgentStatus.idle:
        return Colors.grey;
      case AgentStatus.thinking:
        return const Color(0xFF00D4AA);
      case AgentStatus.working:
        return Colors.blue;
      case AgentStatus.error:
        return Colors.red;
      case AgentStatus.waiting:
        return Colors.orange;
    }
  }
}

/// Widget for displaying agent status with visual indicator
class AgentStatusIndicator extends StatefulWidget {
  final AgentStatus status;
  final String? currentTool;
  final String? currentTask;
  final Duration? taskDuration;
  final double? progress;
  final bool showLabel;
  final bool showPulse;

  const AgentStatusIndicator({
    super.key,
    this.status = AgentStatus.idle,
    this.currentTool,
    this.currentTask,
    this.taskDuration,
    this.progress,
    this.showLabel = true,
    this.showPulse = true,
  });

  @override
  State<AgentStatusIndicator> createState() => _AgentStatusIndicatorState();
}

class _AgentStatusIndicatorState extends State<AgentStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    if (widget.status == AgentStatus.thinking || 
        widget.status == AgentStatus.working) {
      _pulseController.repeat(reverse: true);
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(AgentStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.status != oldWidget.status) {
      if (widget.status == AgentStatus.thinking || 
          widget.status == AgentStatus.working) {
        _pulseController.repeat(reverse: true);
        _startTimer();
      } else {
        _pulseController.stop();
        _stopTimer();
      }
    }
  }

  void _startTimer() {
    _elapsed = widget.taskDuration ?? Duration.zero;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed += const Duration(seconds: 1);
        });
      }
    });
  }

  void _stopTimer() {
    _durationTimer?.cancel();
    _elapsed = Duration.zero;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _durationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.status.color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated icon
              FadeTransition(
                opacity: widget.showPulse && 
                        (widget.status == AgentStatus.thinking || 
                         widget.status == AgentStatus.working)
                    ? _pulseAnimation
                    : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: widget.status.color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.status.icon,
                    size: 14,
                    color: widget.status.color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              
              // Status label
              if (widget.showLabel)
                Text(
                  widget.status.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: widget.status.color,
                  ),
                ),
              
              // Duration
              if (_elapsed > Duration.zero) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(_elapsed),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
          
          // Current tool/task
          if (widget.currentTool != null || widget.currentTask != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.handyman,
                  size: 12,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.currentTool ?? widget.currentTask ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[400],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          
          // Progress bar
          if (widget.progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: widget.progress!.clamp(0.0, 1.0),
                backgroundColor: Colors.grey[700],
                valueColor: AlwaysStoppedAnimation<Color>(widget.status.color),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}

/// Compact status dot for headers/toolbars
class StatusDot extends StatelessWidget {
  final AgentStatus status;
  final double size;
  final bool animate;

  const StatusDot({
    super.key,
    this.status = AgentStatus.idle,
    this.size = 8,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: status.label,
      child: animate && (status == AgentStatus.thinking || status == AgentStatus.working)
          ? _AnimatedDot(status: status, size: size)
          : Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: status.color,
                shape: BoxShape.circle,
              ),
            ),
    );
  }
}

class _AnimatedDot extends StatefulWidget {
  final AgentStatus status;
  final double size;

  const _AnimatedDot({required this.status, required this.size});

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
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.status.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.status.color.withOpacity(0.5),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}