import 'package:flutter/material.dart';

/// A draggable handle between a resizable sidebar and the main pane.
///
/// Dragging resizes (via [onDrag]); releasing fires [onDragEnd] (e.g. to
/// persist the width); double-clicking fires [onReset]. Hovering highlights
/// and slightly widens the handle. Shared by the dashboard and chat workspace
/// so both desktop sidebars behave identically.
class ResizableSidebarHandle extends StatefulWidget {
  const ResizableSidebarHandle({
    super.key,
    required this.onDrag,
    this.onDragEnd,
    this.onReset,
  });

  /// Called with the horizontal drag delta (in logical pixels).
  final void Function(double dx) onDrag;
  final VoidCallback? onDragEnd;
  final VoidCallback? onReset;

  @override
  State<ResizableSidebarHandle> createState() => _ResizableSidebarHandleState();
}

class _ResizableSidebarHandleState extends State<ResizableSidebarHandle> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => widget.onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => widget.onDragEnd?.call(),
        onDoubleTap: widget.onReset,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: _hovering ? 10 : 8,
          color: _hovering
              ? scheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Center(
            child: VerticalDivider(
              width: 1,
              color: _hovering ? scheme.primary : scheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}
