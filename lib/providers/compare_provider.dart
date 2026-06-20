import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/openrouter_model.dart';
import '../models/usage.dart';
import '../services/openrouter_service.dart';
import 'app_providers.dart';
import 'settings_provider.dart';
import 'usage_provider.dart';

/// Riverpod provider for the "Compare models" session.
///
/// Living above the screen means the comparison — selected models, prompt,
/// in-flight streams and results — survives navigating away from (and back to)
/// the Compare screen, instead of being torn down when the route is popped.
final compareProvider =
    NotifierProvider<CompareNotifier, CompareState>(CompareNotifier.new);

/// One model's run: a (mutable) assistant message plus its status.
class CompareRun {
  CompareRun(this.model);

  final OpenRouterModel model;
  final ChatMessage message = ChatMessage(
    id: 'cmp-${DateTime.now().microsecondsSinceEpoch}-${_seq++}',
    role: MessageRole.assistant,
    content: '',
    isStreaming: true,
  );
  TokenUsage? usage;
  String? error;
  StreamSubscription<String>? sub;

  static int _seq = 0;
}

/// Immutable snapshot of the compare session exposed to the UI.
class CompareState {
  const CompareState({
    required List<OpenRouterModel> models,
    required List<CompareRun> runs,
    required this.running,
    required this.prompt,
  })  : _models = models,
        _runs = runs;

  final List<OpenRouterModel> _models;
  final List<CompareRun> _runs;
  final bool running;
  final String prompt;

  List<OpenRouterModel> get models => List.unmodifiable(_models);
  List<CompareRun> get runs => List.unmodifiable(_runs);
}

/// Owns the compare-models session and drives the parallel streaming runs.
class CompareNotifier extends Notifier<CompareState> {
  static const int maxModels = 5;

  late final OpenRouterService _service;

  final List<OpenRouterModel> _models = [];
  final List<CompareRun> _runs = [];
  bool _running = false;
  String _prompt = '';

  // Coalesce streaming updates into ~16 fps (mirrors ChatNotifier).
  Timer? _throttle;
  bool _dirty = false;
  static const _interval = Duration(milliseconds: 60);

  @override
  CompareState build() {
    _service = ref.read(openRouterServiceProvider);
    ref.onDispose(() {
      _throttle?.cancel();
      for (final r in _runs) {
        r.sub?.cancel();
      }
    });
    return _snapshot();
  }

  CompareState _snapshot() => CompareState(
        models: _models,
        runs: _runs,
        running: _running,
        prompt: _prompt,
      );

  void _emit() => state = _snapshot();

  /// Notifies listeners at most once per [_interval] during streaming.
  void _notifyStreaming() {
    if (_throttle != null) {
      _dirty = true;
      return;
    }
    _emit();
    _throttle = Timer(_interval, () {
      _throttle = null;
      if (_dirty) {
        _dirty = false;
        _notifyStreaming();
      }
    });
  }

  /// Cancels throttling and emits a final, immediate update.
  void _endStreaming() {
    _throttle?.cancel();
    _throttle = null;
    _dirty = false;
    _emit();
  }

  void setPrompt(String value) {
    _prompt = value;
    _emit();
  }

  void addModel(OpenRouterModel model) {
    if (_models.length >= maxModels) return;
    if (_models.any((m) => m.id == model.id)) return; // no duplicates
    _models.add(model);
    _emit();
  }

  void removeModel(OpenRouterModel model) {
    if (_running) return;
    _models.removeWhere((m) => m.id == model.id);
    _emit();
  }

  void stop() {
    for (final r in _runs) {
      r.sub?.cancel();
      if (r.message.isStreaming) r.message.isStreaming = false;
    }
    _running = false;
    _endStreaming();
  }

  /// Runs the current prompt against every selected model in parallel.
  void run() {
    final text = _prompt.trim();
    final apiKey = ref.read(settingsProvider).apiKey;
    if (text.isEmpty || _models.isEmpty || _running) return;
    if (apiKey == null || apiKey.isEmpty) return;

    // Reset and build a fresh run per model.
    for (final r in _runs) {
      r.sub?.cancel();
    }
    final usageNotifier = ref.read(usageProvider.notifier);
    final userMsg = ChatMessage(
      id: 'cmp-user-${DateTime.now().microsecondsSinceEpoch}',
      role: MessageRole.user,
      content: text,
    );

    _runs
      ..clear()
      ..addAll(_models.map(CompareRun.new));
    _running = true;
    _emit();

    for (final run in _runs) {
      run.sub = _service
          .streamChat(
            apiKey: apiKey,
            model: run.model.id,
            messages: [userMsg],
            onUsage: (u) {
              run.usage = u;
              usageNotifier.record(run.model.id, u);
            },
          )
          .listen(
        (delta) {
          run.message.content += delta;
          _notifyStreaming();
        },
        onError: (Object e) {
          run.error = e.toString();
          run.message.isStreaming = false;
          _onRunEnded();
        },
        onDone: () {
          run.message.isStreaming = false;
          _onRunEnded();
        },
        cancelOnError: true,
      );
    }
  }

  void _onRunEnded() {
    if (_runs.every((r) => !r.message.isStreaming)) {
      _running = false;
      _endStreaming(); // flush the final result immediately
    } else {
      _notifyStreaming();
    }
  }
}
