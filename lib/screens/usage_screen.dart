import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/usage_provider.dart';
import '../widgets/ui_kit.dart';

/// Shows OpenRouter usage accumulated during the current app session, plus the
/// account credit balance.
class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  static final _int = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
    // Attempt to load the account balance when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsageProvider>().refreshCredits();
    });
  }

  String _money(double v, {int dp = 4}) => '\$${v.toStringAsFixed(dp)}';

  @override
  Widget build(BuildContext context) {
    final usage = context.watch<UsageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session usage'),
        actions: [
          IconButton(
            tooltip: 'Reset session',
            icon: const Icon(Icons.restart_alt),
            onPressed: usage.isEmpty
                ? null
                : () => context.read<UsageProvider>().reset(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Input tokens',
                  value: _int.format(usage.promptTokens),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Output tokens',
                  value: _int.format(usage.completionTokens),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Cost',
                  value: _money(usage.cost),
                  unit: 'USD',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  label: 'Requests',
                  value: '${usage.requests}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AccountPanel(money: _money),
          const SizedBox(height: 16),
          _ByModelPanel(usage: usage, money: _money, intFmt: _int),
        ],
      ),
    );
  }
}

class _AccountPanel extends StatelessWidget {
  const _AccountPanel({required this.money});

  final String Function(double, {int dp}) money;

  @override
  Widget build(BuildContext context) {
    final usage = context.watch<UsageProvider>();
    final credits = usage.credits;

    return SectionPanel(
      title: 'Account balance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (usage.creditsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (usage.creditsError != null)
            InfoBanner(
              title: 'Balance unavailable',
              message: usage.creditsError!,
              kind: BannerKind.warning,
            )
          else if (credits != null) ...[
            LabelValueRow(
              label: 'Remaining',
              value: money(credits.remaining, dp: 2),
              highlight: true,
            ),
            LabelValueRow(
                label: 'Used', value: money(credits.totalUsage, dp: 2)),
            LabelValueRow(
              label: 'Purchased',
              value: money(credits.totalCredits, dp: 2),
            ),
          ] else
            const Text('Tap refresh to load your account balance.'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: usage.creditsLoading
                  ? null
                  : () => context.read<UsageProvider>().refreshCredits(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ByModelPanel extends StatelessWidget {
  const _ByModelPanel({
    required this.usage,
    required this.money,
    required this.intFmt,
  });

  final UsageProvider usage;
  final String Function(double, {int dp}) money;
  final NumberFormat intFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final models = usage.byModel;
    final maxCost = models.isEmpty
        ? 0.0
        : models.map((m) => m.cost).reduce((a, b) => a > b ? a : b);

    return SectionPanel(
      title: 'By model',
      child: models.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No usage recorded yet this session.'),
            )
          : Column(
              children: [
                for (final m in models)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.modelId,
                                  style: theme.textTheme.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              StatusChip('${m.requests}×',
                                  color: theme.colorScheme.outline),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('COST', style: theme.textTheme.labelSmall),
                              const Spacer(),
                              Text(money(m.cost),
                                  style: theme.textTheme.labelSmall),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: maxCost <= 0
                                  ? 0
                                  : (m.cost / maxCost).clamp(0.0, 1.0),
                              minHeight: 6,
                            ),
                          ),
                          LabelValueRow(
                            label: 'Tokens',
                            value: '${intFmt.format(m.promptTokens)} in  ·  '
                                '${intFmt.format(m.completionTokens)} out',
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
