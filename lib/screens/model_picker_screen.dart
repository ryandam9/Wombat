import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/openrouter_model.dart';
import '../providers/settings_provider.dart';
import '../services/openrouter_service.dart';
import '../widgets/ui_kit.dart';

enum _Sort { name, context, price, newest }

enum _ViewMode { grid, list }

/// A quick filter applied to the catalogue. Every predicate uses real data
/// from OpenRouter (no fabricated "popularity"/latency metrics).
enum _Filter {
  all('All', Icons.auto_awesome),
  isNew('New', Icons.fiber_new_outlined),
  free('Free', Icons.money_off),
  cheapest('Cheapest', Icons.savings_outlined),
  highContext('High context', Icons.unfold_more),
  multimodal('Multimodal', Icons.image_outlined),
  tools('Tools', Icons.build_outlined);

  const _Filter(this.label, this.icon);
  final String label;
  final IconData icon;

  static const _newWindow = Duration(days: 60);
  static const _cheapInputPerM = 1.0; // ≤ $1 / M input tokens

  bool matches(OpenRouterModel m) => switch (this) {
        _Filter.all => true,
        _Filter.isNew => m.isNewerThan(_newWindow),
        _Filter.free => m.isFree,
        _Filter.cheapest =>
          !m.isFree && (m.promptPricePerM ?? double.infinity) <= _cheapInputPerM,
        _Filter.highContext => (m.contextLength ?? 0) >= 128000,
        _Filter.multimodal => m.isMultimodal,
        _Filter.tools => m.supportsTools,
      };
}

/// Fetches the OpenRouter model catalogue and lets the user browse, compare
/// and pick one. Pops with the selected [OpenRouterModel].
class ModelPickerScreen extends StatefulWidget {
  const ModelPickerScreen({super.key});

  @override
  State<ModelPickerScreen> createState() => _ModelPickerScreenState();
}

class _ModelPickerScreenState extends State<ModelPickerScreen> {
  static const double _detailBreakpoint = 1000;

  late Future<List<OpenRouterModel>> _future;
  String _query = '';
  // Active filters combine (AND). Empty == "All".
  final Set<_Filter> _filters = <_Filter>{};
  _Sort _sort = _Sort.name;
  bool _asc = true;
  _ViewMode _view = _ViewMode.grid;
  OpenRouterModel? _preview;

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

  void _reload() => setState(() {
        _preview = null;
        _future = _load();
      });

  /// Lets the user type an arbitrary model id (e.g. one too new to be listed).
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

  List<OpenRouterModel> _visible(
    List<OpenRouterModel> models,
    Set<String> favorites,
  ) {
    final q = _query.toLowerCase();
    final list = models.where((m) {
      if (_filters.isNotEmpty && !_filters.every((f) => f.matches(m))) {
        return false;
      }
      if (q.isEmpty) return true;
      return m.id.toLowerCase().contains(q) ||
          m.name.toLowerCase().contains(q) ||
          m.vendor.toLowerCase().contains(q);
    }).toList();

    // Ascending comparator for the active field; flipped when descending.
    int ascending(OpenRouterModel a, OpenRouterModel b) => switch (_sort) {
          _Sort.name =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          _Sort.context =>
            (a.contextLength ?? 0).compareTo(b.contextLength ?? 0),
          _Sort.price => (a.promptPrice ?? 0).compareTo(b.promptPrice ?? 0),
          _Sort.newest => (a.created ?? DateTime(0))
              .compareTo(b.created ?? DateTime(0)),
        };
    list.sort((a, b) => _asc ? ascending(a, b) : ascending(b, a));

    // Bookmarked models surface first, keeping their relative order.
    final favs = list.where((m) => favorites.contains(m.id)).toList();
    final rest = list.where((m) => !favorites.contains(m.id)).toList();
    return [...favs, ...rest];
  }

  void _select(OpenRouterModel model) => Navigator.of(context).pop(model);

