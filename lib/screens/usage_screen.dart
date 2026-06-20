import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/usage.dart';
import '../providers/usage_provider.dart';
import '../widgets/shimmer.dart';
import '../widgets/ui_kit.dart';

/// Shows OpenRouter usage accumulated during the current app session, plus the
/// account credit balance — with fl_chart charts for the balance and the
/// per-model breakdowns.
class UsageScreen extends ConsumerStatefulWidget {
  const UsageScreen({super.key});

  @override
  ConsumerState<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends ConsumerState<UsageScreen> {
  static final _int = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
    // Attempt to load the account balance when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(usageProvider.notifier).refreshCredits();
    });
  }

  String _money(double v, {int dp = 4}) => '\$${v.toStringAsFixed(dp)}';

  @override
  Widget build(BuildContext context) {
    final usage = ref.watch(usageProvider);
    final hasModels = usage.byModel.isNotEmpty;
    final error = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session usage'),
        actions: [
          // Red to flag that this clears the session totals (destructive).
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: error),
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Reset session'),
            onPressed: usage.isEmpty
                ? null
                : () => ref.read(usageProvider.notifier).reset(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CardGrid(
            cards: [
              StatCard(
                label: 'Input tokens',
                value: _int.format(usage.promptTokens),
              ),
              StatCard(
                label: 'Output tokens',
                value: _int.format(usage.completionTokens),
              ),
              StatCard(label: 'Cost', value: _money(usage.cost), unit: 'USD'),
              StatCard(label: 'Requests', value: '${usage.requests}'),
            ],
          ),
          const SizedBox(height: 16),
          _AccountPanel(money: _money),
          const SizedBox(height: 16),
          if (hasModels) ...[
            _CostByModelPanel(usage: usage, money: _money),
            const SizedBox(height: 16),
            _TokensByModelPanel(usage: usage),
            const SizedBox(height: 16),
            _TokenSharePanel(usage: usage),
            const SizedBox(height: 16),
          ],
          _ByModelPanel(usage: usage, money: _money, intFmt: _int),
          const SizedBox(height: 16),
          _UsageSummaryPanel(usage: usage, money: _money, intFmt: _int),
        ],
      ),
    );
  }
}

/// A palette for per-model series, derived from the theme.
List<Color> _palette(ColorScheme s) => [
      s.primary,
      s.tertiary,
      s.secondary,
      s.primaryContainer,
      s.error,
      s.tertiaryContainer,
    ];

/// Short model label for chart axes: the part after the vendor slash.
String _shortModel(String id) => id.contains('/') ? id.split('/').last : id;

/// Lays out a set of cards 4-across on wide layouts and 2-across when narrow.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    const spacing = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth >= 720 ? 4 : 2;
        final width =
            (constraints.maxWidth - spacing * (perRow - 1)) / perRow;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _AccountPanel extends ConsumerWidget {
  const _AccountPanel({required this.money});

  final String Function(double, {int dp}) money;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(usageProvider);
    final credits = usage.credits;

    Widget body;
    if (usage.creditsLoading) {
      body = const _BalanceSkeleton();
    } else if (usage.creditsError != null) {
      body = InfoBanner(
        title: 'Balance unavailable',
        message: usage.creditsError!,
        kind: BannerKind.warning,
      );
    } else if (credits != null) {
      body = _BalanceContent(credits: credits, money: money);
    } else {
      body = const Text('Tap refresh to load your account balance.');
    }

    return SectionPanel(
      title: 'Account balance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body,
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: usage.creditsLoading
                  ? null
                  : () => ref.read(usageProvider.notifier).refreshCredits(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmering placeholder shown while the account balance is being fetched —
/// a donut outline beside a few value rows, mirroring [_BalanceContent].
class _BalanceSkeleton extends StatelessWidget {
  const _BalanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SkeletonBox(width: 130, height: 130, radius: 65),
            SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SkeletonBox(height: 16),
                  SizedBox(height: 12),
                  SkeletonBox(height: 16),
                  SizedBox(height: 12),
                  SkeletonBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The balance doughnut chart + Remaining/Used/Purchased breakdown, side by
/// side on wide screens and stacked when narrow.
class _BalanceContent extends StatelessWidget {
  const _BalanceContent({required this.credits, required this.money});

  final CreditBalance credits;
  final String Function(double, {int dp}) money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = credits.remaining.clamp(0.0, double.infinity);
    final used = credits.totalUsage.clamp(0.0, double.infinity);
    final empty = remaining + used <= 0;
    final donut = SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: empty
                  ? [
                      PieChartSectionData(
                        value: 1,
                        color: theme.colorScheme.surfaceContainerHighest,
                        radius: 22,
                        showTitle: false,
                      ),
                    ]
                  : [
                      PieChartSectionData(
                        value: remaining,
                        color: theme.colorScheme.primary,
                        radius: 22,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: used,
                        color: theme.colorScheme.surfaceContainerHighest,
                        radius: 22,
                        showTitle: false,
                      ),
                    ],
            ),
            duration: Duration.zero,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(money(credits.totalCredits, dp: 2),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text('Balance',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ],
      ),
    );

    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LabelValueRow(
          label: 'Remaining',
          value: money(credits.remaining, dp: 2),
          highlight: true,
        ),
        LabelValueRow(label: 'Used', value: money(credits.totalUsage, dp: 2)),
        LabelValueRow(
          label: 'Purchased',
          value: money(credits.totalCredits, dp: 2),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 420) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              donut,
              const SizedBox(width: 24),
              Expanded(child: rows),
            ],
          );
        }
        return Column(
          children: [
            Center(child: donut),
            const SizedBox(height: 16),
            rows,
          ],
        );
      },
    );
  }
}

