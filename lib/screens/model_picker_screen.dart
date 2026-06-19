import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/openrouter_model.dart';
import '../providers/settings_provider.dart';
import '../services/openrouter_service.dart';

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

  List<OpenRouterModel> _filter(List<OpenRouterModel> models) {
    final q = _query.toLowerCase();
    return models.where((m) {
      if (_freeOnly && !m.isFree) return false;
      if (q.isEmpty) return true;
      return m.id.toLowerCase().contains(q) ||
          m.name.toLowerCase().contains(q);
    }).toList();
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
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FilterChip(
                label: const Text('Free only'),
                selected: _freeOnly,
                onSelected: (v) => setState(() => _freeOnly = v),
              ),
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
                final models = _filter(snapshot.data ?? []);
                if (models.isEmpty) {
                  return const Center(child: Text('No matching models'));
                }
                return ListView.separated(
                  itemCount: models.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _ModelTile(model: models[index]),
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
  const _ModelTile({required this.model});

  final OpenRouterModel model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(model.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(model.id, style: theme.textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            _details(),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
      trailing: model.isFree
          ? Chip(
              label: const Text('Free'),
              visualDensity: VisualDensity.compact,
              backgroundColor: theme.colorScheme.tertiaryContainer,
            )
          : null,
      onTap: () => Navigator.of(context).pop(model.id),
    );
  }

  String _details() {
    final parts = <String>[];
    if (model.contextLength != null) {
      parts.add('${_compact(model.contextLength!)} ctx');
    }
    if (!model.isFree && model.promptPrice != null) {
      // Pricing from the API is per-token; show per-million for readability.
      final perMillion = model.promptPrice! * 1000000;
      parts.add('\$${perMillion.toStringAsFixed(2)}/M in');
    }
    return parts.join('  ·  ');
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
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
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
