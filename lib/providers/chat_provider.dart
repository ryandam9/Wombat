import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/attachment.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/conversation_store.dart';
import '../services/openrouter_service.dart';
import 'settings_provider.dart';
import 'usage_provider.dart';

/// Owns the list of conversations and drives sending/streaming of messages.
class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required OpenRouterService service,
    required ConversationStore store,
    required SettingsProvider settings,
    required UsageProvider usage,
  })  : _service = service,
        _store = store,
        _settings = settings,
        _usage = usage {
    _init();
  }

  final OpenRouterService _service;
  final ConversationStore _store;
  final SettingsProvider _settings;
  final UsageProvider _usage;
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

  void setModelForCurrent(String modelId, {bool? supportsImageOutput}) {
    final convo = _current;
    if (convo == null) return;
    convo.modelId = modelId;
    if (supportsImageOutput != null) {
      convo.supportsImageOutput = supportsImageOutput;
    }
    notifyListeners();
    _persist();
  }

  /// Clears the current conversation's error banner.
  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Appends a user message (optionally with [attachments]) and streams the
  /// assistant's reply into the current conversation.
  Future<void> sendMessage(
    String text, {
    List<MessageAttachment> attachments = const [],
  }) async {
    final content = text.trim();
    if ((content.isEmpty && attachments.isEmpty) || _isResponding) return;

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
    notifyListeners();

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
          onUsage: (usage) => _usage.record(convo.modelId, usage),
          onImage: (image) {
            assistantMsg.attachments.add(image);
            notifyListeners();
          },
          onAudio: (audio) {
            assistantMsg.attachments.add(audio);
            notifyListeners();
          },
        )
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
