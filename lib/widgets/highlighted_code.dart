import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:highlight/highlight.dart' show highlight;

/// A syntax-highlighted code block: the code coloured by language on an
/// editor-style background, in a bordered, horizontally scrollable box.
///
/// Used for fenced code in Markdown replies and `<pre>` blocks in HTML replies.
/// When no [language] is given (or it's unknown) the language is auto-detected;
/// an unrecognised language falls back to plain (un-highlighted) text.
class HighlightedCode extends StatelessWidget {
  const HighlightedCode({super.key, required this.code, this.language});

  final String code;
  final String? language;

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
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: HighlightView(
          code.trimRight(),
          language: _resolveLanguage(),
          theme: theme,
          padding: const EdgeInsets.all(12),
          textStyle: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  /// A non-null language for [HighlightView] (it throws on null; an unknown name
  /// is treated as plain text). Falls back to auto-detection when unspecified.
  String _resolveLanguage() {
    final hint = language?.trim().toLowerCase();
    if (hint != null && hint.isNotEmpty) return hint;
    try {
      final detected = highlight.parse(code, autoDetection: true).language;
      return (detected == null || detected.isEmpty) ? 'plaintext' : detected;
    } catch (_) {
      return 'plaintext';
    }
  }
}
