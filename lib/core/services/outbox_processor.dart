import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/daos/message_dao.dart';
import '../database/daos/outbox_dao.dart';
import '../models/message_dto.dart';
import '../network/chat_repository.dart';
import '../providers/api_provider.dart';
import '../utils/app_logger.dart';
import 'socket_service.dart';

final outboxProcessorProvider = Provider<OutboxProcessor>((ref) {
  final processor = OutboxProcessor(
    OutboxDao(),
    MessageDao(),
    ref.watch(chatRepositoryProvider),
    ref.watch(socketServiceProvider),
  );
  ref.onDispose(processor.dispose);
  return processor;
});

class OutboxProcessor {
  OutboxProcessor(
    this._outboxDao,
    this._messageDao,
    this._chatRepository,
    this._socketService,
  ) {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (results) {
        if (results.any((result) => result != ConnectivityResult.none)) {
          unawaited(processOutbox());
        }
      },
    );
    _socketSubscription = _socketService.onReconnected.listen((_) {
      unawaited(processOutbox());
    });
    unawaited(processOutbox());
  }

  final OutboxDao _outboxDao;
  final MessageDao _messageDao;
  final ChatRepository _chatRepository;
  final SocketService _socketService;
  final _processedController = StreamController<String>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<void>? _socketSubscription;
  bool _isProcessing = false;
  bool _disposed = false;

  Stream<String> get onConversationProcessed => _processedController.stream;

  Future<void> processOutbox() async {
    if (_disposed || _isProcessing) return;
    if (!_socketService.isConnected) return;
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.every((result) => result == ConnectivityResult.none)) return;

    _isProcessing = true;
    try {
      final pendingItems = await _outboxDao.getPendingItems();
      for (final item in pendingItems) {
        if (_disposed) break;
        await _processItem(item);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processItem(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    final clientMsgId = item['client_msg_id']?.toString();
    final conversationId = item['conversation_id']?.toString();
    final attemptCount = (item['attempt_count'] as num?)?.toInt() ?? 0;
    if (id == null || clientMsgId == null || conversationId == null) return;

    try {
      final decoded = jsonDecode(item['payload_json']?.toString() ?? '{}');
      if (decoded is! Map) throw const FormatException('Outbox payload is not an object');
      final payload = Map<String, Object?>.from(decoded);

      await _messageDao.updateMessageStatusByClientId(clientMsgId, 'sending');
      // REST includes clientMsgId and is the idempotent retry path. The server
      // broadcasts the accepted message back over the socket.
      final response = await _chatRepository.sendMessage(
        conversationId,
        payload,
        clientMsgId,
      );
      final rawServerData = response['data'];

      if (rawServerData is Map) {
        final serverData = Map<String, dynamic>.from(rawServerData);
        final local = await _messageDao.getMessageById(clientMsgId);
        serverData['clientMsgId'] ??= clientMsgId;
        serverData['conversationId'] ??= conversationId;
        serverData['senderId'] ??= local?['sender_id'];
        serverData['type'] ??= payload['type'];
        serverData['text'] ??= payload['text'];
        serverData['attachments'] ??= payload['attachments'];
        serverData['createdAt'] ??= local?['created_at'];
        serverData['status'] ??= 'sent';
        final dto = MessageDto.fromJson(serverData);
        if (dto.id.isNotEmpty && dto.conversationId.isNotEmpty) {
          await _messageDao.insertOrUpdateMessages([dto.toSqliteMap()]);
        } else {
          await _messageDao.updateMessageStatusByClientId(clientMsgId, 'sent');
        }
      } else {
        await _messageDao.updateMessageStatusByClientId(clientMsgId, 'sent');
      }

      await _outboxDao.deleteItem(id);
      if (!_processedController.isClosed) {
        _processedController.add(conversationId);
      }
    } catch (error) {
      final nextAttempt = attemptCount + 1;
      if (nextAttempt > 5) {
        await _messageDao.updateMessageStatusByClientId(clientMsgId, 'failed');
        await _outboxDao.updateAttempt(id, nextAttempt, null, error.toString());
      } else {
        await _messageDao.updateMessageStatusByClientId(clientMsgId, 'queued');
        final seconds = min(60, 1 << nextAttempt);
        final retryAt = DateTime.now().add(Duration(seconds: seconds));
        await _outboxDao.updateAttempt(
          id,
          nextAttempt,
          retryAt.toIso8601String(),
          error.toString(),
        );
      }
      Logger.log('Outbox retry failed for $clientMsgId: $error');
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_socketSubscription?.cancel());
    _processedController.close();
  }
}
