import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/chat_view.dart';
import '../widgets/collapsible_sidebar.dart';
import '../widgets/conversation_list.dart';
import '../widgets/desktop_sidebar_handle.dart';
import '../widgets/motion.dart';

/// A focused, two-pane chat workspace opened from the dashboard ("Chat history"
/// or "New chat"): the conversation history on the left and the active chat on
/// the right. On narrow layouts the history is a drawer.
///
/// Shares the dashboard's polished desktop sidebar behaviour: hover/double-click
/// resize handle, persisted width, motion-aware collapse, and a useful
/// collapsed rail.
class ChatWorkspaceScreen extends ConsumerStatefulWidget {
  const ChatWorkspaceScreen({super.key});

  @override
  ConsumerState<ChatWorkspaceScreen> createState() =>
      _ChatWorkspaceScreenState();
}

class _ChatWorkspaceScreenState extends ConsumerState<ChatWorkspaceScreen> {
  static const double _wideBreakpoint = 800;

  double _sidebarWidth = SettingsNotifier.defaultSidebarWidth;
  bool _collapsed = false;
  bool _widthInitialized = false;

  void _resize(double dx) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + dx).clamp(
        SettingsNotifier.minSidebarWidth,
        SettingsNotifier.maxSidebarWidth,
      );
    });
  }

  void _persistWidth() =>
      ref.read(settingsProvider.notifier).setSidebarWidth(_sidebarWidth);

  void _resetWidth() {
    setState(() => _sidebarWidth = SettingsNotifier.defaultSidebarWidth);
    _persistWidth();
  }

  void _newChat() => ref.read(chatProvider.notifier).newConversation();

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    final settings = ref.watch(settingsProvider);
    // Seed the sidebar width from the persisted setting once it has loaded.
    if (!_widthInitialized && !settings.loading) {
      _sidebarWidth = settings.sidebarWidth;
      _widthInitialized = true;
    }
    final motion = Motion.of(context, ref);

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            CollapsibleSidebar(
              collapsed: _collapsed,
              width: _sidebarWidth,
              railWidth: 56,
              duration: motion.medium,
              sidebar: ConversationList(
                showNavigation: false,
                onBack: () => Navigator.of(context).pop(),
                onCollapse: () => setState(() => _collapsed = true),
              ),
              rail: _CollapsedRail(
                onBack: () => Navigator.of(context).pop(),
                onExpand: () => setState(() => _collapsed = false),
                onNewChat: _newChat,
              ),
            ),
            if (!_collapsed)
              ResizableSidebarHandle(
                onDrag: _resize,
                onDragEnd: _persistWidth,
                onReset: _resetWidth,
              ),
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

/// The collapsed workspace sidebar: back, expand, and a New chat action.
class _CollapsedRail extends StatelessWidget {
  const _CollapsedRail({
    required this.onBack,
    required this.onExpand,
    required this.onNewChat,
  });

  final VoidCallback onBack;
  final VoidCallback onExpand;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 56,
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
              tooltip: 'Show chat history',
              icon: const Icon(Icons.menu_open),
              onPressed: onExpand,
            ),
            const Divider(indent: 12, endIndent: 12),
            IconButton(
              tooltip: 'New chat',
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: onNewChat,
            ),
          ],
        ),
      ),
    );
  }
}
