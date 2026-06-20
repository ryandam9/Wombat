import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../widgets/chat_view.dart';
import '../widgets/conversation_list.dart';
import '../widgets/dashboard_landing.dart';
import 'chat_workspace_screen.dart';
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
            if (!_collapsed) ...[
              SizedBox(
                width: _sidebarWidth,
                child: ConversationList(
                  selectedSection: _section,
                  onNavigate: (s) => setState(() => _section = s),
                  onOpenChat: _openWorkspace,
                  onCollapse: () => setState(() => _collapsed = true),
                ),
              ),
              _ResizableSeparator(onDrag: _resize),
            ] else
              _CollapsedRail(
                onExpand: () => setState(() => _collapsed = false),
              ),
            Expanded(child: _sectionPane()),
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
