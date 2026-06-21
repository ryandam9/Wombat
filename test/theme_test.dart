import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/theme/app_theme.dart';

void main() {
  test('AppTheme provides light and dark Material 3 themes', () {
    expect(AppTheme.light, isA<ThemeData>());
    expect(AppTheme.dark, isA<ThemeData>());
    expect(AppTheme.light.useMaterial3, isTrue);
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });

  test('custom-accent themes do not emit FlexColorScheme warnings', () {
    const customSeed = Color(0xFF2E7D32); // any non-default accent
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      AppTheme.lightFor(customSeed);
      AppTheme.darkFor(customSeed);
    } finally {
      debugPrint = original;
    }
    expect(
      logs.where((l) => l.contains('FlexColorScheme WARNING')),
      isEmpty,
      reason: 'custom accent themes should not log FlexColorScheme warnings',
    );
  });

  test('page headings use a bold Neo Brutalist header', () {
    for (final t in [AppTheme.light, AppTheme.dark]) {
      expect(t.appBarTheme.backgroundColor, t.colorScheme.surface);
      expect(t.appBarTheme.foregroundColor, t.colorScheme.onSurface);
      expect(t.appBarTheme.titleTextStyle?.fontSize, 24);
      expect(t.appBarTheme.titleTextStyle?.fontWeight, FontWeight.w800);
    }
    // Seeded (non-default) accents get the same treatment.
    final seeded = AppTheme.lightFor(const Color(0xFF2E7D32));
    expect(seeded.appBarTheme.backgroundColor, seeded.colorScheme.surface);
    expect(seeded.appBarTheme.titleTextStyle?.fontSize, 24);
  });

  testWidgets('renders a Material app with AppTheme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const Scaffold(body: Center(child: Text('Wombat'))),
      ),
    );
    expect(find.text('Wombat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
