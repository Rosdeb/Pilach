import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class ChatDao {
  Future<Database> get db async => await AppDatabase.instance.database;

  Future<void> insertOrUpdateChat(Map<String, dynamic> chat) async {
    final database = await db;
    await database.transaction((txn) async {
      final values = Map<String, dynamic>.from(chat);
      // REPLACE deletes and recreates the row. Preserve the device-local draft
      // when refreshing conversation metadata from the server.
      if (!values.containsKey('draft') && values['id'] != null) {
        final existing = await txn.query(
          'chats',
          columns: ['draft'],
          where: 'id = ?',
          whereArgs: [values['id']],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          values['draft'] = existing.first['draft'];
        }
      }
      await txn.insert(
        'chats',
        values,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> insertOrUpdateChats(List<Map<String, dynamic>> chats) async {
    final database = await db;
    final batch = database.batch();
    for (var chat in chats) {
      batch.rawInsert(
        '''
        INSERT INTO chats (id, other_user_id, type, title, avatar_url, unread_count, last_message_seq, last_message_preview, last_message_at, created_at, updated_at, is_online, last_active_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
          updated_at = excluded.updated_at,
          is_online = COALESCE(excluded.is_online, chats.is_online),
          last_active_at = COALESCE(excluded.last_active_at, chats.last_active_at)
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
          chat['is_online'],
          chat['last_active_at'],
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

  Future<Map<String, dynamic>?> getChatByOtherUserId(String otherUserId) async {
    final database = await db;
    final results = await database.query(
      'chats',
      where: 'other_user_id = ? AND type = ?',
      whereArgs: [otherUserId, 'PRIVATE'],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<void> deleteChat(String id) async {
    final database = await db;
    await database.delete('chats', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateChatLastMessage(
    String id,
    String preview,
    String lastMessageAt,
    int unreadCount,
  ) async {
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

  Future<void> updateGroupMetadata(
    String id, {
    String? title,
    String? avatarUrl,
  }) async {
    final database = await db;
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (title != null && title.trim().isNotEmpty) {
      updates['title'] = title.trim();
    }
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      updates['avatar_url'] = avatarUrl.trim();
    }
    await database.update(
      'chats',
      updates,
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

  Future<void> updatePresenceByUserId(
    String userId, {
    required bool isOnline,
    String? lastActive,
  }) async {
    final database = await db;
    final values = <String, Object?>{'is_online': isOnline ? 1 : 0};
    if (lastActive != null && lastActive.isNotEmpty) {
      values['last_active_at'] = lastActive;
    }
    await database.update(
      'chats',
      values,
      where: 'other_user_id = ? AND type = ?',
      whereArgs: [userId, 'PRIVATE'],
    );
  }

  Future<void> updateMuteStatus(String id, bool isMuted) async {
    final database = await db;
    await database.update(
      'chats',
      {'is_muted': isMuted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String?> getDraft(String id) async {
    final database = await db;
    final rows = await database.query(
      'chats',
      columns: ['draft'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['draft']?.toString();
  }

  Future<void> updateDraft(String id, String? draft) async {
    final database = await db;
    final normalized = draft?.trim();
    await database.update(
      'chats',
      {'draft': normalized == null || normalized.isEmpty ? null : draft},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
