import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:highlight/highlight.dart' show highlight;

/// A syntax-highlighted code block: the code coloured by language on an
/// editor-style background, in a bordered, horizontally scrollable box.
///
/// Long blocks are **collapsible** — they start hidden behind a "Show code"
/// header (with the language and line count) so a lengthy listing doesn't
/// dominate the chat; short blocks render directly. Used for fenced code in
/// Markdown replies and `<pre>` blocks in HTML replies. When no [language] is
/// given (or it's unknown) the language is auto-detected; an unrecognised
/// language falls back to plain (un-highlighted) text.
class HighlightedCode extends StatefulWidget {
  const HighlightedCode({
    super.key,
    required this.code,
    this.language,
    required this.fontFamily,
    this.fontSize = 14.5,
  });

  final String code;
  final String? language;

  /// A real monospace family (e.g. the configured `monoFont`). The literal
  /// `'monospace'` alias only resolves on Android, so it must be passed in.
  final String fontFamily;
  final double fontSize;

  /// Blocks longer than this (in lines) start collapsed.
  static const int collapseThreshold = 16;

  @override
  State<HighlightedCode> createState() => _HighlightedCodeState();
}

class _HighlightedCodeState extends State<HighlightedCode> {
  late final int _lineCount = widget.code.trimRight().split('\n').length;
  late bool _expanded = _lineCount <= HighlightedCode.collapseThreshold;

  bool get _collapsible => _lineCount > HighlightedCode.collapseThreshold;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final baseTheme = dark ? atomOneDarkTheme : atomOneLightTheme;

    // Paint the editor background on the box itself (not on the tightly-sized
    // HighlightView) so it fills the full width — a clean code block instead of
    // a ragged background that only sits behind the text.
    final background = baseTheme['root']?.backgroundColor ??
        (dark ? const Color(0xFF282C34) : const Color(0xFFF6F8FA));
    final theme = Map<String, TextStyle>.from(baseTheme);
    theme['root'] = (baseTheme['root'] ?? const TextStyle())
        .copyWith(backgroundColor: Colors.transparent);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outline, width: 2),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow,
            offset: const Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_collapsible) _header(scheme),
          if (_expanded)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                widget.code.trimRight(),
                language: _resolveLanguage(),
                theme: theme,
                padding: const EdgeInsets.all(12),
                textStyle: TextStyle(
                  fontFamily: widget.fontFamily,
                  fontSize: widget.fontSize,
                  height: 1.45,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A toggle bar (language · line count · Show/Hide) for collapsible blocks.
  Widget _header(ColorScheme scheme) {
    final lang = (widget.language?.trim().isNotEmpty ?? false)
        ? widget.language!.trim().toLowerCase()
        : 'code';
    return Material(
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
              const SizedBox(width: 6),
              Text(
                _expanded ? 'Hide code' : 'Show code',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const Spacer(),
              Text(
                '$lang · $_lineCount lines',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A non-null language for [HighlightView] (it throws on null; an unknown name
  /// is treated as plain text). Falls back to auto-detection when unspecified.
  String _resolveLanguage() {
    final hint = widget.language?.trim().toLowerCase();
    if (hint != null && hint.isNotEmpty) return hint;
    try {
      final detected = highlight.parse(widget.code, autoDetection: true).language;
      return (detected == null || detected.isEmpty) ? 'plaintext' : detected;
    } catch (_) {
      return 'plaintext';
    }
  }
}
