import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/openrouter_model.dart';

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
  OpenRouterService({http.Client? client}) : _client = client ?? http.Client();

  static const String _baseUrl = 'https://openrouter.ai/api/v1';
  final http.Client _client;

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
    final http.Response resp;
    try {
      resp = await _client.get(uri, headers: _headers(apiKey, json: false));
    } catch (e) {
      throw OpenRouterException('Network error: $e');
    }
    if (resp.statusCode != 200) {
      throw OpenRouterException(
        _extractError(resp.body) ?? 'Failed to load models',
        statusCode: resp.statusCode,
      );
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => OpenRouterModel.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Streams assistant token deltas for a chat completion request.
  ///
  /// Each yielded string is an incremental chunk of the assistant's reply.
  Stream<String> streamChat({
    required String apiKey,
    required String model,
    required List<ChatMessage> messages,
  }) async* {
    final uri = Uri.parse('$_baseUrl/chat/completions');
    final request = http.Request('POST', uri)
      ..headers.addAll(_headers(apiKey))
      ..body = jsonEncode({
        'model': model,
        'stream': true,
        'messages': messages
            .map((m) => {'role': m.role.wireName, 'content': m.content})
            .toList(),
      });

    final http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request);
    } catch (e) {
      throw OpenRouterException('Network error: $e');
    }

    if (streamed.statusCode != 200) {
      final body = await streamed.stream.bytesToString();
      throw OpenRouterException(
        _extractError(body) ?? 'Request failed',
        statusCode: streamed.statusCode,
      );
    }

    final lines =
        streamed.stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in lines) {
      // OpenRouter sends SSE comment keep-alives (": OPENROUTER PROCESSING")
      // and blank lines between events; ignore everything but data frames.
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty) continue;
      if (data == '[DONE]') break;
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices == null || choices.isEmpty) continue;
        final delta = (choices.first as Map<String, dynamic>)['delta']
            as Map<String, dynamic>?;
        final content = delta?['content'] as String?;
        if (content != null && content.isNotEmpty) {
          yield content;
        }
      } catch (_) {
        // Skip malformed frames rather than killing the whole stream.
      }
    }
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
