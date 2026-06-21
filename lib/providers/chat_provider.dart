import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/attachment.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/conversation_store.dart';
import '../services/feedback_service.dart';
import '../services/openrouter_service.dart';
import 'app_providers.dart';
import 'settings_provider.dart';
import 'usage_provider.dart';

/// Riverpod provider for chat state.
final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

/// Immutable snapshot of chat state exposed to the UI.
class ChatState {
  const ChatState({
    required List<Conversation> conversations,
    required this.current,
    required this.loading,
    required this.isResponding,
    required this.error,
  }) : _conversations = conversations;

  final List<Conversation> _conversations;
  final Conversation? current;
  final bool loading;
  final bool isResponding;
  final String? error;

  List<Conversation> get conversations => List.unmodifiable(_conversations);
}

/// Owns the list of conversations and drives sending/streaming of messages.
class ChatNotifier extends Notifier<ChatState> {
  late final OpenRouterService _service;
  late final ConversationStore _store;
  final _uuid = const Uuid();

  List<Conversation> _conversations = [];
  Conversation? _current;
  bool _loading = true;
  bool _isResponding = false;
  String? _error;
  StreamSubscription<String>? _sub;

  // Lazy loading: conversations load as metadata-only "shells"; a chat's
  // messages are loaded the first time it's opened. Tracks which are loaded and
  // de-duplicates concurrent loads.
  final Set<String> _loadedIds = {};
  final Map<String, Future<void>> _loadingFutures = {};

  // Coalesces rapid streaming deltas into at most ~16 UI updates/second so the
  // Markdown body isn't re-parsed on every single token.
  Timer? _streamThrottle;
  bool _streamDirty = false;
  static const _streamInterval = Duration(milliseconds: 60);

  @override
  ChatState build() {
    _service = ref.read(openRouterServiceProvider);
    _store = ref.read(conversationStoreProvider);
    ref.onDispose(() {
      _streamThrottle?.cancel();
      _sub?.cancel();
    });
    _init();
    return _snapshot();
  }

  ChatState _snapshot() => ChatState(
        conversations: List.unmodifiable(_conversations),
        current: _current,
        loading: _loading,
        isResponding: _isResponding,
        error: _error,
      );

  /// Sorts [_conversations] in place for display: pinned first, then by
  /// recency. Called only when the order can actually change (load, pin,
  /// new/updated conversation) rather than on every state emit.
  void _sortConversations() {
    _conversations.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  void _emit() => state = _snapshot();

  // Convenience accessors mirroring the current state (handy for callers that
  // hold the notifier directly, e.g. tests).
  List<Conversation> get conversations => List.unmodifiable(_conversations);
  Conversation? get current => _current;
  bool get loading => _loading;
  bool get isResponding => _isResponding;
  String? get error => _error;

  Future<void> _init() async {
    // Load metadata only; the first chat's messages are loaded before we clear
    // the loading flag so the opened chat is ready, but the rest stay as shells.
    _conversations = await _store.loadSummaries();
    _sortConversations();
    if (_conversations.isNotEmpty) {
      _current = _conversations.first;
      await _ensureLoaded(_current!);
    }
    _loading = false;
    _emit();
  }

  /// Loads [convo]'s messages from the store the first time it's opened.
  /// Concurrent calls share a single load.
  Future<void> _ensureLoaded(Conversation convo) {
    if (_loadedIds.contains(convo.id)) return Future.value();
    return _loadingFutures.putIfAbsent(convo.id, () async {
      final full = await _store.loadConversation(convo.id);
      if (full != null) {
        convo.messages
          ..clear()
          ..addAll(full.messages);
      }
      _loadedIds.add(convo.id);
      _loadingFutures.remove(convo.id);
      if (identical(_current, convo)) _emit();
    });
  }

  /// Notifies listeners at most once per [_streamInterval] during streaming.
  void _notifyStreaming() {
    if (_streamThrottle != null) {
      _streamDirty = true;
      return;
    }
    _emit();
    _streamThrottle = Timer(_streamInterval, () {
      _streamThrottle = null;
      if (_streamDirty) {
        _streamDirty = false;
        _notifyStreaming();
      }
    });
  }

  /// Cancels throttling and emits a final, immediate update.
  void _endStreaming() {
    _streamThrottle?.cancel();
    _streamThrottle = null;
    _streamDirty = false;
    _emit();
  }

  void selectConversation(String id) {
    final match = _conversations.where((c) => c.id == id);
    if (match.isEmpty) return;
    _current = match.first;
    _error = null;
    _emit();
    // Load its messages if not already (fills in shortly after via _emit).
    _ensureLoaded(_current!);
  }

  Conversation newConversation() {
    final convo = Conversation(
      id: _uuid.v4(),
      title: 'New chat',
      modelId: ref.read(settingsProvider).defaultModel,
    );
    _conversations.insert(0, convo);
    _sortConversations(); // place below any pinned chats
    _current = convo;
    _error = null;
    _loadedIds.add(convo.id); // a brand-new chat owns its (empty) messages
    _emit();
    _persistMeta(convo);
    return convo;
  }

  /// Toggles the pinned state of a conversation (pinned chats sort to the top).
  void togglePin(String id) {
    final match = _conversations.where((c) => c.id == id);
    if (match.isEmpty) return;
    match.first.pinned = !match.first.pinned;
    _sortConversations();
    _emit();
    _persistMeta(match.first);
  }

  /// Renames a conversation. Empty titles are ignored.
  void renameConversation(String id, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final match = _conversations.where((c) => c.id == id);
    if (match.isEmpty) return;
    match.first.title = trimmed;
    _emit();
    _persistMeta(match.first);
  }

  Future<void> deleteConversation(String id) async {
    _conversations.removeWhere((c) => c.id == id);
    _loadedIds.remove(id);
    if (_current?.id == id) {
      _current = _conversations.isNotEmpty ? _conversations.first : null;
    }
    _emit();
    await _store.deleteConversation(id);
    if (_current != null) _ensureLoaded(_current!);
  }

  /// Removes every conversation (used by "Delete all chats").
  Future<void> deleteAllConversations() async {
    _conversations.clear();
    _loadedIds.clear();
    _current = null;
    _emit();
    await _store.deleteAllConversations();
  }

  /// Sets the model for the current conversation. This is a no-op once the
  /// conversation has messages — a chat's model is fixed once it has started so
  /// a single history never mixes responses from different models.
  void setModelForCurrent(String modelId, {bool? supportsImageOutput}) {
    final convo = _current;
    if (convo == null) return;
    if (convo.messages.isNotEmpty) return;
    convo.modelId = modelId;
    if (supportsImageOutput != null) {
      convo.supportsImageOutput = supportsImageOutput;
    }
    _emit();
    _persistMeta(convo);
  }

  /// Clears the current conversation's error banner.
  void clearError() {
    if (_error == null) return;
    _error = null;
    _emit();
  }

  /// Appends a user message (optionally with [attachments]) and streams the
  /// assistant's reply into the current conversation.
  Future<void> sendMessage(
    String text, {
    List<MessageAttachment> attachments = const [],
  }) async {
    final content = text.trim();
    if ((content.isEmpty && attachments.isEmpty) || _isResponding) return;

    final apiKey = ref.read(settingsProvider).apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      _error = 'Add your OpenRouter API key in Settings first.';
      _emit();
      return;
    }

    final convo = _current ??= newConversation();
    // Ensure prior messages are loaded before appending to this chat.
    await _ensureLoaded(convo);

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: content,
      attachments: List<MessageAttachment>.from(attachments),
    );
    convo.messages.add(userMessage);

