import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/openrouter_model.dart';
import '../providers/compare_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/ui_kit.dart';
import 'model_picker_screen.dart';

/// Runs one prompt against several models at once and shows the replies side
/// by side for comparison.
///
/// The session itself lives in [compareProvider], so navigating back and
/// returning preserves the selected models, prompt, in-flight streams and
/// results.
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  static const double _wideBreakpoint = 760;

  late final TextEditingController _prompt;

  @override
  void initState() {
    super.initState();
    // Restore any in-progress prompt from the persisted session.
    _prompt = TextEditingController(text: ref.read(compareProvider).prompt);
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _addModel() async {
    final picked = await Navigator.of(context).push<OpenRouterModel>(
      MaterialPageRoute(builder: (_) => const ModelPickerScreen()),
    );
    if (picked == null) return;
    ref.read(compareProvider.notifier).addModel(picked);
  }

  void _run() {
    final apiKey = ref.read(settingsProvider).apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add your API key in Settings first.')),
      );
      return;
    }
    ref.read(compareProvider.notifier).run();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    final state = ref.watch(compareProvider);
    final notifier = ref.read(compareProvider.notifier);
    final canRun = !state.running &&
        state.models.isNotEmpty &&
        state.prompt.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Compare models')),
      body: Column(
        children: [
          _ModelBar(
            models: state.models,
            onAdd: state.models.length >= CompareNotifier.maxModels
                ? null
                : _addModel,
            onRemove: state.running ? null : notifier.removeModel,
            max: CompareNotifier.maxModels,
          ),
          const Divider(height: 1),
          Expanded(
            child: state.runs.isEmpty
                ? const _ComparePlaceholder()
                : _Results(runs: state.runs, wide: wide),
          ),
          const Divider(height: 1),
          _PromptBar(
            controller: _prompt,
            running: state.running,
            canRun: canRun,
            onChanged: notifier.setPrompt,
            onRun: _run,
            onStop: notifier.stop,
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

  final List<CompareRun> runs;
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

  final CompareRun run;

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

  final CompareRun run;

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

  final CompareRun run;

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

  final CompareRun run;

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
