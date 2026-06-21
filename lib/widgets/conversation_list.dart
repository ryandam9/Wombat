import 'package:animations/animations.dart';
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
import 'pressable_scale.dart';

/// The sections reachable from the sidebar navigation rail. On desktop these
/// swap the centre pane in place; on mobile each opens as its own route.
enum DashboardSection { chat, models, usage, debug, settings, help }

/// Sidebar: app header, primary actions, a navigation rail (Usage, Debug,
/// Settings, …) and the list of recent chats with search and per-chat actions.
class ConversationList extends ConsumerStatefulWidget {
  const ConversationList({
    super.key,
    this.inDrawer = false,
    this.onCollapse,
    this.onBack,
    this.selectedSection,
    this.onNavigate,
    this.onOpenChat,
    this.openChatBuilder,
    this.showNavigation = true,
    this.embedded = false,
  });

  /// When shown inside a [Drawer], selecting a conversation should close it.
  final bool inDrawer;

  /// When provided (wide layout), shows a button to collapse the sidebar.
  final VoidCallback? onCollapse;

  /// When provided, shows a back button in the header (used by the chat
  /// workspace page to return to the dashboard).
  final VoidCallback? onBack;

  /// The currently active section (desktop), used to highlight its nav item.
  final DashboardSection? selectedSection;

  /// When provided (desktop), tapping a nav item switches the centre pane in
  /// place via this callback instead of pushing a new route.
  final void Function(DashboardSection section)? onNavigate;

  /// When provided, opening or creating a chat (New chat, or "Chat history")
  /// invokes this — used by the dashboard to open the chat workspace page. When
  /// null, chats are shown in place.
  final VoidCallback? onOpenChat;

  /// When provided, tapping a recent chat tile morphs it into the page this
  /// builds (a container transform) instead of calling [onOpenChat]. Used by
  /// the dashboard so the tapped card animates into the chat workspace.
  final WidgetBuilder? openChatBuilder;

  /// Whether to show the navigation rail (Models, Usage, …). The chat workspace
  /// hides it so the sidebar is purely the conversation history.
  final bool showNavigation;

  /// When true, render only the conversation list — no branding header and no
  /// New chat / Compare buttons. Used when a host (e.g. the mobile Chats tab)
  /// provides its own app bar and a New chat FAB.
  final bool embedded;

  @override
  ConsumerState<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends ConsumerState<ConversationList> {
  /// Max recent chats shown in the dashboard sidebar (full list is on the
  /// Chat history page).
  static const int _recentLimit = 5;

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
    // Capture the (app-scoped) notifier before awaiting: popping the drawer
    // below can dispose this widget while the picker is open, and reading `ref`
    // after that throws "Using ref ... unmounted is unsafe". The notifier
    // outlives the widget, so the pick is applied and isn't dropped.
    final settings = ref.read(settingsProvider.notifier);
    if (widget.inDrawer) Navigator.of(context).pop();
    final picked = await Navigator.of(context).push<OpenRouterModel>(
      MaterialPageRoute(builder: (_) => const ModelPickerScreen()),
    );
    if (picked != null) {
      settings.setDefaultModel(picked.id);
    }
  }

  void _newChat() {
    ref.read(chatProvider.notifier).newConversation();
    if (widget.inDrawer) Navigator.of(context).pop();
    widget.onOpenChat?.call();
  }

  /// Opens the chat workspace / history. Closes the drawer first on mobile so
  /// it isn't left open behind the pushed workspace.
  void _openHistory() {
    if (widget.inDrawer) Navigator.of(context).pop();
    widget.onOpenChat?.call();
  }

  bool _isSelected(DashboardSection section) =>
      widget.onNavigate != null && widget.selectedSection == section;

