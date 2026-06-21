import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../screens/settings_screen.dart';
import 'ui_kit.dart';

/// The Wombat welcome dashboard: avatar, title and a getting-started
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
    final scheme = theme.colorScheme;
    final hasKey = ref.watch(settingsProvider.select((s) => s.hasApiKey));

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 12),
                child: child,
              ),
            ),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.pets,
                      size: 64, color: scheme.primary),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Wombat',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Chat with LLMs via OpenRouter',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              SectionPanel(
                title: 'Getting started',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StartStep(
                      step: 1,
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
                      step: 2,
                      icon: Icons.add_comment_outlined,
                      title: 'Start a new chat',
                      description:
                          'Tap "New chat" to open a conversation.',
                    ),
                    const Divider(height: 20),
                    const _StartStep(
                      step: 3,
                      icon: Icons.send_outlined,
                      title: 'Pick a model and send',
                      description: 'Choose a model in the header, then type '
                          'your first message.',
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A getting-started step: a numbered disc, the step icon, title + description,
/// and a trailing green check when [done] (or a chevron only when actionable).
class _StartStep extends StatelessWidget {
  const _StartStep({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
    this.done = false,
    this.onTap,
  });

  final int step;
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
          _StepNumber(step),
          const SizedBox(width: 12),
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
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Green tick once complete; a chevron only when the step is tappable.
          if (done)
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50))
          else if (onTap != null)
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// A small circular step-number badge.
class _StepNumber extends StatelessWidget {
  const _StepNumber(this.step);

  final int step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outline, width: 2),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow,
            offset: const Offset(2, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        '$step',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onPrimary,
        ),
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
    final scheme = theme.colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline, width: 2),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow,
            offset: const Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Icon(icon, size: 20, color: scheme.onPrimary),
    );
  }
}
