import 'package:flutter_test/flutter_test.dart';
import 'package:route/models/attachment.dart';
import 'package:route/models/chat_message.dart';

void main() {
  group('MessageRole wire mapping', () {
    test('maps each role to its wire name', () {
      expect(MessageRole.system.wireName, 'system');
      expect(MessageRole.user.wireName, 'user');
      expect(MessageRole.assistant.wireName, 'assistant');
    });

    test('parses wire names back to roles', () {
      expect(MessageRoleWire.fromWire('system'), MessageRole.system);
      expect(MessageRoleWire.fromWire('assistant'), MessageRole.assistant);
      expect(MessageRoleWire.fromWire('user'), MessageRole.user);
    });

    test('defaults unknown wire names to user', () {
      expect(MessageRoleWire.fromWire('tool'), MessageRole.user);
      expect(MessageRoleWire.fromWire(''), MessageRole.user);
    });
  });

  group('ChatMessage', () {
    test('round-trips through JSON', () {
      final created = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final msg = ChatMessage(
        id: 'abc',
        role: MessageRole.assistant,
        content: 'hello',
        createdAt: created,
      );

      final restored = ChatMessage.fromJson(msg.toJson());

      expect(restored.id, 'abc');
      expect(restored.role, MessageRole.assistant);
      expect(restored.content, 'hello');
      expect(restored.createdAt, created);
    });

    test('persists error when present and omits it otherwise', () {
      final withError = ChatMessage(
        id: '1',
        role: MessageRole.assistant,
        content: '',
        error: 'boom',
      );
      expect(withError.toJson()['error'], 'boom');
      expect(ChatMessage.fromJson(withError.toJson()).error, 'boom');

      final clean = ChatMessage(id: '2', role: MessageRole.user, content: 'hi');
      expect(clean.toJson().containsKey('error'), isFalse);
    });

    test('tolerates missing/invalid fields in JSON', () {
      final restored = ChatMessage.fromJson({'id': 'x', 'role': 'user'});
      expect(restored.content, '');
      // Falls back to "now" for an unparseable date rather than throwing.
      expect(restored.createdAt, isA<DateTime>());
    });

    test('round-trips attachments through JSON', () {
      final msg = ChatMessage(
        id: '1',
        role: MessageRole.user,
        content: 'look',
        attachments: [
          MessageAttachment.fromBytes(
            kind: AttachmentKind.image,
            mimeType: 'image/png',
            bytes: [1, 2, 3],
          ),
        ],
      );
      final restored = ChatMessage.fromJson(msg.toJson());
      expect(restored.attachments, hasLength(1));
      expect(restored.attachments.single.kind, AttachmentKind.image);
      expect(restored.attachments.single.base64Data,
          msg.attachments.single.base64Data);
    });

    test('defaults attachments to empty', () {
      final msg = ChatMessage(id: '1', role: MessageRole.user, content: 'hi');
      expect(msg.attachments, isEmpty);
      expect(msg.toJson().containsKey('attachments'), isFalse);
    });

    test('defaults isStreaming to false and createdAt to now', () {
      final before = DateTime.now();
      final msg = ChatMessage(id: '1', role: MessageRole.user, content: 'hi');
      expect(msg.isStreaming, isFalse);
      expect(
        msg.createdAt.isBefore(before.subtract(const Duration(seconds: 1))),
        isFalse,
      );
    });
  });
}
