import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../screens/settings_screen.dart';
import '../theme/app_tokens.dart';
import 'dotted_background.dart';
import 'pressable_scale.dart';
import 'staggered_entrance.dart';
import 'ui_kit.dart';

/// The Wombat welcome dashboard: avatar, title and a getting-started
/// checklist. Shown as the desktop home centre pane and as the empty state of
/// a chat with no messages.
class DashboardLanding extends ConsumerWidget {
  const DashboardLanding({super.key, this.onStartChat});

  /// When provided, a prominent "Start new chat" call‑to‑action is shown. The
  /// chat empty‑state (where you're already in a conversation) leaves it null.
  final VoidCallback? onStartChat;

  void _openSettings(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasKey = ref.watch(settingsProvider.select((s) => s.hasApiKey));

    return DottedBackground(
      child: Center(
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
              if (onStartChat != null) ...[
                const SizedBox(height: 28),
                _StartChatCta(onTap: onStartChat!),
              ],
              const SizedBox(height: 28),
              SectionPanel(
                title: 'Getting started',
                accent: WombatColors.eucalyptus,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StaggeredEntrance(
                      index: 0,
                      child: _StartStep(
                        step: 1,
                        icon: Icons.key_outlined,
                        accent: WombatColors.clay,
                        tilt: -0.04,
                        title:
                            hasKey ? 'API key configured' : 'Add your API key',
                        description: hasKey
                            ? 'Your OpenRouter API key is set and ready to use.'
                            : 'Save your OpenRouter key in Settings to begin.',
                        done: hasKey,
                        onTap: hasKey ? null : () => _openSettings(context),
                      ),
                    ),
                    const Divider(height: 20),
                    const StaggeredEntrance(
                      index: 1,
                      child: _StartStep(
                        step: 2,
                        icon: Icons.add_comment_outlined,
                        accent: WombatColors.skyBlue,
                        tilt: 0.05,
                        title: 'Start a new chat',
                        description: 'Tap "New chat" to open a conversation.',
                      ),
                    ),
                    const Divider(height: 20),
                    const StaggeredEntrance(
                      index: 2,
                      child: _StartStep(
                        step: 3,
                        icon: Icons.send_outlined,
                        accent: WombatColors.coral,
                        tilt: -0.05,
                        title: 'Pick a model and send',
                        description: 'Choose a model in the header, then type '
                            'your first message.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// The landing page's primary call-to-action: a large, unmistakable Neo
/// Brutalist "Start new chat" block that presses flat and lifts on hover.
class _StartChatCta extends StatelessWidget {
  const _StartChatCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PressableScale(
      mode: PressMode.neo,
      shadowOffset: AppTokens.shadowMd,
      borderRadius: AppTokens.radiusMd,
      child: Material(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(
                  color: scheme.outline, width: AppTokens.borderThick),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: scheme.onPrimary, size: 22),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Start new chat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
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
    this.accent,
    this.tilt = 0,
    this.done = false,
    this.onTap,
  });

  final int step;
  final IconData icon;
  final String title;
  final String description;

  /// Per-step accent (a [WombatColors] hue) for the icon disc + number badge.
  final Color? accent;

  /// A playful rotation (radians) for the icon disc.
  final double tilt;

  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = this.accent ?? theme.colorScheme.primary;
    final row = InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Row(
        children: [
          _StepNumber(step, accent: accent),
          const SizedBox(width: 12),
          _IconDisc(icon: icon, accent: accent, tilt: tilt),
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
                        color: theme.colorScheme.onSurfaceVariant)),
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
    // Tappable steps get a gentle press; static steps render as-is.
    return onTap == null
        ? row
        : PressableScale(scale: 0.98, child: row);
  }
}

/// Black or white, whichever reads on [bg].
Color _onAccent(Color bg) =>
    bg.computeLuminance() > 0.5 ? WombatColors.ink : WombatColors.cream;

/// A small circular step-number badge in the step's accent colour.
class _StepNumber extends StatelessWidget {
  const _StepNumber(this.step, {required this.accent});

  final int step;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant, width: AppTokens.border),
        boxShadow: AppTokens.softShadow(scheme, level: 1),
      ),
      child: Text(
        '$step',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: _onAccent(accent),
        ),
      ),
    );
  }
}

/// A small rounded square with a centered accent icon, tilted a touch for a
/// hand-placed, sticker-like feel.
class _IconDisc extends StatelessWidget {
  const _IconDisc({required this.icon, required this.accent, this.tilt = 0});

  final IconData icon;
  final Color accent;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Transform.rotate(
      angle: tilt,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant, width: AppTokens.border),
          boxShadow: AppTokens.softShadow(scheme, level: 1),
        ),
        child: Icon(icon, size: 20, color: _onAccent(accent)),
      ),
    );
  }
}
