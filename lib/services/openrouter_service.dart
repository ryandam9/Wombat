import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/attachment.dart';
import '../models/chat_message.dart';
import '../models/openrouter_model.dart';
import '../models/usage.dart';
import 'debug_log.dart';

/// Thrown when the OpenRouter API returns an error or a request fails.
class OpenRouterException implements Exception {
  OpenRouterException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Thin client around the OpenRouter REST API (OpenAI-compatible).
///
/// See https://openrouter.ai/docs for the full API reference.
class OpenRouterService {
  OpenRouterService({http.Client? client, DebugLog? debug})
      : _client = client ?? http.Client(),
        _debug = debug;

  static const String _baseUrl = 'https://openrouter.ai/api/v1';
  final http.Client _client;
  final DebugLog? _debug;

  Map<String, String> _headers(String apiKey, {bool json = true}) => {
        'Authorization': 'Bearer $apiKey',
        if (json) 'Content-Type': 'application/json',
        // Optional attribution headers recommended by OpenRouter.
        'HTTP-Referer': 'https://github.com/ryandam9/route',
        'X-Title': 'Route',
      };

  /// Fetches the catalogue of available models, sorted by display name.
  Future<List<OpenRouterModel>> fetchModels(String apiKey) async {
    final uri = Uri.parse('$_baseUrl/models');
    final log = _debug;
    final session = log?.begin(title: 'GET /models');
    final http.Response resp;
    try {
      resp = await _client.get(uri, headers: _headers(apiKey, json: false));
    } catch (e) {
      log?.fail(session, 'Network error: $e');
      throw OpenRouterException('Network error: $e');
    }
    if (resp.statusCode != 200) {
      log?.fail(session, _extractError(resp.body) ?? 'Failed to load models',
          httpStatus: resp.statusCode);
      throw OpenRouterException(
        _extractError(resp.body) ?? 'Failed to load models',
        statusCode: resp.statusCode,
      );
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = data['data'] as List<dynamic>? ?? [];
    log?.complete(session, httpStatus: 200, summary: '${list.length} models');
    return list
        .map((e) => OpenRouterModel.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Fetches the account credit balance from `GET /api/v1/credits`.
  ///
  /// Note: this endpoint may require a privileged key; a plain inference key
  /// can receive a 403, which surfaces as an [OpenRouterException].
  Future<CreditBalance> fetchCredits(String apiKey) async {
    final uri = Uri.parse('$_baseUrl/credits');
    final log = _debug;
    final session = log?.begin(title: 'GET /credits');
    final http.Response resp;
    try {
      resp = await _client.get(uri, headers: _headers(apiKey, json: false));
    } catch (e) {
      log?.fail(session, 'Network error: $e');
      throw OpenRouterException('Network error: $e');
    }
    if (resp.statusCode != 200) {
      log?.fail(session, _extractError(resp.body) ?? 'Failed to load credits',
          httpStatus: resp.statusCode);
      throw OpenRouterException(
        _extractError(resp.body) ?? 'Failed to load credits',
        statusCode: resp.statusCode,
      );
    }
    log?.complete(session, httpStatus: 200, responseBody: resp.body);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return CreditBalance.fromJson(data['data'] as Map<String, dynamic>? ?? {});
  }

  /// Streams assistant token deltas for a chat completion request.
  ///
  /// Each yielded string is an incremental chunk of the assistant's reply.
  /// When OpenRouter reports usage (in the final chunk), [onUsage] is invoked
  /// once with the token counts and cost for the request.
  Stream<String> streamChat({
    required String apiKey,
    required String model,
    required List<ChatMessage> messages,
    bool imageOutput = false,
    void Function(TokenUsage usage)? onUsage,
    void Function(MessageAttachment image)? onImage,
    void Function(MessageAttachment audio)? onAudio,
  }) async* {
    final uri = Uri.parse('$_baseUrl/chat/completions');
    final request = http.Request('POST', uri)
      ..headers.addAll(_headers(apiKey))
      ..body = jsonEncode({
        'model': model,
        'stream': true,
        if (imageOutput) 'modalities': ['image', 'text'],
        'messages':
            messages.map((m) => {'role': m.role.wireName, 'content': _content(m)}).toList(),
      });

    final log = _debug;
    final session = log?.begin(
      title: _promptTitle(messages),
      model: model,
      requestBody: request.body,
    );

    // Generated images can be repeated across the delta and the final message;
    // track what we've emitted so callers see each once.
    final seenImages = <String>{};
    var emittedAudio = false;
    String? finishReason;

    final http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request);
    } catch (e) {
      log?.fail(session, 'Network error: $e');
      throw OpenRouterException('Network error: $e');
    }

    if (streamed.statusCode != 200) {
      final body = await streamed.stream.bytesToString();
      log?.fail(session, _extractError(body) ?? 'Request failed',
          httpStatus: streamed.statusCode);
      throw OpenRouterException(
        _extractError(body) ?? 'Request failed',
        statusCode: streamed.statusCode,
      );
    }

    log?.response(session, httpStatus: 200);

    final lines =
        streamed.stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in lines) {
      if (line.isEmpty) continue;
      // OpenRouter sends SSE comment keep-alives (": OPENROUTER PROCESSING")
      // between events; record them so users see progress while waiting.
      if (!line.startsWith('data:')) {
        log?.note(session, line);
        continue;
      }
      final data = line.substring(5).trim();
      if (data.isEmpty) continue;
      if (data == '[DONE]') break;
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final usage = json['usage'];
        if (usage is Map<String, dynamic>) {
          final u = TokenUsage.fromJson(usage);
          onUsage?.call(u);
          log?.setUsage(session, u);
        }
        final choices = json['choices'] as List<dynamic>?;
        Map<String, dynamic>? delta;
        Map<String, dynamic>? message;
        if (choices != null && choices.isNotEmpty) {
          final choice = choices.first as Map<String, dynamic>;
          delta = choice['delta'] as Map<String, dynamic>?;
          message = choice['message'] as Map<String, dynamic>?;
          final fr = choice['finish_reason'] as String?;
          if (fr != null) finishReason = fr;
        }

        final content = delta?['content'] as String?;
        final reasoning = delta?['reasoning'] as String?;
        log?.chunk(session, data, content: content, reasoning: reasoning);
        if (content != null && content.isNotEmpty) {
          yield content;
        }

        // Generated images live in an `images` array on the delta or message.
        final images = (delta?['images'] ?? message?['images']) as List<dynamic>?;
        if (images != null && onImage != null) {
          for (final img in images) {
            final url = (img as Map<String, dynamic>?)?['image_url']?['url']
                as String?;
            if (url != null && seenImages.add(url)) {
              onImage(MessageAttachment.fromDataUrl(url,
                  kind: AttachmentKind.image));
            }
          }
        }

        // Output audio arrives as a base64 `audio` object.
        final audio = (delta?['audio'] ?? message?['audio']);
        if (audio is Map<String, dynamic> && onAudio != null && !emittedAudio) {
          final audioData = audio['data'] as String?;
          if (audioData != null && audioData.isNotEmpty) {
            emittedAudio = true;
            final format = (audio['format'] as String?) ?? 'wav';
            onAudio(MessageAttachment(
              kind: AttachmentKind.audio,
              mimeType: format == 'mp3' ? 'audio/mpeg' : 'audio/$format',
              base64Data: audioData,
            ));
          }
        }
      } catch (_) {
        // Skip malformed frames rather than killing the whole stream, but
        // still record the raw frame for debugging.
        log?.chunk(session, data);
      }
    }
    log?.complete(session, httpStatus: 200, finishReason: finishReason);
  }

