import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/screens/chat_workspace_screen.dart';
import 'package:wombat/widgets/chat_view.dart';
import 'package:wombat/widgets/desktop_sidebar_handle.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Widget> app(WidgetTester tester) async {
    late ProviderContainer container;
    await tester.runAsync(() async {
      container = await createContainer(
        service: FakeOpenRouterService(),
        store: FakeConversationStore(),
      );
    });
    addTearDown(container.dispose);
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ChatWorkspaceScreen()),
    );
  }

  testWidgets('wide workspace uses the shared resize handle and chat pane',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await app(tester));
    await tester.pump();

    // The same handle the dashboard uses (shared component), plus the chat pane.
    expect(find.byType(ResizableSidebarHandle), findsOneWidget);
    expect(find.byType(ChatView), findsOneWidget);
  });
}
