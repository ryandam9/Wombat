import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/models/openrouter_model.dart';
import 'package:wombat/providers/settings_provider.dart';
import 'package:wombat/widgets/conversation_list.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