  /// On desktop, switches the centre pane via [ConversationList.onNavigate];
  /// on mobile runs [mobile] (which pushes a route / closes the drawer).
  void _navigate(DashboardSection section, {required VoidCallback mobile}) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(section);
    } else {
      mobile();
    }
  }

  Future<void> _confirmClearAll(int count) async {
    // Capture the notifier before awaiting the dialog, in case this widget is
    // disposed while it's open (reading `ref` afterward would throw).
    final chat = ref.read(chatProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all chats?'),
        content: Text(
          'This permanently removes all $count conversation'
          '${count == 1 ? '' : 's'}. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      chat.deleteAllConversations();
    }
  }

  Widget _tile(Conversation convo, String? currentId) {
    final builder = widget.openChatBuilder;
    // On the dashboard the tapped card morphs into the chat workspace via a
    // container transform; elsewhere tapping just selects the chat in place.
    if (builder != null) {
      return OpenContainer(
        tappable: false,
        closedElevation: 0,
        openElevation: 0,
        closedColor: Colors.transparent,
        openColor: Theme.of(context).colorScheme.surface,
        closedShape: const RoundedRectangleBorder(),
        transitionType: ContainerTransitionType.fadeThrough,
        transitionDuration: const Duration(milliseconds: 350),
        closedBuilder: (context, open) => _ConversationTile(
          conversation: convo,
          selected: convo.id == currentId,
          onTap: () {
            ref.read(chatProvider.notifier).selectConversation(convo.id);
            open();
          },
        ),
        openBuilder: (context, _) => builder(context),
      );
    }
    return _ConversationTile(
      conversation: convo,
      selected: convo.id == currentId,
      onTap: () {
        ref.read(chatProvider.notifier).selectConversation(convo.id);
        if (widget.inDrawer) Navigator.of(context).pop();
        widget.onOpenChat?.call();
      },
    );
  }

  static String _dateGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'Previous 7 days';
    if (diff < 30) return 'Previous 30 days';
    return 'Older';
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final theme = Theme.of(context);

    final query = _query.trim().toLowerCase();
    final matches = query.isEmpty
        ? chat.conversations
        : chat.conversations
            .where((c) =>
                c.title.toLowerCase().contains(query) ||
                c.modelId.toLowerCase().contains(query))
            .toList();
    // On the dashboard (nav rail visible) keep the recent list short; the full
    // history lives on the Chat history page. Searching shows all matches.
    final capped = widget.showNavigation && query.isEmpty;
    final conversations =
        (capped && matches.length > _recentLimit)
            ? matches.sublist(0, _recentLimit)
            : matches;
    final hiddenCount = matches.length - conversations.length;
    // The full Chat history page groups chats by date (and pins) for easier
    // scanning; the dashboard's short list and search results stay flat.
    final grouped = !widget.showNavigation && query.isEmpty;

    final curId = chat.current?.id;
    // A flat list of lazy row builders so the (potentially long) history is
    // virtualized by ListView.builder rather than built all at once.
    final rows = <Widget Function()>[];

    if (widget.showNavigation) {
      rows
        ..add(() => const _SectionLabel('Navigation'))
        ..add(() => _NavItem(
            icon: Icons.history,
            label: 'Chat history',
            selected: _isSelected(DashboardSection.chat),
            onTap: _openHistory))
        ..add(() => _NavItem(
            icon: Icons.grid_view_outlined,
            label: 'Models',
            selected: _isSelected(DashboardSection.models),
            onTap: () => _navigate(DashboardSection.models, mobile: _openModels)))
        ..add(() => _NavItem(
            icon: Icons.insights_outlined,
            label: 'Usage',
            selected: _isSelected(DashboardSection.usage),
            onTap: () => _navigate(DashboardSection.usage,
                mobile: () => _open(const UsageScreen()))))
        ..add(() => _NavItem(
            icon: Icons.bug_report_outlined,
            label: 'Debug',
            selected: _isSelected(DashboardSection.debug),
            onTap: () => _navigate(DashboardSection.debug,
                mobile: () => _open(const DebugScreen()))))
        ..add(() => _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            selected: _isSelected(DashboardSection.settings),
            onTap: () => _navigate(DashboardSection.settings,
                mobile: () => _open(const SettingsScreen()))))
        ..add(() => _NavItem(
            icon: Icons.help_outline,
            label: 'Help & Troubleshoot',
            selected: _isSelected(DashboardSection.help),
            onTap: () => _navigate(DashboardSection.help,
                mobile: () => _open(const HelpScreen()))))
        ..add(() => const SizedBox(height: 8));
    }

    rows.add(() => _RecentHeader(
          title: widget.showNavigation ? 'RECENT CHATS' : 'ALL CHATS',
          searching: _searching,
          onToggleSearch: () => setState(() {
            _searching = !_searching;
            if (!_searching) {
              _search.clear();
              _query = '';
            }
          }),
          // Bulk delete on the full history page only.
          onClearAll: (!widget.showNavigation && matches.isNotEmpty)
              ? () => _confirmClearAll(matches.length)
              : null,
        ));

    if (_searching) {
      rows.add(() => Padding(
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
          ));
    }
    rows.add(() => const SizedBox(height: 6));

    if (conversations.isEmpty) {
      rows.add(() => Padding(
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
          ));
    } else if (grouped) {
      _appendGroupedRows(rows, conversations, curId);
    } else {
      for (final convo in conversations) {
        rows.add(() => _tile(convo, curId));
      }
      if (hiddenCount > 0) {
        rows.add(() => Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: TextButton.icon(
                onPressed: _openHistory,
                icon: const Icon(Icons.history, size: 18),
                label: Text('View all ($hiddenCount more)'),
              ),
            ));
      }
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedded) ...[
            _Header(
              onCollapse: widget.onCollapse,
              onBack: widget.onBack,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: PressableScale(
                child: FilledButton.icon(
                  onPressed: _newChat,
                  icon: const Icon(Icons.add),
                  label: const Text('New chat'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: PressableScale(
                child: OutlinedButton.icon(
                  onPressed: () => _open(const CompareScreen()),
                  icon: const Icon(Icons.compare_arrows),
                  label: const Text('Compare models'),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: ListView.builder(
              // Leave room past the last tile for the host's New chat FAB.
              padding: widget.embedded
                  ? const EdgeInsets.only(bottom: 88)
                  : EdgeInsets.zero,
              itemCount: rows.length,
              itemBuilder: (_, i) => rows[i](),
            ),
          ),
        ],
      ),
    );
  }

  /// Appends "Pinned" + date-grouped tile rows as lazy builders.
  void _appendGroupedRows(
    List<Widget Function()> rows,
    List<Conversation> conversations,
    String? curId,
  ) {
    final pinned = conversations.where((c) => c.pinned).toList();
    final rest = conversations.where((c) => !c.pinned).toList();
    if (pinned.isNotEmpty) {
      rows.add(() => const _SectionLabel('Pinned'));
      for (final c in pinned) {
        rows.add(() => _tile(c, curId));
      }
    }
    String? lastLabel;
    for (final c in rest) {
      final label = _dateGroup(c.updatedAt);
      if (label != lastLabel) {
        rows.add(() => _SectionLabel(label));
        lastLabel = label;
      }
      rows.add(() => _tile(c, curId));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({this.onCollapse, this.onBack});

  final VoidCallback? onCollapse;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(onBack != null ? 4 : 16, 12, 8, 12),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              tooltip: 'Back to dashboard',
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            ),
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
          Flexible(
            child: Text(
              'Wombat',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge,
            ),
          ),
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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 1.4,
          fontSize: 11,
          color: theme.colorScheme.outline,
          fontWeight: FontWeight.w700,
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
    final scheme = theme.colorScheme;
    // Selected = a bold primary colour block with a hard offset shadow; the
    // icon/label invert to onPrimary. Unselected = transparent with a subtle
    // hover, bold weight for scannability.
    final iconColor = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    final textColor = selected ? scheme.onPrimary : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: scheme.outline, width: 2)
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.shadow,
                      offset: const Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            onTap: onTap,
            hoverColor: scheme.onSurface.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: iconColor),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentHeader extends StatelessWidget {
  const _RecentHeader({
    required this.searching,
    required this.onToggleSearch,
    this.title = 'RECENT CHATS',
    this.onClearAll,
  });

  final bool searching;
  final VoidCallback onToggleSearch;
  final String title;

  /// When provided, shows a "delete all chats" action.
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Text(
            title,
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
          if (onClearAll != null)
            IconButton(
              tooltip: 'Delete all chats',
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              color: theme.colorScheme.error,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: onClearAll,
            ),
        ],
      ),
    );
  }
}

