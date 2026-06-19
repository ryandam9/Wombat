import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/openrouter_model.dart';
import '../models/usage.dart';
import '../providers/app_providers.dart';
import '../providers/settings_provider.dart';
import '../providers/usage_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/ui_kit.dart';
import 'model_picker_screen.dart';

/// Runs one prompt against several models at once and shows the replies side
/// by side for comparison.
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

/// One model's run: a (mutable) assistant message plus its status.
class _Run {
  _Run(this.model);

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

class _CompareScreenState extends ConsumerState<CompareScreen> {
  static const double _wideBreakpoint = 760;
  static const int _maxModels = 5;

  final TextEditingController _prompt = TextEditingController();
  final List<OpenRouterModel> _models = [];
  final List<_Run> _runs = [];
  bool _running = false;

  // Coalesce streaming updates into ~16 fps.
  Timer? _throttle;
  bool _dirty = false;

  @override
  void dispose() {
    _prompt.dispose();
    _throttle?.cancel();
    for (final r in _runs) {
      r.sub?.cancel();
    }
    super.dispose();
  }

  void _scheduleUpdate() {
    if (_throttle != null) {
      _dirty = true;
      return;
    }
    if (mounted) setState(() {});
    _throttle = Timer(const Duration(milliseconds: 60), () {
      _throttle = null;
      if (_dirty) {
        _dirty = false;
        _scheduleUpdate();
      }
    });
  }

  Future<void> _addModel() async {
    final picked = await Navigator.of(context).push<OpenRouterModel>(
      MaterialPageRoute(builder: (_) => const ModelPickerScreen()),
    );
    if (picked == null) return;
    if (_models.any((m) => m.id == picked.id)) return; // no duplicates
    setState(() => _models.add(picked));
  }

  void _removeModel(OpenRouterModel model) =>
      setState(() => _models.removeWhere((m) => m.id == model.id));

  void _stop() {
    for (final r in _runs) {
      r.sub?.cancel();
      if (r.message.isStreaming) r.message.isStreaming = false;
    }
    setState(() => _running = false);
  }

  Future<void> _run() async {
    final text = _prompt.text.trim();
    final apiKey = ref.read(settingsProvider).apiKey;
    if (text.isEmpty || _models.isEmpty || _running) return;
    if (apiKey == null || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add your API key in Settings first.')),
      );
      return;
    }

    // Reset and build a fresh run per model.
    for (final r in _runs) {
      r.sub?.cancel();
    }
    final service = ref.read(openRouterServiceProvider);
    final usageNotifier = ref.read(usageProvider.notifier);
    final userMsg = ChatMessage(
      id: 'cmp-user-${DateTime.now().microsecondsSinceEpoch}',
      role: MessageRole.user,
      content: text,
    );

    setState(() {
      _runs
        ..clear()
        ..addAll(_models.map(_Run.new));
      _running = true;
    });

    for (final run in _runs) {
      run.sub = service
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
          _scheduleUpdate();
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
    }
    _scheduleUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    final canRun =
        !_running && _models.isNotEmpty && _prompt.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Compare models')),
      body: Column(
        children: [
          _ModelBar(
            models: _models,
            onAdd: _models.length >= _maxModels ? null : _addModel,
            onRemove: _running ? null : _removeModel,
            max: _maxModels,
          ),
          const Divider(height: 1),
          Expanded(
            child: _runs.isEmpty
                ? const _ComparePlaceholder()
                : _Results(runs: _runs, wide: wide),
          ),
          const Divider(height: 1),
          _PromptBar(
            controller: _prompt,
            running: _running,
            canRun: canRun,
            onChanged: (_) => setState(() {}),
            onRun: _run,
            onStop: _stop,
          ),
        ],
      ),
    );
  }
}

class _ModelBar extends StatelessWidget {
  const _ModelBar({
    required this.models,
    required this.onAdd,
    required this.onRemove,
    required this.max,
  });

  final List<OpenRouterModel> models;
  final VoidCallback? onAdd;
  final void Function(OpenRouterModel)? onRemove;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (models.isEmpty)
                  Text(
                    'Add models to compare (up to $max).',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                for (final m in models)
                  InputChip(
                    label: Text(m.name),
                    onDeleted: onRemove == null ? null : () => onRemove!(m),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add model'),
          ),
        ],
      ),
    );
  }
}

class _PromptBar extends StatelessWidget {
  const _PromptBar({
    required this.controller,
    required this.running,
    required this.canRun,
    required this.onChanged,
    required this.onRun,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool running;
  final bool canRun;
  final ValueChanged<String> onChanged;
  final VoidCallback onRun;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                minLines: 1,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Enter a prompt to run on every selected model…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (running)
              FilledButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              )
            else
              FilledButton.icon(
                onPressed: canRun ? onRun : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.runs, required this.wide});

  final List<_Run> runs;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < runs.length; i++) ...[
            if (i > 0) const VerticalDivider(width: 1),
            Expanded(child: _ResultColumn(run: runs[i])),
          ],
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: runs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _ResultCard(run: runs[i]),
    );
  }
}

/// A single model's column on wide layouts: sticky header + scrolling reply.
class _ResultColumn extends StatelessWidget {
  const _ResultColumn({required this.run});

  final _Run run;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultHeader(run: run),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: _ResultBody(run: run),
          ),
        ),
      ],
    );
  }
}

/// A single model's card on narrow layouts.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.run});

  final _Run run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ResultHeader(run: run),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _ResultBody(run: run),
          ),
        ],
      ),
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.run});

  final _Run run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usage = run.usage;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(run.model.name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(run.model.id,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (run.message.isStreaming)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (usage != null)
            StatusChip(
              '\$${usage.cost.toStringAsFixed(4)} · ${usage.totalTokens} tok',
              color: theme.colorScheme.primary,
            ),
        ],
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.run});

  final _Run run;

  @override
  Widget build(BuildContext context) {
    if (run.error != null) {
      return InfoBanner(
        title: 'Failed',
        message: run.error,
        kind: BannerKind.error,
      );
    }
    if (run.message.content.isEmpty && run.message.isStreaming) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Waiting for the first tokens…'),
      );
    }
    // Reuse the chat bubble's Markdown/SVG/image rendering and copy/save.
    return MessageBubble(message: run.message);
  }
}

class _ComparePlaceholder extends StatelessWidget {
  const _ComparePlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.compare_arrows,
                size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('Compare models side by side',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Add two or more models, type a prompt, and Run to see how each '
              'one responds to the same input.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
