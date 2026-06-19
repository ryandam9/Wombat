import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/conversation_store.dart';
import '../services/openrouter_service.dart';
import 'settings_provider.dart';

/// Owns the list of conversations and drives sending/streaming of messages.
class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required OpenRouterService service,
    required ConversationStore store,
    required SettingsProvider settings,
  })  : _service = service,
        _store = store,
        _settings = settings {
    _init();
  }

  final OpenRouterService _service;
  final ConversationStore _store;
  final SettingsProvider _settings;
  final _uuid = const Uuid();

  List<Conversation> _conversations = [];
  Conversation? _current;
  bool _loading = true;
  bool _isResponding = false;
  String? _error;
  StreamSubscription<String>? _sub;

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
    notifyListeners();
  }

  void selectConversation(String id) {
    final match = _conversations.where((c) => c.id == id);
    if (match.isEmpty) return;
    _current = match.first;
    _error = null;
    notifyListeners();
  }

  Conversation newConversation() {
    final convo = Conversation(
      id: _uuid.v4(),
      title: 'New chat',
      modelId: _settings.defaultModel,
    );
    _conversations.insert(0, convo);
    _current = convo;
    _error = null;
    notifyListeners();
    _persist();
    return convo;
  }

  Future<void> deleteConversation(String id) async {
    _conversations.removeWhere((c) => c.id == id);
    if (_current?.id == id) {
      _current = _conversations.isNotEmpty ? _conversations.first : null;
    }
    notifyListeners();
    await _persist();
  }

  void setModelForCurrent(String modelId) {
    final convo = _current;
    if (convo == null) return;
    convo.modelId = modelId;
    notifyListeners();
    _persist();
  }

  /// Clears the current conversation's error banner.
  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Appends a user message and streams the assistant's reply into the
  /// current conversation.
  Future<void> sendMessage(String text) async {
    final content = text.trim();
    if (content.isEmpty || _isResponding) return;

    final apiKey = _settings.apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      _error = 'Add your OpenRouter API key in Settings first.';
      notifyListeners();
      return;
    }

    final convo = _current ??= newConversation();

    convo.messages.add(ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: content,
    ));

    if (convo.title == 'New chat') {
      convo.title =
          content.length > 40 ? '${content.substring(0, 40)}…' : content;
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
    notifyListeners();

    // Build the request history: everything except the placeholder reply and
    // any prior failed messages.
    final history = convo.messages
        .where((m) => m != assistantMsg && m.error == null)
        .toList();

    final completer = Completer<void>();
    _sub = _service
        .streamChat(apiKey: apiKey, model: convo.modelId, messages: history)
        .listen(
      (delta) {
        assistantMsg.content += delta;
        notifyListeners();
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
    notifyListeners();
    _persist();
  }

  void _finish(Conversation convo) {
    _isResponding = false;
    convo.updatedAt = DateTime.now();
    notifyListeners();
    _persist();
  }

  void _bumpToTop(Conversation convo) {
    _conversations.removeWhere((c) => c.id == convo.id);
    _conversations.insert(0, convo);
  }

  Future<void> _persist() => _store.save(_conversations);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
