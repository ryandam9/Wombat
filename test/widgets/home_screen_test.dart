import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/models/conversation.dart';
import 'package:wombat/providers/chat_provider.dart';
import 'package:wombat/screens/home_screen.dart';
import 'package:wombat/screens/settings_screen.dart';
import 'package:wombat/screens/usage_screen.dart';
import 'package:wombat/theme/app_theme.dart';
import 'package:wombat/widgets/chat_input.dart';
import 'package:wombat/widgets/chat_view.dart';
import 'package:wombat/widgets/dashboard_landing.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Widget> buildApp(WidgetTester tester,
      {List<Conversation>? conversations}) async {
    late ProviderContainer container;
    await tester.runAsync(() async {
      container = await createContainer(
        service: FakeOpenRouterService(),
        store: FakeConversationStore(initial: conversations),
      );
      await waitUntil(() => !container.read(chatProvider.notifier).loading);
    });
    addTearDown(container.dispose);
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.dark, home: const HomeScreen()),
    );
  }

  testWidgets('narrow home uses a bottom navigation bar, not a left rail',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 840);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildApp(tester));
    await tester.pump();

    // A Material 3 bottom nav with the four primary destinations.
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['Chats', 'Models', 'Usage', 'Settings']) {
      expect(find.text(label), findsOneWidget, reason: 'missing tab $label');
    }
    // No left drawer/rail, and no chat chrome on the dashboard.
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(ChatView), findsNothing);
    expect(find.byType(ChatInput), findsNothing);
    // Empty store → the welcome dashboard is the Chats tab body.
    expect(find.byType(DashboardLanding), findsOneWidget);
  });

  testWidgets('narrow: the New chat FAB opens the chat workspace',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 840);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildApp(tester));
    await tester.pump();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'New chat'));
    await tester.pumpAndSettle();

    // Now in the chat workspace: the chat view (header + composer) is shown.
    expect(find.byType(ChatView), findsOneWidget);
    expect(find.byType(ChatInput), findsOneWidget);
  });

  testWidgets('narrow: the bottom nav switches sections', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 840);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await buildApp(tester));
    await tester.pump();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.text('Usage'));
    await tester.pumpAndSettle();
    expect(find.byType(UsageScreen), findsOneWidget);
  });

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
      'Settings']) {
      expect(find.text(label), findsOneWidget, reason: 'missing nav item $label');
    }
    // 'API keys' was removed; the key lives in Settings.
    expect(find.text('API keys'), findsNothing);
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

  testWidgets('dashboard caps recent chats at 5; workspace shows all',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    // Tall enough that the lazy sidebar list builds all rows.
    tester.view.physicalSize = const Size(1200, 1600);
    addTearDown(tester.view.reset);

    final convos = [
      for (var i = 0; i < 7; i++)
        Conversation(id: 'c$i', title: 'Chat $i', modelId: 'm/$i'),
    ];
    await tester.pumpWidget(await buildApp(tester, conversations: convos));
    await tester.pump();

    // Dashboard sidebar shows only 5 recent chats + a "view all" affordance.
    expect(find.byType(ListTile), findsNWidgets(5));
    expect(find.textContaining('View all'), findsOneWidget);

    // Opening the full history (Chat history page) lists all 7, grouped by date.
    await tester.tap(find.text('Chat history'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(7));
    expect(find.text('TODAY'), findsOneWidget);
  });

  testWidgets('Chat history page can delete all chats', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 1600);
    addTearDown(tester.view.reset);

    final convos = [
      for (var i = 0; i < 3; i++)
        Conversation(id: 'c$i', title: 'Chat $i', modelId: 'm/$i'),
    ];
    await tester.pumpWidget(await buildApp(tester, conversations: convos));
    await tester.pump();

    await tester.tap(find.text('Chat history'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(3));

    await tester.tap(find.byTooltip('Delete all chats'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete all'));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('No conversations yet'), findsOneWidget);
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

    // Collapse via the sidebar's collapse button (issue #43). Let the
    // collapse animation settle so only the thin rail remains in the tree.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.menu_open));
    await tester.pumpAndSettle();
    expect(find.text('Compare models'), findsNothing);

    // The collapsed rail now offers a button to bring the sidebar back.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.menu_open));
    await tester.pumpAndSettle();
    expect(find.text('Compare models'), findsOneWidget);
  });
}
