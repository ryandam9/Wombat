import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'neo_card.dart';

/// Small Neo Brutalist building blocks shared across the app. Every panel,
/// card and chip shares the same thick outline + hard offset shadow language
/// so the whole app reads as one designed system.

/// A titled section card: thick outline, hard offset shadow, bold uppercase
/// header on a coloured block, content below a thick divider.
class SectionPanel extends StatelessWidget {
  const SectionPanel({
    super.key,
    required this.title,
    required this.child,
    this.accent,
  });

  final String title;
  final Widget child;

  /// A playful header tint (e.g. one of the [WombatColors] accents). Defaults
  /// to the theme primary.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = this.accent ?? scheme.primary;
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
              // A stronger tint so the header reads as a distinct labelled
              // block; the bold caps stay >11:1 against it in both themes.
              color: accent.withValues(alpha: 0.30),
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
              color: scheme.onSurfaceVariant,
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
    return NeoCard(
      radius: AppTokens.radiusSm,
      shadowOffset: AppTokens.shadowSm,
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
                  child: _CountUpText(
                    value: value,
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
    );
  }
}

/// Counts a stat value up from zero when it first appears, then renders the
/// exact [value] string verbatim once settled (so prefixes/suffixes like `$`
/// or grouping stay intact). Falls back to plain text when the value has no
/// leading number or when motion is reduced.
class _CountUpText extends StatelessWidget {
  const _CountUpText({required this.value, this.style});

  final String value;
  final TextStyle? style;

  /// Splits `"$1,234.50 "` into ("$", 1234.5, " ", decimals:2, grouped:true).
  static ({String prefix, double number, String suffix, int decimals, bool grouped})?
      _parse(String v) {
    final m = RegExp(r'^(\D*)([\d,]*\.?\d+)(.*)$').firstMatch(v);
    if (m == null) return null;
    final raw = m.group(2)!;
    final n = double.tryParse(raw.replaceAll(',', ''));
    if (n == null) return null;
    final dot = raw.indexOf('.');
    return (
      prefix: m.group(1)!,
      number: n,
      suffix: m.group(3)!,
      decimals: dot >= 0 ? raw.length - dot - 1 : 0,
      grouped: raw.contains(','),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    Widget plain(String s) => Text(s,
        maxLines: 1, overflow: TextOverflow.ellipsis, style: style);

    final p = _parse(value);
    if (reduce || p == null) return plain(value);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: p.number),
      duration: AppTokens.durSlow,
      curve: AppTokens.curveSnap,
      builder: (context, n, _) {
        // Snap to the original string on the final frame for an exact match.
        if (n >= p.number) return plain(value);
        var num = n.toStringAsFixed(p.decimals);
        if (p.grouped) {
          final parts = num.split('.');
          final whole = parts[0].replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'),
            (m) => ',',
          );
          num = parts.length > 1 ? '$whole.${parts[1]}' : whole;
        }
        return plain('${p.prefix}$num${p.suffix}');
      },
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
