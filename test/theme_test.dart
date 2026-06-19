import 'package:auris/auris.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AurisTheme factories return ThemeData for both brightnesses', () {
    expect(AurisTheme.light(), isA<ThemeData>());
    expect(AurisTheme.dark(), isA<ThemeData>());
    expect(AurisTheme.light().brightness, Brightness.light);
    expect(AurisTheme.dark().brightness, Brightness.dark);
  });

  testWidgets('renders a Material app skinned with AurisTheme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AurisTheme.light(),
        darkTheme: AurisTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const Scaffold(body: Center(child: Text('Route'))),
      ),
    );

    expect(find.text('Route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
