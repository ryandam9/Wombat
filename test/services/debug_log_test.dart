import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route/models/usage.dart';
import 'package:route/services/debug_log.dart';

/// Returns a [DebugLog] notifier mounted in a disposable container.
DebugLog makeLog({int capacity = 50}) {
  final container = ProviderContainer(overrides: [
    debugLogProvider.overrideWith(() => DebugLog(capacity: capacity)),
  ]);
  addTearDown(container.dispose);
  return container.read(debugLogProvider.notifier);
}

void main() {
  test('begins a session with a started event and request body', () {
    final log = makeLog();
    expect(log.isEmpty, isTrue);

    final s = log.begin(
      title: 'Explain vectors',
      model: 'ai21/jamba',
      requestBody: '{"model":"ai21/jamba"}',
    );

    expect(log.isEmpty, isFalse);
    expect(s, isNotNull);
    expect(s!.title, 'Explain vectors');
    expect(s.model, 'ai21/jamba');
    expect(s.status, SessionStatus.pending);
    expect(s.events.map((e) => e.title),
        containsAll(['Session started', 'Request sent']));
  });

  test('assembles streamed content and coalesces stream events', () {
    final log = makeLog();
    final s = log.begin(title: 't')!;
    log.response(s, httpStatus: 200);

    // Two deltas within the coalesce window collapse into one event.
    log.chunk(s, '{"d":1}', content: 'Hello ');
    log.chunk(s, '{"d":2}', content: 'world');

    expect(s.content, 'Hello world');
    expect(s.status, SessionStatus.streaming);
    expect(s.chunkCount, 2);
    expect(s.firstTokenAt, isNotNull);
    final streamEvents = s.events.where((e) => e.title == 'Streaming').toList();
    expect(streamEvents.length, 1);
    expect(streamEvents.single.subtitle, 'Hello world');
  });

  test('captures reasoning deltas separately', () {
    final log = makeLog();
    final s = log.begin(title: 't')!;
    log.chunk(s, '{}', reasoning: 'thinking…');
    expect(s.hasReasoning, isTrue);
    expect(s.reasoning, 'thinking…');
    expect(s.hasContent, isFalse);
  });

  test('complete sets usage, status and finished events', () {
    final log = makeLog();
    final s = log.begin(title: 't')!;
    log.setUsage(s,
        const TokenUsage(promptTokens: 5, completionTokens: 7, cost: 0.01));
    log.complete(s, httpStatus: 200, finishReason: 'stop');

    expect(s.status, SessionStatus.done);
    expect(s.completedAt, isNotNull);
    expect(s.usage!.totalTokens, 12);
    expect(s.events.map((e) => e.title),
        containsAll(['Completed', 'Session finished']));
  });

  test('fail records an error event and status', () {
    final log = makeLog();
    final s = log.begin(title: 't')!;
    log.fail(s, 'nope', httpStatus: 400);

    expect(s.status, SessionStatus.error);
    expect(s.error, 'nope');
    expect(s.httpStatus, 400);
    expect(s.events.any((e) => e.category == DebugCategory.error), isTrue);
  });

  test('drops oldest sessions past capacity', () {
    final log = makeLog(capacity: 2);
    for (var i = 0; i < 4; i++) {
      log.begin(title: 's$i');
    }
    expect(log.length, 2);
    expect(log.sessions.first.title, 's2');
    expect(log.sessions.last.title, 's3');
  });

  test('does not capture while disabled, and clear empties', () {
    final log = makeLog()..enabled = false;
    expect(log.begin(title: 'x'), isNull);
    expect(log.isEmpty, isTrue);

    log.enabled = true;
    log.begin(title: 'y');
    expect(log.isEmpty, isFalse);
    log.clear();
    expect(log.isEmpty, isTrue);
  });

  test('pretty-prints JSON request bodies', () {
    final log = makeLog();
    final s = log.begin(title: 't', requestBody: '{"a":1,"b":[2,3]}')!;
    expect(s.prettyRequest, contains('\n'));
    expect(s.prettyRequest, contains('"a": 1'));
  });
}
