import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:route/providers/settings_provider.dart';
import 'package:route/screens/settings_screen.dart';
import 'package:route/theme/app_theme.dart';

import '../helpers/fakes.dart';

Future<void> _pump(WidgetTester tester, SettingsProvider settings) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: const SettingsScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsProvider settings;
  setUp(() async {
    settings = await buildLoadedSettings();
  });

  testWidgets('narrow layout stacks every panel without layout errors',
      (tester) async {
    // Below the 720 breakpoint every section is stacked in one scroll view.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(500, 3000);
    addTearDown(tester.view.reset);

    await _pump(tester, settings);

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

  testWidgets('wide layout shows a nav list and the selected detail',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.reset);

    await _pump(tester, settings);
    expect(tester.takeException(), isNull);

    // The two-pane nav lists every section; the Fonts detail is hidden until
    // its nav entry is tapped.
    expect(find.text('Fonts'), findsOneWidget);
    expect(find.text('HEADING'), findsNothing);

    await tester.tap(find.text('Fonts'));
    await tester.pumpAndSettle();

    expect(find.text('HEADING'), findsOneWidget);
    expect(find.text('Roboto Condensed'), findsWidgets);
  });
}
