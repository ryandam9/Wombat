import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Small Neo Brutalist building blocks shared across the app. Every panel,
/// card and chip shares the same thick outline + hard offset shadow language
/// so the whole app reads as one designed system.

/// A titled section card: thick outline, hard offset shadow, bold uppercase
/// header on a coloured block, content below a thick divider.
class SectionPanel extends StatelessWidget {
  const SectionPanel({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: scheme.outline, width: AppTokens.border),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow,
              offset: AppTokens.shadowSm,
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: a coloured block with the title in bold caps.
            Container(
              width: double.infinity,
              color: scheme.primary.withValues(alpha: 0.16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                title.toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Container(
              height: AppTokens.border,
              color: scheme.outline,
            ),
            Padding(padding: const EdgeInsets.all(16), child: child),
          ],
        ),
      ),
    );
  }
}

/// A compact label/value stat tile: thick border, hard shadow, bold value.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, this.unit});

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: scheme.outline, width: AppTokens.border),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow,
            offset: AppTokens.shadowSm,
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A label on the left, value (or trailing widget) on the right.
///
/// When [wrap] is true the value is shown on its own line below the label and
/// is allowed to wrap across multiple lines — useful for long values such as
/// file paths or model ids that should stay fully visible.
class LabelValueRow extends StatelessWidget {
  const LabelValueRow({
    super.key,
    required this.label,
    this.value,
    this.trailing,
    this.highlight = false,
    this.wrap = false,
  }) : assert(value != null || trailing != null);

  final String label;
  final String? value;
  final Widget? trailing;
  final bool highlight;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w800,
    );
    final valueStyle = theme.textTheme.bodyLarge?.copyWith(
      color: highlight ? scheme.primary : scheme.onSurface,
      fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
    );

    if (wrap && value != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: labelStyle),
            const SizedBox(height: 4),
            Text(value!, style: valueStyle),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: labelStyle),
          const SizedBox(width: 12),
          Expanded(
            child: trailing != null
                ? Align(alignment: Alignment.centerRight, child: trailing!)
                : Text(
                    value!,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle,
                  ),
          ),
        ],
      ),
    );
  }
}

/// A small, bold status pill: thick border, flat colour block.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: scheme.outline, width: AppTokens.border),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: _onColor(c),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Pick black or white text for max contrast on [bg].
  static Color _onColor(Color bg) =>
      bg.computeLuminance() > 0.5 ? WombatColors.ink : WombatColors.cream;
}

enum BannerKind { info, success, warning, error }

/// An inline dismissible message banner: a flat colour block with a thick
/// border and a bold leading icon.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.title,
    this.message,
    this.kind = BannerKind.info,
    this.onDismiss,
  });

  final String title;
  final String? message;
  final BannerKind kind;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg, IconData icon) = switch (kind) {
      BannerKind.error => (WombatColors.coral, WombatColors.cream, Icons.error_outline),
      BannerKind.warning => (WombatColors.yellow, WombatColors.ink, Icons.warning_amber),
      BannerKind.success => (WombatColors.eucalyptus, WombatColors.cream, Icons.check_circle_outline),
      BannerKind.info => (scheme.surfaceContainerHigh, scheme.onSurface, Icons.info_outline),
    };
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: scheme.outline, width: AppTokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                  if (message != null) ...[
                    const SizedBox(height: 2),
                    Text(message!, style: TextStyle(color: fg, fontSize: 13)),
                  ],
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: Icon(Icons.close, size: 16, color: fg),
                onPressed: onDismiss,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
