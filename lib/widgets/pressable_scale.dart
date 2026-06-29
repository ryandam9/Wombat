import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

/// Tactile press feedback. Two modes:
///
/// * [PressMode.scale] (default): the child scales down slightly — good for
///   generic taps.
/// * [PressMode.neo]: a soft elevation card. At rest it carries a gentle
///   diffused shadow; hovering with a pointer lifts it a touch (the shadow
///   deepens); pressing eases it back down. Pair with [NeoCard].
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
      // A soft elevation card: resting carries a gentle shadow; hovering lifts
      // it (deeper shadow, nudged up); pressing settles it back down.
      final base = widget.shadowOffset.dy >= 6 ? 2 : 1;
      final hovering = _hovered && !pressed && widget.hoverLift && !reduce;
      final level = pressed ? 0 : (hovering ? base + 1 : base);
      final translate = pressed
          ? Offset.zero
          : (hovering ? AppTokens.hoverLift : Offset.zero);

      final body = AnimatedContainer(
        duration: reduce ? Duration.zero : AppTokens.durFast,
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(translate.dx, translate.dy, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: AppTokens.softShadow(scheme, level: level),
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
