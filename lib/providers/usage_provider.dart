import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/usage.dart';
import 'app_providers.dart';
import 'settings_provider.dart';

/// Riverpod provider for session usage tracking.
final usageProvider =
    NotifierProvider<UsageNotifier, UsageState>(UsageNotifier.new);

/// Immutable snapshot of session usage exposed to the UI.
class UsageState {
  const UsageState({
    required this.promptTokens,
    required this.completionTokens,
    required this.cost,
    required this.requests,
    required List<ModelUsage> byModel,
    required this.credits,
    required this.creditsLoading,
    required this.creditsError,
    this.creditsFetchedAt,
  }) : _byModel = byModel;

  final int promptTokens;
  final int completionTokens;
  final double cost;
  final int requests;
  final List<ModelUsage> _byModel;
  final CreditBalance? credits;
  final bool creditsLoading;
  final String? creditsError;

  /// When the credit balance was last fetched (null = never).
  final DateTime? creditsFetchedAt;

  int get totalTokens => promptTokens + completionTokens;
  bool get isEmpty => requests == 0;

  /// Per-model breakdown, sorted by cost (then tokens) descending.
  List<ModelUsage> get byModel {
    final list = List<ModelUsage>.from(_byModel);
    list.sort((a, b) {
      final byCost = b.cost.compareTo(a.cost);
      return byCost != 0 ? byCost : b.totalTokens.compareTo(a.totalTokens);
    });
    return list;
  }
}

/// Tracks OpenRouter usage for the current app session (in-memory; resets on
/// restart). Also fetches the account-level credit balance on demand.
class UsageNotifier extends Notifier<UsageState> {
  int _promptTokens = 0;
  int _completionTokens = 0;
  double _cost = 0;
  int _requests = 0;
  final Map<String, ModelUsage> _byModel = {};

  CreditBalance? _credits;
  bool _creditsLoading = false;
  String? _creditsError;
  DateTime? _creditsFetchedAt;

  /// How long a fetched balance is considered fresh.
  static const creditsTtl = Duration(minutes: 5);

  @override
  UsageState build() => _snapshot();

  UsageState _snapshot() => UsageState(
        promptTokens: _promptTokens,
        completionTokens: _completionTokens,
        cost: _cost,
        requests: _requests,
        byModel: _byModel.values.toList(),
        credits: _credits,
        creditsLoading: _creditsLoading,
        creditsError: _creditsError,
        creditsFetchedAt: _creditsFetchedAt,
      );

  bool get _creditsFresh {
    final at = _creditsFetchedAt;
    return at != null && DateTime.now().difference(at) < creditsTtl;
  }

  void _emit() => state = _snapshot();

  /// Records the usage of one completion against [modelId].
  void record(String modelId, TokenUsage usage) {
    _promptTokens += usage.promptTokens;
    _completionTokens += usage.completionTokens;
    _cost += usage.cost;
    _requests++;
    _byModel.putIfAbsent(modelId, () => ModelUsage(modelId)).add(usage);
    _emit();
  }

  /// Clears all session totals.
  void reset() {
    _promptTokens = 0;
    _completionTokens = 0;
    _cost = 0;
    _requests = 0;
    _byModel.clear();
    _emit();
  }

  /// Fetches the account credit balance. Errors (e.g. a key without credit
  /// permissions) are captured in [UsageState.creditsError] rather than thrown.
  ///
  /// Skips the request when a balance was fetched within [creditsTtl], unless
  /// [force] is set — so re-opening the Usage screen doesn't re-hit the API.
  Future<void> refreshCredits({bool force = false}) async {
    if (!force && (_creditsFresh || _creditsLoading)) return;

    final key = ref.read(settingsProvider).apiKey;
    if (key == null || key.isEmpty) {
      _creditsError = 'Add your API key in Settings first.';
      _emit();
      return;
    }
    _creditsLoading = true;
    _creditsError = null;
    _emit();
    try {
      _credits = await ref.read(openRouterServiceProvider).fetchCredits(key);
      _creditsFetchedAt = DateTime.now();
    } catch (e) {
      _creditsError = e.toString();
    } finally {
      _creditsLoading = false;
      _emit();
    }
  }
}
