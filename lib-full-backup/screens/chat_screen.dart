import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

/// Chat Screen - Direct chat interface with message list, input, and voice support
class ChatScreen extends ConsumerStatefulWidget {
  final String? conversationId;

  const ChatScreen({super.key, this.conversationId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  stt.SpeechToText? _speech;
  bool _isListening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initConversation();
  }

  void _initSpeech() async {
    _speech = stt.SpeechToText();
    _speechAvailable = await _speech!.initialize(
      onError: (error) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    setState(() {});
  }

  void _initConversation() {
    if (widget.conversationId != null) {
      ref.read(currentConversationIdProvider.notifier).state = widget.conversationId;
      ref.read(messagesProvider(widget.conversationId!).notifier).loadMessages();
    } else {
      // Create new conversation
      ref.read(conversationsProvider.notifier).createConversation().then((conv) {
        if (conv != null) {
          ref.read(currentConversationIdProvider.notifier).state = conv.id;
        }
      });
    }

    // Load conversations list
    ref.read(conversationsProvider.notifier).loadConversations();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _speech?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final conversationId = ref.watch(currentConversationIdProvider);
    final messagesState = conversationId != null
        ? ref.watch(messagesProvider(conversationId))
        : const AsyncValue<List<ChatMessage>>.data([]);
    final isTyping = ref.watch(isTypingProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(context, conversationId),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => _showConversationsList(context),
            tooltip: 'Chat History',
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value, conversationId),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new',
                child: ListTile(
                  leading: Icon(Icons.add_rounded),
                  title: Text('New Chat'),
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  leading: Icon(Icons.clear_all_rounded),
                  title: Text('Clear Chat'),
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download_rounded),
                  title: Text('Export'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection banner
          const ConnectionBanner(),
          // Message list
          Expanded(
            child: _buildMessageList(
              context,
              messagesState,
              isTyping,
              settings,
            ),
          ),
          // Input area
          _buildInputArea(context, colorScheme, conversationId),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildAppBarTitle(BuildContext context, String? conversationId) {
    final theme = Theme.of(context);
    final conversation = ref.watch(currentConversationProvider);

    return GestureDetector(
      onTap: () => _showConversationsList(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conversation?.title ?? 'New Chat',
            style: theme.textTheme.titleMedium,
          ),
          if (conversation?.agentId != null)
            Text(
              'Agent: ${conversation!.agentId}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageList(
    BuildContext context,
    AsyncValue<List<ChatMessage>> messagesState,
    bool isTyping,
    AppSettings settings,
  ) {
    if (messagesState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (messagesState.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Failed to load messages'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                final conversationId = ref.read(currentConversationIdProvider);
                if (conversationId != null) {
                  ref.read(messagesProvider(conversationId).notifier).loadMessages();
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final messages = messagesState.valueOrNull ?? [];

    if (messages.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length + (isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length && isTyping) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: TypingIndicator(isTyping: true),
          );
        }

        final message = messages[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _ChatMessageBubble(
            message: message,
            showTimestamp: settings.showTimestamps,
            showTokenCount: settings.showTokenCounts,
            enableMarkdown: settings.markdownEnabled,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Start a Conversation',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Type a message or use voice input to chat with your AI assistant.',
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
              children: [
                _SuggestionChip(
                  label: 'What can you do?',
                  onTap: () => _sendSuggestion('What can you do?'),
                ),
                _SuggestionChip(
                  label: 'Help me with a task',
                  onTap: () => _sendSuggestion('Help me with a task'),
                ),
                _SuggestionChip(
                  label: 'Check system status',
                  onTap: () => _sendSuggestion('Check system status'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(
    BuildContext context,
    ColorScheme colorScheme,
    String? conversationId,
  ) {
    final hasText = _messageController.text.isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment button
          IconButton(
            onPressed: () => _showAttachmentOptions(context),
            icon: Icon(
              Icons.attach_file_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Attach file',
          ),
          // Text input
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _sendMessage(conversationId),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Voice or Send button
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: hasText
                ? FloatingActionButton.small(
                    key: const ValueKey('send'),
                    onPressed: () => _sendMessage(conversationId),
                    child: const Icon(Icons.send_rounded),
                  )
                : FloatingActionButton.small(
                    key: const ValueKey('voice'),
                    onPressed: _speechAvailable ? _toggleListening : null,
                    backgroundColor:
                        _isListening ? colorScheme.error : colorScheme.primary,
                    child: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: colorScheme.onPrimary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return NavigationBar(
      selectedIndex: 1,
      onDestinationSelected: (index) => _navigateTo(context, index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_outlined),
          selectedIcon: Icon(Icons.chat),
          label: 'Chat',
        ),
        NavigationDestination(
          icon: Icon(Icons.gamepad_outlined),
          selectedIcon: Icon(Icons.gamepad),
          label: 'Control',
        ),
        NavigationDestination(
          icon: Icon(Icons.bolt_outlined),
          selectedIcon: Icon(Icons.bolt),
          label: 'Quick',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }

  void _navigateTo(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
      case 2:
        context.go('/control');
      case 3:
        context.go('/quick-actions');
      case 4:
        context.go('/settings');
    }
  }

  void _sendMessage(String? conversationId) {
    if (conversationId == null) return;

    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    _scrollToBottom();

    ref.read(messagesProvider(conversationId).notifier).sendMessage(
          content: content,
          agentId: ref.read(settingsProvider).defaultAgentId,
        );
  }

  void _sendSuggestion(String text) {
    _messageController.text = text;
    final conversationId = ref.read(currentConversationIdProvider);
    _sendMessage(conversationId);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleListening() async {
    if (!_speechAvailable || _speech == null) return;

    if (_isListening) {
      await _speech!.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech!.listen(
        onResult: (result) {
          setState(() {
            _messageController.text = result.recognizedWords;
          });
          if (result.finalResult) {
            setState(() => _isListening = false);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    }
  }

  void _showConversationsList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ConversationsSheet(
        onSelect: (conv) {
          ref.read(currentConversationIdProvider.notifier).state = conv.id;
          ref.read(messagesProvider(conv.id).notifier).loadMessages();
        },
      ),
    );
  }

  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_rounded),
              title: const Text('Image'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement image picker
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_rounded),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement file picker
              },
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded),
              title: const Text('Code Snippet'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement code input
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action, String? conversationId) {
    switch (action) {
      case 'new':
        ref.read(conversationsProvider.notifier).createConversation().then((conv) {
          if (conv != null) {
            ref.read(currentConversationIdProvider.notifier).state = conv.id;
            ref.read(messagesProvider(conv.id).notifier).clear();
          }
        });
      case 'clear':
        if (conversationId != null) {
          ref.read(messagesProvider(conversationId).notifier).clear();
        }
      case 'export':
        // TODO: Implement export
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export coming soon...')),
        );
    }
  }
}

/// Custom message bubble widget
class _ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showTimestamp;
  final bool showTokenCount;
  final bool enableMarkdown;

  const _ChatMessageBubble({
    required this.message,
    required this.showTimestamp,
    required this.showTokenCount,
    required this.enableMarkdown,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isUser = message.role == MessageRole.user;

    final senderType = isUser ? MessageSender.user : MessageSender.agent;
    final status = _mapStatus(message.status);

    final messageData = MessageData(
      id: message.id,
      content: message.content,
      sender: senderType,
      timestamp: message.timestamp,
      status: status,
      senderName: isUser ? 'You' : 'Assistant',
      isMarkdown: enableMarkdown && !isUser,
      error: message.status == MessageStatus.error ? 'Failed to send' : null,
    );

    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        MessageBubble(
          message: messageData,
          showTimestamp: showTimestamp,
          enableMarkdown: enableMarkdown,
          maxWidth: 0.85,
        ),
        if (showTokenCount && message.metadata?.tokensUsed != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${message.metadata!.tokensUsed} tokens',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  MessageStatus _mapStatus(ChatMessageStatus status) {
    switch (status) {
      case ChatMessageStatus.sending:
        return MessageStatus.sending;
      case ChatMessageStatus.sent:
        return MessageStatus.sent;
      case ChatMessageStatus.delivered:
        return MessageStatus.delivered;
      case ChatMessageStatus.read:
        return MessageStatus.read;
      case ChatMessageStatus.error:
        return MessageStatus.error;
    }
  }
}

/// Suggestion chip for empty state
class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: BorderSide(color: colorScheme.outlineVariant),
    );
  }
}

/// Conversations list bottom sheet
class _ConversationsSheet extends ConsumerWidget {
  final void Function(Conversation) onSelect;

  const _ConversationsSheet({required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final conversationsState = ref.watch(conversationsProvider);
    final currentId = ref.watch(currentConversationIdProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Chat History',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        ref.read(conversationsProvider.notifier).createConversation();
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // List
              Expanded(
                child: conversationsState.when(
                  data: (conversations) {
                    if (conversations.isEmpty) {
                      return Center(
                        child: Text(
                          'No conversations yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conv = conversations[index];
                        final isSelected = conv.id == currentId;

                        return ListTile(
                          selected: isSelected,
                          leading: CircleAvatar(
                            backgroundColor: isSelected
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 20,
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          title: Text(
                            conv.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: conv.lastMessage != null
                              ? Text(
                                  conv.lastMessage!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                )
                              : null,
                          trailing: Text(
                            _formatDate(conv.updatedAt),
                            style: theme.textTheme.labelSmall,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            onSelect(conv);
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[date.weekday - 1];
    } else {
      return '${date.month}/${date.day}';
    }
  }
}