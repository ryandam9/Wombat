import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/app_font.dart';
import '../providers/settings_provider.dart';
import '../services/debug_log.dart';
import '../widgets/ui_kit.dart';
import '../widgets/neo_back_button.dart';

/// Debug panel. Lists API exchanges as sessions (one per prompt → response);
/// tapping one opens a detailed view tying the model, prompt, timing, token
/// usage and the assembled streamed reply together.
class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(debugLogProvider);
    final sessions = log.sessions.reversed.toList(); // newest first

    return Scaffold(
      appBar: AppBar(
        leading: NeoBackButton.leading(context),
        title: const Text('Debug sessions'),
        actions: [
          Row(
            children: [
              const Text('Capture'),
              Switch(
                value: log.enabled,
                onChanged: (v) =>
                    ref.read(debugLogProvider.notifier).enabled = v,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: log.isEmpty
                ? null
                : ref.read(debugLogProvider.notifier).clear,
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: InfoBanner(
              title: 'Capture is local and opt-in',
              message: 'When enabled, captured sessions include request and '
                  'response data — your prompts, conversation history and any '
                  'attachments (with large base64 payloads redacted). They are '
                  'kept only in memory, never sent anywhere, and cleared when '
                  'the app restarts or you tap Clear.',
              kind: BannerKind.warning,
            ),
          ),
          Expanded(
            child: sessions.isEmpty
                ? const _EmptyDebug()
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _SessionCard(session: sessions[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final DebugSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final usage = session.usage;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SessionDetailScreen(session: session),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusDot(status: session.status),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      session.title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(DateFormat('HH:mm:ss').format(session.startedAt),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (session.model != null)
                    _MetaPill(icon: Icons.smart_toy_outlined, text: session.model!),
                  _MetaPill(
                    icon: Icons.timer_outlined,
                    text: _fmtDuration(session.duration),
                  ),
                  if (usage != null)
                    _MetaPill(
                      icon: Icons.toll_outlined,
                      text: '${usage.totalTokens} tok',
                    ),
                  if (usage != null)
                    _MetaPill(
                      icon: Icons.attach_money,
                      text: usage.cost.toStringAsFixed(4),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full detail for one session: stat header, a filterable event timeline, and
/// the assembled response / request / raw frames.
/// Full detail for one debug [DebugSession] — its stat header, filterable event
/// timeline and assembled response/request/raw frames. Public so a message's
/// Debug action can open the exchange that produced it directly. See #129.
class SessionDetailScreen extends ConsumerStatefulWidget {
  const SessionDetailScreen({super.key, required this.session});

  final DebugSession session;

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  DebugCategory? _filter; // null == All

  DebugSession get session => widget.session;

  @override
  Widget build(BuildContext context) {
    // Rebuild as the session streams in.
    ref.watch(debugLogProvider);
    final wide = MediaQuery.of(context).size.width >= 900;

    final timeline = _Timeline(
      session: session,
      filter: _filter,
      onFilter: (f) => setState(() => _filter = f),
    );
    final detail = _ResponseDetail(session: session);

    return Scaffold(
      appBar: AppBar(
        leading: NeoBackButton.leading(context),
        title: Text(session.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy session',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _sessionAsText(session)));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Session copied')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _StatHeader(session: session),
          const Divider(height: 1),
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: timeline),
                      const VerticalDivider(width: 1),
                      Expanded(child: detail),
                    ],
                  )
                : Column(
                    // Stacked on phones: each section scrolls independently so
                    // the inner ListViews always have bounded height.
                    children: [
                      Expanded(flex: 3, child: detail),
                      const Divider(height: 1),
                      Expanded(flex: 2, child: timeline),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatHeader extends StatelessWidget {
  const _StatHeader({required this.session});

  final DebugSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final usage = session.usage;
    final ttft = session.timeToFirstToken;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusDot(status: session.status),
              const SizedBox(width: 8),
              Text(_statusLabel(session.status),
                  style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(session.id,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              _Stat(label: 'Model', value: session.model ?? '—'),
              _Stat(label: 'Duration', value: _fmtDuration(session.duration)),
              if (ttft != null)
                _Stat(label: 'First token', value: _fmtDuration(ttft)),
              _Stat(
                label: 'Tokens (in/out)',
                value: usage == null
                    ? '—'
                    : '${usage.promptTokens} / ${usage.completionTokens}',
              ),
              _Stat(
                label: 'Cost',
                value: usage == null ? '—' : '\$${usage.cost.toStringAsFixed(4)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.session,
    required this.filter,
    required this.onFilter,
  });

  final DebugSession session;
  final DebugCategory? filter;
  final ValueChanged<DebugCategory?> onFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = filter == null
        ? session.events
        : session.events.where((e) => e.category == filter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Text('Event stream',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('${session.events.length} events',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _filterChip(context, 'All', null),
              _filterChip(context, 'Request', DebugCategory.request),
              _filterChip(context, 'Response', DebugCategory.response),
              _filterChip(context, 'System', DebugCategory.system),
              _filterChip(context, 'Error', DebugCategory.error),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: events.isEmpty
              ? Center(
                  child: Text('No events',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: events.length,
                  itemBuilder: (_, i) => _EventTile(event: events[i]),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(BuildContext context, String label, DebugCategory? cat) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: filter == cat,
        onSelected: (_) => onFilter(cat),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final DebugEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (color, icon) = _categoryStyle(event.category, scheme);
    final time = DateFormat('HH:mm:ss.SSS').format(event.time);
    final subtitle = event.subtitle;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 78,
            child: Text(time,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (event.status != null) ...[
            const SizedBox(width: 8),
            Text(event.status!,
                style: theme.textTheme.labelSmall?.copyWith(color: color)),
          ],
        ],
      ),
    );

    if (event.detail == null) return row;
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 10),
        title: row,
        children: [_CodeBlock(text: _pretty(event.detail!), highlightJson: true)],
      ),
    );
  }
}

/// The right-hand detail: assembled response, request body, raw frames.
class _ResponseDetail extends StatelessWidget {
  const _ResponseDetail({required this.session});

  final DebugSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (session.error != null) ...[
          const _SectionTitle('Error'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(session.error!,
                style: TextStyle(color: scheme.onErrorContainer)),
          ),
          const SizedBox(height: 16),
        ],
        const _SectionTitle('Response (assembled)'),
        if (session.hasContent)
          _CodeBlock(text: session.content, mono: false)
        else if (session.responseBody != null)
          _CodeBlock(text: session.prettyResponse!, highlightJson: true)
        else if (session.summary != null)
          Text(session.summary!, style: theme.textTheme.bodyMedium)
        else
          Text(
            session.isLive ? 'Waiting for tokens…' : 'No content',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        if (session.hasReasoning) ...[
          const SizedBox(height: 16),
          const _SectionTitle('Reasoning'),
          _CodeBlock(text: session.reasoning, mono: false),
        ],
        if (session.requestBody != null) ...[
          const SizedBox(height: 16),
          _Collapsible(
            title: 'Request body',
            child: _CodeBlock(text: session.prettyRequest!, highlightJson: true),
          ),
        ],
        if (session.rawFrames.isNotEmpty) ...[
          const SizedBox(height: 8),
          _Collapsible(
            title: 'Raw frames (${session.rawFrames.length})',
            child: _CodeBlock(text: session.rawFrames.join('\n')),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _Collapsible extends StatelessWidget {
  const _Collapsible({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        children: [child],
      ),
    );
  }
}

class _CodeBlock extends ConsumerWidget {
  const _CodeBlock({
    required this.text,
    this.mono = true,
    this.highlightJson = false,
  });

  final String text;
  final bool mono;

  /// When true, render the text as colour-coded JSON (keys, strings, numbers,
  /// literals). Falls back to plain text if it can't be tokenised.
  final bool highlightJson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Mono text (code/JSON/raw frames) uses the user-chosen mono font.
    final monoFamily =
        ref.watch(settingsProvider.select((s) => s.monoFont)).family;
    final baseStyle = TextStyle(
      fontFamily: mono ? monoFamily : null,
      fontSize: 12.5,
      height: 1.4,
      color: scheme.onSurface,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: highlightJson
          ? SelectableText.rich(
              _highlightJson(text, _JsonPalette.of(theme), baseStyle),
            )
          : SelectableText(text, style: baseStyle),
    );
  }
}

/// Colours used to syntax-highlight JSON, tuned per theme brightness.
class _JsonPalette {
  const _JsonPalette({
    required this.key,
    required this.string,
    required this.number,
    required this.literal,
    required this.punctuation,
  });

  final Color key;
  final Color string;
  final Color number;
  final Color literal; // true / false / null
  final Color punctuation;

  factory _JsonPalette.of(ThemeData theme) {
    final muted = theme.colorScheme.onSurfaceVariant;
    if (theme.brightness == Brightness.dark) {
      return _JsonPalette(
        key: const Color(0xFF9CDCFE),
        string: const Color(0xFFCE9178),
        number: const Color(0xFFB5CEA8),
        literal: const Color(0xFF569CD6),
        punctuation: muted,
      );
    }
    return _JsonPalette(
      key: const Color(0xFF0451A5),
      string: const Color(0xFFA31515),
      number: const Color(0xFF098658),
      literal: const Color(0xFF0000FF),
      punctuation: muted,
    );
  }
}

/// Tokenises [source] into coloured spans. Keeps the [base] style (font family,
/// size) and only overrides colour per token, so it works for any mono font.
TextSpan _highlightJson(String source, _JsonPalette palette, TextStyle base) {
  final spans = <TextSpan>[];
  final n = source.length;
  var i = 0;

  bool isDigitStart(String c) => c == '-' || (c.codeUnitAt(0) ^ 0x30) <= 9;

  while (i < n) {
    final c = source[i];
    if (c == '"') {
      // Read a (possibly escaped) string, then decide key vs. value by the
      // next non-space character.
      final start = i++;
      while (i < n) {
        if (source[i] == '\\') {
          i += 2;
          continue;
        }
        if (source[i] == '"') {
          i++;
          break;
        }
        i++;
      }
      var j = i;
      while (j < n && (source[j] == ' ' || source[j] == '\t')) {
        j++;
      }
      final isKey = j < n && source[j] == ':';
      spans.add(TextSpan(
        text: source.substring(start, i),
        style: TextStyle(color: isKey ? palette.key : palette.string),
      ));
    } else if (isDigitStart(c)) {
      final start = i;
      while (i < n && '+-0123456789.eE'.contains(source[i])) {
        i++;
      }
      spans.add(TextSpan(
        text: source.substring(start, i),
        style: TextStyle(color: palette.number),
      ));
    } else if (source.startsWith('true', i) ||
        source.startsWith('false', i) ||
        source.startsWith('null', i)) {
      final lit = source.startsWith('false', i)
          ? 'false'
          : source.startsWith('true', i)
              ? 'true'
              : 'null';
      spans.add(TextSpan(
        text: lit,
        style: TextStyle(color: palette.literal),
      ));
      i += lit.length;
    } else {
      // A run of punctuation / whitespace / structural characters.
      final start = i;
      while (i < n) {
        final cc = source[i];
        if (cc == '"' ||
            isDigitStart(cc) ||
            source.startsWith('true', i) ||
            source.startsWith('false', i) ||
            source.startsWith('null', i)) {
          break;
        }
        i++;
      }
      spans.add(TextSpan(
        text: source.substring(start, i),
        style: TextStyle(color: palette.punctuation),
      ));
    }
  }

  return TextSpan(style: base, children: spans);
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      SessionStatus.pending => scheme.outline,
      SessionStatus.streaming => const Color(0xFF1E88E5),
      SessionStatus.done => const Color(0xFF2E9E5B),
      SessionStatus.error => scheme.error,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _EmptyDebug extends StatelessWidget {
  const _EmptyDebug();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bug_report_outlined,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No sessions yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Send a message or load models. Each API call is captured as a '
              'session showing the model, prompt, timing, tokens and the '
              'assembled response.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ──────────────────────────────────────────────────────────

(Color, IconData) _categoryStyle(DebugCategory cat, ColorScheme scheme) =>
    switch (cat) {
      DebugCategory.request => (scheme.primary, Icons.north_east),
      DebugCategory.response => (const Color(0xFF1E88E5), Icons.south_west),
      DebugCategory.system => (scheme.outline, Icons.info_outline),
      DebugCategory.error => (scheme.error, Icons.error_outline),
    };

String _statusLabel(SessionStatus s) => switch (s) {
      SessionStatus.pending => 'Pending',
      SessionStatus.streaming => 'Streaming',
      SessionStatus.done => 'Completed',
      SessionStatus.error => 'Error',
    };

String _fmtDuration(Duration d) {
  if (d.inMilliseconds < 1000) return '${d.inMilliseconds}ms';
  final s = d.inMilliseconds / 1000;
  return '${s.toStringAsFixed(s >= 10 ? 0 : 1)}s';
}

String _pretty(String s) {
  final t = s.trimLeft();
  if (!t.startsWith('{') && !t.startsWith('[')) return s;
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(s));
  } catch (_) {
    return s;
  }
}

String _sessionAsText(DebugSession s) {
  final fmt = DateFormat('HH:mm:ss.SSS');
  final buffer = StringBuffer()
    ..writeln('Session ${s.id} — ${s.title}')
    ..writeln('Model: ${s.model ?? '—'}')
    ..writeln('Status: ${_statusLabel(s.status)}  Duration: ${_fmtDuration(s.duration)}');
  if (s.usage != null) {
    buffer.writeln(
        'Tokens in/out: ${s.usage!.promptTokens}/${s.usage!.completionTokens}  '
        'Cost: \$${s.usage!.cost.toStringAsFixed(4)}');
  }
  buffer.writeln('\nEvents:');
  for (final e in s.events) {
    buffer.writeln('[${fmt.format(e.time)}] ${e.title}'
        '${e.subtitle.isNotEmpty ? ' — ${e.subtitle}' : ''}');
  }
  if (s.hasContent) buffer.writeln('\nResponse:\n${s.content}');
  return buffer.toString();
}
