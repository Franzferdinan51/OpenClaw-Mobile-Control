import 'dart:math' show pi, sin;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

/// Message sender type
enum MessageSender {
  user,
  agent,
  system,
}

/// Message status
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  error,
}

/// Represents a chat message
class MessageData {
  final String id;
  final String content;
  final MessageSender sender;
  final DateTime timestamp;
  final MessageStatus status;
  final String? senderName;
  final String? senderAvatar;
  final bool isMarkdown;
  final String? error;

  const MessageData({
    required this.id,
    required this.content,
    required this.sender,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.senderName,
    this.senderAvatar,
    this.isMarkdown = true,
    this.error,
  });
}

/// A Material 3 styled message bubble for chat interfaces.
/// 
/// Features:
/// - Different styles for user/agent/system messages
/// - Markdown rendering support
/// - Timestamp display
/// - Status indicators
/// - Avatar support
/// - Copy to clipboard
/// 
/// Usage:
/// ```dart
/// MessageBubble(
///   message: MessageData(
///     id: '1',
///     content: 'Hello, how can I help?',
///     sender: MessageSender.agent,
///     timestamp: DateTime.now(),
///   ),
/// )
/// ```
class MessageBubble extends StatelessWidget {
  /// The message data to display
  final MessageData message;
  
  /// Whether to show the timestamp
  final bool showTimestamp;
  
  /// Whether to show the sender avatar
  final bool showAvatar;
  
  /// Whether to enable markdown rendering
  final bool enableMarkdown;
  
  /// Callback when message is long-pressed
  final VoidCallback? onLongPress;
  
  /// Callback when message is tapped
  final VoidCallback? onTap;
  
  /// Maximum width percentage of screen (0.0 - 1.0)
  final double maxWidth;

  const MessageBubble({
    super.key,
    required this.message,
    this.showTimestamp = true,
    this.showAvatar = false,
    this.enableMarkdown = true,
    this.onLongPress,
    this.onTap,
    this.maxWidth = 0.8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUser = message.sender == MessageSender.user;
    final isSystem = message.sender == MessageSender.system;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser && showAvatar) ...[
              _buildAvatar(theme, 32),
              const SizedBox(width: 8),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * maxWidth,
              ),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (message.senderName != null && !isUser && !isSystem)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 4),
                      child: Text(
                        message.senderName!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: onTap,
                    onLongPress: onLongPress ?? () => _showMessageOptions(context),
                    child: _buildBubble(context, theme, colorScheme, isUser, isSystem),
                  ),
                  if (showTimestamp) ...[
                    const SizedBox(height: 4),
                    _buildTimestampAndStatus(context, theme, colorScheme, isUser),
                  ],
                ],
              ),
            ),
            if (isUser && showAvatar) ...[
              const SizedBox(width: 8),
              _buildAvatar(theme, 32),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBubble(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isUser,
    bool isSystem,
  ) {
    final backgroundColor = _getBackgroundColor(colorScheme, isUser, isSystem);
    final foregroundColor = _getForegroundColor(colorScheme, isUser, isSystem);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: _getBorderRadius(isUser, isSystem),
        border: isSystem ? Border.all(color: colorScheme.outlineVariant) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.error != null) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 14, color: colorScheme.error),
                const SizedBox(width: 4),
                Text(
                  'Error',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          _buildContent(context, theme, foregroundColor),
          if (message.error != null) ...[
            const SizedBox(height: 4),
            Text(
              message.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, Color foregroundColor) {
    if (!enableMarkdown || !message.isMarkdown) {
      return SelectableText(
        message.content,
        style: theme.textTheme.bodyMedium?.copyWith(color: foregroundColor),
      );
    }
    
    return MarkdownBody(
      data: message.content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: theme.textTheme.bodyMedium?.copyWith(color: foregroundColor),
        code: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        blockquote: theme.textTheme.bodyMedium?.copyWith(
          color: foregroundColor.withOpacity(0.8),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: foregroundColor.withOpacity(0.3), width: 3),
          ),
        ),
      ),
      onTapLink: (text, href, title) {
        if (href != null) {
          // Launch URL
        }
      },
    );
  }

  Widget _buildAvatar(ThemeData theme, double size) {
    final colorScheme = theme.colorScheme;
    final isUser = message.sender == MessageSender.user;
    
    if (message.senderAvatar != null) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(message.senderAvatar!),
      );
    }
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUser ? colorScheme.primary : colorScheme.secondaryContainer,
      ),
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        size: size * 0.5,
        color: isUser ? colorScheme.onPrimary : colorScheme.onSecondaryContainer,
      ),
    );
  }

  Widget _buildTimestampAndStatus(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isUser,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTimestamp(message.timestamp),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 4),
            _buildStatusIcon(colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon(ColorScheme colorScheme) {
    IconData icon;
    Color color;
    
    switch (message.status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        color = colorScheme.onSurfaceVariant;
      case MessageStatus.sent:
        icon = Icons.check;
        color = colorScheme.onSurfaceVariant;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = colorScheme.onSurfaceVariant;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = colorScheme.primary;
      case MessageStatus.error:
        icon = Icons.error_outline;
        color = colorScheme.error;
    }
    
    return Icon(icon, size: 14, color: color);
  }

  Color _getBackgroundColor(ColorScheme colorScheme, bool isUser, bool isSystem) {
    if (isSystem) {
      return colorScheme.surfaceContainerHighest;
    }
    if (isUser) {
      return colorScheme.primary;
    }
    return colorScheme.secondaryContainer;
  }

  Color _getForegroundColor(ColorScheme colorScheme, bool isUser, bool isSystem) {
    if (isSystem) {
      return colorScheme.onSurface;
    }
    if (isUser) {
      return colorScheme.onPrimary;
    }
    return colorScheme.onSecondaryContainer;
  }

  BorderRadius _getBorderRadius(bool isUser, bool isSystem) {
    if (isSystem) {
      return BorderRadius.circular(12);
    }
    if (isUser) {
      return const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      );
    }
    return const BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) {
      return DateFormat.jm().format(timestamp);
    }
    if (difference.inDays < 7) {
      return DateFormat.E().add_jm().format(timestamp);
    }
    return DateFormat.MMMd().format(timestamp);
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                // Copy to clipboard
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                // Share message
              },
            ),
            if (message.sender == MessageSender.agent)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Regenerate'),
                onTap: () {
                  Navigator.pop(context);
                  // Regenerate response
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// A typing indicator for when the agent is composing a response
class TypingIndicator extends StatefulWidget {
  /// Whether to show the indicator
  final bool isTyping;
  
  /// Size of the dots
  final double dotSize;
  
  /// Color of the dots (defaults to theme)
  final Color? color;

  const TypingIndicator({
    super.key,
    this.isTyping = true,
    this.dotSize = 8,
    this.color,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(begin: 0, end: 1).animate(
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
    if (!widget.isTyping) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.onSurfaceVariant;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final delay = index * 0.2;
              final value = ((_animation.value - delay) % 1.0).clamp(0.0, 1.0);
              final opacity = (sin(value * pi * 2) + 1) / 2 * 0.6 + 0.2;
              
              return Padding(
                padding: EdgeInsets.only(right: index < 2 ? 4 : 0),
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(opacity),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

