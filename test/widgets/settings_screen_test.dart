import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/providers/settings_provider.dart';
import 'package:wombat/screens/settings_screen.dart';
import 'package:wombat/theme/app_theme.dart';

import '../helpers/fakes.dart';

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.dark, home: const SettingsScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  setUp(() async {
    container = await createContainer();
    addTearDown(container.dispose);
  });

  testWidgets('narrow layout stacks every panel without layout errors',
      (tester) async {
    // Below the 720 breakpoint every section is stacked in one scroll view.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(500, 3000);
    addTearDown(tester.view.reset);

    await _pump(tester, container);

    // The font-picker Row previously threw a RenderFlex unbounded-width error.
    expect(tester.takeException(), isNull);

    // Scroll the lazy ListView down to the Fonts panel at the bottom.
    await tester.scrollUntilVisible(
      find.text('HEADING'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('HEADING'), findsOneWidget);
    // All fonts default to Roboto Condensed; its label shows on the dropdowns.
    expect(find.text('Roboto Condensed'), findsWidgets);
  });

  testWidgets('wide layout packs every card without a nav rail',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 1600);
    addTearDown(tester.view.reset);

    await _pump(tester, container);
    expect(tester.takeException(), isNull);

    // Every section card renders at once (no nav/detail split), including the
    // new Font size card. SectionPanel renders titles upper-cased.
    expect(find.text('SETUP'), findsOneWidget);
    expect(find.text('FONTS'), findsOneWidget);
    expect(find.text('FONT SIZE'), findsOneWidget);
    expect(find.text('HEADING'), findsOneWidget);
    expect(find.text('Roboto Condensed'), findsWidgets);
    // Default font-size selection shows on the size dropdowns.
    expect(find.text('Default'), findsWidgets);
  });

  testWidgets('the name field debounces its save and flashes "Saved"',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 1600);
    addTearDown(tester.view.reset);

    await _pump(tester, container);

    await tester.enterText(
        find.widgetWithText(TextField, 'Your name').first, 'Ravi');
    await tester.pump(); // before the debounce: not yet persisted
    expect(container.read(settingsProvider).userName, '');

    await tester.pump(const Duration(milliseconds: 500)); // debounce fires
    expect(container.read(settingsProvider).userName, 'Ravi');
    expect(find.text('Saved'), findsOneWidget);
  });
}
