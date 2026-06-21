import 'package:drift/drift.dart';

import '../models/attachment.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'conversation_store.dart';
import 'database/app_database.dart';

/// SQLite-backed [ConversationStore] using drift.
///
/// Conversations, their messages and attachments are stored in normalised
/// tables.
class DriftConversationStore extends ConversationStore {
  DriftConversationStore(this._db);

  final AppDatabase _db;

  @override
  Future<List<Conversation>> load() async {
    final convRows = await (_db.select(_db.conversations)
          ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)]))
        .get();
    if (convRows.isEmpty) return [];

    final msgRows = await (_db.select(_db.messages)
          ..orderBy([(m) => OrderingTerm.asc(m.position)]))
        .get();
    final attRows = await (_db.select(_db.attachments)
          ..orderBy([(a) => OrderingTerm.asc(a.position)]))
        .get();

    // Group children by their parent id for an O(n) assembly.
    final attByMessage = <String, List<AttachmentRow>>{};
    for (final a in attRows) {
      (attByMessage[a.messageId] ??= []).add(a);
    }
    final msgByConvo = <String, List<MessageRow>>{};
    for (final m in msgRows) {
      (msgByConvo[m.conversationId] ??= []).add(m);
    }

    return [
      for (final c in convRows)
        Conversation(
          id: c.id,
          title: c.title,
          modelId: c.modelId,
          supportsImageOutput: c.supportsImageOutput,
          pinned: c.pinned,
          createdAt: c.createdAt,
          updatedAt: c.updatedAt,
          messages: [
            for (final m in msgByConvo[c.id] ?? const <MessageRow>[])
              ChatMessage(
                id: m.id,
                role: _roleFromName(m.role),
                content: m.content,
                createdAt: m.createdAt,
                error: m.error,
                attachments: [
                  for (final a in attByMessage[m.id] ?? const <AttachmentRow>[])
                    MessageAttachment(
                      kind: _kindFromName(a.kind),
                      mimeType: a.mimeType,
                      base64Data: a.data,
                      name: a.name,
                    ),
                ],
              ),
          ],
        ),
    ];
  }

  @override
  Future<void> save(List<Conversation> conversations) async {
    await _db.transaction(() async {
      final keepIds = conversations.map((c) => c.id).toList();
      // Drop conversations the caller no longer has (cascades to messages and
      // attachments via the foreign keys).
      await (_db.delete(_db.conversations)
            ..where((c) => c.id.isNotIn(keepIds)))
          .go();

      for (final c in conversations) {
        await _db.into(_db.conversations).insertOnConflictUpdate(
              ConversationsCompanion.insert(
                id: c.id,
                title: c.title,
                modelId: c.modelId,
                supportsImageOutput: Value(c.supportsImageOutput),
                pinned: Value(c.pinned),
                createdAt: c.createdAt,
                updatedAt: c.updatedAt,
              ),
            );

        // Replace this conversation's messages wholesale (cascade clears their
        // attachments first), then re-insert in order.
        await (_db.delete(_db.messages)
              ..where((m) => m.conversationId.equals(c.id)))
            .go();

        for (var i = 0; i < c.messages.length; i++) {
          final m = c.messages[i];
          await _db.into(_db.messages).insert(
                MessagesCompanion.insert(
                  id: m.id,
                  conversationId: c.id,
                  position: i,
                  role: m.role.name,
                  content: m.content,
                  createdAt: m.createdAt,
                  error: Value(m.error),
                ),
              );
          for (var j = 0; j < m.attachments.length; j++) {
            final a = m.attachments[j];
            await _db.into(_db.attachments).insert(
                  AttachmentsCompanion.insert(
                    messageId: m.id,
                    position: j,
                    kind: a.kind.name,
                    mimeType: a.mimeType,
                    data: a.base64Data,
                    name: Value(a.name),
                  ),
                );
          }
        }
      }
    });
  }

  @override
  Future<void> upsertConversation(Conversation c) async {
    await _db.into(_db.conversations).insertOnConflictUpdate(
          ConversationsCompanion.insert(
            id: c.id,
            title: c.title,
            modelId: c.modelId,
            supportsImageOutput: Value(c.supportsImageOutput),
            pinned: Value(c.pinned),
            createdAt: c.createdAt,
            updatedAt: c.updatedAt,
          ),
        );
  }

  @override
  Future<void> saveMessage(
      String conversationId, ChatMessage m, int position) async {
    await _db.transaction(() async {
      await _db.into(_db.messages).insertOnConflictUpdate(
            MessagesCompanion.insert(
              id: m.id,
              conversationId: conversationId,
              position: position,
              role: m.role.name,
              content: m.content,
              createdAt: m.createdAt,
              error: Value(m.error),
            ),
          );
      // Replace just this message's attachments.
      await (_db.delete(_db.attachments)
            ..where((a) => a.messageId.equals(m.id)))
          .go();
      for (var j = 0; j < m.attachments.length; j++) {
        final a = m.attachments[j];
        await _db.into(_db.attachments).insert(
              AttachmentsCompanion.insert(
                messageId: m.id,
                position: j,
                kind: a.kind.name,
                mimeType: a.mimeType,
                data: a.base64Data,
                name: Value(a.name),
              ),
            );
      }
    });
  }

  @override
  Future<void> deleteConversation(String id) async {
    await (_db.delete(_db.conversations)..where((c) => c.id.equals(id))).go();
  }

  @override
  Future<void> deleteAllConversations() async {
    await _db.delete(_db.conversations).go();
  }

  MessageRole _roleFromName(String name) => MessageRole.values.firstWhere(
        (r) => r.name == name,
        orElse: () => MessageRole.assistant,
      );

  AttachmentKind _kindFromName(String name) => AttachmentKind.values.firstWhere(
        (k) => k.name == name,
        orElse: () => AttachmentKind.file,
      );
}