  /// A short heading for a chat session: the latest user prompt, truncated.
  String _promptTitle(List<ChatMessage> messages) {
    for (final m in messages.reversed) {
      if (m.role != MessageRole.user) continue;
      final t = m.content.trim();
      if (t.isNotEmpty) return t.length > 80 ? '${t.substring(0, 80)}…' : t;
      if (m.attachments.isNotEmpty) return '[attachment]';
    }
    return 'Chat request';
  }

  /// Builds the OpenAI-compatible `content` for a message: a plain string for
  /// text-only, or an array of typed parts when the user attached media.
  Object _content(ChatMessage m) {
    if (m.role != MessageRole.user || m.attachments.isEmpty) return m.content;
    final parts = <Map<String, dynamic>>[];
    if (m.content.trim().isNotEmpty) {
      parts.add({'type': 'text', 'text': m.content});
    }
    for (final a in m.attachments) {
      switch (a.kind) {
        case AttachmentKind.image:
          parts.add({
            'type': 'image_url',
            'image_url': {'url': a.dataUrl},
          });
        case AttachmentKind.audio:
          parts.add({
            'type': 'input_audio',
            'input_audio': {'data': a.base64Data, 'format': a.audioFormat},
          });
        case AttachmentKind.file:
          parts.add({
            'type': 'file',
            'file': {'filename': a.name ?? 'document', 'file_data': a.dataUrl},
          });
      }
    }
    return parts;
  }

  /// Attempts to pull a human-readable message out of an API error body.
  String? _extractError(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final error = json['error'];
        if (error is Map<String, dynamic>) return error['message'] as String?;
        if (error is String) return error;
      }
    } catch (_) {
      // Fall through and return the raw body if it's short enough.
    }
    if (body.isEmpty) return null;
    return body.length > 300 ? '${body.substring(0, 300)}…' : body;
  }

  void dispose() => _client.close();
}
