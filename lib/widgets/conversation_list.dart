import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/conversation.dart';
import '../providers/chat_provider.dart';
import '../screens/settings_screen.dart';

/// Sidebar listing all saved conversations with controls to create, select
/// and delete them.
class ConversationList extends StatelessWidget {
  const ConversationList({super.key, this.inDrawer = false});

  /// When shown inside a [Drawer], selecting a conversation should close it.
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Icon(Icons.alt_route, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Route', style: theme.textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FilledButton.tonalIcon(
              onPressed: () {
                context.read<ChatProvider>().newConversation();
                if (inDrawer) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.add),
              label: const Text('New chat'),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: chat.conversations.isEmpty
                ? Center(
                    child: Text(
                      'No conversations yet',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: chat.conversations.length,
                    itemBuilder: (context, index) {
                      final convo = chat.conversations[index];
                      return _ConversationTile(
                        conversation: convo,
                        selected: convo.id == chat.current?.id,
                        onTap: () {
                          context
                              .read<ChatProvider>()
                              .selectConversation(convo.id);
                          if (inDrawer) Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
      leading: const Icon(Icons.chat_bubble_outline, size: 20),
      title: Text(
        conversation.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${conversation.modelId}  ·  ${_formatDate(conversation.updatedAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: IconButton(
        tooltip: 'Delete',
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: () => _confirmDelete(context),
      ),
      onTap: onTap,
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text('"${conversation.title}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ChatProvider>().deleteConversation(conversation.id);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    return isToday
        ? DateFormat.Hm().format(date)
        : DateFormat.MMMd().format(date);
  }
}
