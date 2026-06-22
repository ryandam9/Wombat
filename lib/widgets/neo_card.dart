import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'pressable_scale.dart';

/// A Neo Brutalist card: a flat colour block with a thick dark outline and a
/// hard offset shadow (zero blur). This is the signature look — a crisp
/// duplicate of the card's silhouette dropped behind and to the bottom-right.
///
/// When [onTap] is set the card becomes tactile: hovering lifts it (the shadow
/// grows), pressing mashes it flat (the shadow collapses and it sinks in) — the
/// defining Neo Brutalist interaction. Honours reduced motion.
///
/// Pass [shadowOffset] to tune the shadow size (defaults to [AppTokens.shadowMd]).
/// Set [elevated] false to drop the shadow (e.g. for tightly packed grids).
/// Pass a small [tilt] (radians) for a hand-placed, sticker-like feel.
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
  final Offset shadowOffset;
  final bool elevated;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  /// A slight rotation (radians) for a playful, hand-placed look. Defaults to 0.
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = color ?? scheme.surfaceContainerLow;
    final outline = borderColor ?? scheme.outline;
    final interactive = onTap != null;

    // The fill + border. When interactive, the (animated) shadow is cast by the
    // wrapping PressableScale so it can grow on hover / collapse on press; for a
    // static card the shadow lives here.
    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: outline, width: borderWidth),
        boxShadow: (elevated && !interactive)
            ? [
                BoxShadow(
                  color: scheme.shadow,
                  offset: shadowOffset,
                  blurRadius: 0,
                  spreadRadius: 0,
                ),
              ]
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

    if (tilt != 0) {
      card = Transform.rotate(angle: tilt, child: card);
    }
    return card;
  }
}
