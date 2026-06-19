import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:route/models/usage.dart';
import 'package:route/screens/debug_screen.dart';
import 'package:route/services/debug_log.dart';
import 'package:route/theme/app_theme.dart';

// Provider sits above MaterialApp so pushed detail routes can read it too.
Widget _wrap(DebugLog log) => ChangeNotifierProvider<DebugLog>.value(
      value: log,
      child: MaterialApp(theme: AppTheme.dark, home: const DebugScreen()),
    );

DebugLog _logWithSession() {
  final log = DebugLog();
  final s = log.begin(
    title: 'Explain vector databases',
    model: 'ai21/jamba',
    requestBody: '{"model":"ai21/jamba","stream":true}',
  );
  log.response(s, httpStatus: 200);
  log.chunk(s, '{"d":1}', content: 'Vector databases are ');
  log.chunk(s, '{"d":2}', content: 'great.');
  log.setUsage(
      s, const TokenUsage(promptTokens: 10, completionTokens: 20, cost: 0.02));
  log.complete(s, httpStatus: 200, finishReason: 'stop');
  return log;
}

void main() {
  testWidgets('shows an empty state when there is no activity',
      (tester) async {
    await tester.pumpWidget(_wrap(DebugLog()));
    expect(find.text('No sessions yet'), findsOneWidget);
  });

  testWidgets('lists a session with its prompt and model', (tester) async {
    await tester.pumpWidget(_wrap(_logWithSession()));
    await tester.pump();

    expect(find.text('Explain vector databases'), findsOneWidget);
    expect(find.textContaining('ai21/jamba'), findsWidgets);
  });

  testWidgets('opens session detail with assembled response and timeline',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_logWithSession()));
    await tester.pump();

    await tester.tap(find.text('Explain vector databases'));
    await tester.pumpAndSettle();

    // Stat header + assembled response (not raw frames).
    expect(find.text('Response (assembled)'), findsOneWidget);
    // Appears in both the assembled response and the streaming timeline event.
    expect(find.textContaining('Vector databases are great.'), findsWidgets);
    expect(find.text('Event stream'), findsOneWidget);
    // Filter chips present.
    expect(find.widgetWithText(ChoiceChip, 'Response'), findsOneWidget);
  });

  testWidgets('clear empties the log', (tester) async {
    final log = _logWithSession();
    await tester.pumpWidget(_wrap(log));

    await tester.tap(find.byTooltip('Clear'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('No sessions yet'), findsOneWidget);
  });

  testWidgets('begin() during initState does not crash the build',
      (tester) async {
    // Reproduces the model-picker path: a screen starts a session in its
    // initState while the DebugLog provider is being watched.
    final log = DebugLog();
    await tester.pumpWidget(
      ChangeNotifierProvider<DebugLog>.value(
        value: log,
        child: MaterialApp(
          home: Builder(builder: (context) {
            context.watch<DebugLog>(); // provider has a dependent
            return const _BeginOnInit();
          }),
        ),
      ),
    );
    await tester.pump();
    // Let the notification throttle timer fire so none is left pending.
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(log.length, 1);
  });
}

/// Test helper: starts a debug session from initState (like ModelPickerScreen).
class _BeginOnInit extends StatefulWidget {
  const _BeginOnInit();

  @override
  State<_BeginOnInit> createState() => _BeginOnInitState();
}

class _BeginOnInitState extends State<_BeginOnInit> {
  @override
  void initState() {
    super.initState();
    context.read<DebugLog>().begin(title: 'from initState');
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
