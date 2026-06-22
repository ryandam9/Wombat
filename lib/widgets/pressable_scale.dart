import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

/// Tactile press feedback. Two modes:
///
/// * [PressMode.scale] (default): the child scales down slightly — the original
///   behaviour, good for generic taps.
/// * [PressMode.neo]: the child translates down by the shadow offset and the
///   hard offset shadow collapses — the signature Neo Brutalist "button being
///   mashed flat" effect. On a pointer device, hovering instead *lifts* the
///   child (the shadow grows and it nudges up-left). Pair with [NeoCard] /
///   bordered buttons.
///
/// Uses a [Listener] so it never steals the child's own tap handling (buttons,
/// InkWells, etc. keep working). Honours reduced motion via [Motion] — when
/// motion is reduced the press snaps with no animation.
enum PressMode { scale, neo }

class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.scale = 0.96,
    this.haptic = true,
    this.mode = PressMode.scale,
    this.shadowOffset = AppTokens.shadowMd,
    this.borderRadius = AppTokens.radiusSm,
    this.hoverLift = true,
  });

  final Widget child;
  final double scale;

  /// Whether to emit a light selection tick on press-down for tactile feedback.
  /// Disable for controls that already trigger their own haptics.
  final bool haptic;

  /// The press-feedback style.
  final PressMode mode;

  /// For [PressMode.neo]: the resting shadow offset that collapses to zero on
  /// press (and grows on hover).
  final Offset shadowOffset;

  /// For [PressMode.neo]: the corner radius of the cast shadow so it matches a
  /// rounded child instead of poking square corners out behind it.
  final double borderRadius;

  /// For [PressMode.neo]: whether hovering with a pointer lifts the child.
  final bool hoverLift;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;
  bool _hovered = false;

  void _set(bool v) {
    if (_pressed != v) {
      if (v && widget.haptic) HapticFeedback.selectionClick();
      setState(() => _pressed = v);
    }
  }

  void _setHover(bool v) {
    if (_hovered != v) setState(() => _hovered = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final pressed = _pressed;

    if (widget.mode == PressMode.neo) {
      final scheme = Theme.of(context).colorScheme;
      // Resting → pressed collapses the shadow to zero and drops the child into
      // it. Hovering (pointer only) grows the shadow and lifts the child.
      final base = widget.shadowOffset;
      final hovering = _hovered && !pressed && widget.hoverLift && !reduce;
      final grow = hovering ? AppTokens.hoverShadowGrow : 0.0;
      final shadowOff = pressed
          ? Offset.zero
          : Offset(base.dx + grow, base.dy + grow);
      final translate = pressed
          ? Offset(base.dx, base.dy) // sink into where the shadow was
          : (hovering ? AppTokens.hoverLift : Offset.zero);

      final body = AnimatedContainer(
        duration: reduce ? Duration.zero : AppTokens.durFast,
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(translate.dx, translate.dy, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow,
              offset: shadowOff,
              blurRadius: 0,
            ),
          ],
        ),
        child: widget.child,
      );

      final listener = Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: body,
      );

      if (!widget.hoverLift) return listener;
      return MouseRegion(
        onEnter: (_) => _setHover(true),
        onExit: (_) => _setHover(false),
        child: listener,
      );
    }

    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: pressed ? widget.scale : 1.0,
        duration: reduce ? Duration.zero : AppTokens.durFast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
