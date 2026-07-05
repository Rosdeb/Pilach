import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class ChatDao {
  Future<Database> get db async => await AppDatabase.instance.database;

  Future<void> insertOrUpdateChat(Map<String, dynamic> chat) async {
    final database = await db;
    await database.insert(
      'chats',
      chat,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertOrUpdateChats(List<Map<String, dynamic>> chats) async {
    final database = await db;
    final batch = database.batch();
    for (var chat in chats) {
      batch.rawInsert(
        '''
        INSERT INTO chats (id, other_user_id, type, title, avatar_url, unread_count, last_message_seq, last_message_preview, last_message_at, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          other_user_id = COALESCE(excluded.other_user_id, chats.other_user_id),
          type = excluded.type,
          title = COALESCE(excluded.title, chats.title),
          avatar_url = COALESCE(excluded.avatar_url, chats.avatar_url),
          unread_count = CASE
            WHEN chats.unread_count = 0 AND (excluded.last_message_at IS NULL OR excluded.last_message_at = chats.last_message_at) THEN 0
            ELSE excluded.unread_count
          END,
          last_message_seq = COALESCE(excluded.last_message_seq, chats.last_message_seq),
          last_message_preview = COALESCE(excluded.last_message_preview, chats.last_message_preview),
          last_message_at = COALESCE(excluded.last_message_at, chats.last_message_at),
          created_at = excluded.created_at,
          updated_at = excluded.updated_at
        ''',
        [
          chat['id'],
          chat['other_user_id'],
          chat['type'],
          chat['title'],
          chat['avatar_url'],
          chat['unread_count'],
          chat['last_message_seq'],
          chat['last_message_preview'],
          chat['last_message_at'],
          chat['created_at'],
          chat['updated_at'],
        ],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getAllChats() async {
    final database = await db;
    // Order by latest message first (or updated_at if you prefer)
    return await database.query(
      'chats',
      orderBy: 'last_message_at DESC, created_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getChatById(String id) async {
    final database = await db;
    final results = await database.query(
      'chats',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<void> deleteChat(String id) async {
    final database = await db;
    await database.delete(
      'chats',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateChatLastMessage(String id, String preview, String lastMessageAt, int unreadCount) async {
    final database = await db;
    await database.update(
      'chats',
      {
        'last_message_preview': preview,
        'last_message_at': lastMessageAt,
        'unread_count': unreadCount,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearUnreadCount(String id) async {
    final database = await db;
    await database.update(
      'chats',
      {'unread_count': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
