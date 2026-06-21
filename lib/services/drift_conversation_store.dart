import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/attachment.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'attachment_store.dart';
import 'conversation_store.dart';
import 'database/app_database.dart';

/// SQLite-backed [ConversationStore] using drift.
///
/// Conversations and messages live in normalised tables; attachment **bytes**
/// live in files (via [AttachmentStore]) with only their metadata + path in the
/// database. Legacy rows that still hold inline base64 keep working.
class DriftConversationStore extends ConversationStore {
  DriftConversationStore(this._db, {AttachmentStore? attachmentStore})
      : _files = attachmentStore ?? AttachmentStore();

  final AppDatabase _db;
  final AttachmentStore _files;

  /// Builds an in-memory attachment from a row, reading its bytes from disk
  /// (file-backed) or decoding inline base64 (legacy).
  Future<MessageAttachment> _attachmentFromRow(AttachmentRow a) async {
    String base64;
    if (a.filePath != null) {
      final bytes = await _files.read(a.filePath!);
      base64 = bytes == null ? '' : base64Encode(bytes);
    } else {
      base64 = a.data;
    }
    return MessageAttachment(
      kind: _kindFromName(a.kind),
      mimeType: a.mimeType,
      base64Data: base64,
      name: a.name,
    );
  }

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

    final conversations = <Conversation>[];
    for (final c in convRows) {
      conversations.add(Conversation(
        id: c.id,
        title: c.title,
        modelId: c.modelId,
        supportsImageOutput: c.supportsImageOutput,
        pinned: c.pinned,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
        messages: await _messagesFromRows(
          msgByConvo[c.id] ?? const <MessageRow>[],
          attByMessage,
        ),
      ));
    }
    return conversations;
  }

  Future<List<ChatMessage>> _messagesFromRows(
    List<MessageRow> msgRows,
    Map<String, List<AttachmentRow>> attByMessage,
  ) async {
    final messages = <ChatMessage>[];
    for (final m in msgRows) {
      final attachments = <MessageAttachment>[];
      for (final a in attByMessage[m.id] ?? const <AttachmentRow>[]) {
        attachments.add(await _attachmentFromRow(a));
      }
      messages.add(ChatMessage(
        id: m.id,
        role: _roleFromName(m.role),
        content: m.content,
        createdAt: m.createdAt,
        error: m.error,
        attachments: attachments,
      ));
    }
    return messages;
  }

  @override
  Future<List<Conversation>> loadSummaries() async {
    // Metadata only — no messages/attachments — for a fast startup. Full
    // messages are loaded lazily by [loadConversation] when a chat is opened.
    final convRows = await (_db.select(_db.conversations)
          ..orderBy([
            (c) => OrderingTerm.desc(c.pinned),
            (c) => OrderingTerm.desc(c.updatedAt),
          ]))
        .get();
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
          messages: [],
        ),
    ];
  }

  @override
  Future<Conversation?> loadConversation(String id) async {
    final c = await (_db.select(_db.conversations)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (c == null) return null;

    final msgRows = await (_db.select(_db.messages)
          ..where((m) => m.conversationId.equals(id))
          ..orderBy([(m) => OrderingTerm.asc(m.position)]))
        .get();
    final messageIds = msgRows.map((m) => m.id).toList();
    final attRows = messageIds.isEmpty
        ? <AttachmentRow>[]
        : await (_db.select(_db.attachments)
              ..where((a) => a.messageId.isIn(messageIds))
              ..orderBy([(a) => OrderingTerm.asc(a.position)]))
            .get();

    final attByMessage = <String, List<AttachmentRow>>{};
    for (final a in attRows) {
      (attByMessage[a.messageId] ??= []).add(a);
    }

    return Conversation(
      id: c.id,
      title: c.title,
      modelId: c.modelId,
      supportsImageOutput: c.supportsImageOutput,
      pinned: c.pinned,
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
      messages: await _messagesFromRows(msgRows, attByMessage),
    );
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
    // Clean up files from the previous version of this message (e.g. an
    // earlier streaming save), then write the current attachments as files.
    final old = await (_db.select(_db.attachments)
          ..where((a) => a.messageId.equals(m.id)))
        .get();
    for (final a in old) {
      if (a.filePath != null) await _files.delete(a.filePath!);
    }

    final rows = <AttachmentsCompanion>[];
    for (var j = 0; j < m.attachments.length; j++) {
      final a = m.attachments[j];
      final bytes = a.bytes;
      final path = await _files.save(
        messageId: m.id,
        position: j,
        mimeType: a.mimeType,
        bytes: bytes,
      );
      rows.add(AttachmentsCompanion.insert(
        messageId: m.id,
        position: j,
        kind: a.kind.name,
        mimeType: a.mimeType,
        data: '', // bytes live in the file
        filePath: Value(path),
        sizeBytes: Value(bytes.length),
        name: Value(a.name),
      ));
    }

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
      await (_db.delete(_db.attachments)
            ..where((a) => a.messageId.equals(m.id)))
          .go();
      for (final r in rows) {
        await _db.into(_db.attachments).insert(r);
      }
    });
  }

  @override
  Future<void> deleteConversation(String id) async {
    final paths = await _filePathsForConversation(id);
    await (_db.delete(_db.conversations)..where((c) => c.id.equals(id))).go();
    for (final p in paths) {
      await _files.delete(p);
    }
  }

  @override
  Future<void> deleteAllConversations() async {
    final atts = await (_db.select(_db.attachments)
          ..where((a) => a.filePath.isNotNull()))
        .get();
    await _db.delete(_db.conversations).go();
    for (final a in atts) {
      await _files.delete(a.filePath!);
    }
  }

  /// File paths of every file-backed attachment in a conversation.
  Future<List<String>> _filePathsForConversation(String id) async {
    final msgRows = await (_db.select(_db.messages)
          ..where((m) => m.conversationId.equals(id)))
        .get();
    final ids = msgRows.map((m) => m.id).toList();
    if (ids.isEmpty) return const [];
    final atts = await (_db.select(_db.attachments)
          ..where((a) => a.messageId.isIn(ids) & a.filePath.isNotNull()))
        .get();
    return [for (final a in atts) a.filePath!];
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
