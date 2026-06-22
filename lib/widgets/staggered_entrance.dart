import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Fades + slides (+ a touch of scale/overshoot) its [child] into place, with a
/// per-[index] delay so a list of these cascades in. The delay is baked into a
/// single forward tween via an [Interval] curve — no timers — so it settles
/// cleanly under `pumpAndSettle` and respects reduced motion (renders instantly
/// when [reduce] is true or `MediaQuery.disableAnimations` is set).
class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.reduce = false,
    this.offsetY = 14,
    this.maxStagger = 6,
    this.bounce = true,
  });

  final Widget child;

  /// Position in the list; later items start (and finish) slightly later.
  final int index;

  /// Force-disable the animation (in addition to the platform flag).
  final bool reduce;

  /// How far (logical px) the child rises from.
  final double offsetY;

  /// Cap the cascade so long lists don't take forever; items past this share
  /// the last slot's timing.
  final int maxStagger;

  /// Use the playful overshoot curve (vs a plain ease).
  final bool bounce;

  @override
  Widget build(BuildContext context) {
    final disabled =
        reduce || (MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (disabled) return child;

    final slot = index.clamp(0, maxStagger);
    // Each item animates within its own window of the shared 0..1 timeline.
    final start = (slot / (maxStagger + 4)).clamp(0.0, 0.8);
    final curve = Interval(
      start,
      1.0,
      curve: bounce ? AppTokens.curveOvershoot : AppTokens.curveSnap,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppTokens.durSlow + Duration(milliseconds: 60 * slot),
      curve: curve,
      builder: (context, t, child) {
        final eased = t.clamp(0.0, 1.0);
        return Opacity(
          // Fade a touch faster than the slide so overshoot never shows a gap.
          opacity: (eased * 1.4).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * offsetY),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
