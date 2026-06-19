import 'package:flutter/material.dart';

import '../widgets/chat_view.dart';
import '../widgets/conversation_list.dart';

/// Responsive shell: a persistent sidebar on wide (desktop) layouts, and a
/// drawer on narrow (phone) layouts.
///
/// On wide layouts the sidebar can be resized by dragging the separator and
/// collapsed entirely to give the chat pane the full width.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _wideBreakpoint = 800;
  static const double _minSidebarWidth = 220;
  static const double _maxSidebarWidth = 520;

  double _sidebarWidth = 300;
  bool _collapsed = false;

  void _resize(double dx) {
    setState(() {
      _sidebarWidth =
          (_sidebarWidth + dx).clamp(_minSidebarWidth, _maxSidebarWidth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            if (!_collapsed) ...[
              SizedBox(
                width: _sidebarWidth,
                child: ConversationList(
                  onCollapse: () => setState(() => _collapsed = true),
                ),
              ),
              _ResizableSeparator(onDrag: _resize),
            ],
            Expanded(
              child: ChatView(
                showMenuButton: false,
                onExpandSidebar:
                    _collapsed ? () => setState(() => _collapsed = false) : null,
              ),
            ),
          ],
        ),
      );
    }

    return const Scaffold(
      drawer: Drawer(child: ConversationList(inDrawer: true)),
      body: ChatView(showMenuButton: true),
    );
  }
}

/// A thin draggable handle between the sidebar and the chat pane. Dragging it
/// horizontally resizes the sidebar; it shows a resize cursor on desktop/web.
class _ResizableSeparator extends StatelessWidget {
  const _ResizableSeparator({required this.onDrag});

  /// Called with the horizontal drag delta (in logical pixels).
  final void Function(double dx) onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: const SizedBox(
          width: 8,
          child: Center(child: VerticalDivider(width: 1)),
        ),
      ),
    );
  }
}
