import 'package:auris/auris.dart';
import 'package:auris/auris_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders every Auris widget the app uses, under an AurisTheme, to confirm
/// they construct and lay out without throwing (they read a scheme from the
/// theme extension, so a bare MaterialApp would fail).
void main() {
  testWidgets('all adopted Auris widgets render without error',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AurisTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const AurisPanel(title: 'Panel', code: '01', child: Text('x')),
                const AurisContainer(child: Text('container')),
                const AurisBadge('BADGE'),
                const AurisDataRow(label: 'Label', value: 'Value'),
                AurisSelect<int>(
                  value: 1,
                  options: const [
                    AurisSelectOption(value: 1, label: 'ONE'),
                    AurisSelectOption(value: 2, label: 'TWO'),
                  ],
                  onChanged: (_) {},
                ),
                AurisSwitch(value: true, label: 'SW', onChanged: (_) {}),
                AurisRadio<int>(
                  value: 1,
                  groupValue: 1,
                  label: 'RADIO',
                  onChanged: (_) {},
                ),
                const AurisProgressBar(
                  value: 0.5,
                  label: 'CONTEXT',
                  valueLabel: '64K',
                ),
                const AurisStatCard(label: 'Sessions', value: '3'),
                const AurisNotification(
                  title: 'NOTE',
                  message: 'message',
                  variant: AurisNotificationVariant.error,
                ),
                const AurisTerminal(
                  lines: [AurisTerminalLine('> boot ok')],
                  height: 160,
                ),
                const AurisScanBracket(child: Icon(Icons.alt_route)),
                const AurisStepIndicator(
                  step: 1,
                  state: AurisStepState.active,
                ),
                const SizedBox(
                  width: 100,
                  height: 100,
                  child: AurisHexOrnament(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.byType(AurisPanel), findsWidgets);
    expect(find.byType(AurisTerminal), findsOneWidget);
  });
}
