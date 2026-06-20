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

  /// Messages whose entrance animation has already played (so they don't
  /// replay when rebuilt or scrolled back into view).
  final Set<String> _animated = {};
  int _lastCount = 0;
  bool _showJumpToLatest = false;

  /// How close to the bottom (in px) still counts as "following" the chat.
  static const double _bottomThreshold = 160;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    // Don't replay entrance animations for messages that already exist when the
    // chat opens — only animate ones added afterwards.
    final convo = ref.read(chatProvider).current;
    if (convo != null) {
      _animated.addAll(convo.messages.map((m) => m.id));
      _lastCount = convo.messages.length;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  bool get _nearBottom {
    if (!_controller.hasClients) return true;
    final pos = _controller.position;
    return pos.maxScrollExtent - pos.pixels < _bottomThreshold;
  }

  void _onScroll() {
    final show = _controller.hasClients && !_nearBottom;
    if (show != _showJumpToLatest) setState(() => _showJumpToLatest = show);
  }

  /// Follows the conversation as it grows, but only when the user is already
  /// near the bottom — so scrolling up to read isn't interrupted. A brand-new
  /// message animates; streaming token growth jumps (tiny deltas, no jank).
  void _autoFollow({required bool animated}) {
    if (!_controller.hasClients || !_nearBottom) return;
    final target = _controller.position.maxScrollExtent;
    final reduce = ref.read(settingsProvider).reduceMotion;
    if (animated && !reduce) {
      _controller.animateTo(target,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
    } else {
      _controller.jumpTo(target);
    }
  }

  void _jumpToLatest() {
    if (!_controller.hasClients) return;
    final target = _controller.position.maxScrollExtent;
    if (ref.read(settingsProvider).reduceMotion) {
      _controller.jumpTo(target);
    } else {
      _controller.animateTo(target,
          duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The current conversation can become null while this list is still in the
    // tree — e.g. deleting the active chat keeps this widget alive for the
    // AnimatedSwitcher's fade-out. Render nothing rather than dereferencing
    // null.
    final convo = ref.watch(chatProvider).current;
    if (convo == null) return const SizedBox.shrink();

    final newMessage = convo.messages.length != _lastCount;
    _lastCount = convo.messages.length;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _autoFollow(animated: newMessage));

    final reduce = ref.watch(settingsProvider.select((s) => s.reduceMotion)) ||
        MediaQuery.of(context).disableAnimations;

    // Messages are selectable via the app-wide SelectionArea (see app.dart).
    return Stack(
      children: [
        ListView.builder(
          controller: _controller,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          itemCount: convo.messages.length,
          itemBuilder: (context, index) {
            final message = convo.messages[index];
            return MessageBubble(
              message: message,
              modelName: convo.modelId,
              animate: !reduce && _animated.add(message.id),
            );
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: _showJumpToLatest
                  ? FilledButton.tonalIcon(
                      key: const ValueKey('jump-to-latest'),
                      onPressed: _jumpToLatest,
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      label: const Text('Jump to latest'),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
