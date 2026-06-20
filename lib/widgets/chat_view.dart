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

/// Welcome dashboard shown when there is no active conversation.
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  void _openSettings(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chat = ref.watch(chatProvider);
    final hasKey = ref.watch(settingsProvider.select((s) => s.hasApiKey));

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.pets,
                      size: 84, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 16),
              Text('Wombat', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Chat with LLMs via OpenRouter',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 24),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _DashCard(
                        icon: Icons.chat_bubble_outline,
                        label: 'Conversations',
                        value: '${chat.conversations.length}',
                        subtitle: 'Total chats',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _DashCard(
                        icon: Icons.bolt,
                        label: 'API key',
                        value: hasKey ? 'Set' : 'Missing',
                        subtitle: 'OpenRouter',
                        onTap: () => _openSettings(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionPanel(
                title: 'Getting started',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StartStep(
                      icon: Icons.key_outlined,
                      title: hasKey
                          ? 'API key configured'
                          : 'Add your API key',
                      description: hasKey
                          ? 'Your OpenRouter API key is set and ready to use.'
                          : 'Save your OpenRouter key in Settings to begin.',
                      done: hasKey,
                      onTap: hasKey ? null : () => _openSettings(context),
                    ),
                    const Divider(height: 20),
                    const _StartStep(
                      icon: Icons.grid_view_outlined,
                      title: 'Pick a model in the header',
                      description:
                          'Choose from 200+ models available on OpenRouter.',
                    ),
                    const Divider(height: 20),
                    const _StartStep(
                      icon: Icons.send_outlined,
                      title: 'Type a message to begin',
                      description: 'Ask anything. Wombat is ready to help!',
                    ),
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

/// A dashboard summary card: a leading icon disc, a label, a large value and a
/// subtitle. Tappable cards (e.g. API key) show a trailing chevron.
class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconDisc(icon: icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// A getting-started step: icon disc, title + description, and a trailing
/// chevron (or a green check when [done]).
class _StartStep extends StatelessWidget {
  const _StartStep({
    required this.icon,
    required this.title,
    required this.description,
    this.done = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Row(
        children: [
          _IconDisc(icon: icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(description,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (done)
            Icon(Icons.check_circle, color: theme.colorScheme.primary)
          else
            Icon(Icons.chevron_right, color: theme.colorScheme.outline),
        ],
      ),
    );
  }
}

/// A small rounded square with a centered accent icon.
class _IconDisc extends StatelessWidget {
  const _IconDisc({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: theme.colorScheme.primary),
    );
  }
}
