import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wombat/services/attachment_store.dart';

void main() {
  late Directory dir;
  late AttachmentStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('wombat_attstore');
    store = AttachmentStore(directory: dir);
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('saves bytes to a deterministic path and reads them back', () async {
    final bytes = [1, 2, 3, 4];
    final path = await store.save(
      messageId: 'm1',
      position: 0,
      mimeType: 'image/png',
      bytes: bytes,
    );

    expect(path, endsWith('m1_0.png'));
    expect(await File(path).exists(), isTrue);
    expect(await store.read(path), bytes);

    // Re-saving the same message/position overwrites the same file.
    final again = await store.save(
      messageId: 'm1',
      position: 0,
      mimeType: 'image/png',
      bytes: const [9, 9],
    );
    expect(again, path);
    expect(await store.read(path), [9, 9]);
  });

  test('delete removes the file and read returns null when missing', () async {
    final path = await store.save(
      messageId: 'm2',
      position: 1,
      mimeType: 'audio/wav',
      bytes: const [7],
    );
    expect(path, endsWith('m2_1.wav'));

    await store.delete(path);
    expect(await File(path).exists(), isFalse);
    expect(await store.read(path), isNull);
    // Deleting a missing file is a no-op.
    await store.delete(path);
  });

  test('maps mime types to extensions', () {
    expect(AttachmentStore.extensionFor('image/jpeg'), 'jpg');
    expect(AttachmentStore.extensionFor('application/pdf'), 'pdf');
    expect(AttachmentStore.extensionFor('audio/mpeg'), 'mp3');
    expect(AttachmentStore.extensionFor('weird/thing'), 'bin');
  });
}