    if (convo.title == 'New chat') {
      final seed = content.isNotEmpty ? content : '[attachment]';
      convo.title = seed.length > 40 ? '${seed.substring(0, 40)}…' : seed;
    }

    final assistantMsg = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      content: '',
      isStreaming: true,
    );
    convo.messages.add(assistantMsg);
    convo.updatedAt = DateTime.now();
    _isResponding = true;
    _error = null;
    _sortConversations(); // updatedAt just bumped → moves to top of its group
    _emit();

    // Persist the new turn up front (meta + both messages) so it survives a
    // crash mid-stream; the assistant row is updated again at completion.
    _persistMeta(convo);
    _persistMessage(convo, userMessage);
    _persistMessage(convo, assistantMsg);

    // Build the request history: everything except the placeholder reply and
    // any prior failed messages.
    final history = convo.messages
        .where((m) => m != assistantMsg && m.error == null)
        .toList();

    final completer = Completer<void>();
    _sub = _service
        .streamChat(
          apiKey: apiKey,
          model: convo.modelId,
          messages: history,
          imageOutput: convo.supportsImageOutput,
          onUsage: (usage) =>
              ref.read(usageProvider.notifier).record(convo.modelId, usage),
          onImage: (image) {
            assistantMsg.attachments.add(image);
            _emit();
          },
          onAudio: (audio) {
            assistantMsg.attachments.add(audio);
            _emit();
          },
        )
        .listen(
      (delta) {
        assistantMsg.content += delta;
        _notifyStreaming();
      },
      onError: (Object e) {
        assistantMsg
          ..isStreaming = false
          ..error = e.toString();
        if (assistantMsg.content.isEmpty) {
          assistantMsg.content = '⚠️ $e';
        }
        _error = e.toString();
        _finish(convo, assistantMsg);
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        assistantMsg.isStreaming = false;
        _finish(convo, assistantMsg);
        // Cue the user that the reply is complete (haptic on mobile, sound on
        // desktop); errors and manual stops don't fire this.
        if (ref.read(settingsProvider).replyCompleteFeedback) {
          AppFeedback.responseComplete();
        }
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    return completer.future;
  }

  /// Cancels an in-flight streaming response, keeping whatever arrived so far.
  void stopResponding() {
    _sub?.cancel();
    _sub = null;
    final convo = _current;
    if (convo != null && convo.messages.isNotEmpty) {
      final last = convo.messages.last;
      if (last.role == MessageRole.assistant && last.isStreaming) {
        last.isStreaming = false;
      }
      _persistMeta(convo);
      _persistMessage(convo, last);
    }
    _isResponding = false;
    _endStreaming();
  }

  void _finish(Conversation convo, ChatMessage assistantMsg) {
    _isResponding = false;
    convo.updatedAt = DateTime.now();
    _sortConversations();
    _endStreaming();
    _persistMeta(convo);
    _persistMessage(convo, assistantMsg);
  }

  // Targeted persistence: only the affected conversation/message rows are
  // written, instead of rewriting the whole history on every change. Best
  // effort (unawaited) on the hot path; awaited where the caller needs it.
  void _persistMeta(Conversation c) => _store.upsertConversation(c);

  void _persistMessage(Conversation c, ChatMessage m) =>
      _store.saveMessage(c.id, m, c.messages.indexOf(m));
}
