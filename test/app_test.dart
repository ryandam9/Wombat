import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/app.dart';

import 'helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wraps the app in a SelectionArea so text is selectable',
      (tester) async {
    late ProviderContainer container;
    await tester.runAsync(() async {
      container = await createContainer(
        service: FakeOpenRouterService(),
        store: FakeConversationStore(),
      );
    });
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const WombatApp()),
    );
    await tester.pump();

    // The app-wide SelectionArea makes text selectable on every screen.
    expect(find.byType(SelectionArea), findsWidgets);
  });
}
