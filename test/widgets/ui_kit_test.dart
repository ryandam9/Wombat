import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/widgets/ui_kit.dart';

void main() {
  testWidgets('LabelValueRow values share a common right edge', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          // Different label and value lengths — these used to leave the
          // value right edges misaligned.
          body: Center(
            child: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LabelValueRow(label: 'Context window', value: '65,536 tokens'),
                  LabelValueRow(label: 'Output price', value: r'$0.50 / M'),
                  LabelValueRow(label: 'Used', value: r'$3.82'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final r1 = tester.getTopRight(find.text('65,536 tokens')).dx;
    final r2 = tester.getTopRight(find.text(r'$0.50 / M')).dx;
    final r3 = tester.getTopRight(find.text(r'$3.82')).dx;

    expect(r2, moreOrLessEquals(r1, epsilon: 0.5));
    expect(r3, moreOrLessEquals(r1, epsilon: 0.5));
  });
}
