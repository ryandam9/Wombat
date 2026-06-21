import '../models/chat_message.dart';
import '../models/conversation.dart';

/// Persistence boundary for the user's chat history.
///
/// The app ships a SQLite-backed implementation ([DriftConversationStore]);
/// tests provide an in-memory fake.
///
/// Prefer the targeted write methods ([upsertConversation], [saveMessage],
/// [deleteConversation], [deleteAllConversations]) over [save]: they touch only
/// the affected rows instead of rewriting the whole history on every change.
abstract class ConversationStore {
  const ConversationStore();

  /// Loads all saved conversations (most-recently-updated first is the caller's
  /// responsibility to sort, but stores may return any order).
  Future<List<Conversation>> load();

  /// Loads conversation metadata only (no messages/attachments), for a fast
  /// startup. Full messages are loaded lazily via [loadConversation].
  Future<List<Conversation>> loadSummaries();

  /// Loads one conversation in full (messages + attachments), or null if it no
  /// longer exists.
  Future<Conversation?> loadConversation(String id);

  /// Persists [conversations], replacing whatever was stored before. Bulk
  /// fallback; prefer the targeted methods below.
  Future<void> save(List<Conversation> conversations);

  /// Inserts or updates a conversation's metadata row (title, model, pinned,
  /// timestamps) without touching its messages.
  Future<void> upsertConversation(Conversation conversation);

  /// Inserts or updates a single [message] at [position] in [conversationId],
  /// replacing that message's attachments.
  Future<void> saveMessage(
      String conversationId, ChatMessage message, int position);

  /// Deletes one conversation (and, via cascade, its messages/attachments).
  Future<void> deleteConversation(String id);

  /// Deletes every conversation.
  Future<void> deleteAllConversations();
}
