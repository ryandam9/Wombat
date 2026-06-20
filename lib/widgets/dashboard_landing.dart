import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/settings_screen.dart';
import 'ui_kit.dart';

/// The Wombat welcome dashboard: avatar, summary cards and a getting-started
/// checklist. Shown as the desktop home centre pane and as the empty state of
/// a chat with no messages.
class DashboardLanding extends ConsumerWidget {
  const DashboardLanding({super.key});

  void _openSettings(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chat = ref.watch(chatProvider);
    final hasKey = ref.watch(settingsProvider.select((s) => s.hasApiKey));

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.pets,
                      size: 84, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text('Wombat', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Chat with LLMs via OpenRouter',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 24),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _DashCard(
                        icon: Icons.chat_bubble_outline,
                        label: 'Conversations',
                        value: '${chat.conversations.length}',
                        subtitle: 'Total chats',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _DashCard(
                        icon: Icons.bolt,
                        label: 'API key',
                        value: hasKey ? 'Set' : 'Missing',
                        subtitle: 'OpenRouter',
                        onTap: () => _openSettings(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionPanel(
                title: 'Getting started',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StartStep(
                      icon: Icons.key_outlined,
                      title: hasKey ? 'API key configured' : 'Add your API key',
                      description: hasKey
                          ? 'Your OpenRouter API key is set and ready to use.'
                          : 'Save your OpenRouter key in Settings to begin.',
                      done: hasKey,
                      onTap: hasKey ? null : () => _openSettings(context),
                    ),
                    const Divider(height: 20),
                    const _StartStep(
                      icon: Icons.grid_view_outlined,
                      title: 'Pick a model in the header',
                      description:
                          'Choose from 200+ models available on OpenRouter.',
                    ),
                    const Divider(height: 20),
                    const _StartStep(
                      icon: Icons.send_outlined,
                      title: 'Type a message to begin',
                      description: 'Ask anything. Wombat is ready to help!',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dashboard summary card: a leading icon disc, a label, a large value and a
/// subtitle. Tappable cards (e.g. API key) show a trailing chevron.
class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconDisc(icon: icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// A getting-started step: icon disc, title + description, and a trailing
/// chevron (or a green check when [done]).
class _StartStep extends StatelessWidget {
  const _StartStep({
    required this.icon,
    required this.title,
    required this.description,
    this.done = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Row(
        children: [
          _IconDisc(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(description,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (done)
            Icon(Icons.check_circle, color: theme.colorScheme.primary)
          else
            Icon(Icons.chevron_right, color: theme.colorScheme.outline),
        ],
      ),
    );
  }
}

/// A small rounded square with a centered accent icon.
class _IconDisc extends StatelessWidget {
  const _IconDisc({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: theme.colorScheme.primary),
    );
  }
}
