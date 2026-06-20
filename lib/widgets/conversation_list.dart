import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/conversation.dart';
import '../models/openrouter_model.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/compare_screen.dart';
import '../screens/debug_screen.dart';
import '../screens/help_screen.dart';
import '../screens/model_picker_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/usage_screen.dart';
import 'ui_kit.dart';

/// Sidebar: app header, primary actions, a navigation rail (Usage, Debug,
/// Settings, …) and the list of recent chats with search and per-chat actions.
class ConversationList extends ConsumerStatefulWidget {
  const ConversationList({super.key, this.inDrawer = false, this.onCollapse});

  /// When shown inside a [Drawer], selecting a conversation should close it.
  final bool inDrawer;

  /// When provided (wide layout), shows a button to collapse the sidebar.
  final VoidCallback? onCollapse;

  @override
  ConsumerState<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends ConsumerState<ConversationList> {
  final TextEditingController _search = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Closes the drawer (on mobile) then pushes [screen].
  void _open(Widget screen) {
    if (widget.inDrawer) Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _openModels() async {
    if (widget.inDrawer) Navigator.of(context).pop();
    final picked = await Navigator.of(context).push<OpenRouterModel>(
      MaterialPageRoute(builder: (_) => const ModelPickerScreen()),
    );
    if (picked != null) {
      ref.read(settingsProvider.notifier).setDefaultModel(picked.id);
    }
  }

  void _newChat() {
    ref.read(chatProvider.notifier).newConversation();
    if (widget.inDrawer) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final theme = Theme.of(context);

    final query = _query.trim().toLowerCase();
    final conversations = query.isEmpty
        ? chat.conversations
        : chat.conversations
            .where((c) =>
                c.title.toLowerCase().contains(query) ||
                c.modelId.toLowerCase().contains(query))
            .toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
              count: chat.conversations.length, onCollapse: widget.onCollapse),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: FilledButton.icon(
              onPressed: _newChat,
              icon: const Icon(Icons.add),
              label: const Text('New chat'),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: OutlinedButton.icon(
              onPressed: () => _open(const CompareScreen()),
              icon: const Icon(Icons.compare_arrows),
              label: const Text('Compare models'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const _SectionLabel('Navigation'),
                _NavItem(
                  icon: Icons.history,
                  label: 'Chat history',
                  selected: true,
                  onTap: () {
                    if (widget.inDrawer) Navigator.of(context).pop();
                  },
                ),
                _NavItem(
                  icon: Icons.grid_view_outlined,
                  label: 'Models',
                  onTap: _openModels,
                ),
                _NavItem(
                  icon: Icons.insights_outlined,
                  label: 'Usage',
                  onTap: () => _open(const UsageScreen()),
                ),
                _NavItem(
                  icon: Icons.bug_report_outlined,
                  label: 'Debug',
                  onTap: () => _open(const DebugScreen()),
                ),
                _NavItem(
                  icon: Icons.key_outlined,
                  label: 'API keys',
                  onTap: () => _open(const SettingsScreen()),
                ),
                _NavItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => _open(const SettingsScreen()),
                ),
                _NavItem(
                  icon: Icons.help_outline,
                  label: 'Help & Troubleshoot',
                  onTap: () => _open(const HelpScreen()),
                ),
                const SizedBox(height: 8),
                _RecentHeader(
                  searching: _searching,
                  onToggleSearch: () => setState(() {
                    _searching = !_searching;
                    if (!_searching) {
                      _search.clear();
                      _query = '';
                    }
                  }),
                ),
                if (_searching)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: TextField(
                      controller: _search,
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search chats…',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                const Divider(height: 1),
                if (conversations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        query.isEmpty
                            ? 'No conversations yet'
                            : 'No chats match "$_query"',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ),
                  )
                else
                  for (final convo in conversations)
                    _ConversationTile(
                      conversation: convo,
                      selected: convo.id == chat.current?.id,
                      onTap: () {
                        ref
                            .read(chatProvider.notifier)
                            .selectConversation(convo.id);
                        if (widget.inDrawer) Navigator.of(context).pop();
                      },
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count, this.onCollapse});

  final int count;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.pets, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(width: 10),
          Text('Wombat', style: theme.textTheme.titleLarge),
          const SizedBox(width: 8),
          if (count > 0) StatusChip('$count', color: theme.colorScheme.outline),
          const Spacer(),
          if (onCollapse != null)
            IconButton(
              tooltip: 'Collapse sidebar',
              icon: const Icon(Icons.menu_open),
              onPressed: onCollapse,
            ),
        ],
      ),
    );
  }
}

/// A small uppercase section heading (e.g. NAVIGATION, RECENT CHATS).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          color: theme.colorScheme.outline,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A navigation-rail entry: leading icon + label, with an optional active state.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        selected ? theme.colorScheme.primary : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentHeader extends StatelessWidget {
  const _RecentHeader({required this.searching, required this.onToggleSearch});

  final bool searching;
  final VoidCallback onToggleSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Text(
            'RECENT CHATS',
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: searching ? 'Close search' : 'Search chats',
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            icon: Icon(searching ? Icons.close : Icons.search),
            onPressed: onToggleSearch,
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      selected: selected,
      selectedTileColor:
          theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (conversation.pinned)
            Icon(Icons.push_pin, size: 16, color: theme.colorScheme.primary),
          _ChatMenu(conversation: conversation),
        ],
      ),
      onTap: onTap,
    );
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

/// Per-chat overflow menu: Pin/Unpin, Rename, Delete.
class _ChatMenu extends ConsumerWidget {
  const _ChatMenu({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Chat actions',
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (value) {
        switch (value) {
          case 'pin':
            ref.read(chatProvider.notifier).togglePin(conversation.id);
          case 'rename':
            _rename(context, ref);
          case 'delete':
            _confirmDelete(context, ref);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'pin',
          child: ListTile(
            leading: Icon(
                conversation.pinned ? Icons.push_pin_outlined : Icons.push_pin),
            title: Text(conversation.pinned ? 'Unpin' : 'Pin'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Rename'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
      ],
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: conversation.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newTitle != null && newTitle.isNotEmpty) {
      ref.read(chatProvider.notifier).renameConversation(
            conversation.id,
            newTitle,
          );
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
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
      ref.read(chatProvider.notifier).deleteConversation(conversation.id);
    }
  }
}
