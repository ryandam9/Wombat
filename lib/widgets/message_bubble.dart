import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/app_font.dart';
import '../models/chat_message.dart';
import '../providers/settings_provider.dart';
import '../services/download_service.dart';
import 'attachment_view.dart';
import 'save_button.dart';
import 'ui_kit.dart';

/// Renders a single chat message in a rounded bubble. Assistant replies are
/// rendered as Markdown; user messages as plain selectable text.
class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.modelName,
    this.preferModelName = false,
  });

  final ChatMessage message;

  /// The model behind this message, used as the AI label fallback (and, when
  /// [preferModelName] is set, always). Typically the conversation's model id.
  final String? modelName;

  /// When true, AI replies are always labelled with [modelName] rather than the
  /// user's custom AI name — used by the compare screen to keep models distinct.
  final bool preferModelName;

  bool get _isUser => message.role == MessageRole.user;

  /// Label for the user's own messages: their configured name, else "You".
  String _userLabel(SettingsState s) {
    final name = s.userName.trim();
    return name.isNotEmpty ? name : 'You';
  }

  /// Label for AI replies: the configured AI name, else the model name, else
  /// "Assistant". [preferModelName] forces the model name.
  String _aiLabel(SettingsState s) {
    final custom = s.aiName.trim();
    if (!preferModelName && custom.isNotEmpty) return custom;
    final model = _shortModelName(modelName);
    if (model != null) return model;
    return custom.isNotEmpty ? custom : 'Assistant';
  }

  /// The trailing segment of a model id (e.g. `openai/gpt-4o-mini` → `gpt-4o-mini`).
  static String? _shortModelName(String? id) {
    final t = id?.trim() ?? '';
    if (t.isEmpty) return null;
    final slash = t.lastIndexOf('/');
    return (slash >= 0 && slash < t.length - 1) ? t.substring(slash + 1) : t;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final align = _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    // Gentle one-shot entrance (fade + slide-up) as each message appears.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
      ),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Builder(builder: (context) {
            final chip = StatusChip(
              _isUser ? _userLabel(settings) : _aiLabel(settings),
              color: _isUser
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.primary,
            );
            final time = Text(
              DateFormat('MMM d · HH:mm').format(message.createdAt),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            );
            // The name chip sits on the bubble's alignment edge: at the end
            // (after the time) for the right-aligned user, at the start for the
            // left-aligned assistant.
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: _isUser
                  ? [time, const SizedBox(width: 8), chip]
                  : [chip, const SizedBox(width: 8), time],
            );
          }),
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
              child: _content(context, settings),
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
                    baseName: 'wombat-reply',
                    mimeType: save.mimeType,
                  ),
                ],
              );
            }),
        ],
      ),
      ),
    );
  }

  Widget _content(BuildContext context, SettingsState settings) {
    if (message.isStreaming &&
        message.content.isEmpty &&
        message.attachments.isEmpty) {
      return const _TypingIndicator();
    }

    final children = <Widget>[];
    if (message.content.isNotEmpty) {
      children.addAll(_textParts(context, settings));
    }
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

  /// The textual content of a message. For assistant replies that contain an
  /// SVG, the SVG is rendered inline and its code stripped from the Markdown.
  List<Widget> _textParts(BuildContext context, SettingsState settings) {
    final theme = Theme.of(context);

    if (_isUser) {
      return [
        MediaQuery.withClampedTextScaling(
          minScaleFactor: settings.userFontScale,
          maxScaleFactor: settings.userFontScale,
          child: Text(
            message.content,
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontFamily: settings.userFont.family,
            ),
          ),
        ),
      ];
    }

    final extracted = DownloadService.textForSave(message.content);
    if (extracted.mimeType == 'image/svg+xml') {
      final markdown = _stripSvg(message.content, extracted.text).trim();
      return [
        _SvgView(svg: extracted.text),
        if (markdown.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _markdown(context, settings, markdown),
          ),
      ];
    }
    return [_markdown(context, settings, message.content)];
  }

  /// Removes fenced code blocks (and any bare occurrence) that contain the SVG,
  /// leaving only the surrounding prose for the Markdown body.
  String _stripSvg(String content, String svg) {
    final fenced = RegExp(r'```[a-zA-Z0-9]*\r?\n[\s\S]*?\r?\n```');
    var out = content.replaceAllMapped(
      fenced,
      (m) => m[0]!.contains('<svg') ? '' : m[0]!,
    );
    return out.replaceAll(svg, '');
  }

  Widget _markdown(BuildContext context, SettingsState settings, String data) {
    final theme = Theme.of(context);
    // Apply the model-output font to the whole Markdown stylesheet.
    final scheme = theme.colorScheme;
    final mdTheme = theme.copyWith(
      textTheme: theme.textTheme.apply(
        fontFamily: settings.modelFont.family,
        // Force readable body text against the bubble's surface background.
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
    );
    final base = MarkdownStyleSheet.fromTheme(mdTheme);
    // Code uses a clearly distinct, bordered background with on-surface text so
    // it stays readable in both light and dark themes.
    final codeBg = scheme.surfaceContainerLowest;
    // selectable:false — selection is handled by the ancestor SelectionArea,
    // and mixing the two breaks copy of Markdown content.
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: settings.modelFontScale,
      maxScaleFactor: settings.modelFontScale,
      child: MarkdownBody(
        data: data,
        selectable: false,
        imageBuilder: _markdownImage,
        styleSheet: base.copyWith(
        p: base.p?.copyWith(color: scheme.onSurface),
        code: base.code?.copyWith(
          fontFamily: 'monospace',
          color: scheme.onSurface,
          backgroundColor: codeBg,
        ),
        codeblockDecoration: BoxDecoration(
          color: codeBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        // Blockquotes otherwise default to a light-blue box, which leaves
        // light text unreadable in dark theme. Use the same on-surface scheme
        // as code, with a primary accent strip on the left.
        blockquote: base.blockquote?.copyWith(color: scheme.onSurface),
        blockquoteDecoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          border: Border(
            left: BorderSide(color: scheme.primary, width: 4),
          ),
        ),
        ),
      ),
    );
  }

  /// Renders Markdown image links inline, supporting `data:` URIs (base64),
  /// `http(s)` URLs, and inline SVG data URIs.
  Widget _markdownImage(Uri uri, String? title, String? alt) {
    Widget broken() => const _BrokenImage();
    const maxW = BoxConstraints(maxWidth: 320);
    if (uri.scheme == 'data') {
      try {
        final data = UriData.fromUri(uri);
        final bytes = data.contentAsBytes();
        if (data.mimeType.contains('svg')) {
          return ConstrainedBox(
            constraints: maxW,
            child: SvgPicture.memory(bytes, placeholderBuilder: (_) => broken()),
          );
        }
        return ConstrainedBox(
          constraints: maxW,
          child: Image.memory(bytes, errorBuilder: (_, __, ___) => broken()),
        );
      } catch (_) {
        return broken();
      }
    }
    return ConstrainedBox(
      constraints: maxW,
      child: Image.network(uri.toString(), errorBuilder: (_, __, ___) => broken()),
    );
  }
}

/// Renders an inline SVG string as an image, tappable to view full-size.
class _SvgView extends StatelessWidget {
  const _SvgView({required this.svg});

  final String svg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget image(double? width, BoxFit fit) => SvgPicture.string(
          svg,
          width: width,
          fit: fit,
          placeholderBuilder: (_) => const _BrokenImage(),
        );

    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: InteractiveViewer(child: image(null, BoxFit.contain)),
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: image(320, BoxFit.contain),
      ),
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 18),
          SizedBox(width: 6),
          Text('Could not display image'),
        ],
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
