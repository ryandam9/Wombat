import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/providers/chat_provider.dart';
import 'package:wombat/screens/home_screen.dart';
import 'package:wombat/theme/app_theme.dart';
import 'package:wombat/widgets/chat_view.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Widget> buildApp(WidgetTester tester) async {
    late ProviderContainer container;
    await tester.runAsync(() async {
      container = await createContainer(
        service: FakeOpenRouterService(),
        store: FakeConversationStore(),
      );
      await waitUntil(() => !container.read(chatProvider.notifier).loading);
    });
    addTearDown(container.dispose);
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
    );
  }

  testWidgets('wide layout shows the sidebar and a settings icon in the header',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildApp(tester));
    await tester.pump();

    // The sidebar (with its title) is visible alongside the chat pane.
    expect(find.text('Compare models'), findsOneWidget);
    // Settings lives in the sidebar navigation rail.
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('sidebar shows the navigation rail and recent-chats section',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildApp(tester));
    await tester.pump();

    expect(find.text('NAVIGATION'), findsOneWidget);
    expect(find.text('RECENT CHATS'), findsOneWidget);
    for (final label in ['Chat history', 'Models', 'Usage', 'Debug',
      'API keys', 'Settings']) {
      expect(find.text(label), findsOneWidget, reason: 'missing nav item $label');
    }
  });

  testWidgets('desktop nav swaps the centre pane in place (no new route)',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildApp(tester));
    await tester.pump();

    await tester.tap(find.text('Usage'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The Usage section is shown in the centre pane...
    expect(find.text('Session usage'), findsOneWidget);
    // ...while the sidebar stays visible (it was not covered by a new page)...
    expect(find.text('Compare models'), findsOneWidget);
    // ...and there is no back button (nothing was pushed).
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('Chat history opens the two-pane chat workspace', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildApp(tester));
    await tester.pump();

    // The dashboard centre is the landing, not a chat view.
    expect(find.byType(ChatView), findsNothing);

    await tester.tap(find.text('Chat history'));
    await tester.pumpAndSettle();

    // The workspace page (chat + history) is now shown, with a back affordance.
    expect(find.byType(ChatView), findsOneWidget);
    expect(find.byTooltip('Back to dashboard'), findsOneWidget);

    // Going back returns to the dashboard.
    await tester.tap(find.byTooltip('Back to dashboard'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatView), findsNothing);
  });

  testWidgets('New chat opens the chat workspace', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildApp(tester));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'New chat'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatView), findsOneWidget);
    expect(find.byTooltip('Back to dashboard'), findsOneWidget);
  });

  testWidgets('collapsing hides the sidebar and expanding restores it',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildApp(tester));
    await tester.pump();

    expect(find.text('Compare models'), findsOneWidget);

    // Collapse via the sidebar's collapse button (issue #43).
    await tester.tap(find.widgetWithIcon(IconButton, Icons.menu_open));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Compare models'), findsNothing);

    // The chat header now offers a button to bring the sidebar back.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.menu_open));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Compare models'), findsOneWidget);
  });
}
