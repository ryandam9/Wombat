import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/usage_provider.dart';
import '../screens/debug_screen.dart';
import '../screens/usage_screen.dart';
import 'chat_input.dart';
import 'message_bubble.dart';
import 'model_selector.dart';
import 'ui_kit.dart';

/// The main chat pane: header (model selector), message list and composer.
class ChatView extends StatelessWidget {
  const ChatView({super.key, this.showMenuButton = false});

  /// Whether to show a hamburger button that opens the conversation drawer
  /// (used on narrow layouts).
  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final convo = chat.current;

    return Column(
      children: [
        _Header(showMenuButton: showMenuButton),
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
              onDismiss: () => context.read<ChatProvider>().clearError(),
            ),
          ),
        const ChatInput(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.showMenuButton});

  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    final responding =
        context.select<ChatProvider, bool>((c) => c.isResponding);
    final animate = context
        .select<SettingsProvider, bool>((s) => s.animateModelIndicator);
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
            const SizedBox(width: 8),
            const _UsageButton(),
            IconButton(
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: 'Debug sessions',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DebugScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: 'New chat',
              onPressed: () => context.read<ChatProvider>().newConversation(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header action that opens the usage screen, showing the running session
/// cost once any requests have been made.
class _UsageButton extends StatelessWidget {
  const _UsageButton();

  @override
  Widget build(BuildContext context) {
    final usage = context.watch<UsageProvider>();
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

class _MessageList extends StatefulWidget {
  const _MessageList({super.key});

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
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
    final convo = context.watch<ChatProvider>().current!;
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
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chat = context.watch<ChatProvider>();
    final settings = context.watch<SettingsProvider>();
    final hasKey = settings.hasApiKey;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.alt_route, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Route', style: theme.textTheme.headlineSmall),
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
