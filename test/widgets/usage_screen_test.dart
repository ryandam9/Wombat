import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/models/usage.dart';
import 'package:wombat/providers/usage_provider.dart';
import 'package:wombat/screens/usage_screen.dart';
import 'package:wombat/theme/app_theme.dart';
import 'package:wombat/widgets/ui_kit.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders session totals, balance and per-model breakdown',
      (tester) async {
    late ProviderContainer container;
    await tester.runAsync(() async {
      final service = FakeOpenRouterService()
        ..credits = const CreditBalance(totalCredits: 5, totalUsage: 2);
      container = await createContainer(service: service);
      container.read(usageProvider.notifier).record(
            'openai/gpt-4o',
            const TokenUsage(
                promptTokens: 100, completionTokens: 40, cost: 0.01),
          );
    });
    addTearDown(container.dispose);

    // Tall viewport so the lazy ListView builds the lower panels too.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 2800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark, home: const UsageScreen()),
      ),
    );
    // Let the post-frame credit fetch resolve.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('Session usage'), findsOneWidget);
    // Input / output / cost / requests.
    expect(find.byType(StatCard), findsNWidgets(4));
    expect(find.text('openai/gpt-4o'), findsOneWidget);
    // LabelValueRow renders labels uppercase.
    expect(find.text('REMAINING'), findsOneWidget);
    // Section headers and the new usage-summary recap.
    expect(find.text('By model'), findsOneWidget);
    expect(find.text('Usage summary'), findsOneWidget);
    expect(find.text('AVG COST / REQUEST'), findsOneWidget);
  });
}
