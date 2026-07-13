import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class MessageDao {
  Future<Database> get db async => await AppDatabase.instance.database;

  Future<void> insertOrUpdateMessage(Map<String, dynamic> message) async {
    final database = await db;
    await database.insert(
      'messages',
      message,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isChatUpToDate(String chatId) async {
    final database = await db;
    final chatRes = await database.query('chats', columns: ['last_message_seq'], where: 'id = ?', whereArgs: [chatId]);
    if (chatRes.isEmpty) return false;
    final lastSeqInChat = chatRes.first['last_message_seq'] as int? ?? 0;
    
    final msgRes = await database.rawQuery('SELECT MAX(seq) as max_seq FROM messages WHERE conversation_id = ?', [chatId]);
    final maxSeqInMessages = msgRes.first['max_seq'] as int? ?? 0;
    
    return maxSeqInMessages >= lastSeqInChat && maxSeqInMessages > 0;
  }

  Future<void> insertOrUpdateMessages(List<Map<String, dynamic>> messages) async {
    final database = await db;
    final batch = database.batch();
    for (var msg in messages) {
      batch.rawInsert(
        '''
        INSERT INTO messages (id, client_msg_id, conversation_id, seq, sender_id, type, text, status, created_at, edited_at, deleted, reply_to_id, reactions_json, attachments_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          client_msg_id = COALESCE(excluded.client_msg_id, messages.client_msg_id),
          conversation_id = excluded.conversation_id,
          seq = COALESCE(excluded.seq, messages.seq),
          sender_id = excluded.sender_id,
          type = excluded.type,
          text = excluded.text,
          status = CASE 
            WHEN LOWER(messages.status) IN ('seen', 'read') THEN messages.status
            WHEN LOWER(messages.status) = 'delivered' AND LOWER(excluded.status) NOT IN ('seen', 'read') THEN messages.status
            ELSE excluded.status
          END,
          created_at = excluded.created_at,
          edited_at = excluded.edited_at,
          deleted = excluded.deleted,
          reply_to_id = excluded.reply_to_id,
          reactions_json = COALESCE(excluded.reactions_json, messages.reactions_json),
          attachments_json = COALESCE(excluded.attachments_json, messages.attachments_json)
        ''',
        [
          msg['id'],
          msg['client_msg_id'],
          msg['conversation_id'],
          msg['seq'],
          msg['sender_id'],
          msg['type'],
          msg['text'],
          msg['status'],
          msg['created_at'],
          msg['edited_at'],
          msg['deleted'],
          msg['reply_to_id'],
          msg['reactions_json'],
          msg['attachments_json'],
        ],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateMessageStatusUpToSeq(String conversationId, String status, int seq) async {
    final database = await db;
    await database.update(
      'messages',
      {'status': status},
      where: 'conversation_id = ? AND (seq IS NULL OR seq <= ?)',
      whereArgs: [conversationId, seq],
    );
  }

  Future<List<Map<String, dynamic>>> getMessagesForChat(String conversationId, {int limit = 30, int offset = 0, int? beforeSeq}) async {
    final database = await db;
    String whereClause = 'conversation_id = ?';
    List<dynamic> whereArgs = [conversationId];

    if (beforeSeq != null) {
      whereClause += ' AND seq < ?';
      whereArgs.add(beforeSeq);
    }

    return await database.query(
      'messages',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC, seq DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<void> updateMessageStatusByClientId(String clientMsgId, String status, {int? seq, String? serverId}) async {
    final database = await db;
    Map<String, dynamic> updateData = {'status': status};
    if (seq != null) updateData['seq'] = seq;
    if (serverId != null) updateData['id'] = serverId;

    await database.update(
      'messages',
      updateData,
      where: 'client_msg_id = ?',
      whereArgs: [clientMsgId],
    );
  }

  Future<void> deleteMessage(String id) async {
    final database = await db;
    await database.delete(
      'messages',
      where: 'id = ? OR client_msg_id = ?',
      whereArgs: [id, id],
    );
  }

  Future<void> updateMessageReactions(String id, String reactionsJson) async {
    final database = await db;
    await database.update(
      'messages',
      {'reactions_json': reactionsJson},
      where: 'id = ? OR client_msg_id = ?',
      whereArgs: [id, id],
    );
  }

  Future<Map<String, dynamic>?> getMessageById(String id) async {
    final database = await db;
    final results = await database.query(
      'messages',
      where: 'id = ? OR client_msg_id = ?',
      whereArgs: [id, id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

}