/// Bar chart of cost per model.
class _CostByModelPanel extends StatelessWidget {
  const _CostByModelPanel({required this.usage, required this.money});

  final UsageState usage;
  final String Function(double, {int dp}) money;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _palette(theme.colorScheme);
    final models = usage.byModel;
    final maxCost =
        models.map((m) => m.cost).fold<double>(0, (a, b) => a > b ? a : b);
    return SectionPanel(
      title: 'Cost by model',
      child: SizedBox(
        height: 240,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxCost <= 0 ? 1 : maxCost * 1.25,
            barTouchData: const BarTouchData(enabled: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 0.5),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  getTitlesWidget: (v, _) => Text(
                    NumberFormat.simpleCurrency(decimalDigits: 2).format(v),
                    style: _axisLabelStyle(theme),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  getTitlesWidget: (v, _) =>
                      _bottomLabel(theme, models, v.toInt()),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < models.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: models[i].cost,
                    color: palette[i % palette.length],
                    width: 20,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stacked column chart of input vs output tokens per model.
class _TokensByModelPanel extends StatelessWidget {
  const _TokensByModelPanel({required this.usage});

  final UsageState usage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final models = usage.byModel;
    final maxTokens = models
        .map((m) => m.totalTokens)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return SectionPanel(
      title: 'Tokens by model',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartLegend(items: [
            (label: 'Input', color: theme.colorScheme.primary),
            (label: 'Output', color: theme.colorScheme.tertiary),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxTokens <= 0 ? 1 : maxTokens * 1.25,
                barTouchData: const BarTouchData(enabled: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: theme.colorScheme.outlineVariant, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, _) => Text(
                        NumberFormat.compact().format(v),
                        style: _axisLabelStyle(theme),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (v, _) =>
                          _bottomLabel(theme, models, v.toInt()),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < models.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: models[i].totalTokens.toDouble(),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                        rodStackItems: [
                          BarChartRodStackItem(
                            0,
                            models[i].promptTokens.toDouble(),
                            theme.colorScheme.primary,
                          ),
                          BarChartRodStackItem(
                            models[i].promptTokens.toDouble(),
                            models[i].totalTokens.toDouble(),
                            theme.colorScheme.tertiary,
                          ),
                        ],
                      ),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pie chart of each model's share of total tokens.
class _TokenSharePanel extends StatelessWidget {
  const _TokenSharePanel({required this.usage});

  final UsageState usage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _palette(theme.colorScheme);
    final models = usage.byModel;
    final total = models.fold<int>(0, (sum, m) => sum + m.totalTokens);
    final denom = total == 0 ? 1 : total;
    return SectionPanel(
      title: 'Token share',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  for (var i = 0; i < models.length; i++)
                    PieChartSectionData(
                      value: models[i].totalTokens.toDouble(),
                      color: palette[i % palette.length],
                      radius: 64,
                      title:
                          '${(models[i].totalTokens / denom * 100).toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              duration: Duration.zero,
            ),
          ),
          const SizedBox(height: 12),
          _ChartLegend(items: [
            for (var i = 0; i < models.length; i++)
              (
                label: _shortModel(models[i].modelId),
                color: palette[i % palette.length]
              ),
          ]),
        ],
      ),
    );
  }
}

TextStyle _axisLabelStyle(ThemeData theme) => TextStyle(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 11,
    );

/// A bottom-axis label for bar charts: the short model name for [index].
Widget _bottomLabel(ThemeData theme, List<ModelUsage> models, int index) {
  if (index < 0 || index >= models.length) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: SizedBox(
      width: 72,
      child: Text(
        _shortModel(models[index].modelId),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _axisLabelStyle(theme),
      ),
    ),
  );
}

/// A small wrapping legend: a coloured dot + label per item.
class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.items});

