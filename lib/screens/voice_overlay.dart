import 'package:flutter/material.dart';
import '../services/voice_service.dart';
import '../services/voice_commands.dart';

/// Voice overlay UI - shows listening animation and command feedback
class VoiceOverlay extends StatefulWidget {
  final VoiceService voiceService;
  final Function(CommandResult)? onCommandExecuted;
  final Function(int)? onNavigate;
  final VoidCallback onClose;

  const VoiceOverlay({
    super.key,
    required this.voiceService,
    this.onCommandExecuted,
    this.onNavigate,
    required this.onClose,
  });

  @override
  State<VoiceOverlay> createState() => _VoiceOverlayState();
}

class _VoiceOverlayState extends State<VoiceOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  
  String _recognizedText = '';
  String _responseText = '';
  bool _isListening = false;
  bool _isProcessing = false;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Set up voice service callbacks
    widget.voiceService.onResult = _onVoiceResult;
    widget.voiceService.onListeningStateChanged = _onListeningStateChanged;
    widget.voiceService.onSpeakingStateChanged = _onSpeakingStateChanged;
    
    // Start listening
    _startListening();
  }

  void _startListening() async {
    setState(() {
      _isProcessing = false;
      _showResult = false;
      _recognizedText = '';
      _responseText = '';
    });
    
    await widget.voiceService.startListening();
  }

  void _onVoiceResult(String text) {
    setState(() {
      _recognizedText = text;
    });
    
    // Check if command is complete (not partial)
    if (text.isNotEmpty && text.length > 3) {
      _processCommand(text);
    }
  }

  void _onListeningStateChanged(bool listening) {
    setState(() {
      _isListening = listening;
    });
  }

  void _onSpeakingStateChanged(bool speaking) {
    if (!speaking && _responseText.isNotEmpty) {
      // Finished speaking, show result
      setState(() {
        _showResult = true;
      });
    }
  }

  void _processCommand(String text) async {
    // Stop listening while processing
    await widget.voiceService.stopListening();
    
    setState(() {
      _isProcessing = true;
    });
    
    // Parse and execute command
    final parser = VoiceCommands();
    final result = parser.parseCommand(text);
    final response = await parser.executeCommand(result);
    
    setState(() {
      _responseText = response;
    });
    
    // Speak the response
    await widget.voiceService.speak(response);
    
    // Handle navigation
    if (result.type == CommandType.navigateDashboard) {
      widget.onNavigate?.call(0);
    } else if (result.type == CommandType.navigateChat) {
      widget.onNavigate?.call(1);
    } else if (result.type == CommandType.navigateSettings) {
      widget.onNavigate?.call(4);
    } else if (result.type == CommandType.navigateControl) {
      widget.onNavigate?.call(3);
    }
    
    widget.onCommandExecuted?.call(result);
  }

  void _cancelListening() async {
    await widget.voiceService.stopListening();
    await widget.voiceService.stopSpeaking();
    widget.onClose();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Voice Command',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: _cancelListening,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Main listening area
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated mic button
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Pulse rings
                            if (_isListening) ...[
                              Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF00D4AA)
                                          .withOpacity(1 - _waveAnimation.value),
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                              Transform.scale(
                                scale: 1 + (_waveAnimation.value * 0.3),
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF00D4AA)
                                          .withOpacity(1 - _waveAnimation.value),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            // Main circle
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isListening
                                    ? const Color(0xFF00D4AA)
                                    : Colors.grey[700],
                              ),
                              child: Icon(
                                _isListening ? Icons.mic : Icons.mic_off,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Status text
                    Text(
                      _isProcessing
                          ? 'Processing...'
                          : _isListening
                              ? 'Listening...'
                              : 'Tap to speak',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Recognized text
                    if (_recognizedText.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.record_voice_over,
                              color: Color(0xFF00D4AA),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '"$_recognizedText"',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    
                    // Response text
                    if (_responseText.isNotEmpty && _showResult)
                      Container(
                        margin: const EdgeInsets.all(32),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D4AA).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF00D4AA),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF00D4AA),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _responseText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _isProcessing ? null : _startListening,
                    icon: const Icon(Icons.mic),
                    label: const Text('Try Again'),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: _cancelListening,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                ],
              ),
            ),
            
            // Help text
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Say "OpenClaw" followed by a command',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
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