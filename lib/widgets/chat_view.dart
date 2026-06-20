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

    return Column(
      children: [
        _Header(
          showMenuButton: showMenuButton,
          onExpandSidebar: onExpandSidebar,
        ),
        const Divider(height: 1),
        Expanded(
          child: chat.loading
              ? const Center(child: CircularProgressIndicator())
              : (convo == null || convo.messages.isEmpty)
                  ? const _EmptyState()
                  : _MessageList(key: ValueKey(convo.id)),
        ),
        if (chat.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: InfoBanner(
              title: 'Error',
              message: chat.error!,
              kind: BannerKind.error,
              onDismiss: () => ref.read(chatProvider.notifier).clearError(),
            ),
          ),
        const ChatInput(),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.showMenuButton, this.onExpandSidebar});

  final bool showMenuButton;
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
            // New chat stays a one-tap action everywhere.
            IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: 'New chat',
              onPressed: () =>
                  ref.read(chatProvider.notifier).newConversation(),
            ),
            // On phones, fold the secondary actions into an overflow menu so the
            // header never overcrowds; show them inline on wide layouts.
            if (showMenuButton)
              const _OverflowMenu()
            else ...[
              const _UsageButton(),
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: 'Help & Troubleshoot',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.bug_report_outlined),
                tooltip: 'Debug sessions',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const DebugScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
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

/// Header action that opens the usage screen, showing the running session
/// cost once any requests have been made.
class _UsageButton extends ConsumerWidget {
  const _UsageButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(usageProvider);
    void open() => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const UsageScreen()),
        );

    if (usage.isEmpty) {
      return IconButton(
        icon: const Icon(Icons.insights_outlined),
        tooltip: 'Usage',
        onPressed: open,
      );
    }
    return TextButton.icon(
      onPressed: open,
      icon: const Icon(Icons.insights_outlined, size: 18),
      label: Text('\$${usage.cost.toStringAsFixed(4)}'),
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
    final convo = ref.watch(chatProvider).current!;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // SelectionArea lets the user drag-select and copy across messages.
    return SelectionArea(
      child: ListView.builder(
        controller: _controller,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        itemCount: convo.messages.length,
        itemBuilder: (context, index) =>
            MessageBubble(message: convo.messages[index]),
      ),
    );
  }
}

/// Welcome screen shown when there is no active conversation.
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chat = ref.watch(chatProvider);
    final hasKey = ref.watch(settingsProvider.select((s) => s.hasApiKey));

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.pets,
                      size: 56, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text('Wombat', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Chat with LLMs via OpenRouter',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Conversations',
                      value: '${chat.conversations.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'API key',
                      value: hasKey ? 'Set' : 'Missing',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SectionPanel(
                title: 'Getting started',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Step(
                      done: hasKey,
                      text: hasKey
                          ? 'API key configured'
                          : 'Add your API key in Settings',
                    ),
                    const _Step(text: 'Pick a model in the header'),
                    const _Step(text: 'Type a message to begin'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.text, this.done = false});

  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: done ? theme.colorScheme.primary : theme.colorScheme.outline,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
