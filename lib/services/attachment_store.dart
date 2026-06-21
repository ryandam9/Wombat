import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores attachment bytes as files on disk (so SQLite holds only metadata).
///
/// Files live under `<app support>/attachments/`. Filenames are deterministic
/// (`<messageId>_<position>.<ext>`) so re-saving a message overwrites its files
/// instead of accumulating orphans.
class AttachmentStore {
  AttachmentStore({Directory? directory}) : _override = directory;

  /// Optional base directory override, primarily for tests.
  final Directory? _override;

  Future<Directory> _dir() async {
    final base = _override ?? await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'attachments'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Writes [bytes] for the attachment at [position] on [messageId] and returns
  /// the file path.
  Future<String> save({
    required String messageId,
    required int position,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final dir = await _dir();
    final file = File(
      p.join(dir.path, '${messageId}_$position.${extensionFor(mimeType)}'),
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Reads the bytes at [path], or null if the file is missing.
  Future<List<int>?> read(String path) async {
    final f = File(path);
    return await f.exists() ? f.readAsBytes() : null;
  }

  /// Deletes the file at [path] if it exists.
  Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  static String extensionFor(String mime) => switch (mime) {
        'image/png' => 'png',
        'image/jpeg' => 'jpg',
        'image/gif' => 'gif',
        'image/webp' => 'webp',
        'image/svg+xml' => 'svg',
        'audio/wav' || 'audio/x-wav' => 'wav',
        'audio/mpeg' || 'audio/mp3' => 'mp3',
        'application/pdf' => 'pdf',
        _ => 'bin',
      };
}
