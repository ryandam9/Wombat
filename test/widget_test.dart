import 'package:flutter_test/flutter_test.dart';

import 'package:route/models/chat_message.dart';
import 'package:route/models/conversation.dart';
import 'package:route/models/openrouter_model.dart';

void main() {
  group('ChatMessage', () {
    test('round-trips through JSON', () {
      final msg = ChatMessage(
        id: 'abc',
        role: MessageRole.assistant,
        content: 'hello',
      );
      final restored = ChatMessage.fromJson(msg.toJson());
      expect(restored.id, 'abc');
      expect(restored.role, MessageRole.assistant);
      expect(restored.content, 'hello');
    });

    test('maps roles to wire names', () {
      expect(MessageRole.system.wireName, 'system');
      expect(MessageRole.user.wireName, 'user');
      expect(MessageRole.assistant.wireName, 'assistant');
      expect(MessageRoleWire.fromWire('assistant'), MessageRole.assistant);
      expect(MessageRoleWire.fromWire('unknown'), MessageRole.user);
    });
  });

  group('Conversation', () {
    test('round-trips through JSON with messages', () {
      final convo = Conversation(
        id: 'c1',
        title: 'Test',
        modelId: 'openai/gpt-4o-mini',
        messages: [
          ChatMessage(id: 'm1', role: MessageRole.user, content: 'hi'),
        ],
      );
      final restored = Conversation.fromJson(convo.toJson());
      expect(restored.id, 'c1');
      expect(restored.title, 'Test');
      expect(restored.modelId, 'openai/gpt-4o-mini');
      expect(restored.messages.single.content, 'hi');
    });
  });

  group('OpenRouterModel', () {
    test('parses pricing and detects free models', () {
      final paid = OpenRouterModel.fromJson({
        'id': 'openai/gpt-4o',
        'name': 'GPT-4o',
        'context_length': 128000,
        'pricing': {'prompt': '0.000005', 'completion': '0.000015'},
      });
      expect(paid.isFree, isFalse);
      expect(paid.contextLength, 128000);
      expect(paid.promptPrice, 0.000005);

      final free = OpenRouterModel.fromJson({
        'id': 'meta/free-model',
        'name': '',
        'pricing': {'prompt': '0', 'completion': '0'},
      });
      expect(free.isFree, isTrue);
      // Falls back to id when name is empty.
      expect(free.name, 'meta/free-model');
    });
  });
}
