import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:route/theme/app_theme.dart';

import '../helpers/fakes.dart';

/// Smoke tests that key screens lay out without RenderFlex overflow at the
/// small logical widths typical of Android phones.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 320 = compact/older phones, 360 = common Android, 412 = large phone.
  const phoneWidths = [320.0, 360.0, 412.0];

  late ProviderContainer container;

  Future<void> setup(WidgetTester tester,
      {FakeOpenRouterService? service}) async {
    await tester.runAsync(() async {
      container = await createContainer(
        service: service ?? FakeOpenRouterService(),
        store: FakeConversationStore(),
      );
      await waitUntil(() => !container.read(chatProvider.notifier).loading);
    });
    addTearDown(container.dispose);
  }

  Widget wrap(Widget home) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark, home: home),
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
    await setup(tester);
    // Worst case for the header: a long model name, a visible cost, and the
    // streaming activity indicator enabled.
    await container.read(settingsProvider.notifier).setAnimateModelIndicator(true);
    final chat = container.read(chatProvider.notifier);
    chat.newConversation();
    chat.setModelForCurrent(
      'some-vendor/really-long-model-name-4.5-instruct-preview',
    );
    container.read(usageProvider.notifier).record(
          'some-vendor/really-long-model-name-4.5-instruct-preview',
          const TokenUsage(
              promptTokens: 1234, completionTokens: 5678, cost: 1.2345),
        );

    for (final w in phoneWidths) {
      await pumpAt(tester, w, const HomeScreen());
      expect(tester.takeException(), isNull, reason: 'overflow at width $w');
    }
  });

  testWidgets('settings and usage screens lay out at phone widths',
      (tester) async {
    await setup(tester);
    container.read(usageProvider.notifier).record(
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
    await setup(tester, service: service);

    for (final w in phoneWidths) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(w, 780);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap(const ModelPickerScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'model picker overflow at $w');
    }
  });

  testWidgets('debug session detail lays out at phone widths', (tester) async {
    await setup(tester);
    final log = container.read(debugLogProvider.notifier);
    final s = log.begin(
      title: 'A fairly long debug session title that might wrap on phones',
      model: 'some-vendor/really-long-model-name-4.5-instruct-preview',
      requestBody: '{"model":"some-vendor/x","stream":true,"messages":[]}',
    );
    log.response(s, httpStatus: 200);
    log.chunk(s, '{"d":1}', content: 'Hello ');
    log.complete(s, httpStatus: 200, finishReason: 'stop');

    for (final w in phoneWidths) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(w, 780);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap(const DebugScreen()));
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
