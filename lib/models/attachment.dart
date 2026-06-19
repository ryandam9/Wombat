import 'dart:convert';
import 'dart:typed_data';

/// The kind of non-text content carried by a message.
enum AttachmentKind { image, audio, file }

/// A non-text part of a message — an image, audio clip, or document — used for
/// both user input (attached/recorded) and assistant output (generated images,
/// audio replies). Stored as raw base64 so it round-trips through JSON.
class MessageAttachment {
  const MessageAttachment({
    required this.kind,
    required this.mimeType,
    required this.base64Data,
    this.name,
  });

  final AttachmentKind kind;

  /// MIME type, e.g. `image/png`, `audio/wav`, `application/pdf`.
  final String mimeType;

  /// Base64-encoded bytes, without the `data:` URI prefix.
  final String base64Data;

  /// Original filename, for documents.
  final String? name;

  /// A `data:` URI suitable for OpenRouter `image_url`/`file` parts and for
  /// rendering with `Image.network`/decoding.
  String get dataUrl => 'data:$mimeType;base64,$base64Data';

  Uint8List get bytes => base64Decode(base64Data);

  /// The format token OpenRouter expects for audio input (`wav` or `mp3`).
  String get audioFormat =>
      (mimeType.contains('mpeg') || mimeType.contains('mp3')) ? 'mp3' : 'wav';

  factory MessageAttachment.fromBytes({
    required AttachmentKind kind,
    required String mimeType,
    required List<int> bytes,
    String? name,
  }) =>
      MessageAttachment(
        kind: kind,
        mimeType: mimeType,
        name: name,
        base64Data: base64Encode(bytes),
      );

  /// Parses a `data:<mime>;base64,<data>` URI (as returned for generated
  /// images) into an attachment.
  factory MessageAttachment.fromDataUrl(
    String url, {
    required AttachmentKind kind,
    String? name,
  }) {
    final match =
        RegExp(r'^data:([^;,]+)(?:;[^,]*)?,(.*)$', dotAll: true).firstMatch(url);
    if (match != null) {
      return MessageAttachment(
        kind: kind,
        mimeType: match.group(1)!,
        name: name,
        base64Data: match.group(2)!,
      );
    }
    // Not a data URI: assume it's already bare base64.
    return MessageAttachment(
      kind: kind,
      mimeType: kind == AttachmentKind.image ? 'image/png' : 'application/octet-stream',
      name: name,
      base64Data: url,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'mimeType': mimeType,
        if (name != null) 'name': name,
        'data': base64Data,
      };

  factory MessageAttachment.fromJson(Map<String, dynamic> json) =>
      MessageAttachment(
        kind: AttachmentKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => AttachmentKind.file,
        ),
        mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
        name: json['name'] as String?,
        base64Data: json['data'] as String? ?? '',
      );
}
