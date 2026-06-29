import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'pressable_scale.dart';

/// A soft, modern surface card: a rounded panel with a hairline outline and a
/// gentle, diffused shadow. This is the app's primary container.
///
/// When [onTap] is set the card becomes tactile: hovering lifts it a touch (the
/// soft shadow deepens), pressing eases it back down. Honours reduced motion.
///
/// [shadowOffset] is retained for source compatibility but the card now uses
/// soft elevation; pass [elevated] false to render it flat (e.g. for tightly
/// packed grids or nested cards).
class NeoCard extends StatelessWidget {
  const NeoCard({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.borderWidth = AppTokens.border,
    this.radius = AppTokens.radiusMd,
    this.shadowOffset = AppTokens.shadowMd,
    this.elevated = true,
    this.padding,
    this.onTap,
    this.tilt = 0,
  });

  final Widget child;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final double radius;

  /// Retained for source compatibility; soft elevation is used instead of a
  /// hard offset. Larger offsets map to a slightly deeper shadow.
  final Offset shadowOffset;
  final bool elevated;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// Retained for source compatibility; the soft-modern look is flat (no tilt).
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = color ?? scheme.surfaceContainerLow;
    final outline = borderColor ?? scheme.outlineVariant;
    final interactive = onTap != null;
    // Map the legacy offset magnitude onto a soft elevation level.
    final level = shadowOffset.dy >= 6 ? 2 : 1;

    // The fill + border. When interactive the (animated) shadow is cast by the
    // wrapping PressableScale so it can deepen on hover; for a static card the
    // soft shadow lives here.
    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: outline, width: borderWidth),
        boxShadow: (elevated && !interactive)
            ? AppTokens.softShadow(scheme, level: level)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppTokens.padCard),
            child: child,
          ),
        ),
      ),
    );

    if (interactive && elevated) {
      card = PressableScale(
        mode: PressMode.neo,
        shadowOffset: shadowOffset,
        borderRadius: radius,
        child: card,
      );
    }
    return card;
  }
}
