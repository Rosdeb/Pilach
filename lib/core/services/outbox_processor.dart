import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
import 'upload_service.dart';

final outboxProcessorProvider = Provider<OutboxProcessor>((ref) {
  final processor = OutboxProcessor(
    OutboxDao(),
    MessageDao(),
    ref.watch(chatRepositoryProvider),
    ref.watch(socketServiceProvider),
    ref.watch(uploadServiceProvider),
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
    this._uploadService,
  ) {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        // Immediately flush outbox when connection returns
        _scheduledRetryTimer?.cancel();
        unawaited(processOutbox());
      }
    });
    _socketSubscription = _socketService.onReconnected.listen((_) {
      _scheduledRetryTimer?.cancel();
      unawaited(processOutbox());
    });

    unawaited(processOutbox());
  }

  final OutboxDao _outboxDao;
  final MessageDao _messageDao;
  final ChatRepository _chatRepository;
  final SocketService _socketService;
  final UploadService _uploadService;
  final _processedController = StreamController<String>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<void>? _socketSubscription;
  Timer? _scheduledRetryTimer;
  bool _isProcessing = false;
  bool _disposed = false;

  Stream<String> get onConversationProcessed => _processedController.stream;

  Future<void> triggerImmediate() async {
    _scheduledRetryTimer?.cancel();
    await processOutbox();
  }

  Future<void> processOutbox() async {
    if (_disposed || _isProcessing) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.every((result) => result == ConnectivityResult.none)) {
      return;
    }

    _isProcessing = true;
    try {
      final pendingItems = await _outboxDao.getPendingItems();
      for (final item in pendingItems) {
        if (_disposed) break;
        await _processItem(item);
      }
    } finally {
      _isProcessing = false;
      _scheduleNextDueRetry();
    }
  }

  Future<void> _scheduleNextDueRetry() async {
    if (_disposed) return;
    _scheduledRetryTimer?.cancel();

    final earliest = await _outboxDao.getEarliestNextRetry();
    if (earliest == null || _disposed) return;

    final now = DateTime.now();
    final diff = earliest.difference(now);
    final delay = diff.isNegative ? Duration.zero : diff;

    _scheduledRetryTimer = Timer(delay, () {
      if (!_disposed) {
        unawaited(processOutbox());
      }
    });
  }

  Future<void> _processItem(Map<String, dynamic> item) async {
    final id = (item['id'] as num?)?.toInt();
    final clientMsgId = item['client_msg_id']?.toString();
    final conversationId = item['conversation_id']?.toString();
    final attemptCount = (item['attempt_count'] as num?)?.toInt() ?? 0;
    if (id == null || clientMsgId == null || conversationId == null) return;

    try {
      // 1. Check if the message has already completed (sent, delivered, or seen)
      final existingLocal = await _messageDao.getMessageById(clientMsgId);
      final currentStatus = existingLocal?['status']?.toString().toLowerCase();
      if (currentStatus == 'sent' ||
          currentStatus == 'delivered' ||
          currentStatus == 'seen') {
        await _outboxDao.deleteItem(id);
        if (!_processedController.isClosed) {
          _processedController.add(conversationId);
        }
        return;
      }

      final decoded = jsonDecode(item['payload_json']?.toString() ?? '{}');
      if (decoded is! Map) {
        throw const FormatException('Outbox payload is not an object');
      }
      var payload = Map<String, Object?>.from(decoded);

      if (item['action'] == 'UPLOAD_MESSAGE') {
        final filePath = payload['localFilePath']?.toString();
        final messageType = payload['type']?.toString().toUpperCase() ?? 'FILE';
        if (filePath == null || filePath.isEmpty) {
          throw const FormatException('Queued upload has no local file path');
        }
        final upload = await _uploadService.uploadMediaFile(
          filePath: filePath,
          purpose: 'message',
        );
        final key = upload['key'] ?? upload['publicUrl'];
        if (key == null || key.isEmpty) {
          throw StateError('Upload completed without an attachment key');
        }
        payload = <String, Object?>{
          'type': messageType,
          'text': payload['text'] ?? '',
          'localFilePath': filePath,
          'managedLocalFile': payload['managedLocalFile'] == true,
          if (payload['replyToId'] != null) 'replyToId': payload['replyToId'],
          'attachments': [
            {
              'type': messageType,
              'url': key,
              'mimeType': upload['contentType'] ?? 'application/octet-stream',
              'fileName': upload['fileName'] ?? 'attachment',
            },
          ],
        };
        await _outboxDao.updatePayload(
          clientMsgId,
          action: 'SEND_MESSAGE',
          payloadJson: jsonEncode(payload),
        );
      }

      await _messageDao.updateMessageStatusByClientId(clientMsgId, 'sending');

      // A stable idempotency key is attached to every retry. The server should
      // persist that key to guarantee exactly-once creation across timeouts.
      final response = await _chatRepository.sendMessage(
        conversationId,
        payload,
        clientMsgId,
      );
      final rawServerData = response['data'];
      var hasAuthoritativeServerRow = false;

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
          hasAuthoritativeServerRow = true;
        } else {
          await _messageDao.updateMessageStatusByClientId(clientMsgId, 'sent');
        }
      } else {
        await _messageDao.updateMessageStatusByClientId(clientMsgId, 'sent');
      }

      await _outboxDao.deleteItem(id);
      if (hasAuthoritativeServerRow) {
        await _deleteManagedLocalFile(payload);
      }
      if (!_processedController.isClosed) {
        _processedController.add(conversationId);
      }
    } catch (error) {
      final nextAttempt = attemptCount + 1;
      if (nextAttempt > 5) {
        // Feature 82: Max retries exceeded; move to failed state for user recovery
        await _messageDao.updateMessageStatusByClientId(clientMsgId, 'failed');
        await _outboxDao.updateAttempt(id, nextAttempt, null, error.toString());
      } else {
        // Feature 78: Exponential backoff
        await _messageDao.updateMessageStatusByClientId(clientMsgId, 'queued');
        final seconds = min(
          60,
          1 << nextAttempt,
        ); // 2s, 4s, 8s, 16s, 32s, max 60s
        final retryAt = DateTime.now().add(Duration(seconds: seconds));
        await _outboxDao.updateAttempt(
          id,
          nextAttempt,
          retryAt.toIso8601String(),
          error.toString(),
        );
      }
      Logger.log(
        'Outbox retry failed for $clientMsgId (attempt $nextAttempt): $error',
      );
      if (!_processedController.isClosed) {
        _processedController.add(conversationId);
      }
    }
  }

  Future<void> _deleteManagedLocalFile(Map<String, Object?> payload) async {
    if (payload['managedLocalFile'] != true) return;
    final filePath = payload['localFilePath']?.toString();
    if (filePath == null || filePath.isEmpty) return;
    try {
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } catch (error) {
      Logger.log('Could not remove staged attachment $filePath: $error');
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _scheduledRetryTimer?.cancel();
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_socketSubscription?.cancel());
    _processedController.close();
  }
}
