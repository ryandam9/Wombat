import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/models/conversation.dart';
import 'package:wombat/models/openrouter_model.dart';
import 'package:wombat/providers/chat_provider.dart';
import 'package:wombat/providers/settings_provider.dart';
import 'package:wombat/widgets/conversation_list.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('no chat-count chip next to the app name (#132)', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 900);
    addTearDown(tester.view.reset);

    late ProviderContainer container;
    await tester.runAsync(() async {
      container = await createContainer(
        store: FakeConversationStore(initial: [
          Conversation(id: 'a', title: 'Alpha', modelId: 'm'),
          Conversation(id: 'b', title: 'Beta', modelId: 'm'),
          Conversation(id: 'c', title: 'Gamma', modelId: 'm'),
        ]),
      );
      await waitUntil(() => !container.read(chatProvider.notifier).loading);
    });
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 320, child: ConversationList()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The app name is shown, but the "3" conversation-count chip is not.
    expect(find.text('Wombat'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets(
      'choosing a model from the drawer does not crash after it closes',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 840);
    addTearDown(tester.view.reset);

    late ProviderContainer container;
    final service = FakeOpenRouterService()
      ..models = [
        OpenRouterModel(id: 'x/chosen', name: 'Chosen'),
      ];
    await tester.runAsync(() async {
      container = await createContainer(
        prefs: const {'default_model': 'a/old'},
        service: service,
      );
    });
    addTearDown(container.dispose);

    final scaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            key: scaffoldKey,
            drawer: const Drawer(child: ConversationList(inDrawer: true)),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );

    // Open the drawer and tap "Models" — this pops the drawer (disposing the
    // ConversationList) and pushes the model picker while it's gone.
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Models'));
    await tester.pumpAndSettle();

    // Pick the model: on narrow the card opens a detail sheet; tapping
    // "Select model" pops the picker, resuming _openModels after the list
    // widget was disposed — this used to throw "Using ref ... unmounted".
    await tester.tap(find.text('Chosen').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select model'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(settingsProvider).defaultModel, 'x/chosen');
  });
}