/// Short model label: the part after the vendor slash.
String _shortModel(String id) => id.contains('/') ? id.split('/').last : id;

/// A small palette giving each vendor a distinct, consistent avatar colour.
const List<Color> _avatarPalette = [
  Color(0xFF5A4FCF), // indigo
  Color(0xFF00897B), // teal
  Color(0xFFEF6C00), // orange
  Color(0xFFC2185B), // pink
  Color(0xFF2E7D32), // green
  Color(0xFF1565C0), // blue
  Color(0xFF6A1B9A), // purple
  Color(0xFF00838F), // cyan
];

String _vendor(String modelId) =>
    modelId.contains('/') ? modelId.split('/').first : modelId;

Color _modelColor(String modelId) {
  final v = _vendor(modelId);
  var hash = 0;
  for (final c in v.codeUnits) {
    hash = (hash * 31 + c) & 0x7fffffff;
  }
  return _avatarPalette[hash % _avatarPalette.length];
}

String _modelInitial(String modelId) {
  final v = _vendor(modelId).trim();
  return v.isEmpty ? '?' : v[0].toUpperCase();
}

/// A coloured, rounded avatar with the model vendor's initial. Same vendor →
/// same colour, so the list reads at a glance instead of a wall of identical
/// rows. A soft gradient + tinted shadow give it depth.
class _ModelAvatar extends StatelessWidget {
  const _ModelAvatar({required this.modelId});

