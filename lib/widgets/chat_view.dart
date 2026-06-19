import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/chat_provider.dart';
import 'chat_input.dart';
import 'message_bubble.dart';
import 'model_selector.dart';

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
        if (chat.error != null) _ErrorBanner(message: chat.error!),
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
            const SizedBox(width: 8),
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
    // Keep the latest message in view as tokens stream in.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return ListView.builder(
      controller: _controller,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      itemCount: convo.messages.length,
      itemBuilder: (context, index) =>
          MessageBubble(message: convo.messages[index]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alt_route, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('Start a conversation', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Pick a model above and send a message.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                size: 20, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close,
                  size: 18, color: theme.colorScheme.onErrorContainer),
              onPressed: () => context.read<ChatProvider>().clearError(),
            ),
          ],
        ),
      ),
    );
  }
}
