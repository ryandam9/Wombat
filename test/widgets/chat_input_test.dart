import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route/models/attachment.dart';
import 'package:route/models/chat_message.dart';
import 'package:route/models/usage.dart';
import 'package:route/providers/chat_provider.dart';
import 'package:route/widgets/chat_input.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Build the container inside runAsync: provider/settings setup relies on real
  // timers and platform channels, which don't advance in the fake-async zone
  // that testWidgets bodies run in.
  Future<ProviderContainer> loadChat(
    WidgetTester tester, {
    FakeOpenRouterService? service,
  }) async {
    late ProviderContainer container;
    await tester.runAsync(() async {
      container = await createContainer(
        service: service ?? FakeOpenRouterService(chunks: ['hi back']),
        store: FakeConversationStore(),
      );
      await waitUntil(() => !container.read(chatProvider.notifier).loading);
    });
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpInput(WidgetTester tester, ProviderContainer container) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ChatInput())),
      ),
    );
  }

  testWidgets('tapping send adds the typed message to the conversation',
      (tester) async {
    final container = await loadChat(tester);
    await pumpInput(tester, container);
    final chat = container.read(chatProvider.notifier);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    expect(chat.current, isNotNull);
    expect(chat.current!.messages.first.content, 'hello');
  });

  testWidgets('clears the input field after sending', (tester) async {
    final container = await loadChat(tester);
    await pumpInput(tester, container);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    expect(find.text('hello'), findsNothing);
  });

  testWidgets('does not send blank input', (tester) async {
    final container = await loadChat(tester);
    await pumpInput(tester, container);
    final chat = container.read(chatProvider.notifier);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    expect(chat.current, isNull);
  });

  testWidgets('shows a stop button while a response is streaming',
      (tester) async {
    final container = await loadChat(tester, service: _NeverEndingService());
    await pumpInput(tester, container);
    final chat = container.read(chatProvider.notifier);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    expect(find.byIcon(Icons.stop), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);

    chat.stopResponding();
  });
}

/// Emits one chunk then hangs, so the provider stays in the responding state.
/// Uses a never-completing [Completer] (not a timer) to avoid leaving a
/// pending timer when the test ends.
class _NeverEndingService extends FakeOpenRouterService {
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
    yield 'partial';
    await Completer<void>().future;
  }
}
