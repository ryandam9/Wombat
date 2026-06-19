import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum SaveOutcome { saved, shared, cancelled, failed }

class SaveResult {
  const SaveResult(this.outcome, {this.path, this.error});

  final SaveOutcome outcome;
  final String? path;
  final String? error;

  String get message => switch (outcome) {
        SaveOutcome.saved => 'Saved to $path',
        SaveOutcome.shared => 'Ready to share',
        SaveOutcome.cancelled => 'Save cancelled',
        SaveOutcome.failed => 'Save failed: $error',
      };
}

/// Saves output to disk. On desktop it writes to a configured download folder
/// or shows a native Save-As dialog; on mobile it writes to app storage and
/// opens the system share sheet.
class DownloadService {
  const DownloadService();

  bool get isDesktop =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  /// Opens a native folder picker (desktop) for choosing the download folder.
  Future<String?> chooseDirectory() => getDirectoryPath();

  /// Saves [bytes] under a filename derived from [baseName] + [mimeType].
  ///
  /// Desktop: writes into [defaultDir] when set and [forceDialog] is false,
  /// otherwise prompts with a Save-As dialog. Mobile: writes to a temp file and
  /// shares it.
  Future<SaveResult> save({
    required List<int> bytes,
    required String baseName,
    String? mimeType,
    String? defaultDir,
    bool forceDialog = false,
  }) async {
    final fileName = buildFileName(baseName, mimeType);
    try {
      if (isDesktop) {
        String? targetPath;
        if (!forceDialog && defaultDir != null && defaultDir.isNotEmpty) {
          targetPath = '$defaultDir${Platform.pathSeparator}$fileName';
        } else {
          final location = await getSaveLocation(suggestedName: fileName);
          targetPath = location?.path;
        }
        if (targetPath == null) return const SaveResult(SaveOutcome.cancelled);
        await File(targetPath).writeAsBytes(bytes);
        return SaveResult(SaveOutcome.saved, path: targetPath);
      } else {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}${Platform.pathSeparator}$fileName';
        await File(path).writeAsBytes(bytes);
        await SharePlus.instance.share(
          ShareParams(files: [XFile(path, mimeType: mimeType)]),
        );
        return SaveResult(SaveOutcome.shared, path: path);
      }
    } catch (e) {
      return SaveResult(SaveOutcome.failed, error: e.toString());
    }
  }

  /// `<sanitized base>.<ext>` with the extension inferred from [mimeType].
  static String buildFileName(String baseName, String? mimeType) {
    final base = sanitize(baseName);
    final ext = extensionForMime(mimeType);
    return ext.isEmpty ? base : '$base.$ext';
  }

  static String sanitize(String name) {
    final cleaned = name
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final trimmed = cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
    return trimmed.isEmpty ? 'route-output' : trimmed;
  }

  static String extensionForMime(String? mime) {
    if (mime == null) return 'txt';
    return switch (mime) {
      'text/markdown' => 'md',
      'text/plain' => 'txt',
      'image/png' => 'png',
      'image/jpeg' => 'jpg',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      'audio/wav' || 'audio/x-wav' => 'wav',
      'audio/mpeg' || 'audio/mp3' => 'mp3',
      'application/pdf' => 'pdf',
      _ => mime.contains('/') ? mime.split('/').last : 'bin',
    };
  }
}
