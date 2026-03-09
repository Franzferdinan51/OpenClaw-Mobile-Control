import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Conversations state
class ConversationsNotifier extends StateNotifier<AsyncValue<List<Conversation>>> {
  final GatewayApiService _apiService;
  final StorageService _storageService;

  ConversationsNotifier({
    required GatewayApiService apiService,
    required StorageService storageService,
  })  : _apiService = apiService,
        _storageService = storageService,
        super(const AsyncValue.loading());

  /// Load all conversations
  Future<void> loadConversations() async {
    state = const AsyncValue.loading();
    
    try {
      // Try to load from API first
      final conversations = await _apiService.getConversations();
      state = AsyncValue.data(conversations);
      
      // Cache locally
      for (final conv in conversations) {
        await _storageService.saveConversation(conv);
      }
    } catch (e, st) {
      // Fallback to local cache
      final localConversations = _storageService.getConversations();
      if (localConversations.isNotEmpty) {
        state = AsyncValue.data(localConversations);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Create a new conversation
  Future<Conversation?> createConversation({
    String? title,
    String? agentId,
  }) async {
    try {
      final conversation = await _apiService.createConversation(
        title: title,
        agentId: agentId,
      );
      
      // Add to current state
      final currentConvs = state.valueOrNull ?? [];
      state = AsyncValue.data([conversation, ...currentConvs]);
      
      // Save locally
      await _storageService.saveConversation(conversation);
      
      return conversation;
    } catch (e) {
      return null;
    }
  }

  /// Delete a conversation
  Future<bool> deleteConversation(String conversationId) async {
    try {
      await _apiService.deleteConversation(conversationId);
      
      // Remove from current state
      final currentConvs = state.valueOrNull ?? [];
      state = AsyncValue.data(
        currentConvs.where((c) => c.id != conversationId).toList(),
      );
      
      // Remove from local storage
      await _storageService.deleteConversation(conversationId);
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update conversation title
  Future<void> updateTitle(String conversationId, String title) async {
    final currentConvs = state.valueOrNull;
    if (currentConvs == null) return;

    final index = currentConvs.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      currentConvs[index] = currentConvs[index].copyWith(title: title);
      state = AsyncValue.data(List.from(currentConvs));
      
      await _storageService.saveConversation(currentConvs[index]);
    }
  }
}

/// Messages state for a specific conversation
class MessagesNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final GatewayApiService _apiService;
  final GatewayWebSocketService _webSocketService;
  final StorageService _storageService;
  final String conversationId;

  MessagesNotifier({
    required GatewayApiService apiService,
    required GatewayWebSocketService webSocketService,
    required StorageService storageService,
    required this.conversationId,
  })  : _apiService = apiService,
        _webSocketService = webSocketService,
        _storageService = storageService,
        super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    // Listen for incoming messages
    _webSocketService.events.listen((event) {
      if (event.type == GatewayEventType.chatMessage) {
        final message = event.chatMessage;
        if (message != null && message.conversationId == conversationId) {
          _addMessage(message);
        }
      }
    });
  }

  /// Load messages for this conversation
  Future<void> loadMessages() async {
    state = const AsyncValue.loading();
    
    try {
      // Try to load from API first
      final messages = await _apiService.getMessages(conversationId);
      state = AsyncValue.data(messages);
      
      // Cache locally
      for (final msg in messages) {
        await _storageService.saveMessage(conversationId, msg);
      }
    } catch (e, st) {
      // Fallback to local cache
      final localMessages = _storageService.getMessages(conversationId);
      if (localMessages.isNotEmpty) {
        state = AsyncValue.data(localMessages);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Send a message
  Future<ChatMessage?> sendMessage({
    required String content,
    String? agentId,
  }) async {
    // Create optimistic message
    final optimisticMessage = ChatMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    // Add optimistically
    _addMessage(optimisticMessage);

    try {
      // Send via WebSocket for real-time
      _webSocketService.sendChatMessage(
        conversationId: conversationId,
        content: content,
        agentId: agentId,
      );

      // Also send via API for persistence
      final sentMessage = await _apiService.sendMessage(
        conversationId: conversationId,
        content: content,
        agentId: agentId,
      );

      // Replace optimistic message with real one
      _replaceMessage(optimisticMessage.id, sentMessage.copyWith(
        status: MessageStatus.sent,
      ));

      // Save locally
      await _storageService.saveMessage(conversationId, sentMessage);

      return sentMessage;
    } catch (e) {
      // Mark message as failed
      _updateMessageStatus(optimisticMessage.id, MessageStatus.error);
      return null;
    }
  }

  /// Add a message to the list
  void _addMessage(ChatMessage message) {
    final currentMessages = state.valueOrNull ?? [];
    state = AsyncValue.data([...currentMessages, message]);
  }

  /// Replace a message (used for optimistic updates)
  void _replaceMessage(String oldId, ChatMessage newMessage) {
    final currentMessages = state.valueOrNull;
    if (currentMessages == null) return;

    final index = currentMessages.indexWhere((m) => m.id == oldId);
    if (index != -1) {
      currentMessages[index] = newMessage;
      state = AsyncValue.data(List.from(currentMessages));
    }
  }

  /// Update message status
  void _updateMessageStatus(String messageId, MessageStatus status) {
    final currentMessages = state.valueOrNull;
    if (currentMessages == null) return;

    final index = currentMessages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      currentMessages[index] = currentMessages[index].copyWith(status: status);
      state = AsyncValue.data(List.from(currentMessages));
    }
  }

  /// Clear messages
  void clear() {
    state = const AsyncValue.data([]);
  }
}

/// Current active conversation ID
final currentConversationIdProvider = StateProvider<String?>((ref) => null);

/// Provider for conversations list
final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, AsyncValue<List<Conversation>>>((ref) {
  final apiService = ref.watch(gatewayApiServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  
  return ConversationsNotifier(
    apiService: apiService,
    storageService: storageService,
  );
});

/// Provider for messages of a specific conversation
final messagesProvider = StateNotifierProvider.family<MessagesNotifier, AsyncValue<List<ChatMessage>>, String>((ref, conversationId) {
  final apiService = ref.watch(gatewayApiServiceProvider);
  final wsService = ref.watch(gatewayWebSocketServiceProvider);
  final storageService = ref.watch(storageServiceProvider);
  
  return MessagesNotifier(
    apiService: apiService,
    webSocketService: wsService,
    storageService: storageService,
    conversationId: conversationId,
  );
});

/// Provider for the current active conversation
final currentConversationProvider = Provider<Conversation?>((ref) {
  final conversationId = ref.watch(currentConversationIdProvider);
  if (conversationId == null) return null;
  
  final conversations = ref.watch(conversationsProvider).valueOrNull;
  return conversations?.firstWhere(
    (c) => c.id == conversationId,
    orElse: () => throw StateError('Conversation not found'),
  );
});

/// Provider for messages of the current conversation
final currentMessagesProvider = Provider<AsyncValue<List<ChatMessage>>>((ref) {
  final conversationId = ref.watch(currentConversationIdProvider);
  if (conversationId == null) {
    return const AsyncValue.data([]);
  }
  return ref.watch(messagesProvider(conversationId));
});

/// Chat input state
final chatInputProvider = StateProvider<String>((ref) => '');

/// Is typing indicator
final isTypingProvider = StateProvider<bool>((ref) => false);