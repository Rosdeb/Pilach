import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/daos/outbox_dao.dart';
import '../database/daos/message_dao.dart';
import 'api_service.dart';

class OutboxProcessor {
  final OutboxDao _outboxDao;
  final MessageDao _messageDao;
  final ApiService _apiService; // In real implementation, inject this
  
  bool _isProcessing = false;
  StreamSubscription? _connectivitySub;

  OutboxProcessor(this._outboxDao, this._messageDao, this._apiService) {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        processOutbox();
      }
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
  }

  Future<void> processOutbox() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final pendingItems = await _outboxDao.getPendingItems();
      
      for (var item in pendingItems) {
        // Break if we lost connection during processing
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult.every((result) => result == ConnectivityResult.none)) {
          break;
        }

        await _processItem(item);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processItem(Map<String, dynamic> item) async {
    final int id = item['id'];
    final String action = item['action'];
    final String clientMsgId = item['client_msg_id'];
    // final String payloadStr = item['payload_json'];
    final int attemptCount = item['attempt_count'];

    try {
      // Update status to sending in UI
      await _messageDao.updateMessageStatusByClientId(clientMsgId, 'sending');

      // TODO: Here you would parse payloadStr and send via REST fallback or SocketService.
      // For now, we simulate a successful REST post.
      // Example: await _apiService.post('/chats/.../messages', data: jsonDecode(payloadStr));
      
      // On success:
      // Update the message in DB to sent/delivered, assign real seq from server if applicable.
      await _messageDao.updateMessageStatusByClientId(clientMsgId, 'sent');
      
      // Remove from outbox
      await _outboxDao.deleteItem(id);

    } catch (e) {
      // Failure
      final newAttempt = attemptCount + 1;
      if (newAttempt > 5) {
        // Mark as failed in UI
        await _messageDao.updateMessageStatusByClientId(clientMsgId, 'failed');
        // We can keep it in outbox with a very long retry or just leave it for manual retry.
        await _outboxDao.updateAttempt(id, newAttempt, null, e.toString());
      } else {
        // Backoff: 2s, 4s, 8s, 16s...
        final backoffSeconds = 1 << newAttempt; 
        final nextRetry = DateTime.now().add(Duration(seconds: backoffSeconds));
        await _outboxDao.updateAttempt(id, newAttempt, nextRetry.toIso8601String(), e.toString());
      }
    }
  }
}
