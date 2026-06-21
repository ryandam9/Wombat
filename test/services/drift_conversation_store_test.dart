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

  group('targeted writes', () {
    test('upsertConversation + saveMessage build a chat incrementally',
        () async {
      final convo = Conversation(id: 'c1', title: 'New chat', modelId: 'm');
      await store.upsertConversation(convo);
      expect((await store.load()).single.messages, isEmpty);

      await store.saveMessage('c1',
          ChatMessage(id: 'u1', role: MessageRole.user, content: 'hi'), 0);
      await store.saveMessage('c1',
          ChatMessage(id: 'a1', role: MessageRole.assistant, content: 'yo'), 1);

      final loaded = await store.load();
      expect(loaded.single.messages.map((m) => m.id), ['u1', 'a1']);
    });

    test('saveMessage updates an existing message in place', () async {
      await store.upsertConversation(
          Conversation(id: 'c1', title: 't', modelId: 'm'));
      await store.saveMessage('c1',
          ChatMessage(id: 'a1', role: MessageRole.assistant, content: ''), 0);

      // Re-save the same id with grown content + an attachment.
      await store.saveMessage(
        'c1',
        ChatMessage(
          id: 'a1',
          role: MessageRole.assistant,
          content: 'Hello world',
          attachments: const [
            MessageAttachment(
                kind: AttachmentKind.image, mimeType: 'image/png', base64Data: 'Z'),
          ],
        ),
        0,
      );

      final msg = (await store.load()).single.messages.single;
      expect(msg.content, 'Hello world');
      expect(msg.attachments.single.base64Data, 'Z');
      // No duplicate message rows.
      expect((await db.select(db.messages).get()), hasLength(1));
    });

    test('upsertConversation updates metadata without touching messages',
        () async {
      await store.upsertConversation(
          Conversation(id: 'c1', title: 'Old', modelId: 'm'));
      await store.saveMessage('c1',
          ChatMessage(id: 'u1', role: MessageRole.user, content: 'hi'), 0);

      await store.upsertConversation(
          Conversation(id: 'c1', title: 'Renamed', modelId: 'm', pinned: true));

      final loaded = (await store.load()).single;
      expect(loaded.title, 'Renamed');
      expect(loaded.pinned, isTrue);
      expect(loaded.messages.single.id, 'u1'); // messages untouched
    });

    test('deleteConversation and deleteAllConversations', () async {
      await store.upsertConversation(
          Conversation(id: 'a', title: 'A', modelId: 'm'));
      await store.upsertConversation(
          Conversation(id: 'b', title: 'B', modelId: 'm'));

      await store.deleteConversation('a');
      expect((await store.load()).map((c) => c.id), ['b']);

      await store.deleteAllConversations();
      expect(await store.load(), isEmpty);
    });
  });
}
