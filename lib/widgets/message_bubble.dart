import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;

import '../models/app_font.dart';
import '../models/chat_message.dart';
import '../providers/settings_provider.dart';
import '../screens/debug_screen.dart';
import '../services/debug_log.dart';
import '../services/download_service.dart';
import 'attachment_view.dart';
import 'highlighted_code.dart';
import 'save_button.dart';
import 'ui_kit.dart';

/// Renders a single chat message in a rounded bubble. Assistant replies are
/// rendered as Markdown (or HTML, when the reply is HTML); user messages as
/// plain selectable text. Assistant replies can be toggled to a raw "Source"
/// view so the complete response is always visible.
class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.modelName,
    this.preferModelName = false,
    this.animate = true,
    this.onAttachmentLoaded,
  });

  final ChatMessage message;

  /// Whether to play the one-shot entrance animation. The list sets this to
  /// false for pre-existing messages so they don't replay on rebuild/scroll.
  final bool animate;

  /// Called when an image attachment finishes decoding (and so changes the
  /// bubble's height). Lets the message list re-anchor to the bottom, so the
  /// last reply's image isn't left clipped below the fold. See #138.
  final VoidCallback? onAttachmentLoaded;

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

    final content = Padding(
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
          if (_isUser)
            _UserBubble(
              message: message,
              settings: settings,
              onAttachmentLoaded: onAttachmentLoaded,
            )
          else
            _AssistantBubble(
              message: message,
              onAttachmentLoaded: onAttachmentLoaded,
            ),
        ],
      ),
    );

    if (!animate) return content;
    // Gentle one-shot entrance (fade + slide-up) as each message appears.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: child),
      ),
      child: content,
    );
  }

}

/// A user message: their text in the configured font plus any attachments
/// (images they sent, recorded audio, documents).
class _UserBubble extends StatelessWidget {
  const _UserBubble({
    required this.message,
    required this.settings,
    this.onAttachmentLoaded,
  });

  final ChatMessage message;
  final SettingsState settings;
  final VoidCallback? onAttachmentLoaded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final children = <Widget>[
      if (message.content.isNotEmpty)
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
      for (final attachment in message.attachments)
        Padding(
          padding: EdgeInsets.only(top: message.content.isEmpty ? 0 : 8),
          child: AttachmentView(
            attachment: attachment,
            onImageLoaded: onAttachmentLoaded,
          ),
        ),
    ];

    final body = children.length == 1
        ? children.first
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.primary),
        ),
        child: body,
      ),
    );
  }
}

/// An assistant reply: the rendered (Markdown / HTML / inline SVG) body plus an
/// action row (Copy, Save, and a Rendered ⇄ Source toggle). The Source view
/// shows the raw response verbatim, so nothing the renderer can't display is
/// ever lost. See #128.
class _AssistantBubble extends ConsumerStatefulWidget {
  const _AssistantBubble({required this.message, this.onAttachmentLoaded});

  final ChatMessage message;
  final VoidCallback? onAttachmentLoaded;

