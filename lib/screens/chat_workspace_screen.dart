import 'package:flutter/material.dart';

import '../widgets/chat_view.dart';
import '../widgets/collapsible_sidebar.dart';
import '../widgets/conversation_list.dart';

/// A focused, two-pane chat workspace opened from the dashboard ("Chat history"
/// or "New chat"): the conversation history on the left and the active chat on
/// the right. On narrow layouts the history is a drawer.
class ChatWorkspaceScreen extends StatefulWidget {
  const ChatWorkspaceScreen({super.key});

  @override
  State<ChatWorkspaceScreen> createState() => _ChatWorkspaceScreenState();
}

class _ChatWorkspaceScreenState extends State<ChatWorkspaceScreen> {
  static const double _wideBreakpoint = 800;
  static const double _minSidebarWidth = 220;
  static const double _maxSidebarWidth = 520;

  double _sidebarWidth = 340;
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
            CollapsibleSidebar(
              collapsed: _collapsed,
              width: _sidebarWidth,
              sidebar: ConversationList(
                showNavigation: false,
                onBack: () => Navigator.of(context).pop(),
                onCollapse: () => setState(() => _collapsed = true),
              ),
              rail: _CollapsedRail(
                onBack: () => Navigator.of(context).pop(),
                onExpand: () => setState(() => _collapsed = false),
              ),
            ),
            if (!_collapsed) _ResizableSeparator(onDrag: _resize),
            const Expanded(child: ChatView(showMenuButton: false)),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: Drawer(
        child: ConversationList(
          inDrawer: true,
          showNavigation: false,
          onBack: () {
            Navigator.of(context) // close the drawer
              ..pop()
              ..pop(); // leave the workspace
          },
        ),
      ),
      body: const ChatView(showMenuButton: true),
    );
  }
}

/// A thin rail shown when the workspace sidebar is collapsed: back + expand.
class _CollapsedRail extends StatelessWidget {
  const _CollapsedRail({required this.onBack, required this.onExpand});

  final VoidCallback onBack;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 48,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            IconButton(
              tooltip: 'Back to dashboard',
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            ),
            IconButton(
              tooltip: 'Show sidebar',
              icon: const Icon(Icons.menu_open),
              onPressed: onExpand,
            ),
          ],
        ),
      ),
    );
  }
}

/// A thin draggable handle to resize the sidebar.
class _ResizableSeparator extends StatelessWidget {
  const _ResizableSeparator({required this.onDrag});

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
