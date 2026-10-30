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
      where:
          'attempt_count <= 5 AND (next_retry_at IS NULL OR next_retry_at <= ?)',
      whereArgs: [DateTime.now().toIso8601String()],
      orderBy: 'created_at ASC', // FIFO
    );
  }

  Future<void> deleteItem(int id) async {
    final database = await db;
    await database.delete('outbox', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateAttempt(
    int id,
    int attemptCount,
    String? nextRetryAt,
    String? lastError,
  ) async {
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

  Future<DateTime?> getEarliestNextRetry() async {
    final database = await db;
    final results = await database.query(
      'outbox',
      columns: ['next_retry_at'],
      where:
          'attempt_count <= 5 AND next_retry_at IS NOT NULL AND next_retry_at > ?',
      whereArgs: [DateTime.now().toIso8601String()],
      orderBy: 'next_retry_at ASC',
      limit: 1,
    );
    if (results.isNotEmpty) {
      final str = results.first['next_retry_at']?.toString();
      if (str != null) return DateTime.tryParse(str);
    }
    return null;
  }

  Future<void> resetAttempts(String clientMsgId) async {
    final database = await db;
    await database.update(
      'outbox',
      {'attempt_count': 0, 'next_retry_at': null, 'last_error': null},
      where: 'client_msg_id = ?',
      whereArgs: [clientMsgId],
    );
  }

  Future<void> updatePayload(
    String clientMsgId, {
    required String action,
    required String payloadJson,
  }) async {
    final database = await db;
    await database.update(
      'outbox',
      {
        'action': action,
        'payload_json': payloadJson,
        'attempt_count': 0,
        'next_retry_at': null,
        'last_error': null,
      },
      where: 'client_msg_id = ?',
      whereArgs: [clientMsgId],
    );
  }

  Future<Map<String, dynamic>?> getOutboxItemByClientMsgId(
    String clientMsgId,
  ) async {
    final database = await db;
    final results = await database.query(
      'outbox',
      where: 'client_msg_id = ?',
      whereArgs: [clientMsgId],
      limit: 1,
    );
    if (results.isNotEmpty) return results.first;
    return null;
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
