import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/screens/help_screen.dart';

void main() {
  testWidgets('renders the voice-message flow and troubleshooting', (
    tester,
  ) async {
    // Tall viewport so the lazy ListView builds the lower sections too.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 2000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
    await tester.pump();

    expect(find.text('Help & Troubleshoot'), findsOneWidget);
    expect(find.text('How voice messages work'.toUpperCase()), findsOneWidget);
    expect(find.text('Troubleshooting'.toUpperCase()), findsOneWidget);

    // The four-step flow and the input_audio snippet are present.
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Persistence'), findsOneWidget);
    expect(find.textContaining('input_audio'), findsOneWidget);

    // The model-support caveat is surfaced.
    expect(find.text('The model must support audio input'), findsOneWidget);
  });
}
