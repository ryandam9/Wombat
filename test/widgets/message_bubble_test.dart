import 'package:auris/auris.dart';
import 'package:auris/auris_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route/models/attachment.dart';
import 'package:route/models/chat_message.dart';
import 'package:route/widgets/message_bubble.dart';

// Auris HUD widgets read their scheme from the AurisTheme extension, so the
// bubble must be hosted under an AurisTheme-skinned MaterialApp.
Widget _wrap(ChatMessage message) => MaterialApp(
      theme: AurisTheme.dark(),
      home: Scaffold(body: MessageBubble(message: message)),
    );

void main() {
  testWidgets('renders a user message with a YOU badge in a container',
      (tester) async {
    await tester.pumpWidget(_wrap(
      ChatMessage(id: '1', role: MessageRole.user, content: 'Hello there'),
    ));

    expect(find.text('YOU'), findsOneWidget);
    expect(find.text('Hello there'), findsOneWidget);
    // The bubble (and the badge) are chamfered Auris containers.
    expect(find.byType(AurisContainer), findsWidgets);
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
