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

  Future<void> insertOrUpdateMessages(List<Map<String, dynamic>> messages) async {
    final database = await db;
    final batch = database.batch();
    for (var msg in messages) {
      batch.insert(
        'messages',
        msg,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getMessagesForChat(String conversationId, {int limit = 30, int? beforeSeq}) async {
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
      orderBy: 'seq DESC, created_at DESC',
      limit: limit,
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
}
