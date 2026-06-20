import '../models/conversation.dart';

/// Persistence boundary for the user's chat history.
///
/// The app ships a SQLite-backed implementation ([DriftConversationStore]);
/// tests provide an in-memory fake.
abstract class ConversationStore {
  const ConversationStore();

  /// Loads all saved conversations (most-recently-updated first is the caller's
  /// responsibility to sort, but stores may return any order).
  Future<List<Conversation>> load();

  /// Persists [conversations], replacing whatever was stored before.
  Future<void> save(List<Conversation> conversations);
}
