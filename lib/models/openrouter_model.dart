/// Metadata for a model available through OpenRouter, as returned by the
/// `GET /api/v1/models` endpoint.
class OpenRouterModel {
  OpenRouterModel({
    required this.id,
    required this.name,
    this.description,
    this.contextLength,
    this.promptPrice,
    this.completionPrice,
  });

  /// The fully-qualified id used in requests, e.g. `openai/gpt-4o-mini`.
  final String id;
  final String name;
  final String? description;
  final int? contextLength;

  /// Price per token (USD) for prompt / completion tokens.
  final double? promptPrice;
  final double? completionPrice;

  bool get isFree => (promptPrice ?? 0) == 0 && (completionPrice ?? 0) == 0;

  /// The vendor segment of the id, e.g. `openai` for `openai/gpt-4o-mini`.
  String get vendor => id.contains('/') ? id.split('/').first : 'other';

  factory OpenRouterModel.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'] as Map<String, dynamic>?;
    double? parsePrice(dynamic v) => v == null ? null : double.tryParse(v.toString());

    final rawName = (json['name'] as String?)?.trim();
    return OpenRouterModel(
      id: json['id'] as String,
      name: rawName != null && rawName.isNotEmpty ? rawName : json['id'] as String,
      description: json['description'] as String?,
      contextLength: (json['context_length'] as num?)?.toInt(),
      promptPrice: parsePrice(pricing?['prompt']),
      completionPrice: parsePrice(pricing?['completion']),
    );
  }
}
