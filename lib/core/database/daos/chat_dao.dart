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
      batch.insert(
        'chats',
        chat,
        conflictAlgorithm: ConflictAlgorithm.replace,
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
}
