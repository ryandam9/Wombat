import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'pressable_scale.dart';

/// A soft "back" control: a gently accent-tinted rounded button whose arrow
/// slides left on hover — a touch more characterful than a bare arrow icon.
///
/// Used both in the chat sidebar header and as the [AppBar.leading] of pushed
/// screens (via [NeoBackButton.leading]). [onTap] defaults to popping the
/// current route.
class NeoBackButton extends StatefulWidget {
  const NeoBackButton({super.key, this.onTap, this.tooltip = 'Back'});

  final VoidCallback? onTap;
  final String tooltip;

  /// An [AppBar.leading]-ready back button: shown only when there's a route to
  /// pop (so it stays absent when a screen is hosted in-pane on desktop).
  static Widget? leading(BuildContext context, {String tooltip = 'Back'}) {
    if (!Navigator.of(context).canPop()) return null;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: NeoBackButton(tooltip: tooltip),
      ),
    );
  }

  @override
  State<NeoBackButton> createState() => _NeoBackButtonState();
}

class _NeoBackButtonState extends State<NeoBackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: PressableScale(
          scale: 0.94,
          child: Material(
            color: Color.alphaBlend(
                scheme.primary.withValues(alpha: _hover ? 0.18 : 0.12),
                scheme.surfaceContainerLow),
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap ?? () => Navigator.of(context).maybePop(),
              child: SizedBox(
                width: 42,
                height: 38,
                child: Center(
                  child: AnimatedSlide(
                    duration: reduce ? Duration.zero : AppTokens.durFast,
                    curve: AppTokens.curveSnap,
                    offset: Offset(_hover && !reduce ? -0.14 : 0, 0),
                    child: Icon(Icons.arrow_back_rounded,
                        size: 20, color: scheme.primary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
