import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/models/usage.dart';
import 'package:wombat/providers/usage_provider.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> build(
    FakeOpenRouterService service, {
    String? apiKey = 'test-key',
  }) async {
    final container = await createContainer(service: service, apiKey: apiKey);
    addTearDown(container.dispose);
    return container;
  }

  test('record accumulates totals and per-model breakdown', () async {
    final c = await build(FakeOpenRouterService());
    final usage = c.read(usageProvider.notifier);

    usage.record('a/one',
        const TokenUsage(promptTokens: 10, completionTokens: 5, cost: 0.001));
    usage.record('a/one',
        const TokenUsage(promptTokens: 2, completionTokens: 1, cost: 0.0005));
    usage.record('b/two',
        const TokenUsage(promptTokens: 100, completionTokens: 50, cost: 0.02));

    final s = c.read(usageProvider);
    expect(s.promptTokens, 112);
    expect(s.completionTokens, 56);
    expect(s.totalTokens, 168);
    expect(s.requests, 3);
    expect(s.cost, closeTo(0.0215, 1e-9));
    expect(s.isEmpty, isFalse);

    // Sorted by cost descending: b/two first.
    expect(s.byModel.first.modelId, 'b/two');
    expect(s.byModel.firstWhere((m) => m.modelId == 'a/one').requests, 2);
  });

  test('reset clears all totals', () async {
    final c = await build(FakeOpenRouterService());
    final usage = c.read(usageProvider.notifier);
    usage.record('a/one', const TokenUsage(promptTokens: 1, cost: 0.1));
    usage.reset();

    final s = c.read(usageProvider);
    expect(s.isEmpty, isTrue);
    expect(s.totalTokens, 0);
    expect(s.cost, 0);
    expect(s.byModel, isEmpty);
  });

  test('refreshCredits loads the balance on success', () async {
    final service = FakeOpenRouterService()
      ..credits = const CreditBalance(totalCredits: 10, totalUsage: 4);
    final c = await build(service);

    await c.read(usageProvider.notifier).refreshCredits();

    final s = c.read(usageProvider);
    expect(s.credits?.remaining, 6);
    expect(s.creditsError, isNull);
    expect(s.creditsLoading, isFalse);
  });

  test('refreshCredits captures errors instead of throwing', () async {
    final service = FakeOpenRouterService()..creditsError = Exception('403');
    final c = await build(service);

    await c.read(usageProvider.notifier).refreshCredits();

    final s = c.read(usageProvider);
    expect(s.credits, isNull);
    expect(s.creditsError, contains('403'));
    expect(s.creditsLoading, isFalse);
  });

  test('refreshCredits requires an API key', () async {
    final c = await build(FakeOpenRouterService(), apiKey: null);

    await c.read(usageProvider.notifier).refreshCredits();

    expect(c.read(usageProvider).creditsError, contains('API key'));
  });

  test('refreshCredits caches within the TTL and force re-fetches', () async {
    final service = _CountingCreditsService()
      ..credits = const CreditBalance(totalCredits: 10, totalUsage: 4);
    final c = await build(service);
    final n = c.read(usageProvider.notifier);

    await n.refreshCredits();
    expect(service.creditsCalls, 1);
    expect(c.read(usageProvider).creditsFetchedAt, isNotNull);

    // A fresh balance is reused — no second API call.
    await n.refreshCredits();
    expect(service.creditsCalls, 1);

    // force bypasses the cache.
    await n.refreshCredits(force: true);
    expect(service.creditsCalls, 2);
  });
}

/// Counts how many times the credit balance is actually fetched.
class _CountingCreditsService extends FakeOpenRouterService {
  int creditsCalls = 0;

  @override
  Future<CreditBalance> fetchCredits(String apiKey) {
    creditsCalls++;
    return super.fetchCredits(apiKey);
  }
}
