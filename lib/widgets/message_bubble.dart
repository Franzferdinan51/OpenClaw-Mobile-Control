import 'dart:math' show pi, sin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';

/// Message sender type
enum MessageSender {
  user,
  agent,
  system,
}

/// Message delivery status
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  error,
}

/// Represents a chat message with all metadata
class MessageData {
  final String id;
  final String content;
  final MessageSender sender;
  final DateTime timestamp;
  final MessageStatus status;
  final String? senderName;
  final String? senderEmoji;
  final Color? senderColor;
  final bool isMarkdown;
  final String? error;
  final bool canRetry;

  const MessageData({
    required this.id,
    required this.content,
    required this.sender,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.senderName,
    this.senderEmoji,
    this.senderColor,
    this.isMarkdown = true,
    this.error,
    this.canRetry = true,
  });
}

/// Modern Material 3 message bubble with WhatsApp/Telegram-style design
class MessageBubble extends StatefulWidget {
  final MessageData message;
  final bool showTimestamp;
  final bool showAvatar;
  final bool enableMarkdown;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final double maxWidth;
  final bool showStatus;

  const MessageBubble({
    super.key,
    required this.message,
    this.showTimestamp = true,
    this.showAvatar = true,
    this.enableMarkdown = true,
    this.onRetry,
    this.onDelete,
    this.onTap,
    this.maxWidth = 0.8,
    this.showStatus = true,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUser = widget.message.sender == MessageSender.user;
    final isSystem = widget.message.sender == MessageSender.system;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                mainAxisAlignment: isUser
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isUser && !isSystem && widget.showAvatar) ...[
                    _buildAvatar(theme, 28),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * widget.maxWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: isUser
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (widget.message.senderName != null &&
                              !isUser &&
                              !isSystem)
                            _buildSenderName(theme, colorScheme),
                          GestureDetector(
                            onTapDown: (_) {
                              _animationController.forward();
                            },
                            onTapUp: (_) {
                              _animationController.reverse();
                              widget.onTap?.call();
                            },
                            onTapCancel: () {
                              _animationController.reverse();
                            },
                            onLongPress: () => _showMessageOptions(context),
                            child: Material(
                              color: Colors.transparent,
                              child: _buildBubble(
                                context,
                                theme,
                                colorScheme,
                                isUser,
                                isSystem,
                              ),
                            ),
                          ),
                          if (widget.showTimestamp) ...[
                            const SizedBox(height: 2),
                            _buildTimestampAndStatus(theme, colorScheme, isUser),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (isUser && widget.showAvatar) ...[
                    const SizedBox(width: 8),
                    _buildAvatar(theme, 28),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSenderName(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.message.senderEmoji != null) ...[
            Text(
              widget.message.senderEmoji!,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            widget.message.senderName!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: widget.message.senderColor ?? colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
    final borderRadius = _getBorderRadius(isUser, isSystem);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: isSystem
            ? Border.all(color: colorScheme.outline.withAlpha(30))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.message.error != null) _buildErrorHeader(theme, colorScheme),
          if (widget.message.error != null) const SizedBox(height: 6),
          _buildContent(context, theme, foregroundColor),
          if (widget.message.error != null) ...[
            const SizedBox(height: 6),
            if (widget.message.canRetry && widget.onRetry != null)
              TextButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Retry', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorHeader(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 14, color: colorScheme.error),
        const SizedBox(width: 4),
        Text(
          'Failed to send',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
      BuildContext context, ThemeData theme, Color foregroundColor) {
    if (!widget.enableMarkdown || !widget.message.isMarkdown) {
      return SelectableText(
        widget.message.content,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: foregroundColor,
          height: 1.4,
        ),
      );
    }

    // Try markdown, fall back to plain text if package not available
    try {
      return MarkdownBody(
        data: widget.message.content,
        selectable: true,
        shrinkWrap: true,
        styleSheet: MarkdownStyleSheet(
          p: theme.textTheme.bodyMedium?.copyWith(
            color: foregroundColor,
            height: 1.4,
          ),
          code: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Colors.black.withAlpha(20),
          ),
          codeblockPadding: const EdgeInsets.all(8),
          codeblockDecoration: BoxDecoration(
            color: Colors.black.withAlpha(15),
            borderRadius: BorderRadius.circular(8),
          ),
          blockquote: theme.textTheme.bodyMedium?.copyWith(
            color: foregroundColor.withAlpha(200),
            fontStyle: FontStyle.italic,
          ),
          blockquoteDecoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: foregroundColor.withAlpha(80), width: 3),
            ),
          ),
          listBullet: theme.textTheme.bodyMedium?.copyWith(color: foregroundColor),
          tableBody: theme.textTheme.bodySmall?.copyWith(color: foregroundColor),
        ),
      );
    } catch (e) {
      // Fallback to plain text if markdown fails
      return SelectableText(
        widget.message.content,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: foregroundColor,
          height: 1.4,
        ),
      );
    }
  }

