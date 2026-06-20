import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/models/attachment.dart';
import 'package:wombat/models/chat_message.dart';
import 'package:wombat/models/conversation.dart';
import 'package:wombat/services/database/app_database.dart';
import 'package:wombat/services/drift_conversation_store.dart';

void main() {
  late AppDatabase db;
  late DriftConversationStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftConversationStore(db);
  });

  tearDown(() async => db.close());

  test('returns empty list for a fresh database', () async {
    expect(await store.load(), isEmpty);
  });

  test('round-trips conversations, messages and attachments', () async {
    final convo = Conversation(
      id: 'c1',
      title: 'Saved chat',
      modelId: 'openai/gpt-4o',
      supportsImageOutput: true,
      pinned: true,
      messages: [
        ChatMessage(id: 'm1', role: MessageRole.user, content: 'hello'),
        ChatMessage(
          id: 'm2',
          role: MessageRole.assistant,
          content: 'hi there',
          attachments: [
            const MessageAttachment(
              kind: AttachmentKind.image,
              mimeType: 'image/png',
              base64Data: 'AAAA',
              name: 'pic.png',
            ),
          ],
        ),
      ],
    );

    await store.save([convo]);
    final loaded = await store.load();

    expect(loaded, hasLength(1));
    final c = loaded.single;
    expect(c.id, 'c1');
    expect(c.title, 'Saved chat');
    expect(c.modelId, 'openai/gpt-4o');
    expect(c.supportsImageOutput, isTrue);
    expect(c.pinned, isTrue);

    // Order is preserved.
    expect(c.messages.map((m) => m.id), ['m1', 'm2']);
    expect(c.messages[0].role, MessageRole.user);
    expect(c.messages[1].content, 'hi there');

    final att = c.messages[1].attachments.single;
    expect(att.kind, AttachmentKind.image);
    expect(att.mimeType, 'image/png');
    expect(att.base64Data, 'AAAA');
    expect(att.name, 'pic.png');
  });

  test('save replaces removed conversations and cascades children', () async {
    await store.save([
      Conversation(
        id: 'a',
        title: 'A',
        modelId: 'm',
        messages: [ChatMessage(id: 'm1', role: MessageRole.user, content: 'x')],
      ),
      Conversation(id: 'b', title: 'B', modelId: 'm'),
    ]);
    expect((await store.load()).map((c) => c.id).toSet(), {'a', 'b'});

    // Persisting without 'a' removes it (and its messages via cascade).
    await store.save([Conversation(id: 'b', title: 'B', modelId: 'm')]);
    final loaded = await store.load();
    expect(loaded.map((c) => c.id), ['b']);

    // No orphaned messages remain.
    final messages = await db.select(db.messages).get();
    expect(messages, isEmpty);
  });
}