  void _toggleFilter(_Filter f) {
    setState(() {
      if (f == _Filter.all) {
        _filters.clear();
      } else if (!_filters.add(f)) {
        _filters.remove(f);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final favorites = settings.favoriteModels;
    final showDetail =
        MediaQuery.of(context).size.width >= _detailBreakpoint;

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
      body: FutureBuilder<List<OpenRouterModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(message: '${snapshot.error}', onRetry: _reload);
          }
          final all = snapshot.data ?? [];
          final models = _visible(all, favorites);
          // Default the detail preview to the current default model, else first.
          _preview ??= () {
            final def = settings.defaultModel;
            for (final m in all) {
              if (m.id == def) return m;
            }
            return models.isNotEmpty ? models.first : null;
          }();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Toolbar(
                query: _query,
                onQuery: (v) => setState(() => _query = v),
                view: _view,
                onView: (v) => setState(() => _view = v),
                sort: _sort,
                onSort: (v) => setState(() => _sort = v),
                ascending: _asc,
                onToggleDirection: () => setState(() => _asc = !_asc),
              ),
              _FilterBar(active: _filters, onToggled: _toggleFilter),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: models.isEmpty
                          ? const Center(child: Text('No matching models'))
                          : _ModelCollection(
                              models: models,
                              view: _view,
                              favorites: favorites,
                              selectedId: _preview?.id,
                              onTap: (m) => showDetail
                                  ? setState(() => _preview = m)
                                  : _select(m),
                              onToggleFavorite: (m) => context
                                  .read<SettingsProvider>()
                                  .toggleFavoriteModel(m.id),
                            ),
                    ),
                    if (showDetail) ...[
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: 340,
                        child: _DetailPanel(
                          model: _preview,
                          onSelect: _preview == null
                              ? null
                              : () => _select(_preview!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Toolbar (search, view toggle, sort) ─────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.query,
    required this.onQuery,
    required this.view,
    required this.onView,
    required this.sort,
    required this.onSort,
    required this.ascending,
    required this.onToggleDirection,
  });

  final String query;
  final ValueChanged<String> onQuery;
  final _ViewMode view;
  final ValueChanged<_ViewMode> onView;
  final _Sort sort;
  final ValueChanged<_Sort> onSort;
  final bool ascending;
  final VoidCallback onToggleDirection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 360,
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search models by name, provider or capability…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: onQuery,
            ),
          ),
          SegmentedButton<_ViewMode>(
            segments: const [
              ButtonSegment(
                value: _ViewMode.grid,
                icon: Icon(Icons.grid_view),
                label: Text('Grid'),
              ),
              ButtonSegment(
                value: _ViewMode.list,
                icon: Icon(Icons.view_list),
                label: Text('List'),
              ),
            ],
            selected: {view},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onView(s.first),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sort by', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(width: 8),
              DropdownButton<_Sort>(
                value: sort,
                onChanged: (v) {
                  if (v != null) onSort(v);
                },
                items: const [
                  DropdownMenuItem(value: _Sort.name, child: Text('Name')),
                  DropdownMenuItem(
                      value: _Sort.context, child: Text('Context')),
                  DropdownMenuItem(value: _Sort.price, child: Text('Price')),
                  DropdownMenuItem(
                      value: _Sort.newest, child: Text('Release date')),
                ],
              ),
              IconButton(
                icon: Icon(
                    ascending ? Icons.arrow_upward : Icons.arrow_downward),
                tooltip: ascending ? 'Ascending' : 'Descending',
                onPressed: onToggleDirection,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.active, required this.onToggled});

  /// Active filters (empty == "All"). Filters combine with AND.
  final Set<_Filter> active;
  final ValueChanged<_Filter> onToggled;

  // Green accent for the "selected" state, legible in both themes.
  static const _accent = Color(0xFF2E9E5B);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // Lighten the green on dark backgrounds, darken it on light ones.
    final hsl = HSLColor.fromColor(_accent);
    final accentFg = hsl
        .withLightness(
            (dark ? hsl.lightness + 0.22 : hsl.lightness - 0.10).clamp(0.0, 1.0))
        .toColor();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          for (final f in _Filter.values) ...[
            Builder(builder: (context) {
              // "All" is selected when no specific filter is active; the rest
              // toggle independently and combine.
              final selected =
                  f == _Filter.all ? active.isEmpty : active.contains(f);
              return FilterChip(
                avatar: Icon(
                  f.icon,
                  size: 18,
                  color: selected ? accentFg : null,
                ),
                label: Text(f.label),
                selected: selected,
                onSelected: (_) => onToggled(f),
                // Green fill + green border + green checkmark when selected.
                showCheckmark: true,
                checkmarkColor: accentFg,
                selectedColor: _accent.withValues(alpha: dark ? 0.28 : 0.16),
                labelStyle: selected
                    ? TextStyle(color: accentFg, fontWeight: FontWeight.w600)
                    : null,
                side: selected
                    ? BorderSide(color: accentFg, width: 1.5)
                    : null,
              );
            }),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// ── Card / list collection ──────────────────────────────────────────────────

class _ModelCollection extends StatelessWidget {
  const _ModelCollection({
    required this.models,
    required this.view,
    required this.favorites,
    required this.selectedId,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final List<OpenRouterModel> models;
  final _ViewMode view;
  final Set<String> favorites;
  final String? selectedId;
  final ValueChanged<OpenRouterModel> onTap;
  final ValueChanged<OpenRouterModel> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    if (view == _ViewMode.list) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: models.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _ModelCard(
          model: models[i],
          dense: true,
          selected: models[i].id == selectedId,
          favorite: favorites.contains(models[i].id),
          onTap: () => onTap(models[i]),
          onToggleFavorite: () => onToggleFavorite(models[i]),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 232,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: models.length,
      itemBuilder: (context, i) => _ModelCard(
        model: models[i],
        selected: models[i].id == selectedId,
        favorite: favorites.contains(models[i].id),
        onTap: () => onTap(models[i]),
        onToggleFavorite: () => onToggleFavorite(models[i]),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.selected,
    required this.favorite,
    required this.onTap,
    required this.onToggleFavorite,
    this.dense = false,
  });

  final OpenRouterModel model;
  final bool selected;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _VendorAvatar(vendor: model.vendor, size: dense ? 36 : 44),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      model.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (model.isFree) ...[
                    const SizedBox(width: 6),
                    StatusChip('Free', color: scheme.tertiary),
                  ],
                ],
              ),
              Text(
                model.id,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.outline),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: favorite ? 'Remove bookmark' : 'Bookmark',
          icon: Icon(
            favorite ? Icons.bookmark : Icons.bookmark_border,
            color: favorite ? scheme.primary : scheme.outline,
            size: 20,
          ),
          onPressed: onToggleFavorite,
        ),
      ],
    );