  final List<({String label, Color color})> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              Text(item.label, style: _axisLabelStyle(theme)),
            ],
          ),
      ],
    );
  }
}

class _ByModelPanel extends StatelessWidget {
  const _ByModelPanel({
    required this.usage,
    required this.money,
    required this.intFmt,
  });

  final UsageState usage;
  final String Function(double, {int dp}) money;
  final NumberFormat intFmt;

  @override
  Widget build(BuildContext context) {
    final models = usage.byModel;
    final totalCost = usage.cost;

    return SectionPanel(
      title: 'By model',
      child: models.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No usage recorded yet this session.'),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 640;
                return Column(
                  children: [
                    if (wide) const _ByModelHeader(),
                    for (final m in models)
                      wide
                          ? _ByModelRow(
                              model: m,
                              totalCost: totalCost,
                              money: money,
                              intFmt: intFmt,
                            )
                          : _ByModelCard(
                              model: m,
                              totalCost: totalCost,
                              money: money,
                              intFmt: intFmt,
                            ),
                  ],
                );
              },
            ),
    );
  }
}

class _ByModelHeader extends StatelessWidget {
  const _ByModelHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget h(String t, int flex, {TextAlign align = TextAlign.left}) => Expanded(
          flex: flex,
          child: Text(
            t.toUpperCase(),
            textAlign: align,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          h('Model', 4),
          h('Input', 2, align: TextAlign.right),
          h('Output', 2, align: TextAlign.right),
          h('Req', 1, align: TextAlign.right),
          h('Cost', 2, align: TextAlign.right),
          h('% of total cost', 3, align: TextAlign.right),
        ],
      ),
    );
  }
}

class _ByModelRow extends StatelessWidget {
  const _ByModelRow({
    required this.model,
    required this.totalCost,
    required this.money,
    required this.intFmt,
  });

  final ModelUsage model;
  final double totalCost;
  final String Function(double, {int dp}) money;
  final NumberFormat intFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = totalCost <= 0 ? 0.0 : (model.cost / totalCost).clamp(0.0, 1.0);
    Widget cell(String t, int flex, {TextAlign align = TextAlign.right}) =>
        Expanded(
          flex: flex,
          child: Text(
            t,
            textAlign: align,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              model.modelId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          cell(intFmt.format(model.promptTokens), 2),
          cell(intFmt.format(model.completionTokens), 2),
          cell('${model.requests}', 1),
          cell(money(model.cost), 2),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: share, minHeight: 6),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(share * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stacked per-model card used on narrow layouts where a table would overflow.
class _ByModelCard extends StatelessWidget {
  const _ByModelCard({
    required this.model,
    required this.totalCost,
    required this.money,
    required this.intFmt,
  });

  final ModelUsage model;
  final double totalCost;
  final String Function(double, {int dp}) money;
  final NumberFormat intFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final share = totalCost <= 0 ? 0.0 : (model.cost / totalCost).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    model.modelId,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusChip('${model.requests}×',
                    color: theme.colorScheme.outline),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('COST', style: theme.textTheme.labelSmall),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${money(model.cost)}  ·  ${(share * 100).toStringAsFixed(1)}% of total',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: share, minHeight: 6),
            ),
            LabelValueRow(
              label: 'Tokens',
              value: '${intFmt.format(model.promptTokens)} in  ·  '
                  '${intFmt.format(model.completionTokens)} out',
            ),
          ],
        ),
      ),
    );
  }
}

/// A recap of the session: total cost/tokens, average cost per request, total
/// requests.
class _UsageSummaryPanel extends StatelessWidget {
  const _UsageSummaryPanel({
    required this.usage,
    required this.money,
    required this.intFmt,
  });

  final UsageState usage;
  final String Function(double, {int dp}) money;
  final NumberFormat intFmt;

  @override
  Widget build(BuildContext context) {
    final avg = usage.requests == 0 ? 0.0 : usage.cost / usage.requests;
    return SectionPanel(
      title: 'Usage summary',
      child: _CardGrid(
        cards: [
          _SummaryTile(
            icon: Icons.payments_outlined,
            label: 'Total cost',
            value: money(usage.cost),
          ),
          _SummaryTile(
            icon: Icons.toll_outlined,
            label: 'Total tokens',
            value: intFmt.format(usage.totalTokens),
          ),
          _SummaryTile(
            icon: Icons.trending_up,
            label: 'Avg cost / request',
            value: money(avg),
          ),
          _SummaryTile(
            icon: Icons.swap_horiz,
            label: 'Total requests',
            value: '${usage.requests}',
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
