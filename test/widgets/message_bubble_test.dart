import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route/models/attachment.dart';
import 'package:route/models/chat_message.dart';
import 'package:route/providers/settings_provider.dart';
import 'package:route/theme/app_theme.dart';
import 'package:route/widgets/message_bubble.dart';

import '../helpers/fakes.dart';

late ProviderContainer _container;

// The bubble reads fonts from settings, so provide a configured container.
Widget _wrap(ChatMessage message) => UncontrolledProviderScope(
      container: _container,
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: MessageBubble(message: message)),
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

    expect(find.byType(CircleAvatar), findsNWidgets(3));
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
}
