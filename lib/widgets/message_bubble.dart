import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_font.dart';
import '../models/chat_message.dart';
import '../providers/settings_provider.dart';
import '../services/download_service.dart';
import 'attachment_view.dart';
import 'save_button.dart';
import 'ui_kit.dart';

/// Renders a single chat message in a rounded bubble. Assistant replies are
/// rendered as Markdown; user messages as plain selectable text.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align = _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusChip(
                _isUser ? 'YOU' : 'ASSISTANT',
                color: _isUser
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('MMM d · HH:mm').format(message.createdAt),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _isUser ? 560 : double.infinity,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _isUser
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isUser
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              child: _content(context),
            ),
          ),
          if (!_isUser && !message.isStreaming && message.content.isNotEmpty)
            Builder(builder: (context) {
              // SVG replies save as a clean .svg (fences stripped), not .xml/.md.
              final save = DownloadService.textForSave(message.content);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CopyButton(text: message.content),
                  SaveButton(
                    compact: true,
                    bytes: () => utf8.encode(save.text),
                    baseName: 'route-reply',
                    mimeType: save.mimeType,
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (message.isStreaming &&
        message.content.isEmpty &&
        message.attachments.isEmpty) {
      return const _TypingIndicator();
    }

    final children = <Widget>[];
    if (message.content.isNotEmpty) children.add(_text(context));
    for (final attachment in message.attachments) {
      children.add(Padding(
        padding: EdgeInsets.only(top: children.isEmpty ? 0 : 8),
        child: AttachmentView(attachment: attachment),
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) return children.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _text(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    if (_isUser) {
      // Plain Text; the surrounding SelectionArea makes it selectable.
      return Text(
        message.content,
        style: TextStyle(
          color: theme.colorScheme.onPrimaryContainer,
          fontFamily: settings.userFont.family,
        ),
      );
    }
    // Apply the model-output font to the whole Markdown stylesheet.
    final mdTheme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: settings.modelFont.family),
    );
    // selectable:false — selection is handled by the ancestor SelectionArea,
    // and mixing the two breaks copy of Markdown content.
    return MarkdownBody(
      data: message.content,
      selectable: false,
      styleSheet: MarkdownStyleSheet.fromTheme(mdTheme).copyWith(
        code: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: theme.colorScheme.surface,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.copy, size: 14),
        label: const Text('Copy'),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied to clipboard'),
              duration: Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (_controller.value - i * 0.2) % 1.0;
              final opacity = 0.3 + 0.7 * (1 - (t - 0.5).abs() * 2).clamp(0, 1);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Opacity(
                  opacity: opacity.toDouble(),
                  child: CircleAvatar(radius: 3, backgroundColor: color),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
