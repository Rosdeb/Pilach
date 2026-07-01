import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class OutboxDao {
  Future<Database> get db async => await AppDatabase.instance.database;

  Future<void> enqueue(Map<String, dynamic> outboxRow) async {
    final database = await db;
    await database.insert(
      'outbox',
      outboxRow,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingItems() async {
    final database = await db;
    return await database.query(
      'outbox',
      where: 'next_retry_at IS NULL OR next_retry_at <= ?',
      whereArgs: [DateTime.now().toIso8601String()],
      orderBy: 'created_at ASC', // FIFO
    );
  }

  Future<void> deleteItem(int id) async {
    final database = await db;
    await database.delete(
      'outbox',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateAttempt(int id, int attemptCount, String? nextRetryAt, String? lastError) async {
    final database = await db;
    await database.update(
      'outbox',
      {
        'attempt_count': attemptCount,
        'next_retry_at': nextRetryAt,
        'last_error': lastError,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Helper methods for direct_chat_provider.dart
  Future<List<Map<String, dynamic>>> getPendingMessages(String chatId) async {
    final database = await db;
    return await database.query(
      'outbox',
      where: 'conversation_id = ? AND action = ?',
      whereArgs: [chatId, 'SEND_MESSAGE'],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> insertOutboxItem(Map<String, dynamic> outboxRow) async {
    await enqueue(outboxRow);
  }

  Future<void> deleteOutboxItem(String clientMsgId) async {
    final database = await db;
    await database.delete(
      'outbox',
      where: 'client_msg_id = ?',
      whereArgs: [clientMsgId],
    );
  }
}
