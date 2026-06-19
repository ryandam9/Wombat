import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:route/models/attachment.dart';
import 'package:route/models/chat_message.dart';
import 'package:route/models/usage.dart';
import 'package:route/services/debug_log.dart';
import 'package:route/services/openrouter_service.dart';

void main() {
  group('OpenRouterService.fetchModels', () {
    test('parses and sorts models by display name', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, endsWith('/models'));
        expect(request.headers['Authorization'], 'Bearer key');
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 'z/zeta', 'name': 'Zeta'},
              {'id': 'a/alpha', 'name': 'Alpha'},
            ]
          }),
          200,
        );
      });

      final models = await OpenRouterService(client: client).fetchModels('key');

      expect(models.map((m) => m.name), ['Alpha', 'Zeta']);
    });

    test('throws OpenRouterException with API message on non-200', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {'message': 'Invalid API key'}
          }),
          401,
        );
      });

      expect(
        () => OpenRouterService(client: client).fetchModels('bad'),
        throwsA(
          isA<OpenRouterException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'Invalid API key'),
        ),
      );
    });

    test('wraps network errors', () async {
      final client = MockClient((request) async {
        throw const SocketExceptionLike();
      });

      expect(
        () => OpenRouterService(client: client).fetchModels('key'),
        throwsA(isA<OpenRouterException>()
            .having((e) => e.message, 'message', contains('Network error'))),
      );
    });
  });

  group('OpenRouterService.streamChat', () {
    http.StreamedResponse sse(List<String> lines, {int status = 200}) {
      final body = lines.map((l) => utf8.encode('$l\n'));
      return http.StreamedResponse(Stream.fromIterable(body), status);
    }

    test('yields content deltas and stops at [DONE]', () async {
      final client = MockClient.streaming((request, bodyStream) async {
        final body = await bodyStream.bytesToString();
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        expect(decoded['stream'], true);
        expect(decoded['model'], 'test/model');
        return sse([
          'data: {"choices":[{"delta":{"content":"Hel"}}]}',
          ': OPENROUTER PROCESSING',
          '',
          'data: {"choices":[{"delta":{"content":"lo"}}]}',
          'data: [DONE]',
          'data: {"choices":[{"delta":{"content":"ignored"}}]}',
        ]);
      });

      final chunks = await OpenRouterService(client: client)
          .streamChat(
            apiKey: 'key',
            model: 'test/model',
            messages: [
              ChatMessage(id: '1', role: MessageRole.user, content: 'hi'),
            ],
          )
          .toList();

      expect(chunks, ['Hel', 'lo']);
    });

    test('records a session with assembled content in the debug log',
        () async {
      final client = MockClient.streaming((request, bodyStream) async {
        return sse([
          'data: {"choices":[{"delta":{"content":"Hel"}}]}',
          ': OPENROUTER PROCESSING',
          'data: {"choices":[{"delta":{"content":"lo"},"finish_reason":"stop"}]}',
          'data: {"usage":{"prompt_tokens":2,"completion_tokens":3,"cost":0.01}}',
          'data: [DONE]',
        ]);
      });
      final debug = DebugLog();

      await OpenRouterService(client: client, debug: debug).streamChat(
        apiKey: 'k',
        model: 'm',
        messages: [
          ChatMessage(id: '1', role: MessageRole.user, content: 'say hi'),
        ],
      ).toList();

      expect(debug.length, 1);
      final s = debug.sessions.single;
      expect(s.title, 'say hi'); // links the prompt to the session
      expect(s.model, 'm');
      expect(s.content, 'Hello'); // assembled, not fragmented
      expect(s.status, SessionStatus.done);
      expect(s.usage!.totalTokens, 5);
      expect(s.requestBody, isNotNull);
    });

    test('records an error session on non-200', () async {
      final client = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"error":{"message":"nope"}}')),
          400,
        );
      });
      final debug = DebugLog();

      await expectLater(
        OpenRouterService(client: client, debug: debug)
            .streamChat(apiKey: 'k', model: 'm', messages: []).toList(),
        throwsA(isA<OpenRouterException>()),
      );
      final s = debug.sessions.single;
      expect(s.status, SessionStatus.error);
      expect(s.httpStatus, 400);
    });

    test('skips malformed frames without aborting', () async {
      final client = MockClient.streaming((request, bodyStream) async {
        return sse([
          'data: not-json',
          'data: {"choices":[{"delta":{"content":"ok"}}]}',
          'data: [DONE]',
        ]);
      });

      final chunks = await OpenRouterService(client: client)
          .streamChat(apiKey: 'k', model: 'm', messages: []).toList();

      expect(chunks, ['ok']);
    });

    test('throws with API message on non-200 stream', () async {
      final client = MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode(
              jsonEncode({'error': {'message': 'rate limited'}}))),
          429,
        );
      });

      expect(
        () => OpenRouterService(client: client)
            .streamChat(apiKey: 'k', model: 'm', messages: []).toList(),
        throwsA(isA<OpenRouterException>()
            .having((e) => e.statusCode, 'statusCode', 429)
            .having((e) => e.message, 'message', 'rate limited')),
      );
    });

    test('builds multimodal content parts and requests image output',
        () async {
      Map<String, dynamic>? sentBody;
      final client = MockClient.streaming((request, bodyStream) async {
        sentBody = jsonDecode(await bodyStream.bytesToString())
            as Map<String, dynamic>;
        return sse(['data: [DONE]']);
      });

      await OpenRouterService(client: client).streamChat(
        apiKey: 'k',
        model: 'm',
        imageOutput: true,
        messages: [
          ChatMessage(
            id: '1',
            role: MessageRole.user,
            content: 'describe this',
            attachments: [
              const MessageAttachment(
                kind: AttachmentKind.image,
                mimeType: 'image/png',
                base64Data: 'AAA',
              ),
              const MessageAttachment(
                kind: AttachmentKind.audio,
                mimeType: 'audio/wav',
                base64Data: 'BBB',
              ),
              const MessageAttachment(
                kind: AttachmentKind.file,
                mimeType: 'application/pdf',
                base64Data: 'CCC',
                name: 'doc.pdf',
              ),
            ],
          ),
        ],
      ).toList();

      expect(sentBody!['modalities'], ['image', 'text']);
      final parts = sentBody!['messages'][0]['content'] as List<dynamic>;
      expect(parts[0], {'type': 'text', 'text': 'describe this'});
      expect(parts[1]['type'], 'image_url');
      expect(parts[1]['image_url']['url'], 'data:image/png;base64,AAA');
      expect(parts[2]['type'], 'input_audio');
      expect(parts[2]['input_audio'], {'data': 'BBB', 'format': 'wav'});
      expect(parts[3]['type'], 'file');
      expect(parts[3]['file']['filename'], 'doc.pdf');
    });

    test('sends a plain string for text-only messages', () async {
      Map<String, dynamic>? sentBody;
      final client = MockClient.streaming((request, bodyStream) async {
        sentBody = jsonDecode(await bodyStream.bytesToString())
            as Map<String, dynamic>;
        return sse(['data: [DONE]']);
      });

      await OpenRouterService(client: client).streamChat(
        apiKey: 'k',
        model: 'm',
        messages: [
          ChatMessage(id: '1', role: MessageRole.user, content: 'hi'),
        ],
      ).toList();

      expect(sentBody!['messages'][0]['content'], 'hi');
      expect(sentBody!.containsKey('modalities'), isFalse);
    });

    test('emits generated images via onImage (deduped)', () async {
      final client = MockClient.streaming((request, bodyStream) async {
        return sse([
          'data: {"choices":[{"delta":{"images":[{"type":"image_url",'
              '"image_url":{"url":"data:image/png;base64,IMG"}}]}}]}',
          // Same image repeated in the final message — should not duplicate.
          'data: {"choices":[{"message":{"images":[{"type":"image_url",'
              '"image_url":{"url":"data:image/png;base64,IMG"}}]}}]}',
          'data: [DONE]',
        ]);
      });

      final images = <MessageAttachment>[];
      await OpenRouterService(client: client).streamChat(
        apiKey: 'k',
        model: 'm',
        messages: [],
        onImage: images.add,
      ).toList();

      expect(images, hasLength(1));
      expect(images.single.kind, AttachmentKind.image);
      expect(images.single.mimeType, 'image/png');
      expect(images.single.base64Data, 'IMG');
    });

    test('reports usage from the final chunk via onUsage', () async {
      final client = MockClient.streaming((request, bodyStream) async {
        return sse([
          'data: {"choices":[{"delta":{"content":"hi"}}]}',
          'data: {"choices":[],"usage":{"prompt_tokens":12,'
              '"completion_tokens":3,"cost":0.0005}}',
          'data: [DONE]',
        ]);
      });

      TokenUsage? captured;
      final chunks = await OpenRouterService(client: client)
          .streamChat(
            apiKey: 'k',
            model: 'm',
            messages: [],
            onUsage: (u) => captured = u,
          )
          .toList();

      expect(chunks, ['hi']);
      expect(captured, isNotNull);
      expect(captured!.promptTokens, 12);
      expect(captured!.completionTokens, 3);
      expect(captured!.cost, 0.0005);
    });
  });

  group('OpenRouterService.fetchCredits', () {
    test('parses the balance', () async {
      final client = MockClient((request) async {
        expect(request.url.path, endsWith('/credits'));
        return http.Response(
          jsonEncode({
            'data': {'total_credits': 10, 'total_usage': 4}
          }),
          200,
        );
      });

      final credits = await OpenRouterService(client: client).fetchCredits('k');

      expect(credits.totalCredits, 10);
      expect(credits.totalUsage, 4);
      expect(credits.remaining, 6);
    });

    test('throws on non-200 (e.g. key without credit access)', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': {'message': 'forbidden'}}),
          403,
        );
      });

      expect(
        () => OpenRouterService(client: client).fetchCredits('k'),
        throwsA(isA<OpenRouterException>()
            .having((e) => e.statusCode, 'statusCode', 403)),
      );
    });
  });
}

/// A lightweight stand-in to simulate a transport-level failure.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
  @override
  String toString() => 'Connection refused';
}
