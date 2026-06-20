import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/models/chat_message.dart';
import 'package:wombat/models/conversation.dart';
import 'package:wombat/services/conversation_store.dart';

void main() {
  late Directory tempDir;
  late ConversationStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wombat_store_test');
    store = ConversationStore(directory: tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('returns empty list when no file exists yet', () async {
    expect(await store.load(), isEmpty);
  });

  test('saves and reloads conversations', () async {
    final convo = Conversation(
      id: 'c1',
      title: 'Saved',
      modelId: 'm',
      messages: [
        ChatMessage(id: 'm1', role: MessageRole.user, content: 'hi'),
      ],
    );

    await store.save([convo]);
    final loaded = await ConversationStore(directory: tempDir).load();

    expect(loaded, hasLength(1));
    expect(loaded.single.title, 'Saved');
    expect(loaded.single.messages.single.content, 'hi');
  });

  test('persists the JSON file on disk', () async {
    await store.save([Conversation(id: 'c', title: 't', modelId: 'm')]);
    final file = File('${tempDir.path}${Platform.pathSeparator}'
        'conversations.json');
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync(), contains('"title":"t"'));
  });

  test('returns empty list for corrupt content', () async {
    final file = File('${tempDir.path}${Platform.pathSeparator}'
        'conversations.json');
    await file.writeAsString('{ not valid json');
    expect(await store.load(), isEmpty);
  });
}
