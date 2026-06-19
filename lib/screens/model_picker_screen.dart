import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/openrouter_model.dart';
import '../providers/settings_provider.dart';
import '../services/openrouter_service.dart';
import '../widgets/ui_kit.dart';

enum _Sort { name, context, price }

/// Fetches the OpenRouter model catalogue and lets the user pick one.
/// Pops with the selected model id (a [String]).
class ModelPickerScreen extends StatefulWidget {
  const ModelPickerScreen({super.key});

  @override
  State<ModelPickerScreen> createState() => _ModelPickerScreenState();
}

class _ModelPickerScreenState extends State<ModelPickerScreen> {
  late Future<List<OpenRouterModel>> _future;
  String _query = '';
  bool _freeOnly = false;
  _Sort _sort = _Sort.name;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<OpenRouterModel>> _load() {
    final apiKey = context.read<SettingsProvider>().apiKey ?? '';
    if (apiKey.isEmpty) {
      return Future.error(
        OpenRouterException('Add your API key in Settings to load models.'),
      );
    }
    return context.read<OpenRouterService>().fetchModels(apiKey);
  }

  void _reload() => setState(() => _future = _load());

  /// Lets the user type an arbitrary model id (e.g. one too new to be listed).
  /// Validity is left to OpenRouter — an unknown id surfaces as a request error.
  Future<void> _enterCustomId() async {
    final controller = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter model ID'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. z-ai/glm-4.6',
            helperText: 'Used as-is; an invalid id will return an API error.',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Use model'),
          ),
        ],
      ),
    );
    if (id != null && id.isNotEmpty && mounted) {
      Navigator.of(context).pop(OpenRouterModel(id: id, name: id));
    }
  }

  List<OpenRouterModel> _filterAndSort(List<OpenRouterModel> models) {
    final q = _query.toLowerCase();
    final list = models.where((m) {
      if (_freeOnly && !m.isFree) return false;
      if (q.isEmpty) return true;
      return m.id.toLowerCase().contains(q) ||
          m.name.toLowerCase().contains(q);
    }).toList();

    switch (_sort) {
      case _Sort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _Sort.context:
        list.sort((a, b) => (b.contextLength ?? 0).compareTo(a.contextLength ?? 0));
      case _Sort.price:
        list.sort((a, b) => (a.promptPrice ?? 0).compareTo(b.promptPrice ?? 0));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a model'),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: 'Enter model ID',
            onPressed: _enterCustomId,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _reload,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search models…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Free only'),
                  selected: _freeOnly,
                  onSelected: (v) => setState(() => _freeOnly = v),
                ),
                const Spacer(),
                const Text('Sort'),
                const SizedBox(width: 8),
                DropdownButton<_Sort>(
                  value: _sort,
                  onChanged: (v) {
                    if (v != null) setState(() => _sort = v);
                  },
                  items: const [
                    DropdownMenuItem(value: _Sort.name, child: Text('Name')),
                    DropdownMenuItem(
                        value: _Sort.context, child: Text('Context')),
                    DropdownMenuItem(value: _Sort.price, child: Text('Price')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<OpenRouterModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorView(
                    message: '${snapshot.error}',
                    onRetry: _reload,
                  );
                }
                final models = _filterAndSort(snapshot.data ?? []);
                if (models.isEmpty) {
                  return const Center(child: Text('No matching models'));
                }
                final maxContext = models
                    .map((m) => m.contextLength ?? 0)
                    .fold<int>(1, (a, b) => a > b ? a : b);
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: models.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ModelTile(
                      model: models[index],
                      maxContext: maxContext,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({required this.model, required this.maxContext});

  final OpenRouterModel model;
  final int maxContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ctx = model.contextLength ?? 0;

    return InkWell(
      onTap: () => Navigator.of(context).pop(model),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    model.name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (model.isFree)
                  StatusChip('Free', color: theme.colorScheme.tertiary),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              model.id,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            if (ctx > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('CONTEXT', style: theme.textTheme.labelSmall),
                  const Spacer(),
                  Text(_compact(ctx), style: theme.textTheme.labelSmall),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (ctx / maxContext).clamp(0.0, 1.0),
                  minHeight: 6,
                ),
              ),
            ],
            if (!model.isFree && model.promptPrice != null)
              LabelValueRow(
                label: 'Prompt',
                value:
                    '\$${(model.promptPrice! * 1000000).toStringAsFixed(2)}/M',
              ),
          ],
        ),
      ),
    );
  }

  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).round()}K';
    return '$n';
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoBanner(
              title: 'Catalogue unavailable',
              message: message,
              kind: BannerKind.error,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
