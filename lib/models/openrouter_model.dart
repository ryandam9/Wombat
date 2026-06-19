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
    this.inputModalities = const ['text'],
    this.outputModalities = const ['text'],
  });

  /// The fully-qualified id used in requests, e.g. `openai/gpt-4o-mini`.
  final String id;
  final String name;
  final String? description;
  final int? contextLength;

  /// Price per token (USD) for prompt / completion tokens.
  final double? promptPrice;
  final double? completionPrice;

  /// Modalities the model accepts / produces, e.g. `['text', 'image']`.
  final List<String> inputModalities;
  final List<String> outputModalities;

  bool get isFree => (promptPrice ?? 0) == 0 && (completionPrice ?? 0) == 0;

  /// The vendor segment of the id, e.g. `openai` for `openai/gpt-4o-mini`.
  String get vendor => id.contains('/') ? id.split('/').first : 'other';

  bool get supportsImageInput => inputModalities.contains('image');
  bool get supportsImageOutput => outputModalities.contains('image');

  factory OpenRouterModel.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'] as Map<String, dynamic>?;
    double? parsePrice(dynamic v) => v == null ? null : double.tryParse(v.toString());

    final arch = json['architecture'] as Map<String, dynamic>?;
    List<String> modalities(dynamic v) =>
        (v as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const ['text'];

    final rawName = (json['name'] as String?)?.trim();
    return OpenRouterModel(
      id: json['id'] as String,
      name: rawName != null && rawName.isNotEmpty ? rawName : json['id'] as String,
      description: json['description'] as String?,
      contextLength: (json['context_length'] as num?)?.toInt(),
      promptPrice: parsePrice(pricing?['prompt']),
      completionPrice: parsePrice(pricing?['completion']),
      inputModalities: modalities(arch?['input_modalities']),
      outputModalities: modalities(arch?['output_modalities']),
    );
  }
}
