import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:route/models/openrouter_model.dart';
import 'package:route/models/usage.dart';
import 'package:route/providers/settings_provider.dart';
import 'package:route/providers/usage_provider.dart';
import 'package:route/screens/compare_screen.dart';
import 'package:route/services/openrouter_service.dart';
import 'package:route/widgets/message_bubble.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsProvider settings;
  late FakeOpenRouterService service;
  late UsageProvider usage;

  setUp(() async {
    settings = await buildLoadedSettings();
    service = FakeOpenRouterService()
      ..chunks = ['Hello ', 'world']
      ..usage = const TokenUsage(promptTokens: 3, completionTokens: 2, cost: 0.01)
      ..models = [
        OpenRouterModel(id: 'a/alpha', name: 'Alpha'),
        OpenRouterModel(id: 'b/beta', name: 'Beta'),
      ];
    usage = UsageProvider(service: service, settings: settings);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    // Wide enough for the compare side-by-side layout (>=760) but below the
    // model picker's detail-panel breakpoint (1000) so a card tap pops.
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<UsageProvider>.value(value: usage),
          Provider<OpenRouterService>.value(value: service),
        ],
        child: const MaterialApp(home: CompareScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows a placeholder until a run starts', (tester) async {
    await pump(tester);
    expect(find.text('Compare models side by side'), findsOneWidget);
    // Run is disabled with no models or prompt.
    final runButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Run'),
    );
    expect(runButton.onPressed, isNull);
  });

  testWidgets('runs the same prompt against multiple models', (tester) async {
    await pump(tester);

    // Pick two models via the model picker (tapping a card pops it back).
    Future<void> addModel(String name) async {
      await tester.tap(find.text('Add model'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).first);
      await tester.pumpAndSettle();
    }

    await addModel('Alpha');
    await addModel('Beta');

    await tester.enterText(find.byType(TextField).first, 'Hi there');
    await tester.pump();

    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();

    // Both models produced a rendered reply column.
    expect(find.byType(MessageBubble), findsNWidgets(2));
    // Usage from both runs was recorded (2 × $0.01).
    expect(usage.cost, closeTo(0.02, 1e-9));
  });
}
