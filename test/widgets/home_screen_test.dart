import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:route/providers/chat_provider.dart';
import 'package:route/providers/settings_provider.dart';
import 'package:route/providers/usage_provider.dart';
import 'package:route/screens/home_screen.dart';
import 'package:route/theme/app_theme.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Widget> buildApp(WidgetTester tester) async {
    late SettingsProvider settings;
    late ChatProvider chat;
    late UsageProvider usage;
    await tester.runAsync(() async {
      settings = await buildLoadedSettings();
      final svc = FakeOpenRouterService();
      usage = UsageProvider(service: svc, settings: settings);
      chat = ChatProvider(
        service: svc,
        store: FakeConversationStore(),
        settings: settings,
        usage: usage,
      );
      await waitUntil(() => !chat.loading);
    });
    return MaterialApp(
      theme: AppTheme.dark,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<UsageProvider>.value(value: usage),
          ChangeNotifierProvider<ChatProvider>.value(value: chat),
        ],
        child: const HomeScreen(),
      ),
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
    // Settings moved into the chat header (issue #42).
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
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
