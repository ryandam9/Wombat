import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:route/models/attachment.dart';

void main() {
  group('MessageAttachment', () {
    test('builds from bytes and exposes a data URL', () {
      final a = MessageAttachment.fromBytes(
        kind: AttachmentKind.image,
        mimeType: 'image/png',
        bytes: [1, 2, 3],
      );
      expect(a.base64Data, base64Encode([1, 2, 3]));
      expect(a.dataUrl, 'data:image/png;base64,${base64Encode([1, 2, 3])}');
      expect(a.bytes, [1, 2, 3]);
    });

    test('round-trips through JSON', () {
      final a = MessageAttachment.fromBytes(
        kind: AttachmentKind.file,
        mimeType: 'application/pdf',
        bytes: [9, 9],
        name: 'spec.pdf',
      );
      final restored = MessageAttachment.fromJson(a.toJson());
      expect(restored.kind, AttachmentKind.file);
      expect(restored.mimeType, 'application/pdf');
      expect(restored.name, 'spec.pdf');
      expect(restored.base64Data, a.base64Data);
    });

    test('parses a data URL into mime + base64', () {
      final a = MessageAttachment.fromDataUrl(
        'data:image/jpeg;base64,QUJD',
        kind: AttachmentKind.image,
      );
      expect(a.mimeType, 'image/jpeg');
      expect(a.base64Data, 'QUJD');
    });

    test('derives the OpenRouter audio format from the mime type', () {
      expect(
        const MessageAttachment(
          kind: AttachmentKind.audio,
          mimeType: 'audio/mpeg',
          base64Data: '',
        ).audioFormat,
        'mp3',
      );
      expect(
        const MessageAttachment(
          kind: AttachmentKind.audio,
          mimeType: 'audio/wav',
          base64Data: '',
        ).audioFormat,
        'wav',
      );
    });
  });
}
