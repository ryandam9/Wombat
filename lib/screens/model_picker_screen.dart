import 'package:auris/auris_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/openrouter_model.dart';
import '../providers/settings_provider.dart';
import '../services/openrouter_service.dart';

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
                AurisSwitch(
                  value: _freeOnly,
                  label: 'FREE ONLY',
                  onChanged: (v) => setState(() => _freeOnly = v),
                ),
                const Spacer(),
                AurisSelect<_Sort>(
                  value: _sort,
                  placeholder: 'SORT',
                  width: 150,
                  options: const [
                    AurisSelectOption(value: _Sort.name, label: 'NAME'),
                    AurisSelectOption(value: _Sort.context, label: 'CONTEXT'),
                    AurisSelectOption(value: _Sort.price, label: 'PRICE'),
                  ],
                  onChanged: (v) => setState(() => _sort = v),
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
      child: AurisContainer(
        padding: const EdgeInsets.all(14),
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
                  const AurisBadge('FREE', variant: AurisBadgeVariant.success),
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
              AurisProgressBar(
                value: (ctx / maxContext).clamp(0.0, 1.0),
                label: 'CONTEXT',
                valueLabel: _compact(ctx),
                segments: 16,
                height: 8,
              ),
            ],
            if (!model.isFree && model.promptPrice != null) ...[
              const SizedBox(height: 8),
              AurisDataRow(
                label: 'Prompt',
                value: '\$${(model.promptPrice! * 1000000).toStringAsFixed(2)}/M',
                height: 28,
              ),
            ],
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
            AurisNotification(
              title: 'CATALOGUE UNAVAILABLE',
              message: message,
              variant: AurisNotificationVariant.error,
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
