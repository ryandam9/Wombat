/// The role of a participant in a chat conversation, matching the
/// OpenAI-compatible roles used by the OpenRouter API.
enum MessageRole { system, user, assistant }

extension MessageRoleWire on MessageRole {
  /// The string value the API expects for this role.
  String get wireName => switch (this) {
        MessageRole.system => 'system',
        MessageRole.user => 'user',
        MessageRole.assistant => 'assistant',
      };

  static MessageRole fromWire(String value) => switch (value) {
        'system' => MessageRole.system,
        'assistant' => MessageRole.assistant,
        _ => MessageRole.user,
      };
}

/// A single message in a conversation.
///
/// [content] is mutable so the assistant message can grow while tokens are
/// streamed in from the API.
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? createdAt,
    this.isStreaming = false,
    this.error,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final MessageRole role;
  String content;
  final DateTime createdAt;

  /// True while tokens are still being streamed into this message.
  bool isStreaming;

  /// Non-null if the request that produced this message failed.
  String? error;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.wireName,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        if (error != null) 'error': error,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        role: MessageRoleWire.fromWire(json['role'] as String? ?? 'user'),
        content: json['content'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        error: json['error'] as String?,
      );
}
