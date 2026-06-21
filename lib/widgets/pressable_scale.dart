import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

/// Tactile press feedback. Two modes:
///
/// * [PressMode.scale] (default): the child scales down slightly — the original
///   behaviour, good for generic taps.
/// * [PressMode.neo]: the child translates down by the shadow offset and the
///   hard offset shadow collapses — the signature Neo Brutalist "button being
///   mashed flat" effect. Pair with [NeoCard] / bordered buttons.
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
  });

  final Widget child;
  final double scale;

  /// Whether to emit a light selection tick on press-down for tactile feedback.
  /// Disable for controls that already trigger their own haptics.
  final bool haptic;

  /// The press-feedback style.
  final PressMode mode;

  /// For [PressMode.neo]: the resting shadow offset that collapses to zero on
  /// press.
  final Offset shadowOffset;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) {
      if (v && widget.haptic) HapticFeedback.selectionClick();
      setState(() => _pressed = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final pressed = _pressed;

    if (widget.mode == PressMode.neo) {
      // Translate down into where the shadow was, and shrink the shadow to
      // zero — the button looks physically pressed flat.
      final t = pressed ? 1.0 : 0.0;
      final dy = (widget.shadowOffset.dy * t);
      final dx = (widget.shadowOffset.dx * t);
      final shadowOff = Offset(
        widget.shadowOffset.dx * (1 - t),
        widget.shadowOffset.dy * (1 - t),
      );
      return Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : AppTokens.durFast,
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(dx, dy, 0),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow,
                offset: shadowOff,
                blurRadius: 0,
              ),
            ],
          ),
          child: widget.child,
        ),
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
