import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'pressable_scale.dart';

/// A chunky, playful "back" control: a bordered, accent-tinted Neo button whose
/// arrow springs left on hover and mashes flat on press — more characterful
/// than a bare arrow icon.
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
          mode: PressMode.neo,
          shadowOffset: AppTokens.shadowSm,
          borderRadius: AppTokens.radiusSm,
          child: Material(
            color: Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.16),
                scheme.surfaceContainerLow),
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap ?? () => Navigator.of(context).maybePop(),
              child: Container(
                width: 42,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  border:
                      Border.all(color: scheme.outline, width: AppTokens.border),
                ),
                child: AnimatedSlide(
                  duration: reduce ? Duration.zero : AppTokens.durFast,
                  curve: Curves.easeOutBack,
                  offset: Offset(_hover && !reduce ? -0.16 : 0, 0),
                  child: Icon(Icons.arrow_back_rounded,
                      size: 20, color: scheme.primary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
