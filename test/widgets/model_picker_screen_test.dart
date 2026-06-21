import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/models/openrouter_model.dart';
import 'package:wombat/providers/settings_provider.dart';
import 'package:wombat/screens/model_picker_screen.dart';

import '../helpers/fakes.dart';

OpenRouterModel _model(
  String id,
  String name, {
  int? context,
  double? prompt,
  List<String> params = const [],
}) =>
    OpenRouterModel(
      id: id,
      name: name,
      contextLength: context,
      promptPrice: prompt,
      completionPrice: prompt,
      supportedParameters: params,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FakeOpenRouterService service;

  setUp(() async {
    service = FakeOpenRouterService()
      ..models = [
        _model('a/alpha', 'Alpha', context: 200000, prompt: 0.000002,
            params: ['tools']),
        _model('b/beta', 'Beta', context: 8000, prompt: 0),
        // Free, with tools and high context — matches several filters at once.
        _model('c/gamma', 'Gamma', context: 150000, prompt: 0,
            params: ['tools']),
      ];
    container = await createContainer(
      prefs: const {'default_model': 'a/alpha'},
      service: service,
    );
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester, {Size size = const Size(1300, 1000)}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ModelPickerScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists models with a detail panel on a wide screen',
      (tester) async {
    await pump(tester);

    expect(find.text('Alpha'), findsWidgets);
    expect(find.text('Beta'), findsWidgets);
    // The detail panel defaults to the configured default model.
    expect(find.text('Selected model'), findsOneWidget);
    expect(find.text('Select model'), findsOneWidget);
    expect(find.text('Key details'), findsOneWidget);
  });

  testWidgets('Free filter narrows the list to free models', (tester) async {
    // Narrow surface → no detail panel, so only the grid is on screen.
    await pump(tester, size: const Size(700, 1000));

    await tester.tap(find.widgetWithText(FilterChip, 'Free'));
    await tester.pumpAndSettle();

    expect(find.text('Beta'), findsWidgets); // free
    expect(find.text('Alpha'), findsNothing); // paid, filtered out
  });

  testWidgets('filters combine (AND) and toggle independently',
      (tester) async {
    await pump(tester, size: const Size(760, 1000)); // narrow: no detail panel

    Future<void> tapChip(String label) async {
      final chip = find.widgetWithText(FilterChip, label);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    await tapChip('Free');
    expect(find.text('Beta'), findsWidgets);
    expect(find.text('Gamma'), findsWidgets);
    expect(find.text('Alpha'), findsNothing); // paid

    // Adding Tools narrows further: Beta (free, no tools) drops out.
    await tapChip('Tools');
    expect(find.text('Gamma'), findsWidgets);
    expect(find.text('Beta'), findsNothing);

    // Both chips stay selected (multi-select, not radio).
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Free')).selected, isTrue);
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Tools')).selected, isTrue);

    // Toggling Tools off restores the Free-only result.
    await tapChip('Tools');
    expect(find.text('Beta'), findsWidgets);
  });

  testWidgets('sort direction toggle flips order', (tester) async {
    await pump(tester, size: const Size(760, 1000));

    // Default: ascending (arrow up shown).
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bookmark toggles a favorite in settings', (tester) async {
    await pump(tester);
    expect(container.read(settingsProvider).isFavoriteModel('b/beta'), isFalse);

    await tester.tap(find.byIcon(Icons.bookmark_border).first);
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).favoriteModels, isNotEmpty);
  });

  testWidgets('narrow: tapping a model opens a detail sheet with a Select button',
      (tester) async {
    await pump(tester, size: const Size(420, 900)); // no inline detail panel

    // No inline "Select model" button at this width…
    expect(find.text('Select model'), findsNothing);

    await tester.tap(find.text('Alpha').first);
    await tester.pumpAndSettle();

    // …tapping a card opens a bottom sheet with an explicit select action.
    expect(find.text('Select model'), findsOneWidget);
    expect(find.text('View documentation'), findsOneWidget);
  });

  testWidgets('narrow: all filter chips stay on-screen (wrap, not clipped)',
      (tester) async {
    await pump(tester, size: const Size(420, 900));

    // The last filter chip wraps onto a new line instead of clipping off the
    // right edge.
    final tools = tester.getRect(find.widgetWithText(FilterChip, 'Tools'));
    expect(tools.right, lessThanOrEqualTo(420),
        reason: 'Tools chip should wrap on-screen, not run off the right edge');
  });

  testWidgets('search input is debounced', (tester) async {
    await pump(tester, size: const Size(420, 900)); // no inline detail panel

    expect(find.text('Alpha'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'beta');
    await tester.pump(); // before the debounce fires: still unfiltered
    expect(find.text('Alpha'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 300)); // debounce fires
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsWidgets);
  });
}
