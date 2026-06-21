import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/models/chat_message.dart';
import 'package:wombat/models/conversation.dart';
import 'package:wombat/providers/chat_provider.dart';
import 'package:wombat/widgets/chat_input.dart';
import 'package:wombat/widgets/chat_view.dart';
import 'package:wombat/widgets/model_selector.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Settings/provider setup relies on real timers and platform channels, so the
  // container is built inside runAsync (see chat_input_test for the pattern).
  Future<ProviderContainer> load(WidgetTester tester) async {
    late ProviderContainer container;
    await tester.runAsync(() async {
      container = await createContainer(
        service: FakeOpenRouterService(),
        store: FakeConversationStore(),
      );
      await waitUntil(() => !container.read(chatProvider.notifier).loading);
    });
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pump(WidgetTester tester, ProviderContainer container) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: ChatView(showMenuButton: true)),
        ),
      ),
    );
  }

  testWidgets('initial launch hides the model selector, new chat and composer',
      (tester) async {
    final container = await load(tester);
    await pump(tester, container);
    await tester.pump();

    // Nothing has been started yet.
    expect(container.read(chatProvider.notifier).current, isNull);

    expect(find.byType(ModelSelector), findsNothing);
    expect(find.byType(ChatInput), findsNothing);
    expect(find.byTooltip('New chat'), findsNothing);

    // The drawer button stays, so the user can reach "+ New chat".
    expect(find.byTooltip('Conversations'), findsOneWidget);
  });

  testWidgets('starting a chat reveals the model selector and composer',
      (tester) async {
    final container = await load(tester);
    await pump(tester, container);

    container.read(chatProvider.notifier).newConversation();
    await tester.pump();

    expect(find.byType(ModelSelector), findsOneWidget);
    expect(find.byType(ChatInput), findsOneWidget);
    // The header no longer carries a "New chat" action (#130) — it's reached
    // from the sidebar/drawer instead.
    expect(find.byTooltip('New chat'), findsNothing);
  });

  testWidgets('deleting the active chat does not crash the message list',
      (tester) async {
    final convo = Conversation(
      id: 'c1',
      title: 'Chat',
      modelId: 'test/model',
      messages: [
        ChatMessage(id: 'm1', role: MessageRole.user, content: 'hi'),
      ],
    );
    late ProviderContainer container;
    await tester.runAsync(() async {
      container = await createContainer(
        service: FakeOpenRouterService(),
        store: FakeConversationStore(initial: [convo]),
      );
      await waitUntil(() => !container.read(chatProvider.notifier).loading);
    });
    addTearDown(container.dispose);

    await pump(tester, container);
    await tester.pumpAndSettle();
    // A conversation with messages is active, so the composer is shown.
    expect(find.byType(ChatInput), findsOneWidget);

    // Deleting the active chat sets `current` to null while the message list
    // is still fading out — this used to throw a null-check error.
    container.read(chatProvider.notifier).deleteAllConversations();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ChatInput), findsNothing);
  });
}
