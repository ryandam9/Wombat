import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/conversation.dart';

/// Persistence boundary for the user's chat history.
///
/// The app ships a SQLite-backed implementation ([DriftConversationStore]);
/// tests provide an in-memory fake. The legacy JSON file format lives on in
/// [JsonConversationStore], used to import older installs into the database.
abstract class ConversationStore {
  const ConversationStore();

  /// Loads all saved conversations (most-recently-updated first is the caller's
  /// responsibility to sort, but stores may return any order).
  Future<List<Conversation>> load();

  /// Persists [conversations], replacing whatever was stored before.
  Future<void> save(List<Conversation> conversations);
}

/// The original conversation store: a flat `conversations.json` file in the app
/// support directory. Retained so existing installs can be migrated into the
/// SQLite database on first launch (see [DriftConversationStore]).
class JsonConversationStore extends ConversationStore {
  JsonConversationStore({Directory? directory}) : _overrideDir = directory;

  /// Optional directory override, primarily for tests. When null the platform
  /// application-support directory is used.
  final Directory? _overrideDir;

  static const fileName = 'conversations.json';
  File? _cachedFile;

  Future<File> _file() async {
    if (_cachedFile != null) return _cachedFile!;
    final dir = _overrideDir ?? await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    if (!await file.exists()) {
      await file.create(recursive: true);
      await file.writeAsString('[]');
    }
    _cachedFile = file;
    return file;
  }

  @override
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

  @override
  Future<void> save(List<Conversation> conversations) async {
    final file = await _file();
    final data = jsonEncode(conversations.map((c) => c.toJson()).toList());
    await file.writeAsString(data);
  }

  /// Renames the JSON file to `<name>.migrated` so it is read once and kept as a
  /// backup after the data has been imported into the database. No-op if the
  /// file is missing.
  Future<void> archive() async {
    final dir = _overrideDir ?? await getApplicationSupportDirectory();
    final path = '${dir.path}${Platform.pathSeparator}$fileName';
    final file = File(path);
    if (await file.exists()) {
      await file.rename('$path.migrated');
      _cachedFile = null;
    }
  }
}
