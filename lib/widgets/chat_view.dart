import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/usage_provider.dart';
import '../screens/debug_screen.dart';
import '../screens/help_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/usage_screen.dart';
import 'chat_input.dart';
import 'dashboard_landing.dart';
import 'message_bubble.dart';
import 'model_selector.dart';
import 'ui_kit.dart';

/// The main chat pane: header (model selector), message list and composer.
class ChatView extends ConsumerWidget {
  const ChatView({
    super.key,
    this.showMenuButton = false,
    this.onExpandSidebar,
  });

  /// Whether to show a hamburger button that opens the conversation drawer
  /// (used on narrow layouts).
  final bool showMenuButton;

  /// When provided (wide layout with the sidebar collapsed), shows a button to
  /// re-open the sidebar.
  final VoidCallback? onExpandSidebar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatProvider);
    final convo = chat.current;
    // On the initial-launch dashboard (no conversation started yet) there is
    // nothing to type into or pick a model for: hide the model selector, the
    // header "new chat" action and the composer. Starting a chat from "New
    // chat" (sidebar/drawer) brings them back. See issue #100.
    final hasChat = convo != null;

    return Column(
      children: [
        _Header(
          showMenuButton: showMenuButton,
          onExpandSidebar: onExpandSidebar,
          showChatActions: hasChat,
        ),
        const Divider(height: 1),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: chat.loading
                ? const Center(
                    key: ValueKey('loading'),
                    child: CircularProgressIndicator())
                : (convo == null || convo.messages.isEmpty)
                    ? const DashboardLanding(key: ValueKey('empty'))
                    : _MessageList(key: ValueKey(convo.id)),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: chat.error == null
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey(chat.error),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: InfoBanner(
                    title: 'Error',
                    message: chat.error!,
                    kind: BannerKind.error,
                    onDismiss: () =>
                        ref.read(chatProvider.notifier).clearError(),
                  ),
                ),
        ),
        if (hasChat) const ChatInput(),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.showMenuButton,
    required this.showChatActions,
    this.onExpandSidebar,
  });

  final bool showMenuButton;

  /// Whether to show the model selector and the "new chat" action. Hidden on
  /// the initial-launch dashboard, where no conversation is active yet.
  final bool showChatActions;
  final VoidCallback? onExpandSidebar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responding =
        ref.watch(chatProvider.select((c) => c.isResponding));
    final animate =
        ref.watch(settingsProvider.select((s) => s.animateModelIndicator));
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Row(
          children: [
            if (showMenuButton)
              IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Conversations',
                onPressed: () => Scaffold.of(context).openDrawer(),
              )
            else if (onExpandSidebar != null)
              IconButton(
                icon: const Icon(Icons.menu_open),
                tooltip: 'Show sidebar',
                onPressed: onExpandSidebar,
              ),
            if (showChatActions) ...[
              const Expanded(child: ModelSelector()),
              if (responding && animate)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              const SizedBox(width: 4),
              // New chat: a one-tap action once a conversation is active.
              IconButton(
                icon: const Icon(Icons.add_comment_outlined),
                tooltip: 'New chat',
                onPressed: () =>
                    ref.read(chatProvider.notifier).newConversation(),
              ),
            ] else
              const Spacer(),
            // Secondary actions (Usage, Debug, Settings, …) live in the sidebar
            // navigation rail on wide layouts. Show them in a header overflow
            // menu only when the sidebar isn't available: on phones (drawer) or
            // when the wide sidebar is collapsed.
            if (showMenuButton || onExpandSidebar != null) const _OverflowMenu(),
          ],
        ),
      ),
    );
  }
}

/// Compact header menu for narrow layouts: gathers Usage, Debug and Settings
/// behind a single button so the header fits on small phones.
class _OverflowMenu extends ConsumerWidget {
  const _OverflowMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(usageProvider);
    final cost = usage.isEmpty ? null : '\$${usage.cost.toStringAsFixed(4)}';

    void push(Widget screen) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => screen),
        );

    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'usage':
            push(const UsageScreen());
          case 'help':
            push(const HelpScreen());
          case 'debug':
            push(const DebugScreen());
          case 'settings':
            push(const SettingsScreen());
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'usage',
          child: ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: const Text('Usage'),
            trailing: cost == null ? null : Text(cost),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'help',
          child: ListTile(
            leading: Icon(Icons.help_outline),
            title: Text('Help & Troubleshoot'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'debug',
          child: ListTile(
            leading: Icon(Icons.bug_report_outlined),
            title: Text('Debug sessions'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    );
  }
}

class _MessageList extends ConsumerStatefulWidget {
  const _MessageList({super.key});

  @override
  ConsumerState<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<_MessageList> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_controller.hasClients) return;
    _controller.jumpTo(_controller.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    // The current conversation can become null while this list is still in the
    // tree — e.g. deleting the active chat keeps this widget alive for the
    // AnimatedSwitcher's fade-out. Render nothing rather than dereferencing
    // null.
    final convo = ref.watch(chatProvider).current;
    if (convo == null) return const SizedBox.shrink();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Messages are selectable via the app-wide SelectionArea (see app.dart).
    return ListView.builder(
      controller: _controller,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      itemCount: convo.messages.length,
      itemBuilder: (context, index) => MessageBubble(
        message: convo.messages[index],
        modelName: convo.modelId,
      ),
    );
  }
}
