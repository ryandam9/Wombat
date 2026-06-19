import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/attachment.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/conversation_store.dart';
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
        conversations: _conversations,
        current: _current,
        loading: _loading,
        isResponding: _isResponding,
        error: _error,
      );

  void _emit() => state = _snapshot();

  // Convenience accessors mirroring the current state (handy for callers that
  // hold the notifier directly, e.g. tests).
  List<Conversation> get conversations => List.unmodifiable(_conversations);
  Conversation? get current => _current;
  bool get loading => _loading;
  bool get isResponding => _isResponding;
  String? get error => _error;

  Future<void> _init() async {
    _conversations = await _store.load();
    _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (_conversations.isNotEmpty) _current = _conversations.first;
    _loading = false;
    _emit();
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
  }

  Conversation newConversation() {
    final convo = Conversation(
      id: _uuid.v4(),
      title: 'New chat',
      modelId: ref.read(settingsProvider).defaultModel,
    );
    _conversations.insert(0, convo);
    _current = convo;
    _error = null;
    _emit();
    _persist();
    return convo;
  }

  Future<void> deleteConversation(String id) async {
    _conversations.removeWhere((c) => c.id == id);
    if (_current?.id == id) {
      _current = _conversations.isNotEmpty ? _conversations.first : null;
    }
    _emit();
    await _persist();
  }

  void setModelForCurrent(String modelId, {bool? supportsImageOutput}) {
    final convo = _current;
    if (convo == null) return;
    convo.modelId = modelId;
    if (supportsImageOutput != null) {
      convo.supportsImageOutput = supportsImageOutput;
    }
    _emit();
    _persist();
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

    convo.messages.add(ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: content,
      attachments: List<MessageAttachment>.from(attachments),
    ));

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
    _bumpToTop(convo);
    _emit();

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
        _finish(convo);
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        assistantMsg.isStreaming = false;
        _finish(convo);
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
    }
    _isResponding = false;
    _endStreaming();
    _persist();
  }

  void _finish(Conversation convo) {
    _isResponding = false;
    convo.updatedAt = DateTime.now();
    _endStreaming();
    _persist();
  }

  void _bumpToTop(Conversation convo) {
    _conversations.removeWhere((c) => c.id == convo.id);
    _conversations.insert(0, convo);
  }

  Future<void> _persist() => _store.save(_conversations);
}
