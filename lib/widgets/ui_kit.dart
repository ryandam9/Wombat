import 'package:flutter/material.dart';

/// Small Material building blocks used across the app (replacing the previous
/// third-party HUD widget kit).

/// A titled, outlined section card.
class SectionPanel extends StatelessWidget {
  const SectionPanel({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                letterSpacing: 1.2,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

/// A compact label/value statistic tile.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, this.unit});

  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline),
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
                  style: theme.textTheme.titleLarge,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(unit!, style: theme.textTheme.labelSmall),
              ],
            ],
          ),
        ],
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
    final labelStyle = theme.textTheme.labelMedium
        ?.copyWith(color: theme.colorScheme.outline);
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      color: highlight ? theme.colorScheme.primary : null,
      fontWeight: highlight ? FontWeight.w600 : null,
    );

    if (wrap && value != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: labelStyle),
            const SizedBox(height: 4),
            // Full value, wrapping across lines (no truncation).
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
          const Spacer(),
          if (trailing != null)
            trailing!
          else
            Flexible(
              child: Text(
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

/// A small colored status pill.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall
            ?.copyWith(color: c, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    );
  }
}

enum BannerKind { info, success, warning, error }

/// An inline dismissible message banner.
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
      BannerKind.error => (scheme.errorContainer, scheme.onErrorContainer, Icons.error_outline),
      BannerKind.warning => (scheme.tertiaryContainer, scheme.onTertiaryContainer, Icons.warning_amber),
      BannerKind.success => (scheme.secondaryContainer, scheme.onSecondaryContainer, Icons.check_circle_outline),
      BannerKind.info => (scheme.surfaceContainerHighest, scheme.onSurface, Icons.info_outline),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
                  if (message != null) ...[
                    const SizedBox(height: 2),
                    Text(message!, style: TextStyle(color: fg)),
                  ],
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: Icon(Icons.close, size: 18, color: fg),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}
