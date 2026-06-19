import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/conversation.dart';

/// Persists conversations to a JSON file in the app support directory.
///
/// A flat JSON file keeps the app dependency-free of native databases and
/// works uniformly across Android and desktop targets.
class ConversationStore {
  static const _fileName = 'conversations.json';
  File? _cachedFile;

  Future<File> _file() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$_fileName');
    if (!await file.exists()) {
      await file.create(recursive: true);
      await file.writeAsString('[]');
    }
    _cachedFile = file;
    return file;
  }

  Future<List<Conversation>> load() async {
    try {
      final file = await _file();
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Corrupt or unreadable store: start fresh rather than crashing.
      return [];
    }
  }

  Future<void> save(List<Conversation> conversations) async {
    final file = await _file();
    final data = jsonEncode(conversations.map((c) => c.toJson()).toList());
    await file.writeAsString(data);
  }
}
