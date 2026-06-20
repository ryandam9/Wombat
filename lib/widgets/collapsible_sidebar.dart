import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Animates a sidebar collapsing to a thin [rail] and back. The expanded
/// content is always laid out at its full [width] and clipped as the panel
/// shrinks (so nothing reflows or overflows mid-animation), while the two
/// layers cross-fade. Changing [width] while expanded (e.g. dragging to
/// resize) is applied immediately — only the collapse/expand is animated.
class CollapsibleSidebar extends StatefulWidget {
  const CollapsibleSidebar({
    super.key,
    required this.collapsed,
    required this.width,
    required this.sidebar,
    required this.rail,
    this.railWidth = 48,
  });

  final bool collapsed;
  final double width;
  final double railWidth;
  final Widget sidebar;
  final Widget rail;

  @override
  State<CollapsibleSidebar> createState() => _CollapsibleSidebarState();
}

class _CollapsibleSidebarState extends State<CollapsibleSidebar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: widget.collapsed ? 0 : 1,
  );

  @override
  void didUpdateWidget(CollapsibleSidebar old) {
    super.didUpdateWidget(old);
    if (widget.collapsed != old.collapsed) {
      widget.collapsed ? _c.reverse() : _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final f = Curves.easeInOutCubic.transform(_c.value);
        final w = lerpDouble(widget.railWidth, widget.width, f)!;
        // Only build the layer(s) that are (partly) visible. At rest exactly one
        // layer is in the tree, so hidden buttons don't linger as focusable /
        // findable widgets; both are built only during the cross-fade.
        final showSidebar = _c.value > 0;
        final showRail = _c.value < 1;
        return ClipRect(
          child: SizedBox(
            width: w,
            child: Stack(
              children: [
                // Expanded sidebar — full width, clipped as the panel narrows.
                if (showSidebar)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    width: widget.width,
                    child: IgnorePointer(
                      ignoring: f < 0.5,
                      child: Opacity(opacity: f, child: widget.sidebar),
                    ),
                  ),
                // Collapsed rail.
                if (showRail)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    width: widget.railWidth,
                    child: IgnorePointer(
                      ignoring: f >= 0.5,
                      child: Opacity(opacity: 1 - f, child: widget.rail),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
