import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/models/attachment.dart';
import 'package:wombat/models/chat_message.dart';
import 'package:wombat/providers/settings_provider.dart';
import 'package:wombat/screens/debug_screen.dart';
import 'package:wombat/services/debug_log.dart';
import 'package:wombat/theme/app_theme.dart';
import 'package:wombat/widgets/highlighted_code.dart';
import 'package:wombat/widgets/message_bubble.dart';
import 'package:wombat/widgets/save_button.dart';

import '../helpers/fakes.dart';

late ProviderContainer _container;

// The bubble reads fonts from settings, so provide a configured container.
Widget _wrap(ChatMessage message, {String? modelName}) =>
    UncontrolledProviderScope(
      container: _container,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: MessageBubble(message: message, modelName: modelName),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    _container = await createContainer();
    addTearDown(_container.dispose);
  });

  testWidgets('renders a user message with a YOU badge', (tester) async {
    await tester.pumpWidget(_wrap(
      ChatMessage(id: '1', role: MessageRole.user, content: 'Hello there'),
    ));

    expect(find.text('YOU'), findsOneWidget);
    expect(find.text('Hello there'), findsOneWidget);
  });

  testWidgets('renders an assistant message as Markdown with a copy button',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ChatMessage(id: '1', role: MessageRole.assistant, content: '# Title'),
    ));

    expect(find.text('ASSISTANT'), findsOneWidget);
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('shows a typing indicator while streaming with no content',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ChatMessage(
        id: '1',
        role: MessageRole.assistant,
        content: '',
        isStreaming: true,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // Three chunky block dots make up the typing indicator.
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.text('Copy'), findsNothing);
  });

  testWidgets('hides the copy button for empty assistant content',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ChatMessage(id: '1', role: MessageRole.assistant, content: ''),
    ));
    expect(find.text('Copy'), findsNothing);
  });

  testWidgets('renders inline SVG from an assistant reply', (tester) async {
    await tester.pumpWidget(_wrap(
      ChatMessage(
        id: '1',
        role: MessageRole.assistant,
        content: 'Here is some art:\n\n'
            '```svg\n<svg width="10" height="10"><rect width="10" height="10"/>'
            '</svg>\n```',
      ),
    ));
    await tester.pump();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders an HTML reply as HTML, not dropped Markdown',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ChatMessage(
        id: '1',
        role: MessageRole.assistant,
        content: '<h1>Report</h1><p>Hello <b>world</b></p>'
            '<table><tr><td>cell</td></tr></table>',
      ),
    ));
    await tester.pump();

    // The HTML is rendered (so tables/divs/spans aren't silently dropped)…
    expect(find.byType(Html), findsOneWidget);
    // …and not routed through the Markdown renderer.
    expect(find.byType(MarkdownBody), findsNothing);
  });

  testWidgets('syntax-highlights fenced code blocks in Markdown',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ChatMessage(
        id: '1',
        role: MessageRole.assistant,
        content: 'Here:\n\n```dart\nvoid main() {}\n```',
      ),
    ));
    await tester.pump();

    expect(find.byType(HighlightedCode), findsOneWidget);
  });

  testWidgets('inline code is not turned into a highlighted block',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ChatMessage(
        id: '1',
        role: MessageRole.assistant,
        content: 'call `print()` to log',
      ),
    ));
    await tester.pump();

    expect(find.byType(HighlightedCode), findsNothing);
    expect(find.byType(MarkdownBody), findsOneWidget);
  });

  testWidgets('syntax-highlights <pre> code blocks in HTML replies',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ChatMessage(
        id: '1',
        role: MessageRole.assistant,
        content: '<p>Example:</p>'
            '<pre><code class="language-python">print(1)</code></pre>',
      ),
    ));
    await tester.pump();

    expect(find.byType(Html), findsOneWidget);
    expect(find.byType(HighlightedCode), findsOneWidget);
  });

  testWidgets('renders styled HTML (CSS/script stripped) without crashing',
      (tester) async {
    // Author CSS (<style>, inline style) used to crash csslib and take down the
    // whole reply; it's now stripped before rendering.
    await tester.pumpWidget(_wrap(
      ChatMessage(
        id: '1',
        role: MessageRole.assistant,
        content: '<style>:root{--p:#6366f1}'
            '@keyframes spin{from{transform:rotate(0)}to{transform:rotate(360deg)}}'
            '.card{display:grid;width:calc(100% - 2rem)}</style>'
            '<script>console.log(1)</script>'
            '<div style="color:red;transform:translateY(-50%)">'
            '<h1>Title</h1><p>Body</p></div>',
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(Html), findsOneWidget);
  });

  testWidgets('renders an HTML reply with a code block without error',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ChatMessage(
        id: '1',
        role: MessageRole.assistant,
        content: '<p>Example:</p><pre><code>&lt;div&gt;hi&lt;/div&gt;</code></pre>',
      ),
    ));
    await tester.pump();

    expect(find.byType(Html), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HTML shown inside a code fence is not auto-rendered',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ChatMessage(
        id: '1',
        role: MessageRole.assistant,
        content: 'Here is some markup:\n\n```html\n<div>hi</div>\n```',
      ),
    ));
    await tester.pump();

    expect(find.byType(Html), findsNothing);
    expect(find.byType(MarkdownBody), findsOneWidget);
  });

  testWidgets('the Source toggle reveals the raw reply verbatim',
      (tester) async {
    const raw = '<h1>Title</h1><p>Body</p>';
    await tester.pumpWidget(_wrap(
      ChatMessage(id: '1', role: MessageRole.assistant, content: raw),
    ));
    await tester.pump();

    // Rendered by default.
    expect(find.byType(Html), findsOneWidget);
    expect(find.text(raw), findsNothing);

    // Switch to Source: the complete raw text is shown verbatim.
    await tester.tap(find.text('Source'));
    await tester.pump();
    expect(find.text(raw), findsOneWidget);
    expect(find.byType(Html), findsNothing);

    // And back to Rendered.
    await tester.tap(find.text('Rendered'));
    await tester.pump();
    expect(find.byType(Html), findsOneWidget);
    expect(find.text(raw), findsNothing);
  });

  testWidgets('shows a Debug action that opens the recorded session',
      (tester) async {
    final debug = _container.read(debugLogProvider.notifier)..enabled = true;
    final session = debug.begin(title: 'hello', model: 'm', requestBody: '{}')!;

    final msg = ChatMessage(id: '1', role: MessageRole.assistant, content: 'hi')
      ..debugSessionId = session.id;
    await tester.pumpWidget(_wrap(msg));
    await tester.pump();

    expect(find.text('Debug'), findsOneWidget);
    await tester.tap(find.text('Debug'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionDetailScreen), findsOneWidget);
  });

  testWidgets('no Debug action when the reply has no recorded session',
      (tester) async {
    // A reply with no debugSessionId (capture was off / cleared / restarted).
    await tester.pumpWidget(_wrap(
      ChatMessage(id: '1', role: MessageRole.assistant, content: 'hi'),
    ));
    await tester.pump();
    expect(find.text('Debug'), findsNothing);
  });

  testWidgets('saves the full reply as Markdown, even for SVG content',
      (tester) async {
    const reply = 'Here is some art:\n\n'
        '```svg\n<svg width="10" height="10"><rect width="10" height="10"/>'
        '</svg>\n```';
    await tester.pumpWidget(_wrap(
      ChatMessage(id: '1', role: MessageRole.assistant, content: reply),
    ));
    await tester.pump();

    final save = tester.widget<SaveButton>(find.byType(SaveButton));
    // Don't guess the type (#126): always Markdown with the full content.
    expect(save.mimeType, 'text/markdown');
    expect(utf8.decode(save.bytes()), reply);
  });

  testWidgets('applies the user font scale to user message text',
      (tester) async {
    await _container.read(settingsProvider.notifier).setUserFontScale(1.3);

    await tester.pumpWidget(_wrap(
      ChatMessage(id: '1', role: MessageRole.user, content: 'Scaled hi'),
    ));

    final textWidget = tester.widget<Text>(find.text('Scaled hi'));
    final scaler = textWidget.textScaler ??
        MediaQuery.of(tester.element(find.text('Scaled hi'))).textScaler;
    expect(scaler.scale(10), closeTo(13, 0.01));
  });

  testWidgets('renders a blockquote without a layout error', (tester) async {
    await tester.pumpWidget(_wrap(
      ChatMessage(
        id: '1',
        role: MessageRole.assistant,
        content: '> Prompt: a beautiful pelican riding a bicycle',
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(MarkdownBody), findsOneWidget);
  });

  testWidgets('uses the configured user name on the user badge',
      (tester) async {
    await _container.read(settingsProvider.notifier).setUserName('Ravi');

    await tester.pumpWidget(_wrap(
      ChatMessage(id: '1', role: MessageRole.user, content: 'hi'),
    ));

    expect(find.text('RAVI'), findsOneWidget); // StatusChip uppercases
    expect(find.text('YOU'), findsNothing);
  });

  testWidgets('falls back to the model name for AI replies', (tester) async {
    await tester.pumpWidget(_wrap(
      ChatMessage(id: '1', role: MessageRole.assistant, content: 'hello'),
      modelName: 'openai/gpt-4o-mini',
    ));

    expect(find.text('GPT-4O-MINI'), findsOneWidget);
    expect(find.text('ASSISTANT'), findsNothing);
  });

  testWidgets('uses the configured AI name over the model name', (tester) async {
    await _container.read(settingsProvider.notifier).setAiName('Jarvis');

    await tester.pumpWidget(_wrap(
      ChatMessage(id: '1', role: MessageRole.assistant, content: 'hello'),
      modelName: 'openai/gpt-4o-mini',
    ));

    expect(find.text('JARVIS'), findsOneWidget);
    expect(find.text('GPT-4O-MINI'), findsNothing);
  });

  testWidgets('user badge sits after the timestamp (at the trailing edge)',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ChatMessage(id: '1', role: MessageRole.user, content: 'hi'),
    ));

    final nameDx = tester.getTopLeft(find.text('YOU')).dx;
    final timeDx = tester.getTopLeft(find.textContaining('·')).dx;
    expect(nameDx, greaterThan(timeDx),
        reason: 'the user name should follow the time, at the trailing edge');
  });

  testWidgets('renders an image attachment inline', (tester) async {
    // 1x1 transparent PNG.
    const pngBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    await tester.pumpWidget(_wrap(
      ChatMessage(
        id: '1',
        role: MessageRole.assistant,
        content: 'here is an image',
        attachments: [
          MessageAttachment.fromDataUrl(
            'data:image/png;base64,$pngBase64',
            kind: AttachmentKind.image,
          ),
        ],
      ),
    ));

    expect(find.text('here is an image'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('renders attachments on user messages too', (tester) async {
    // Regression: user-sent images must render (not just assistant replies).
    const pngBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
        '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    await tester.pumpWidget(_wrap(
      ChatMessage(
        id: '1',
        role: MessageRole.user,
        content: 'look at this',
        attachments: [
          MessageAttachment.fromDataUrl(
            'data:image/png;base64,$pngBase64',
            kind: AttachmentKind.image,
          ),
        ],
      ),
    ));

    expect(find.text('look at this'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

}
