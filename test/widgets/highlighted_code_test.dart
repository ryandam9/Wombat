import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/widgets/highlighted_code.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('short code renders directly with no toggle', (tester) async {
    await tester.pumpWidget(_wrap(const HighlightedCode(
      code: 'void main() {}',
      language: 'dart',
      fontFamily: 'monospace',
    )));

    expect(find.byType(HighlightView), findsOneWidget);
    expect(find.text('Show code'), findsNothing);
    expect(find.text('Hide code'), findsNothing);
  });

  testWidgets('long code is collapsed by default and can be shown/hidden',
      (tester) async {
    final longCode =
        List.generate(40, (i) => 'final value$i = $i;').join('\n');
    await tester.pumpWidget(_wrap(HighlightedCode(
      code: longCode,
      language: 'dart',
      fontFamily: 'monospace',
    )));

    // Collapsed by default: code hidden behind a "Show code" toggle.
    expect(find.byType(HighlightView), findsNothing);
    expect(find.text('Show code'), findsOneWidget);
    expect(find.textContaining('40 lines'), findsOneWidget);

    await tester.tap(find.text('Show code'));
    await tester.pump();
    expect(find.byType(HighlightView), findsOneWidget);
    expect(find.text('Hide code'), findsOneWidget);

    await tester.tap(find.text('Hide code'));
    await tester.pump();
    expect(find.byType(HighlightView), findsNothing);
    expect(find.text('Show code'), findsOneWidget);
  });
}
