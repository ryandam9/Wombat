import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/collapsible_sidebar.dart';
import '../widgets/conversation_list.dart';
import '../widgets/dashboard_landing.dart';
import 'chat_workspace_screen.dart';
import 'compare_screen.dart';
import 'debug_screen.dart';
import 'help_screen.dart';
import 'model_picker_screen.dart';
import 'settings_screen.dart';
import 'usage_screen.dart';

/// Responsive shell: a persistent sidebar on wide (desktop) layouts, and a
/// drawer on narrow (phone) layouts.
///
/// On wide layouts the sidebar's navigation rail swaps the centre pane in place
/// (no new routes / back buttons); the sidebar can also be resized by dragging
/// the separator and collapsed to a thin rail. On narrow layouts each nav item
/// opens as its own route instead.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const double _wideBreakpoint = 800;
  static const double _minSidebarWidth = 220;
  static const double _maxSidebarWidth = 520;

  double _sidebarWidth = 340;
  bool _collapsed = false;
  DashboardSection _section = DashboardSection.chat;

  // Selected bottom-navigation tab on the narrow (phone) layout.
  int _tab = 0;

  void _resize(double dx) {
    setState(() {
      _sidebarWidth =
          (_sidebarWidth + dx).clamp(_minSidebarWidth, _maxSidebarWidth);
    });
  }

  void _openWorkspace() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ChatWorkspaceScreen()),
    );
  }

  /// The centre-pane content for the active section. Each section is shown in
  /// place (not pushed), so there is no back button on desktop. Chat itself
  /// opens as its own workspace page, so the default centre is the dashboard.
  Widget _sectionPane() {
    switch (_section) {
      case DashboardSection.chat:
        return const DashboardLanding();
      case DashboardSection.models:
        return ModelPickerScreen(
          onPicked: (model) {
            ref.read(settingsProvider.notifier).setDefaultModel(model.id);
            setState(() => _section = DashboardSection.chat);
          },
        );
      case DashboardSection.usage:
        return const UsageScreen();
      case DashboardSection.debug:
        return const DebugScreen();
      case DashboardSection.settings:
        return const SettingsScreen();
      case DashboardSection.help:
        return const HelpScreen();
    }
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
                selectedSection: _section,
                onNavigate: (s) => setState(() => _section = s),
                onOpenChat: _openWorkspace,
                openChatBuilder: (_) => const ChatWorkspaceScreen(),
                onCollapse: () => setState(() => _collapsed = true),
              ),
              rail: _CollapsedRail(
                onExpand: () => setState(() => _collapsed = false),
              ),
            ),
            if (!_collapsed) _ResizableSeparator(onDrag: _resize),
            Expanded(
              child: PageTransitionSwitcher(
                transitionBuilder: (child, primary, secondary) =>
                    FadeThroughTransition(
                  animation: primary,
                  secondaryAnimation: secondary,
                  child: child,
                ),
                child: KeyedSubtree(
                  key: ValueKey(_section),
                  child: _sectionPane(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Narrow (phone) layout: a Material 3 bottom navigation bar instead of a
    // left drawer/rail. Each tab is a self-contained screen; opening a chat
    // pushes the workspace as a full route, so the bottom bar is hidden there.
    final Widget tab = switch (_tab) {
      0 => _MobileChatsTab(onOpenChat: _openWorkspace),
      1 => ModelPickerScreen(
          onPicked: (model) {
            ref.read(settingsProvider.notifier).setDefaultModel(model.id);
            setState(() => _tab = 0); // back to Chats after choosing a default
          },
        ),
      2 => const UsageScreen(),
      _ => const SettingsScreen(),
    };

    return Scaffold(
      body: tab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Models',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Usage',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// The mobile "Chats" tab: conversation history (or the welcome dashboard when
/// empty), a "New chat" FAB, and an overflow with the secondary actions that no
/// longer live in a side rail (Compare, Help, Debug).
class _MobileChatsTab extends ConsumerWidget {
  const _MobileChatsTab({required this.onOpenChat});

  /// Pushes the chat workspace (a full route, so the bottom bar is hidden).
  final VoidCallback onOpenChat;

  void _newChat(WidgetRef ref) {
    ref.read(chatProvider.notifier).newConversation();
    onOpenChat();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasChats =
        ref.watch(chatProvider.select((c) => c.conversations.isNotEmpty));

    void push(Widget screen) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => screen),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wombat'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => switch (value) {
              'compare' => push(const CompareScreen()),
              'help' => push(const HelpScreen()),
              'debug' => push(const DebugScreen()),
              _ => null,
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'compare',
                child: ListTile(
                  leading: Icon(Icons.compare_arrows),
                  title: Text('Compare models'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'help',
                child: ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text('Help & Troubleshoot'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'debug',
                child: ListTile(
                  leading: Icon(Icons.bug_report_outlined),
                  title: Text('Debug sessions'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: hasChats
          ? ConversationList(
              embedded: true,
              showNavigation: false,
              onOpenChat: onOpenChat,
            )
          : const DashboardLanding(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newChat(ref),
        icon: const Icon(Icons.add),
        label: const Text('New chat'),
      ),
    );
  }
}

/// A thin rail shown when the sidebar is collapsed: just an expand button so
/// the navigation can be brought back from any section.
class _CollapsedRail extends StatelessWidget {
  const _CollapsedRail({required this.onExpand});

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