  final String modelId;

  @override
  Widget build(BuildContext context) {
    final color = _modelColor(modelId);
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.12)!,
            Color.lerp(color, Colors.black, 0.20)!,
          ],
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        _modelInitial(modelId),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }
}

/// A small, vendor-coloured pill showing the short model name in the subtitle.
class _ModelChip extends StatelessWidget {
  const _ModelChip({required this.modelId});

  final String modelId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final color = _modelColor(modelId);
    final fg = dark
        ? Color.lerp(color, Colors.white, 0.5)!
        : Color.lerp(color, Colors.black, 0.18)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.22 : 0.13),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _shortModel(modelId),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
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
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: scheme.outline, width: 2)
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.shadow,
                      offset: const Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            selected: selected,
            selectedTileColor: Colors.transparent,
            hoverColor: scheme.onSurface.withValues(alpha: 0.06),
            contentPadding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
            minVerticalPadding: 10,
            horizontalTitleGap: 12,
            leading: _ModelAvatar(modelId: conversation.modelId),
            title: Text(
              conversation.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: selected ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Flexible(child: _ModelChip(modelId: conversation.modelId)),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(conversation.updatedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? scheme.onPrimary.withValues(alpha: 0.8)
                          : scheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (conversation.pinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(Icons.push_pin,
                        size: 15,
                        color: selected
                            ? scheme.onPrimary
                            : scheme.primary),
                  ),
                _ChatMenu(conversation: conversation),
              ],
            ),
            onTap: onTap,
          ),
        ),
      ),
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
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Chat actions',
      icon: const Icon(Icons.more_vert, size: 20),
      // A softer, rounded menu surface to match the refreshed list.
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      color: scheme.surfaceContainerHigh,
      clipBehavior: Clip.antiAlias,
      position: PopupMenuPosition.under,
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
        _item(
          context,
          value: 'pin',
          icon: conversation.pinned ? Icons.push_pin_outlined : Icons.push_pin,
          label: conversation.pinned ? 'Unpin' : 'Pin',
        ),
        _item(context, value: 'rename', icon: Icons.edit_outlined, label: 'Rename'),
        _item(
          context,
          value: 'delete',
          icon: Icons.delete_outline,
          label: 'Delete',
          danger: true,
        ),
      ],
    );
  }

  /// A compact, icon + label popup row. [danger] tints it with the error colour
  /// for destructive actions (Delete).
  PopupMenuItem<String> _item(
    BuildContext context, {
    required String value,
    required IconData icon,
    required String label,
    bool danger = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = danger ? scheme.error : scheme.onSurface;
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 14),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final chat = ref.read(chatProvider.notifier);
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
      chat.renameConversation(conversation.id, newTitle);
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
