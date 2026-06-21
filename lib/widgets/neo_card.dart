import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// A Neo Brutalist card: a flat colour block with a thick dark outline and a
/// hard offset shadow (zero blur). This is the signature look — a crisp
/// duplicate of the card's silhouette dropped behind and to the bottom-right.
///
/// Pass [shadowOffset] to tune the shadow size (defaults to [AppTokens.shadowMd]).
/// Set [elevated] false to drop the shadow (e.g. for tightly packed grids).
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = color ?? scheme.surfaceContainerLow;
    final outline = borderColor ?? scheme.outline;
    final shadow = scheme.shadow;

    // A single BoxDecoration with a zero-blur boxShadow gives the crisp hard
    // offset shadow that defines Neo Brutalism — no second stacked box needed.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: outline, width: borderWidth),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: shadow,
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
  }
}
