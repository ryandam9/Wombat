import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/models/attachment.dart';
import 'package:wombat/models/chat_message.dart';
import 'package:wombat/models/openrouter_model.dart';
import 'package:wombat/models/usage.dart';
import 'package:wombat/providers/compare_provider.dart';
import 'package:wombat/providers/usage_provider.dart';
import 'package:wombat/screens/compare_screen.dart';
import 'package:wombat/services/openrouter_service.dart';
import 'package:wombat/widgets/message_bubble.dart';

import '../helpers/fakes.dart';

/// A fake that streams normally for every model except [failModelId], which
/// errors — simulating one model being unavailable while the others succeed.
class _OneModelFailsService extends FakeOpenRouterService {
  _OneModelFailsService(this.failModelId);

  final String failModelId;

  @override
  Stream<String> streamChat({
    required String apiKey,
    required String model,
    required List<ChatMessage> messages,
    bool imageOutput = false,
    void Function(TokenUsage usage)? onUsage,
    void Function(MessageAttachment image)? onImage,
    void Function(MessageAttachment audio)? onAudio,
    void Function(String debugSessionId)? onDebugSession,
  }) {
    if (model == failModelId) {
      return Stream<String>.error(
        OpenRouterException('Model unavailable', statusCode: 502),
      );
    }
    return super.streamChat(
      apiKey: apiKey,
      model: model,
      messages: messages,
      imageOutput: imageOutput,
      onUsage: onUsage,
      onImage: onImage,
      onAudio: onAudio,
      onDebugSession: onDebugSession,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FakeOpenRouterService service;

  setUp(() async {
    service = FakeOpenRouterService()
      ..chunks = ['Hello ', 'world']
      ..usage = const TokenUsage(promptTokens: 3, completionTokens: 2, cost: 0.01)
      ..models = [
        OpenRouterModel(id: 'a/alpha', name: 'Alpha'),
        OpenRouterModel(id: 'b/beta', name: 'Beta'),
      ];
    container = await createContainer(service: service);
    addTearDown(container.dispose);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    // Wide enough for the compare side-by-side layout (>=760) but below the
    // model picker's detail-panel breakpoint (1000) so a card tap pops.
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CompareScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows a placeholder until a run starts', (tester) async {
    await pump(tester);
    expect(find.text('Compare models side by side'), findsOneWidget);
    // A Debug button is available to inspect the underlying API sessions.
    expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
    // Run is disabled with no models or prompt.
    final runButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Run'),
    );
    expect(runButton.onPressed, isNull);
  });

  testWidgets('runs the same prompt against multiple models', (tester) async {
    await pump(tester);

    // Pick two models via the model picker (tapping a card pops it back).
    Future<void> addModel(String name) async {
      await tester.tap(find.text('Add model'));
      await tester.pumpAndSettle();
      // Multi-select picker: tick the model, then confirm with the FAB.
      await tester.tap(find.text(name).first);
      await tester.pump();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
    }

    await addModel('Alpha');
    await addModel('Beta');

    await tester.enterText(find.byType(TextField).first, 'Hi there');
    await tester.pump();

    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();

    // Both models produced a rendered reply column.
    expect(find.byType(MessageBubble), findsNWidgets(2));
    // Usage from both runs was recorded (2 × $0.01).
    expect(container.read(usageProvider).cost, closeTo(0.02, 1e-9));
  });

  testWidgets('adds several models in one trip through the picker',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Add model'));
    await tester.pumpAndSettle();
    // Tick two models, then confirm once.
    await tester.tap(find.text('Alpha').first);
    await tester.tap(find.text('Beta').first);
    await tester.pump();
    // The running "Selected" summary shows what's been ticked so far.
    expect(find.text('SELECTED (2)'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton)); // "Add 2"
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'Alpha'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Beta'), findsOneWidget);
  });

  testWidgets('preserves the session after leaving and returning',
      (tester) async {
    await pump(tester);

    Future<void> addModel(String name) async {
      await tester.tap(find.text('Add model'));
      await tester.pumpAndSettle();
      // Multi-select picker: tick the model, then confirm with the FAB.
      await tester.tap(find.text(name).first);
      await tester.pump();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
    }

    await addModel('Alpha');
    await addModel('Beta');
    await tester.enterText(find.byType(TextField).first, 'Hi there');
    await tester.pump();
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    expect(find.byType(MessageBubble), findsNWidgets(2));

    // Simulate pressing Back: tear the screen down (disposes its State) while
    // keeping the same provider container, then return to it.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SizedBox())),
      ),
    );
    await tester.pump();
    expect(find.byType(CompareScreen), findsNothing);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CompareScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The models, results and prompt all came back.
    expect(find.widgetWithText(InputChip, 'Alpha'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Beta'), findsOneWidget);
    expect(find.byType(MessageBubble), findsNWidgets(2));
    expect(find.widgetWithText(TextField, 'Hi there'), findsOneWidget);
  });

  // Drives the notifier directly (no UI pump loop) so the concurrent streams +
  // throttle timers run on the real event loop deterministically.
  test('one model failing is isolated — the others still answer', () async {
    final failService = _OneModelFailsService('b/beta')
      ..chunks = ['Hello ', 'world']
      ..usage =
          const TokenUsage(promptTokens: 3, completionTokens: 2, cost: 0.01);
    final c = await createContainer(service: failService);
    addTearDown(c.dispose);

    final notifier = c.read(compareProvider.notifier);
    notifier.addModel(OpenRouterModel(id: 'a/alpha', name: 'Alpha'));
    notifier.addModel(OpenRouterModel(id: 'b/beta', name: 'Beta'));
    notifier.setPrompt('Hi there');
    notifier.run();

    // Both runs are kicked off concurrently; let them finish (chunks, the
    // ~60ms streaming throttle, and the error delivery).
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final state = c.read(compareProvider);
    final alpha = state.runs.firstWhere((r) => r.model.id == 'a/alpha');
    final beta = state.runs.firstWhere((r) => r.model.id == 'b/beta');

    // Alpha streamed its full reply; Beta carries an isolated error.
    expect(alpha.error, isNull);
    expect(alpha.message.content, 'Hello world');
    expect(alpha.message.isStreaming, isFalse);
    expect(beta.error, contains('Model unavailable'));
    expect(beta.message.content, isEmpty);
    expect(beta.message.isStreaming, isFalse);

    // Only the successful run recorded usage, and the session settles even
    // though one run errored.
    expect(c.read(usageProvider).cost, closeTo(0.01, 1e-9));
    expect(state.running, isFalse);
  });
}
