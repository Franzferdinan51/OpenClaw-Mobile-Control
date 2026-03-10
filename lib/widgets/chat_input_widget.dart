import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modern chat input widget with animations and voice support
class ChatInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onVoiceTap;
  final VoidCallback? onAttachTap;
  final VoidCallback? onAgentTap;
  final String hintText;
  final bool isLoading;
  final bool voiceAvailable;
  final bool isListening;
  final Color? accentColor;

  const ChatInputWidget({
    super.key,
    required this.controller,
    required this.onSend,
    this.onVoiceTap,
    this.onAttachTap,
    this.onAgentTap,
    this.hintText = 'Type a message...',
    this.isLoading = false,
    this.voiceAvailable = false,
    this.isListening = false,
    this.accentColor,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _sendAnimationController;
  late Animation<double> _sendScaleAnimation;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _sendAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _sendScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _sendAnimationController,
        curve: Curves.elasticOut,
      ),
    );
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _sendAnimationController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
      if (hasText) {
        _sendAnimationController.forward();
      } else {
        _sendAnimationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = widget.accentColor ?? colorScheme.primary;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: bottomPadding + 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withAlpha(60),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Left action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onAgentTap != null)
                _buildActionButton(
                  icon: Icons.psychology_rounded,
                  onTap: widget.onAgentTap!,
                  color: accentColor,
                  tooltip: 'Select Agent',
                ),
              if (widget.onAttachTap != null)
                _buildActionButton(
                  icon: Icons.attach_file_rounded,
                  onTap: widget.onAttachTap!,
                  tooltip: 'Attach file',
                ),
            ],
          ),
          const SizedBox(width: 4),
          // Text input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: _hasText
                    ? Border.all(color: accentColor.withAlpha(40), width: 1.5)
                    : null,
              ),
              child: TextField(
                controller: widget.controller,
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                enabled: !widget.isLoading,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withAlpha(160),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) {
                  if (_hasText) {
                    HapticFeedback.lightImpact();
                    widget.onSend();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Right action button (send or voice)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: _hasText
                ? ScaleTransition(
                    scale: _sendScaleAnimation,
                    child: _buildSendButton(context, colorScheme, accentColor),
                  )
                : _buildVoiceButton(context, colorScheme, accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    Color? color,
  }) {
    return IconButton(
      icon: Icon(icon),
      onPressed: onTap,
      tooltip: tooltip,
      color: color,
      iconSize: 22,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildSendButton(
    BuildContext context,
    ColorScheme colorScheme,
    Color accentColor,
  ) {
    // Use a slightly lighter shade for gradient
        final lighterColor = Color.lerp(accentColor, Colors.white, 0.15) ?? accentColor;
        return Container(
      key: const ValueKey('send'),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentColor, lighterColor],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(80),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: widget.isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.send_rounded, color: Colors.white),
        onPressed: widget.isLoading ? null : widget.onSend,
        tooltip: 'Send',
      ),
    );
  }

  Widget _buildVoiceButton(
    BuildContext context,
    ColorScheme colorScheme,
    Color accentColor,
  ) {
    final isListening = widget.isListening;
    final voiceAvailable = widget.voiceAvailable;

    return Container(
      key: const ValueKey('voice'),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isListening ? colorScheme.error : colorScheme.surfaceContainerHigh,
        shape: BoxShape.circle,
        boxShadow: isListening
            ? [
                BoxShadow(
                  color: colorScheme.error.withAlpha(80),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: IconButton(
        icon: Icon(
          isListening ? Icons.stop_rounded : Icons.mic_rounded,
          color: isListening ? Colors.white : colorScheme.onSurfaceVariant,
        ),
        onPressed: voiceAvailable ? widget.onVoiceTap : null,
        tooltip: isListening ? 'Stop' : 'Voice input',
      ),
    );
  }
}

/// Date separator widget for message groups
class DateSeparator extends StatelessWidget {
  final DateTime date;

  const DateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final difference = now.difference(date);

    String text;
    if (difference.inDays == 0) {
      text = 'Today';
    } else if (difference.inDays == 1) {
      text = 'Yesterday';
    } else if (difference.inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      text = weekdays[date.weekday - 1];
    } else {
      text = '${date.month}/${date.day}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: colorScheme.outlineVariant.withAlpha(60),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: colorScheme.outlineVariant.withAlpha(60),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state widget for chat
class EmptyChatState extends StatelessWidget {
  final VoidCallback? onSuggestionTap;
  final List<String>? suggestions;

  const EmptyChatState({
    super.key,
    this.onSuggestionTap,
    this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final defaultSuggestions = suggestions ??
        [
          'What can you do?',
          'Check system status',
          'Help me with a task',
        ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.tertiaryContainer,
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withAlpha(40),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '🦆',
                  style: const TextStyle(fontSize: 48),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Start a Conversation',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Type a message or use voice input to chat with DuckBot.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: defaultSuggestions.map((suggestion) {
                return ActionChip(
                  label: Text(suggestion),
                  onPressed: onSuggestionTap != null
                      ? () {
                          // This would be handled by parent
                        }
                      : null,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  side: BorderSide(color: colorScheme.outlineVariant.withAlpha(60)),
                  labelStyle: TextStyle(color: colorScheme.primary),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Message search widget
class MessageSearchWidget extends StatefulWidget {
  final Function(String query) onSearch;
  final VoidCallback? onClose;
  final String? hintText;

  const MessageSearchWidget({
    super.key,
    required this.onSearch,
    this.onClose,
    this.hintText,
  });

  @override
  State<MessageSearchWidget> createState() => _MessageSearchWidgetState();
}

class _MessageSearchWidgetState extends State<MessageSearchWidget> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withAlpha(60)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onClose,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.hintText ?? 'Search messages...',
                  border: InputBorder.none,
                ),
                onChanged: widget.onSearch,
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  widget.onSearch('');
                },
              ),
          ],
        ),
      ),
    );
  }
}