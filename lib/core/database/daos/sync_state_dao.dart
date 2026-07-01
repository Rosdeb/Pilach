import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class SyncStateDao {
  Future<Database> get db async => await AppDatabase.instance.database;

  Future<Map<String, dynamic>?> getSyncState(String conversationId) async {
    final database = await db;
    final results = await database.query(
      'sync_state',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );
    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<void> updateSyncState(Map<String, dynamic> syncState) async {
    final database = await db;
    await database.insert(
      'sync_state',
      syncState,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
