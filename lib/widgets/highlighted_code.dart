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
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: HighlightView(
          code.trimRight(),
          language: _resolveLanguage(),
          theme: dark ? atomOneDarkTheme : atomOneLightTheme,
          padding: const EdgeInsets.all(12),
          textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
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
