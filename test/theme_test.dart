import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route/theme/app_theme.dart';

void main() {
  test('AppTheme provides light and dark Material 3 themes', () {
    expect(AppTheme.light, isA<ThemeData>());
    expect(AppTheme.dark, isA<ThemeData>());
    expect(AppTheme.light.useMaterial3, isTrue);
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });

  testWidgets('renders a Material app with AppTheme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const Scaffold(body: Center(child: Text('Route'))),
      ),
    );
    expect(find.text('Route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
