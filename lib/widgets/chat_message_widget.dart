/// Chat Message Widget
/// 
/// A message widget that works with ChatMessageUI and supports
/// inline widgets like charts and weather displays.
///
/// Features:
/// - Text messages with markdown support
/// - Inline chart widgets
/// - Inline weather widgets
/// - Animations and touch feedback
/// - Material 3 styling

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';
import '../services/chat_service.dart';
import 'inline_chart_widget.dart';

/// Chat message bubble with inline widget support
class ChatMessageWidget extends StatefulWidget {
  final ChatMessageUI message;
  final bool showTimestamp;
  final bool showAvatar;
  final bool enableMarkdown;
  final VoidCallback? onRetry;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final double maxWidth;
  final bool showStatus;

  const ChatMessageWidget({
    super.key,
    required this.message,
    this.showTimestamp = true,
    this.showAvatar = true,
    this.enableMarkdown = true,
    this.onRetry,
    this.onDelete,
    this.onTap,
    this.maxWidth = 0.85,
    this.showStatus = true,
  });

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
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
    final isUser = widget.message.isUser;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser && widget.showAvatar) ...[
              _buildAvatar(theme, 32),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (widget.message.agentName != null && !isUser)
                    _buildSenderName(theme, colorScheme),
                  GestureDetector(
                    onLongPress: () => _showMessageOptions(context),
                    child: _buildContent(context, theme, colorScheme, isUser),
                  ),
                  if (widget.showTimestamp)
                    _buildTimestamp(theme, colorScheme, isUser),
                ],
              ),
            ),
            if (isUser && widget.showAvatar) ...[
              const SizedBox(width: 8),
              _buildAvatar(theme, 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSenderName(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.message.agentEmoji != null) ...[
            Text(
              widget.message.agentEmoji!,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            widget.message.agentName!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isUser,
  ) {
    // If this is a chart-only message
    if (widget.message.chartOnly && widget.message.hasChartWidget) {
      return InlineChartWidget(
        chartData: widget.message.chartWidget!,
        maxWidth: 350,
        height: 180,
      );
    }

    // If message has both text and chart
    if (widget.message.hasChartWidget) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.message.content.isNotEmpty)
            _buildTextBubble(context, theme, colorScheme, isUser),
          const SizedBox(height: 8),
          InlineChartWidget(
            chartData: widget.message.chartWidget!,
            maxWidth: 350,
            height: 180,
            compact: true,
          ),
        ],
      );
    }

    // Regular text message
    return _buildTextBubble(context, theme, colorScheme, isUser);
  }

  Widget _buildTextBubble(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isUser,
  ) {
    final backgroundColor = isUser
        ? colorScheme.primary
        : colorScheme.surfaceContainerHigh;
    final foregroundColor = isUser
        ? colorScheme.onPrimary
        : colorScheme.onSurface;
    final borderRadius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          );

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * widget.maxWidth,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: _buildTextContent(theme, foregroundColor),
    );
  }

  Widget _buildTextContent(ThemeData theme, Color foregroundColor) {
    if (!widget.enableMarkdown) {
      return SelectableText(
        widget.message.content,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: foregroundColor,
          height: 1.4,
        ),
      );
    }

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
          backgroundColor: Colors.black.withOpacity(0.1),
        ),
        codeblockPadding: const EdgeInsets.all(8),
        codeblockDecoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
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
        listBullet: theme.textTheme.bodyMedium?.copyWith(color: foregroundColor),
        tableBody: theme.textTheme.bodySmall?.copyWith(color: foregroundColor),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, double size) {
    final colorScheme = theme.colorScheme;
    final isUser = widget.message.isUser;

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
              : [colorScheme.tertiary, colorScheme.tertiary.withOpacity(0.7)],
        ),
        boxShadow: [
          BoxShadow(
            color: (isUser ? colorScheme.primary : colorScheme.tertiary)
                .withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: widget.message.agentEmoji != null && !isUser
            ? Text(
                widget.message.agentEmoji!,
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

  Widget _buildTimestamp(ThemeData theme, ColorScheme colorScheme, bool isUser) {
    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 0 : 4,
        right: isUser ? 4 : 0,
        top: 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTimestamp(widget.message.timestamp),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withOpacity(0.6),
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
      case ChatMessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onSurfaceVariant),
          ),
        );
      case ChatMessageStatus.sent:
        icon = Icons.check;
        color = colorScheme.onSurfaceVariant.withOpacity(0.6);
      case ChatMessageStatus.delivered:
        icon = Icons.done_all;
        color = colorScheme.onSurfaceVariant.withOpacity(0.6);
      case ChatMessageStatus.error:
        icon = Icons.error_outline;
        color = colorScheme.error;
        size = 16;
    }

    return Icon(icon, size: size, color: color);
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
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
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
            if (widget.message.hasChartWidget)
              ListTile(
                leading: const Icon(Icons.save_alt),
                title: const Text('Save Chart'),
                subtitle: const Text('Export chart as image'),
                onTap: () {
                  Navigator.pop(context);
                  // Chart export would go here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chart export coming soon'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            if (widget.message.isUser && widget.onDelete != null)
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

/// Chat message list with inline chart support
class ChatMessageList extends StatelessWidget {
  final List<ChatMessageUI> messages;
  final ScrollController? controller;
  final bool showTimestamps;
  final bool showAvatars;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;

  const ChatMessageList({
    super.key,
    required this.messages,
    this.controller,
    this.showTimestamps = true,
    this.showAvatars = true,
    this.onLoadMore,
    this.isLoadingMore = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length && isLoadingMore) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final message = messages[index];
        return ChatMessageWidget(
          message: message,
          showTimestamp: showTimestamps,
          showAvatar: showAvatars,
        );
      },
    );
  }
}