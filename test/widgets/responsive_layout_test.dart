import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:route/models/openrouter_model.dart';
import 'package:route/models/usage.dart';
import 'package:route/providers/chat_provider.dart';
import 'package:route/providers/settings_provider.dart';
import 'package:route/providers/usage_provider.dart';
import 'package:route/screens/debug_screen.dart';
import 'package:route/screens/home_screen.dart';
import 'package:route/screens/model_picker_screen.dart';
import 'package:route/screens/settings_screen.dart';
import 'package:route/screens/usage_screen.dart';
import 'package:route/services/debug_log.dart';
import 'package:route/services/openrouter_service.dart';
import 'package:route/theme/app_theme.dart';

import '../helpers/fakes.dart';

/// Smoke tests that key screens lay out without RenderFlex overflow at the
/// small logical widths typical of Android phones.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 320 = compact/older phones, 360 = common Android, 412 = large phone.
  const phoneWidths = [320.0, 360.0, 412.0];

  late SettingsProvider settings;
  late ChatProvider chat;
  late UsageProvider usage;

  Future<void> buildProviders(WidgetTester tester) async {
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
  }

  Widget wrap(Widget home) => MaterialApp(
        theme: AppTheme.dark,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<UsageProvider>.value(value: usage),
            ChangeNotifierProvider<DebugLog>.value(value: DebugLog()),
            ChangeNotifierProvider<ChatProvider>.value(value: chat),
          ],
          child: home,
        ),
      );

  Future<void> pumpAt(WidgetTester tester, double width, Widget home) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 780);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(home));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('home lays out at phone widths with a long model id and usage',
      (tester) async {
    await buildProviders(tester);
    // Worst case for the header: a long model name, a visible cost, and the
    // streaming activity indicator enabled.
    await settings.setAnimateModelIndicator(true);
    chat.newConversation();
    chat.setModelForCurrent(
      'some-vendor/really-long-model-name-4.5-instruct-preview',
    );
    usage.record(
      'some-vendor/really-long-model-name-4.5-instruct-preview',
      const TokenUsage(promptTokens: 1234, completionTokens: 5678, cost: 1.2345),
    );

    for (final w in phoneWidths) {
      await pumpAt(tester, w, const HomeScreen());
      expect(tester.takeException(), isNull, reason: 'overflow at width $w');
    }
  });

  testWidgets('settings and usage screens lay out at phone widths',
      (tester) async {
    await buildProviders(tester);
    usage.record(
      'x/y',
      const TokenUsage(promptTokens: 10, completionTokens: 20, cost: 0.5),
    );

    for (final w in phoneWidths) {
      await pumpAt(tester, w, const SettingsScreen());
      expect(tester.takeException(), isNull,
          reason: 'settings overflow at $w');

      await pumpAt(tester, w, const UsageScreen());
      expect(tester.takeException(), isNull, reason: 'usage overflow at $w');
    }
  });

  testWidgets('model picker lays out at phone widths', (tester) async {
    await buildProviders(tester);
    final service = FakeOpenRouterService()
      ..models = [
        OpenRouterModel(
          id: 'some-vendor/really-long-model-name-4.5-instruct-preview',
          name: 'Really Long Model Name 4.5 Instruct Preview',
          contextLength: 2000000,
          promptPrice: 0.000015,
          completionPrice: 0.00006,
          supportedParameters: const ['tools', 'reasoning'],
        ),
        OpenRouterModel(
          id: 'b/beta',
          name: 'Beta',
          contextLength: 8000,
          promptPrice: 0,
          completionPrice: 0,
        ),
      ];

    final picker = MaterialApp(
      theme: AppTheme.dark,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<DebugLog>.value(value: DebugLog()),
          Provider<OpenRouterService>.value(value: service),
        ],
        child: const ModelPickerScreen(),
      ),
    );

    for (final w in phoneWidths) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(w, 780);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(picker);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'model picker overflow at $w');
    }
  });

  testWidgets('debug session detail lays out at phone widths', (tester) async {
    await buildProviders(tester);
    final log = DebugLog();
    final s = log.begin(
      title: 'A fairly long debug session title that might wrap on phones',
      model: 'some-vendor/really-long-model-name-4.5-instruct-preview',
      requestBody: '{"model":"some-vendor/x","stream":true,"messages":[]}',
    );
    log.response(s, httpStatus: 200);
    log.chunk(s, '{"d":1}', content: 'Hello ');
    log.complete(s, httpStatus: 200, finishReason: 'stop');

    // Providers sit above MaterialApp so the pushed detail route can read them.
    final debug = MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<DebugLog>.value(value: log),
      ],
      child: MaterialApp(theme: AppTheme.dark, home: const DebugScreen()),
    );

    for (final w in phoneWidths) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(w, 780);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(debug);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('debug session title'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'debug detail overflow at $w');
      // Back out for the next size.
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
