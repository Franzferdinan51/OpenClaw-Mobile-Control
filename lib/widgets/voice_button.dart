import 'package:flutter/material.dart';
import '../services/voice_service.dart';

/// Voice button widget - floating mic button for triggering voice input
class VoiceButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool isListening;
  final bool enabled;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  const VoiceButton({
    super.key,
    this.onPressed,
    this.isListening = false,
    this.enabled = true,
    this.size = 56,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(VoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isListening && !oldWidget.isListening) {
      _animationController.repeat(reverse: true);
    } else if (!widget.isListening && oldWidget.isListening) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ?? 
        (widget.isListening ? const Color(0xFF00D4AA) : theme.colorScheme.primary);
    final fgColor = widget.iconColor ?? Colors.white;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isListening ? _pulseAnimation.value : 1.0,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: FloatingActionButton(
              onPressed: widget.enabled ? widget.onPressed : null,
              backgroundColor: widget.enabled ? bgColor : Colors.grey,
              foregroundColor: fgColor,
              elevation: widget.isListening ? 8 : 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated rings when listening
                  if (widget.isListening)
                    SizedBox(
                      width: widget.size,
                      height: widget.size,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          fgColor.withOpacity(0.3),
                        ),
                        strokeWidth: 2,
                      ),
                    ),
                  // Icon
                  Icon(
                    widget.isListening ? Icons.mic : Icons.mic_none,
                    size: widget.size * 0.5,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated builder helper
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}

/// Voice button that integrates with voice service
class ServiceVoiceButton extends StatefulWidget {
  final VoiceService voiceService;
  final VoidCallback? onListeningStarted;
  final VoidCallback? onListeningStopped;
  final double size;

  const ServiceVoiceButton({
    super.key,
    required this.voiceService,
    this.onListeningStarted,
    this.onListeningStopped,
    this.size = 56,
  });

  @override
  State<ServiceVoiceButton> createState() => _ServiceVoiceButtonState();
}

class _ServiceVoiceButtonState extends State<ServiceVoiceButton> {
  bool _isListening = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize voice service
    widget.voiceService.initialize();
    
    // Set up callbacks
    widget.voiceService.onListeningStateChanged = (listening) {
      setState(() {
        _isListening = listening;
      });
      if (listening) {
        widget.onListeningStarted?.call();
      } else {
        widget.onListeningStopped?.call();
      }
    };
    
    widget.voiceService.onSpeakingStateChanged = (speaking) {
      setState(() {
        _isSpeaking = speaking;
      });
    };
  }

  void _handlePressed() async {
    if (_isListening) {
      await widget.voiceService.stopListening();
    } else {
      await widget.voiceService.startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VoiceButton(
      onPressed: _handlePressed,
      isListening: _isListening,
      backgroundColor: _isSpeaking 
          ? Colors.orange 
          : (_isListening ? const Color(0xFF00D4AA) : null),
    );
  }
}

/// Voice status indicator - small indicator showing voice state
class VoiceStatusIndicator extends StatelessWidget {
  final bool isListening;
  final bool isSpeaking;
  final bool isEnabled;

  const VoiceStatusIndicator({
    super.key,
    this.isListening = false,
    this.isSpeaking = false,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isEnabled) return const SizedBox.shrink();
    
    Color color;
    String tooltip;
    IconData icon;
    
    if (isListening) {
      color = const Color(0xFF00D4AA);
      tooltip = 'Voice listening...';
      icon = Icons.mic;
    } else if (isSpeaking) {
      color = Colors.orange;
      tooltip = 'Speaking...';
      icon = Icons.volume_up;
    } else {
      color = Colors.grey;
      tooltip = 'Voice ready';
      icon = Icons.mic_none;
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.2),
        ),
        child: Icon(
          icon,
          size: 14,
          color: color,
        ),
      ),
    );
  }
}