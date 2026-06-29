import 'package:flutter/material.dart';

/// A calm backdrop wash: a soft, barely-there gradient that lifts a plain
/// surface with gentle warmth and depth (a faint accent glow near the top
/// fading into the scaffold). Cheap — a single gradient, no per-frame paint.
///
/// Replaces the old Neo Brutalist dot-grid. The legacy [spacing]/[radius]/
/// [color] parameters are kept for source compatibility but no longer used.
class DottedBackground extends StatelessWidget {
  const DottedBackground({
    super.key,
    required this.child,
    this.spacing = 22,
    this.radius = 1.3,
    this.color,
  });

  final Widget child;
  final double spacing;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
                scheme.primary.withValues(alpha: dark ? 0.06 : 0.05),
                scheme.surface),
            scheme.surface,
          ],
        ),
      ),
      child: child,
    );
  }
}
