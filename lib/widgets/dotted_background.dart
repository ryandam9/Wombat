import 'package:flutter/material.dart';

/// A subtle dot-grid backdrop — a hallmark of modern Neo Brutalism. Paints a
/// regularly spaced grid of small dots in a very low-contrast tone so it reads
/// as texture, not noise, behind content. Cheap: a single [CustomPaint].
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
    // Lean on the muted outline tone; keep it whisper-quiet in both themes.
    final dot = (color ?? scheme.onSurfaceVariant)
        .withValues(alpha: scheme.brightness == Brightness.dark ? 0.07 : 0.10);
    return CustomPaint(
      painter: _DotGridPainter(spacing: spacing, radius: radius, color: dot),
      child: child,
    );
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter({
    required this.spacing,
    required this.radius,
    required this.color,
  });

  final double spacing;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double y = spacing / 2; y < size.height; y += spacing) {
      for (double x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) =>
      old.spacing != spacing || old.radius != radius || old.color != color;
}