  @override
  ConsumerState<_AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends ConsumerState<_AssistantBubble> {
  bool _showSource = false;

  ChatMessage get message => widget.message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final canToggle = message.content.isNotEmpty && !message.isStreaming;
    // The debug session that produced this reply, when debug capture was on and
    // it is still recorded. Lets the user inspect this exact interaction. #129.
    final debugSession = message.debugSessionId == null
        ? null
        : ref.watch(debugLogProvider).sessionById(message.debugSessionId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: _body(context, settings),
        ),
        if (canToggle)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CopyButton(text: message.content),
              // Save the reply verbatim as Markdown — don't guess the output
              // type (it isn't always an SVG). See #126.
              SaveButton(
                compact: true,
                bytes: () => utf8.encode(message.content),
                baseName: 'wombat-reply',
                mimeType: 'text/markdown',
              ),
              _SourceToggle(
                showSource: _showSource,
                onChanged: (v) => setState(() => _showSource = v),
              ),
              if (debugSession != null) _DebugButton(session: debugSession),
            ],
          ),
      ],
    );
  }

  Widget _body(BuildContext context, SettingsState settings) {
    if (message.isStreaming &&
        message.content.isEmpty &&
        message.attachments.isEmpty) {
      return const _TypingIndicator();
    }

    final children = <Widget>[];
    if (message.content.isNotEmpty) {
      children.add(_showSource
          ? _SourceText(text: message.content, settings: settings)
          : _rendered(context, settings));
    }
    for (final attachment in message.attachments) {
      children.add(Padding(
        padding: EdgeInsets.only(top: children.isEmpty ? 0 : 8),
        child: AttachmentView(
          attachment: attachment,
          onImageLoaded: widget.onAttachmentLoaded,
        ),
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

  /// The rendered view of the reply. HTML replies render as HTML; a reply that
  /// is purely (or mostly) an SVG renders the image inline; everything else
  /// renders as Markdown.
  Widget _rendered(BuildContext context, SettingsState settings) {
    final content = message.content;

    if (_looksLikeHtml(content)) {
      return _HtmlView(html: content, settings: settings);
    }

    final extracted = DownloadService.textForSave(content);
    if (extracted.mimeType == 'image/svg+xml') {
      final markdown = _stripSvg(content, extracted.text).trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _SvgView(svg: extracted.text),
          if (markdown.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _markdown(context, settings, markdown),
            ),
        ],
      );
    }
    return _markdown(context, settings, content);
  }

  /// HTML-ish block/inline tags the Markdown renderer would otherwise drop.
  /// SVG tags are deliberately excluded so SVG art still routes to [_SvgView].
  static final _htmlTag = RegExp(
    r'<\s*/?\s*(?:!doctype|html|head|body|table|thead|tbody|tfoot|tr|td|th|'
    r'div|p|ul|ol|li|dl|dt|dd|h[1-6]|section|article|header|footer|nav|main|'
    r'aside|figure|figcaption|pre|blockquote|span|a|img|br|hr|strong|em|b|i|'
    r'u|code|button|form|input|label|select|option|caption|colgroup|col)\b',
    caseSensitive: false,
  );

  /// Whether the reply should be rendered as HTML. Fenced/inline code is ignored
  /// so HTML shown *as a code sample* isn't auto-rendered.
  bool _looksLikeHtml(String content) {
    final stripped = content
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'`[^`]*`'), '');
    return _htmlTag.hasMatch(stripped);
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
        // Fenced code blocks render with syntax highlighting (HighlightedCode
        // draws its own bordered box, so the default codeblock decoration is
        // cleared to avoid a double border). Inline `code` keeps its styling.
        builders: {'pre': _CodeBlockBuilder()},
        styleSheet: base.copyWith(
          p: base.p?.copyWith(color: scheme.onSurface),
          code: base.code?.copyWith(
            fontFamily: 'monospace',
            color: scheme.onSurface,
            backgroundColor: codeBg,
          ),
          codeblockPadding: EdgeInsets.zero,
          codeblockDecoration: const BoxDecoration(),
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

/// A fenced Markdown code block, syntax-highlighted via [HighlightedCode]. The
/// `<pre>` element wraps a `<code class="language-xxx">` for fenced blocks; the
/// language (when present) drives the highlighting.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  _CodeBlockBuilder();

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    String? language;
    final children = element.children;
    if (children != null) {
      for (final node in children) {
        if (node is md.Element && node.tag == 'code') {
          final cls = node.attributes['class'];
          if (cls != null && cls.startsWith('language-')) {
            language = cls.substring('language-'.length);
          }
        }
      }
    }
    return HighlightedCode(code: element.textContent, language: language);
  }
}

/// Renders an assistant reply that is HTML, so tables/divs/spans show up
/// instead of being dropped by the Markdown renderer.
class _HtmlView extends StatelessWidget {
  const _HtmlView({required this.html, required this.settings});

  final String html;
  final SettingsState settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: settings.modelFontScale,
      maxScaleFactor: settings.modelFontScale,
      child: Html(
        data: html,
        // <pre> code blocks render with syntax highlighting; inline <code>
        // keeps a monospace style (the body font would otherwise cascade in).
        extensions: [
          TagExtension(
            tagsToExtend: const {'pre'},
            builder: (ec) {
              final el = ec.element;
              final codeEl = el?.querySelector('code');
              final cls = codeEl?.className ?? '';
              final langClass = cls.split(RegExp(r'\s+')).firstWhere(
                    (c) => c.startsWith('language-'),
                    orElse: () => '',
                  );
              return HighlightedCode(
                code: (codeEl ?? el)?.text ?? '',
                language: langClass.isEmpty
                    ? null
                    : langClass.substring('language-'.length),
              );
            },
          ),
        ],
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            color: scheme.onSurface,
            fontFamily: settings.modelFont.family,
          ),
          'a': Style(color: scheme.primary),
          // Inline code keeps a monospace font on a distinct background.
          'code': Style(
            fontFamily: 'monospace',
            backgroundColor: scheme.surfaceContainerLowest,
          ),
        },
      ),
    );
  }
}

/// The raw response text, shown verbatim in a monospace font.
class _SourceText extends StatelessWidget {
  const _SourceText({required this.text, required this.settings});

  final String text;
  final SettingsState settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // selectable:false — selection is handled by the ancestor SelectionArea.
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: settings.modelFontScale,
      maxScaleFactor: settings.modelFontScale,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          color: scheme.onSurface,
          height: 1.4,
        ),
      ),
    );
  }
}

/// A small toggle that flips an assistant reply between its rendered view and
/// the raw "Source" text.
class _SourceToggle extends StatelessWidget {
  const _SourceToggle({required this.showSource, required this.onChanged});

  final bool showSource;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(showSource ? Icons.visibility_outlined : Icons.code, size: 14),
      label: Text(showSource ? 'Rendered' : 'Source'),
      onPressed: () => onChanged(!showSource),
    );
  }
}

/// Opens the full debug detail for the exchange that produced this reply —
/// model, request, streamed response, tokens, cost, timing and any errors.
class _DebugButton extends StatelessWidget {
  const _DebugButton({required this.session});

  final DebugSession session;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.bug_report_outlined, size: 14),
      label: const Text('Debug'),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SessionDetailScreen(session: session),
        ),
      ),
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
