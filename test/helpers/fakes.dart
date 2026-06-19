import 'package:route/models/attachment.dart';
import 'package:route/models/chat_message.dart';
import 'package:route/models/usage.dart';
import 'package:route/services/conversation_store.dart';
import 'package:route/services/openrouter_service.dart';
import 'package:route/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:route/models/conversation.dart';
import 'package:route/providers/settings_provider.dart';

/// In-memory [SecureStorageService] for tests; never touches a platform store.
class FakeSecureStorageService extends SecureStorageService {
  FakeSecureStorageService({String? initial}) : _value = initial;

  String? _value;

  @override
  Future<String?> readApiKey() async => _value;

  @override
  Future<void> writeApiKey(String value) async => _value = value;

  @override
  Future<void> deleteApiKey() async => _value = null;
}

/// In-memory [ConversationStore] that records every save for assertions.
class FakeConversationStore extends ConversationStore {
  FakeConversationStore({List<Conversation>? initial})
      : _data = initial ?? [];

  List<Conversation> _data;
  int saveCount = 0;

  @override
  Future<List<Conversation>> load() async => _data;

  @override
  Future<void> save(List<Conversation> conversations) async {
    saveCount++;
    // Store a detached copy so later mutations don't retroactively change it.
    _data = List<Conversation>.from(conversations);
  }
}

/// Scriptable [OpenRouterService]: emits [chunks] or throws [errorToThrow],
/// optionally reports [usage], and records the last request arguments.
class FakeOpenRouterService extends OpenRouterService {
  FakeOpenRouterService({this.chunks = const ['Hello', ' ', 'world']});

  List<String> chunks;
  Object? errorToThrow;
  TokenUsage? usage;
  List<MessageAttachment> outputImages = const [];
  CreditBalance? credits;
  Object? creditsError;
  String? lastModel;
  String? lastApiKey;
  bool? lastImageOutput;
  List<ChatMessage>? lastMessages;

  @override
  Stream<String> streamChat({
    required String apiKey,
    required String model,
    required List<ChatMessage> messages,
    bool imageOutput = false,
    void Function(TokenUsage usage)? onUsage,
    void Function(MessageAttachment image)? onImage,
    void Function(MessageAttachment audio)? onAudio,
  }) async* {
    lastApiKey = apiKey;
    lastModel = model;
    lastImageOutput = imageOutput;
    lastMessages = List<ChatMessage>.from(messages);
    if (errorToThrow != null) throw errorToThrow!;
    for (final chunk in chunks) {
      yield chunk;
    }
    for (final image in outputImages) {
      onImage?.call(image);
    }
    if (usage != null) onUsage?.call(usage!);
  }

  @override
  Future<CreditBalance> fetchCredits(String apiKey) async {
    if (creditsError != null) throw creditsError!;
    return credits ?? const CreditBalance(totalCredits: 0, totalUsage: 0);
  }
}

/// Builds a fully-loaded [SettingsProvider] backed by fakes/mock prefs.
Future<SettingsProvider> buildLoadedSettings({
  String? apiKey = 'test-key',
  String defaultModel = 'test/model',
}) async {
  SharedPreferences.setMockInitialValues({'default_model': defaultModel});
  final prefs = await SharedPreferences.getInstance();
  final secure = FakeSecureStorageService(initial: apiKey);
  final settings = SettingsProvider(secure, prefs);
  await _waitUntil(() => !settings.loading);
  return settings;
}

/// Pumps microtasks until [condition] is true (or a sane attempt limit).
Future<void> _waitUntil(bool Function() condition) async {
  for (var i = 0; i < 1000; i++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
}

/// Pumps microtasks until [condition] is true; exposed for provider tests.
Future<void> waitUntil(bool Function() condition) => _waitUntil(condition);