    final tags = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in _capabilities(model)) _CapabilityChip(c),
      ],
    );

    final stats = Row(
      children: [
        Expanded(
          child: _StatBlock(
            label: 'Context window',
            value: _compactTokens(model.contextLength),
          ),
        ),
        Expanded(
          child: _StatBlock(
            label: 'Price (Input)',
            value: _pricePerM(model.promptPricePerM, model.isFree),
          ),
        ),
      ],
    );

    final dark = theme.brightness == Brightness.dark;
    final accent = _VendorAvatar.colorFor(model.vendor);
    // Unselected cards carry a faint provider-tinted wash so providers are
    // visually distinct and the card lifts off the page background.
    final BoxDecoration decoration = selected
        ? BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.primary, width: 1.5),
          )
        : BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  accent.withValues(alpha: dark ? 0.16 : 0.10),
                  scheme.surfaceContainerHighest,
                ),
                scheme.surfaceContainerHighest,
              ],
              stops: const [0, 0.7],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: decoration,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: dense
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    header,
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: tags),
                        const SizedBox(width: 12),
                        _InlineStat(
                          label: 'Context',
                          value: _compactTokens(model.contextLength),
                        ),
                        const SizedBox(width: 16),
                        _InlineStat(
                          label: 'Input',
                          value:
                              _pricePerM(model.promptPricePerM, model.isFree),
                        ),
                      ],
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: 10),
                    // Flexible, clipped so wrapping tags never overflow the
                    // fixed-height grid cell.
                    Expanded(
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: tags,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    stats,
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

/// A capability label paired with a semantic accent colour.
typedef _Cap = ({String label, Color color});

/// A colour-coded capability chip that stays legible in both themes: the
/// accent is lightened on dark backgrounds and darkened on light ones.
class _CapabilityChip extends StatelessWidget {
  const _CapabilityChip(this.cap);
  final _Cap cap;

  static Color _legible(Color seed, Brightness b) {
    final hsl = HSLColor.fromColor(seed);
    final l = b == Brightness.dark
        ? (hsl.lightness + 0.28).clamp(0.0, 1.0)
        : (hsl.lightness - 0.12).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fg = _legible(cap.color, theme.brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cap.color.withValues(alpha: dark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.45)),
      ),
      child: Text(
        cap.label,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            )),
      ],
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline)),
        Text(value,
            style: theme.textTheme.labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// A colored, rounded avatar bearing the vendor's initial (OpenRouter does not
/// expose provider logos).
class _VendorAvatar extends StatelessWidget {
  const _VendorAvatar({required this.vendor, required this.size});
  final String vendor;
  final double size;

  static const _palette = [
    Color(0xFF6750A4),
    Color(0xFF1E88E5),
    Color(0xFF00897B),
    Color(0xFFD81B60),
    Color(0xFFF4511E),
    Color(0xFF5E35B1),
    Color(0xFF3949AB),
  ];

  /// Stable accent colour for a vendor, shared by the avatar and card wash.
  static Color colorFor(String vendor) =>
      _palette[vendor.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    final color = colorFor(vendor);
    final letter = vendor.isEmpty ? '?' : vendor[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.6)],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
}

// ── Detail panel ────────────────────────────────────────────────────────────

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.model, required this.onSelect});

  final OpenRouterModel? model;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = model;
    if (m == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Select a model to see its details.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      );
    }
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selected model',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.outline)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _VendorAvatar(vendor: m.vendor, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          Text(m.id,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.outline)),
                        ],
                      ),
                    ),
                    if (m.isFree)
                      StatusChip('Free', color: scheme.tertiary),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in _capabilities(m)) _CapabilityChip(c)
                  ],
                ),
                const SizedBox(height: 20),
                Text('Key details',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                LabelValueRow(
                  label: 'Context window',
                  value: m.contextLength != null
                      ? '${NumberFormat.decimalPattern().format(m.contextLength)} tokens'
                      : '—',
                ),
                LabelValueRow(
                  label: 'Max output',
                  value: m.maxOutputTokens != null
                      ? '${NumberFormat.decimalPattern().format(m.maxOutputTokens)} tokens'
                      : '—',
                ),
                LabelValueRow(
                  label: 'Input price',
                  value: _pricePerM(m.promptPricePerM, m.isFree),
                ),
                LabelValueRow(
                  label: 'Output price',
                  value: _pricePerM(m.completionPricePerM, m.isFree),
                ),
                LabelValueRow(
                  label: 'Released',
                  value: m.created != null
                      ? DateFormat.yMMMd().format(m.created!)
                      : '—',
                ),
                if (_capabilities(m).isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Capabilities',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in _capabilities(m)) _CapabilityChip(c)
                    ],
                  ),
                ],
                if (m.description != null &&
                    m.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Description',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(m.description!.trim(),
                      style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onSelect,
                  icon: const Icon(Icons.check),
                  label: const Text('Select model'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openDocs(context, m),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('View documentation'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openDocs(BuildContext context, OpenRouterModel m) async {
    final uri = Uri.parse('https://openrouter.ai/${m.id}');
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $uri')),
      );
    }
  }
}

// ── Shared helpers ──────────────────────────────────────────────────────────

List<_Cap> _capabilities(OpenRouterModel m) => [
      (label: 'Text gen', color: const Color(0xFF7E8AA0)),
      if (m.contextLength != null)
        (label: '${_compactTokens(m.contextLength)} context', color: const Color(0xFF2196F3)),
      if (m.supportsTools) (label: 'Tools', color: const Color(0xFF2E9E5B)),
      if (m.supportsJsonOutput) (label: 'JSON', color: const Color(0xFFE08A00)),
      if (m.supportsReasoning) (label: 'Reasoning', color: const Color(0xFF9C5BE0)),
      if (m.supportsImageInput) (label: 'Vision', color: const Color(0xFF12A4A4)),
      if (m.supportsImageOutput) (label: 'Image out', color: const Color(0xFFE0518A)),
    ];

String _compactTokens(int? n) {
  if (n == null || n <= 0) return '—';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).round()}K';
  return '$n';
}

String _pricePerM(double? perM, bool isFree) {
  if (isFree) return 'Free';
  if (perM == null) return '—';
  return '\$${perM.toStringAsFixed(2)} / M';
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