  Widget _buildAvatar(ThemeData theme, double size) {
    final colorScheme = theme.colorScheme;
    final isUser = widget.message.sender == MessageSender.user;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isUser
              ? [colorScheme.primary, colorScheme.primary.withBlue(255)]
              : [
                  colorScheme.tertiary,
                  colorScheme.tertiary.withAlpha(180),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: (isUser ? colorScheme.primary : colorScheme.tertiary)
                .withAlpha(60),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: widget.message.senderEmoji != null
            ? Text(
                widget.message.senderEmoji!,
                style: TextStyle(fontSize: size * 0.5),
              )
            : Icon(
                isUser ? Icons.person : Icons.smart_toy,
                size: size * 0.5,
                color: Colors.white,
              ),
      ),
    );
  }

  Widget _buildTimestampAndStatus(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isUser,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 0 : 12,
        right: isUser ? 12 : 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTimestamp(widget.message.timestamp),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withAlpha(160),
              fontSize: 10,
            ),
          ),
          if (isUser && widget.showStatus) ...[
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
    double size = 14;

    switch (widget.message.status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor:
                AlwaysStoppedAnimation<Color>(colorScheme.onSurfaceVariant),
          ),
        );
      case MessageStatus.sent:
        icon = Icons.check;
        color = colorScheme.onSurfaceVariant.withAlpha(160);
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = colorScheme.onSurfaceVariant.withAlpha(160);
      case MessageStatus.read:
        icon = Icons.done_all;
        color = const Color(0xFF4FC3F7); // WhatsApp-style blue
      case MessageStatus.error:
        icon = Icons.error_outline;
        color = colorScheme.error;
        size = 16;
    }

    return Icon(icon, size: size, color: color);
  }

  Color _getBackgroundColor(
      ColorScheme colorScheme, bool isUser, bool isSystem) {
    if (isSystem) {
      return colorScheme.surfaceContainerHighest;
    }
    if (isUser) {
      return colorScheme.primary;
    }
    return colorScheme.surfaceContainerHigh;
  }

  Color _getForegroundColor(
      ColorScheme colorScheme, bool isUser, bool isSystem) {
    if (isSystem) {
      return colorScheme.onSurface;
    }
    if (isUser) {
      return colorScheme.onPrimary;
    }
    return colorScheme.onSurface;
  }

  BorderRadius _getBorderRadius(bool isUser, bool isSystem) {
    if (isSystem) {
      return BorderRadius.circular(12);
    }
    if (isUser) {
      return const BorderRadius.only(
        topLeft: Radius.circular(18),
        topRight: Radius.circular(4),
        bottomLeft: Radius.circular(18),
        bottomRight: Radius.circular(18),
      );
    }
    return const BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(18),
      bottomLeft: Radius.circular(18),
      bottomRight: Radius.circular(18),
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
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy'),
              subtitle: const Text('Copy message text'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: widget.message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share'),
              subtitle: const Text('Share this message'),
              onTap: () {
                Navigator.pop(context);
                // Share functionality would go here
              },
            ),
            if (widget.message.sender == MessageSender.user &&
                widget.onDelete != null)
              ListTile(
                leading: Icon(
                  Icons.delete_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDelete?.call();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Animated typing indicator with bouncing dots
class TypingIndicator extends StatefulWidget {
  final bool isTyping;
  final double dotSize;
  final Color? color;
  final String? text;

  const TypingIndicator({
    super.key,
    this.isTyping = true,
    this.dotSize = 8,
    this.color,
    this.text,
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
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  final delay = index * 0.2;
                  final value = ((_animation.value - delay) % 1.0).clamp(0.0, 1.0);
                  final bounce = (sin(value * pi * 2) + 1) / 2;
                  final opacity = bounce * 0.7 + 0.3;

                  return Container(
                    margin: EdgeInsets.only(
                      right: index < 2 ? 4 : 0,
                      bottom: bounce * 4,
                    ),
                    width: widget.dotSize,
                    height: widget.dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withAlpha((opacity * 255).round()),
                    ),
                  );
                }),
              );
            },
          ),
          if (widget.text != null) ...[
            const SizedBox(width: 8),
            Text(
              widget.text!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}