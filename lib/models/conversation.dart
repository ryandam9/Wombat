import 'chat_message.dart';

/// A saved chat session: an ordered list of messages tied to a model.
class Conversation {
  Conversation({
    required this.id,
    required this.title,
    required this.modelId,
    this.supportsImageOutput = false,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String modelId;

  /// Whether the selected model can return generated images, so the request
  /// should ask for the `image` output modality.
  bool supportsImageOutput;

  final List<ChatMessage> messages;
  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'modelId': modelId,
        'supportsImageOutput': supportsImageOutput,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'New chat',
        modelId: json['modelId'] as String? ?? '',
        supportsImageOutput: json['supportsImageOutput'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
        messages: (json['messages'] as List<dynamic>? ?? [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
