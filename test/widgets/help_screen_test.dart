import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/screens/help_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, {double width = 800}) async {
    // Tall viewport so all sections/topics build in the lazy ListView.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
    await tester.pump();
  }

  testWidgets('groups topics into sections, collapsed by default', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Help & Troubleshoot'), findsOneWidget);

    // Section headers.
    expect(find.text('VOICE & AUDIO'), findsOneWidget);
    expect(find.text('MODELS & USAGE'), findsOneWidget);
    expect(find.text('SETUP, PRIVACY & DATA'), findsOneWidget);

    // Topic summaries are visible...
    expect(find.text('How voice messages work'), findsOneWidget);
    expect(find.text('Comparing models'), findsOneWidget);

    // ...but the details are hidden until a topic is expanded.
    expect(find.text('Capture'), findsNothing);
    expect(find.textContaining('input_audio'), findsNothing);
  });

  testWidgets('uses a multi-column layout on wide screens', (tester) async {
    await pump(tester, width: 1300);

    // All three sections render side by side without overflow.
    expect(tester.takeException(), isNull);
    expect(find.text('VOICE & AUDIO'), findsOneWidget);
    expect(find.text('MODELS & USAGE'), findsOneWidget);
    expect(find.text('SETUP, PRIVACY & DATA'), findsOneWidget);
    // Multi-column uses a horizontally-scrolling Row of columns rather than a
    // single ListView.
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('data-storage help reflects the SQLite + files storage', (
    tester,
  ) async {
    await pump(tester);

    // Summary is accurate to how data is actually persisted now…
    expect(
      find.text('Conversations live on your device in a local database.'),
      findsOneWidget,
    );
    // …and the old "as JSON" wording is gone.
    expect(find.textContaining('as JSON'), findsNothing);

    await tester.tap(find.text('Where is my data stored?'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'SQLite database, and attachment bytes are kept as files on disk',
      ),
      findsOneWidget,
    );
  });

  testWidgets('expanding a topic reveals its details', (tester) async {
    await pump(tester);

    await tester.tap(find.text('How voice messages work'));
    await tester.pumpAndSettle();

    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Persistence'), findsOneWidget);
    expect(find.textContaining('input_audio'), findsOneWidget);
    expect(find.text('The model must support audio input'), findsOneWidget);
  });
}
