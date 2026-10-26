import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'package:app/Features/Chat/presentation/providers/chat_provider.dart';
import 'package:app/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/upload_service.dart';
import 'package:app/Features/Chat/data/models/message_model.dart';
import '../../../../core/database/daos/chat_dao.dart';
import '../../../../core/database/daos/message_dao.dart';
import '../../../../core/database/daos/outbox_dao.dart';
import '../../../../core/models/message_dto.dart';
import '../../../../core/network/chat_repository.dart';
import '../../../../core/providers/api_provider.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/services/outbox_processor.dart';
import '../../../../core/utils/message_merge_utils.dart';
import 'package:app/core/utils/date_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatState {
  final List<String> messageIds;
  final Map<String, MessageModel> messagesById;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;

  ChatState({
    required this.messageIds,
    required this.messagesById,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
  });

  factory ChatState.initial() => ChatState(messageIds: [], messagesById: {});

  ChatState copyWith({
    List<String>? messageIds,
    Map<String, MessageModel>? messagesById,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
  }) {
    return ChatState(
      messageIds: messageIds ?? this.messageIds,
      messagesById: messagesById ?? this.messagesById,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
    );
  }
}

final currentChatIdProvider = StateProvider<String?>((ref) => null);

final typingStatusProvider = StateProvider.family<bool, String>((ref, chatId) => false);

final directChatProvider = StateNotifierProvider<DirectChatNotifier, ChatState>((ref) {
  final chatId = ref.watch(currentChatIdProvider);
  final chatRepo = ref.watch(chatRepositoryProvider);
  final socketService = ref.watch(socketServiceProvider);
  final uploadService = ref.watch(uploadServiceProvider);
  final outboxProcessor = ref.watch(outboxProcessorProvider);
  final authState = ref.watch(authProvider);
  return DirectChatNotifier(
    chatId,
    ref,
    chatRepo,
    socketService,
    uploadService,
    outboxProcessor,
    authState.id,
  );
});

class DirectChatNotifier extends StateNotifier<ChatState> {
  final String? chatId;
  final Ref _ref;
  final ChatRepository _chatRepository;
  final SocketService _socketService;
  final UploadService _uploadService;
  final OutboxProcessor _outboxProcessor;
  final MessageDao _messageDao = MessageDao();
  final OutboxDao _outboxDao = OutboxDao();
  final ChatDao _chatDao = ChatDao();
  String _currentUserId; // Made mutable
  String? _otherUserId;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _messageEditedSubscription;
  StreamSubscription? _messageDeletedSubscription;
  StreamSubscription? _messagePinnedSubscription;
  StreamSubscription? _messageUnpinnedSubscription;
  StreamSubscription? _messageReactionSubscription;
  StreamSubscription? _messageReadReceiptSubscription;
  StreamSubscription? _messageDeliveredSubscription;
  StreamSubscription? _userActionSubscription;
  StreamSubscription? _reconnectSubscription;
  StreamSubscription? _outboxProcessedSubscription;
  StreamSubscription? _connectionStateSubscription;
  Timer? _typingResetTimer;   
  Timer? _typingDebounce;     
  bool _isTypingEmitted = false;

  DirectChatNotifier(
    this.chatId,
    this._ref,
    this._chatRepository,
    this._socketService,
    this._uploadService,
    this._outboxProcessor,
    String? initialUserId,
  )
    : _currentUserId = initialUserId ?? '', 
      super(ChatState.initial()) {
    if (chatId != null) {
      _init();
    }
  }

  String get currentUserId => _currentUserId;

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<String> _ensureCurrentUserId() async {
    if (_currentUserId.isNotEmpty && !_currentUserId.contains('@')) {
      return _currentUserId;
    }

    final authId = _ref.read(authProvider).id;
    if (authId != null && authId.isNotEmpty && !authId.contains('@')) {
      _currentUserId = authId;
      return _currentUserId;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getString('user_id');
    if (savedUserId != null && savedUserId.isNotEmpty && !savedUserId.contains('@')) {
      _currentUserId = savedUserId;
      return _currentUserId;
    }

    final token = prefs.getString('auth_token');
    if (token != null && token.split('.').length == 3) {
      try {
        final payloadStr = token.split('.')[1];
        final normalized = base64Url.normalize(payloadStr);
        final decodedBytes = base64Url.decode(normalized);
        final payload = jsonDecode(utf8.decode(decodedBytes));
        final rawId = payload['id'] ?? payload['_id'] ?? payload['userId'] ?? (payload['sub']?.toString().contains('@') == false ? payload['sub'] : null);
        if (rawId != null && !rawId.toString().contains('@')) {
          _currentUserId = rawId.toString();
          await prefs.setString('user_id', _currentUserId);
          return _currentUserId;
        }
      } catch (_) {}
    }

    // Direct API fallback: Fetch from /api/v1/profile/me
    try {
      final res = await _ref.read(apiServiceProvider).get('/api/v1/profile/me');
      final data = res.data;
      if (data is Map && data['data'] is Map) {
        final profile = data['data'] as Map;
        final fetchedId = (profile['userId'] ?? profile['id'] ?? profile['_id'])?.toString();
        if (fetchedId != null && fetchedId.isNotEmpty && !fetchedId.contains('@')) {
          _currentUserId = fetchedId;
          await prefs.setString('user_id', _currentUserId);
          return _currentUserId;
        }
      }
    } catch (_) {}

    return _currentUserId;
  }

  Future<String?> _resolveOtherUserId() async {
    if (_otherUserId != null && _otherUserId!.isNotEmpty) {
      return _otherUserId;
    }

    try {
      final chats = _ref.read(chatProvider);
      final chat = chats.where((c) => c.id == chatId).firstOrNull;
      if (chat?.userId != null && chat!.userId!.isNotEmpty) {
        _otherUserId = chat.userId;
        return _otherUserId;
      }
    } catch (_) {}

    if (chatId != null) {
      try {
        final chatRow = await _chatDao.getChatById(chatId!);
        final storedOtherId = chatRow?['other_user_id']?.toString();
        if (storedOtherId != null && storedOtherId.isNotEmpty) {
          _otherUserId = storedOtherId;
          return _otherUserId;
        }
      } catch (_) {}
    }
    return _otherUserId;
  }

  Future<void> _init() async {
    await _ensureCurrentUserId();
    await _resolveOtherUserId();

    _messageSubscription = _socketService.onNewMessage.listen((data) async {
      try {
        await _ensureCurrentUserId();
        Logger.log('📨 NEW MESSAGE EVENT received — data: $data');
        final eventChatId = (data['conversationId'] ?? data['chatId'] ?? (data['message'] is Map ? (data['message']['conversationId'] ?? data['message']['chatId']) : null))?.toString();
        if (eventChatId != null && chatId != null && eventChatId.toLowerCase() == chatId!.toLowerCase()) {
          Logger.log('✅ NEW MESSAGE matched our chat — processing...');
          Map<String, dynamic> messageData = Map<String, dynamic>.from(data['message'] is Map ? data['message'] : data);
          messageData['conversationId'] ??= eventChatId;
          messageData['chatId'] ??= eventChatId;

          // Fetch full details from local SQLite database if the broadcast is minimal
          final String? msgId = (messageData['id'] ?? messageData['messageId'])?.toString();
          if (msgId != null && (messageData['senderId'] == null || messageData['text'] == null)) {
            final localMsg = await _messageDao.getMessageById(msgId);
            if (localMsg != null) {
              messageData['senderId'] ??= localMsg['sender_id'];
              messageData['text'] ??= localMsg['text'];
              messageData['type'] ??= localMsg['type'];
              messageData['createdAt'] ??= localMsg['created_at'];
              messageData['status'] ??= localMsg['status'];
              messageData['clientMsgId'] ??= localMsg['client_msg_id'];
            }
          }
          
          String? matchedTempId;
          final clientMsgId = messageData['clientMsgId'] as String?;
          if (clientMsgId != null) {
             await _outboxDao.deleteOutboxItem(clientMsgId);
             if (!mounted) return;
             final tId = 'temp_$clientMsgId';
             if (state.messagesById.containsKey(tId)) {
               matchedTempId = tId;
             }
          } else if (messageData['senderId'] == null || messageData['senderId'] == '' || messageData['senderId'] == currentUserId) {
             final outboxItems = await _outboxDao.getPendingMessages(chatId!);
             if (!mounted) return;
             for (var item in outboxItems) {
                final payload = jsonDecode(item['payload_json']);
                if (payload['text'] == messageData['text']) {
                    await _outboxDao.deleteOutboxItem(item['client_msg_id']);
                    if (!mounted) return;
                    final tId = 'temp_${item['client_msg_id']}';
                    if (state.messagesById.containsKey(tId)) {
                      matchedTempId = tId;
                    }
                    break;
                }
             }

             // Fallback for race condition: find the oldest temp message in state that is still sending.
             if (matchedTempId == null) {
                String? oldestTempId;
                DateTime? oldestTime;
                for (var entry in state.messagesById.entries) {
                  if (entry.key.startsWith('temp_') && entry.value.status == MessageStatus.sending) {
                    if (oldestTime == null || entry.value.timestamp.isBefore(oldestTime)) {
                      oldestTime = entry.value.timestamp;
                      oldestTempId = entry.key;
                    }
                  }
                }
                if (oldestTempId != null) {
                  matchedTempId = oldestTempId;
                  final matchedClientMsgId = oldestTempId.replaceFirst('temp_', '');
                  await _outboxDao.deleteOutboxItem(matchedClientMsgId);
                  if (!mounted) return;
                }
             }
          }

          if (matchedTempId != null) {
            final tempMsg = state.messagesById[matchedTempId];
            if (tempMsg != null) {
              messageData['senderId'] ??= tempMsg.senderId ?? currentUserId;
              messageData['text'] ??= tempMsg.text;
              messageData['type'] ??= tempMsg.type.name.toUpperCase();
              messageData['createdAt'] ??= tempMsg.timestamp.toIso8601String();
              messageData['clientMsgId'] ??= matchedTempId.replaceFirst('temp_', '');
            } else {
              matchedTempId = null;
            }
          }
          
          if (msgId != null && state.messagesById.containsKey(msgId)) {
            Logger.log('Message $msgId already handled by ACK, but parsing broadcast to fill missing data.');
          }
          
          // Secondary fallback: if still no senderId, it MUST be our own message that lacked a temp match
          if (messageData['senderId'] == null || messageData['senderId'] == '') {
            messageData['senderId'] = currentUserId;
          }

          Logger.log('Parsing message data...');
          final dto = MessageDto.fromJson(messageData);
          final sqliteMap = await _mergeIncomingRow(dto.toSqliteMap());
          Logger.log('Saving message to DB: id=${sqliteMap['id']}');
          
          await _messageDao.insertOrUpdateMessages([sqliteMap]);
          
          // Directly insert/update in state without rebuilding all message objects from DB
          final newMsg = sqliteMap.toMessageModel(currentUserId, _otherUserId);
          final newById = Map<String, MessageModel>.from(state.messagesById);
          List<String> newIds;
          
          if (matchedTempId != null) {
            newById.remove(matchedTempId);
            newById[newMsg.id] = newMsg;
            newIds = state.messageIds.map((id) => id == matchedTempId ? newMsg.id : id).toList();
          } else if (!state.messagesById.containsKey(newMsg.id)) {
            newById[newMsg.id] = newMsg;
            newIds = [newMsg.id, ...state.messageIds];
          } else {
            final existing = state.messagesById[newMsg.id];
            if (existing != null) {
              newById[newMsg.id] = existing.copyWith(
                seq: newMsg.seq ?? existing.seq,
                status: newMsg.status,
                text: (newMsg.text.isNotEmpty) ? newMsg.text : existing.text,
                mediaUrl: (newMsg.mediaUrl != null && newMsg.mediaUrl!.isNotEmpty) ? newMsg.mediaUrl : existing.mediaUrl,
                replyToMessage: newMsg.replyToMessage ?? existing.replyToMessage,
              );
            } else {
              newById[newMsg.id] = newMsg;
            }
            newIds = state.messageIds;
          }
          
          state = state.copyWith(messageIds: newIds, messagesById: newById);
          Logger.log('Message added directly to state.');
          
          if (!newMsg.isMe && newMsg.seq != null && _ref.read(currentChatIdProvider) == chatId) {
            markAsRead(newMsg.seq);
          }
        }
      } catch (e, st) {
        Logger.log('Error processing new message: $e\n$st', type: "error");
      }
    });

    _messageEditedSubscription = _socketService.onMessageUpdated.listen((data) async {
      final raw = data['message'] ?? data;
      if (raw is! Map) return;
      final messageData = Map<String, dynamic>.from(raw);
      final messageId = (messageData['id'] ?? messageData['messageId'])?.toString();
      final belongsToChat = data['conversationId']?.toString() == chatId ||
          data['chatId']?.toString() == chatId ||
          messageData['conversationId']?.toString() == chatId ||
          messageData['chatId']?.toString() == chatId ||
          (messageId != null && state.messagesById.containsKey(messageId));
      if (belongsToChat && messageId != null) {
        final existingRow = await _messageDao.getMessageById(messageId);
        messageData['id'] = messageId;
        messageData['conversationId'] ??= existingRow?['conversation_id'] ?? chatId;
        messageData['senderId'] ??= existingRow?['sender_id'];
        messageData['type'] ??= existingRow?['type'];
        messageData['status'] ??= existingRow?['status'];
        messageData['createdAt'] ??= existingRow?['created_at'];
        messageData['editedAt'] ??= DateTime.now().toIso8601String();
        final dto = MessageDto.fromJson(messageData);
        final sqliteMap = await _mergeIncomingRow(dto.toSqliteMap());
        await _messageDao.insertOrUpdateMessages([sqliteMap]);
        final updatedMsg = sqliteMap.toMessageModel(currentUserId, _otherUserId);
        if (state.messagesById.containsKey(updatedMsg.id)) {
          final newById = Map<String, MessageModel>.from(state.messagesById);
          newById[updatedMsg.id] = updatedMsg;
          state = state.copyWith(messagesById: newById);
        }
      }
    });

    _messageDeletedSubscription = _socketService.onMessageDeleted.listen((data) async {
      final msgId = (data['messageId'] ?? data['id'])?.toString();
      final belongsToChat = data['conversationId']?.toString() == chatId ||
          data['chatId']?.toString() == chatId ||
          (msgId != null && state.messagesById.containsKey(msgId));
      if (belongsToChat && msgId != null) {
          await _messageDao.markMessageDeleted(msgId);
          final existing = state.messagesById[msgId];
          if (existing != null) {
            final updatedMsg = existing.copyWith(isDeleted: true);
            final newById = Map<String, MessageModel>.from(state.messagesById);
            newById[msgId] = updatedMsg;
            state = state.copyWith(messagesById: newById);
          }
      }
    });

    _messagePinnedSubscription = _socketService.onMessagePinned.listen((data) async {
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        final String? msgId = (data['messageId'] ?? data['id'] ?? (data['message'] is Map ? data['message']['id'] : null))?.toString();
        if (msgId != null && state.messagesById.containsKey(msgId)) {
          await _messageDao.updateMessagePinned(
            msgId,
            true,
            pinnedAt: data['pinnedAt']?.toString(),
          );
          final newById = Map<String, MessageModel>.from(state.messagesById);
          newById[msgId] = newById[msgId]!.copyWith(isPinned: true);
          state = state.copyWith(messagesById: newById);
        }
      }
    });

    _messageUnpinnedSubscription = _socketService.onMessageUnpinned.listen((data) async {
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        final String? msgId = (data['messageId'] ?? data['id'] ?? (data['message'] is Map ? data['message']['id'] : null))?.toString();
        if (msgId != null && state.messagesById.containsKey(msgId)) {
          await _messageDao.updateMessagePinned(msgId, false);
          final newById = Map<String, MessageModel>.from(state.messagesById);
          newById[msgId] = newById[msgId]!.copyWith(isPinned: false);
          state = state.copyWith(messagesById: newById);
        }
      }
    });

    _messageReactionSubscription = _socketService.onMessageReactionUpdated.listen((data) async {
      final msgId = (data['messageId'] ?? data['id'])?.toString();
      final belongsToChat = data['conversationId']?.toString() == chatId ||
          data['chatId']?.toString() == chatId ||
          (msgId != null && state.messagesById.containsKey(msgId));
      if (belongsToChat && msgId != null) {
        final existing = state.messagesById[msgId];
        if (existing != null) {
          List<Map<String, dynamic>> parsed;
          final reactions = data['reactions'];
          if (reactions is List) {
            parsed = reactions
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          } else {
            parsed = List<Map<String, dynamic>>.from(existing.reactions ?? const []);
            final emoji = data['emoji']?.toString();
            final userId = data['userId']?.toString();
            if (emoji == null || userId == null) return;
            parsed.removeWhere((item) =>
                item['emoji']?.toString() == emoji &&
                item['userId']?.toString() == userId);
            if (data['isAdded'] != false) {
              parsed.add({'emoji': emoji, 'userId': userId, 'messageId': msgId});
            }
          }
          await _messageDao.updateMessageReactions(msgId, jsonEncode(parsed));
            final updatedMsg = existing.copyWith(reactions: parsed);
            final newById = Map<String, MessageModel>.from(state.messagesById);
            newById[msgId] = updatedMsg;
            state = state.copyWith(messagesById: newById);
        }
      }
    });

    _messageReadReceiptSubscription = _socketService.onMessageReadReceipt.listen((data) async {
      Logger.log('👁️ READ RECEIPT received — data: $data');
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        final int? readSeq = _parseInt(data['seq'] ?? data['lastReadSeq']);
        if (readSeq != null && mounted) {
          if (chatId != null) {
            await _messageDao.updateMessageStatusUpToSeq(
              chatId!,
              'seen',
              readSeq,
              senderId: currentUserId,
            );
          }
          final newById = Map<String, MessageModel>.from(state.messagesById);
          bool hasChanges = false;
          newById.forEach((id, msg) {
            if (msg.isMe && (msg.seq != null && msg.seq! <= readSeq) && msg.status != MessageStatus.seen) {
              newById[id] = msg.copyWith(status: MessageStatus.seen);
              hasChanges = true;
            }
          });
          if (hasChanges) {
            state = state.copyWith(messagesById: newById);
          }
        }
      }
    });

    _messageDeliveredSubscription = _socketService.onMessageDelivered.listen((data) async {
      Logger.log('🚚 DELIVERED RECEIPT received — data: $data');
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        final int? deliveredSeq = _parseInt(data['seq'] ?? data['lastDeliveredSeq']);
        if (deliveredSeq != null && mounted) {
          if (chatId != null) {
            await _messageDao.updateMessageStatusUpToSeq(
              chatId!,
              'delivered',
              deliveredSeq,
              senderId: currentUserId,
            );
          }
          final newById = Map<String, MessageModel>.from(state.messagesById);
          bool hasChanges = false;
          newById.forEach((id, msg) {
            if (msg.isMe && (msg.seq != null && msg.seq! <= deliveredSeq) && (msg.status == MessageStatus.sent || msg.status == MessageStatus.sending)) {
              newById[id] = msg.copyWith(status: MessageStatus.delivered);
              hasChanges = true;
            }
          });
          if (hasChanges) {
            state = state.copyWith(messagesById: newById);
          }
        }
      }
    });

    _userActionSubscription = _socketService.onUserTyping.listen((data) {
      Logger.log('⌨️ TYPING EVENT received — data: $data, our chatId: $chatId');
      if (chatId == null) return;

      final eventChatId = (data['conversationId'] ?? data['chatId'])?.toString();
      final senderId = (data['userId'] ?? data['senderId'] ?? (data['user'] is Map ? data['user']['id'] : null))?.toString();

      if (senderId != null && senderId == currentUserId) {
        return; // Ignore typing indicators generated by ourselves
      }

      if (eventChatId != null && eventChatId.toLowerCase() == chatId!.toLowerCase()) {
        Logger.log('✅ TYPING matched our chat — triggering typing indicator UI');
        _ref.read(typingStatusProvider(chatId!).notifier).state = true;
        
        _typingResetTimer?.cancel();
        _typingResetTimer = Timer(const Duration(seconds: 4), () {
           if (mounted) _ref.read(typingStatusProvider(chatId!).notifier).state = false;
        });
      } else {
        Logger.log('⚠️ TYPING chatId mismatch — ignored ($eventChatId vs $chatId)');
      }
    });

    _reconnectSubscription = _socketService.onReconnected.listen((_) async {
      if (chatId == null) return;
      await syncHistoryFromServer(forceRefresh: true);
      if (mounted) markAsRead();
    });

    _outboxProcessedSubscription =
        _outboxProcessor.onConversationProcessed.listen((conversationId) async {
      if (conversationId == chatId && mounted) {
        await loadFromDb(limitOverride: max(60, state.page * 60));
      }
    });

    _connectionStateSubscription = _socketService.connectionStates.listen((socketState) {
      if (socketState == SocketConnectionState.disconnected && chatId != null) {
        _typingResetTimer?.cancel();
        _typingDebounce?.cancel();
        _isTypingEmitted = false;
        _ref.read(typingStatusProvider(chatId!).notifier).state = false;
      }
    });

    // 1. Load instantly from local SQLite (Offline-first)
    await loadFromDb();
    
    // 2. Fetch latest from server if mismatched or missing
    if (chatId != null) {
      final isUpToDate = await _messageDao.isChatUpToDate(chatId!);
      if (!isUpToDate || state.messageIds.isEmpty) {
        await syncHistoryFromServer(forceRefresh: !isUpToDate);
      }
    }
    
    if (mounted && _ref.read(currentChatIdProvider) == chatId) {
      markAsRead();
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageEditedSubscription?.cancel();
    _messageDeletedSubscription?.cancel();
    _messagePinnedSubscription?.cancel();
    _messageUnpinnedSubscription?.cancel();
    _messageReactionSubscription?.cancel();
    _messageReadReceiptSubscription?.cancel();
    _messageDeliveredSubscription?.cancel();
    _userActionSubscription?.cancel();
    _reconnectSubscription?.cancel();
    _outboxProcessedSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _typingResetTimer?.cancel();
    _typingDebounce?.cancel();
    super.dispose();
  }

  void markAsRead([int? seq]) {
    if (chatId == null) return;
    if (_ref.read(currentChatIdProvider) != chatId) return;

    int targetSeq = seq ?? 0;
    if (seq == null) {
      for (final id in state.messageIds) {
        final msg = state.messagesById[id];
        if (msg != null && !msg.isMe && msg.seq != null && msg.seq! > targetSeq) {
          targetSeq = msg.seq!;
        }
      }
    }

    if (targetSeq > 0) {
      try {
        _socketService.emit('message:read', {
          'conversationId': chatId,
          'seq': targetSeq,
        });
        Logger.log('👁️ EMITTED message:read for chat $chatId, seq: $targetSeq');
      } catch (e) {
        Logger.log('Failed to emit message:read: $e');
      }
    }
  }

  Future<void> loadFromDb({int? limitOverride}) async {
    if (chatId == null) return;
    
    await _ensureCurrentUserId();
    await _resolveOtherUserId();

    final limit = limitOverride ?? ((state.messageIds.length > state.page * 30)
        ? state.messageIds.length
        : state.page * 30);
    final msgRows = await _messageDao.getMessagesForChat(chatId!, limit: limit);
    if (!mounted) return;
    final outboxRows = await _outboxDao.getPendingMessages(chatId!);
    if (!mounted) return;
    final userId = currentUserId;
    final otherId = _otherUserId;

    // Heavy mapping and sorting offloaded to background Isolate
    final List<MessageModel> models = await Isolate.run(() {
      final List<MessageModel> list = msgRows.map((row) => row.toMessageModel(userId, otherId)).toList();
      final persistedClientIds = msgRows
          .map((row) => row['client_msg_id']?.toString())
          .whereType<String>()
          .toSet();

      for (var outboxMsg in outboxRows) {
        if (persistedClientIds.contains(outboxMsg['client_msg_id']?.toString())) {
          continue;
        }
        final payload = jsonDecode(outboxMsg['payload_json']);
        final attachments = payload is Map ? payload['attachments'] : null;
        final firstAttachment = attachments is List && attachments.isNotEmpty && attachments.first is Map
            ? attachments.first as Map
            : null;
        list.add(MessageModel(
          id: 'temp_${outboxMsg['client_msg_id']}',
          text: payload['text'] ?? '',
          time: 'Sending...',
          timestamp: DateTime.parse(outboxMsg['created_at']),
          isMe: true,
          status: MessageStatus.queued,
          type: messageTypeFromWire(payload is Map ? payload['type']?.toString() : null),
          mediaUrl: firstAttachment?['url']?.toString(),
        ));
      }
      
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
    
    if (!mounted) return;
    
    final List<String> ids = [];
    final Map<String, MessageModel> byId = {};
    for (var model in models) {
      ids.add(model.id);
      byId[model.id] = model;
    }
    
    // Optimize: Only update Riverpod state if message IDs list or message contents have changed.
    // Preserve the current pagination level while still allowing history to remain visible.
    final int newPage = state.page;
    final bool newHasMore = ids.length >= state.page * 30;
    
    final bool changed = _hasStateChanged(state.messageIds, ids, state.messagesById, byId) ||
                         state.page != newPage ||
                         state.hasMore != newHasMore;
                         
    if (changed) {
      state = state.copyWith(
        messageIds: ids, 
        messagesById: byId,
        page: newPage,
        hasMore: newHasMore,
      );
    }
  }

  bool _hasStateChanged(List<String> oldIds, List<String> newIds, Map<String, MessageModel> oldById, Map<String, MessageModel> newById) {
    if (oldIds.length != newIds.length) return true;
    for (int i = 0; i < oldIds.length; i++) {
      if (oldIds[i] != newIds[i]) return true;
    }
    for (final key in newById.keys) {
      if (!oldById.containsKey(key)) return true;
      if (oldById[key] != newById[key]) return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> _mergeIncomingRow(Map<String, dynamic> incomingRow) async {
    final id = incomingRow['id']?.toString();
    if (id == null || id.isEmpty) {
      return incomingRow;
    }

    final existingRow = await _messageDao.getMessageById(id);
    if (existingRow == null) {
      return incomingRow;
    }

    return mergeMessageRows(incomingRow, existingRow);
  }

  Future<List<Map<String, dynamic>>> _hydrateReplyReferences(List<Map<String, dynamic>> rows) async {
    final hydrated = <Map<String, dynamic>>[];
    for (final row in rows) {
      final replyToId = row['reply_to_id']?.toString();
      final replyToJson = row['reply_to_json']?.toString();

      if ((replyToId == null || replyToId.isEmpty) || (replyToJson != null && replyToJson.isNotEmpty)) {
        hydrated.add(row);
        continue;
      }

      final replyRow = await _messageDao.getMessageById(replyToId);
      if (replyRow != null) {
        // Resolve the media URL from attachments_json if not directly stored.
        String? mediaUrl;
        final attachmentsJson = replyRow['attachments_json']?.toString();
        if (attachmentsJson != null && attachmentsJson.isNotEmpty) {
          try {
            final decoded = jsonDecode(attachmentsJson);
            if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
              mediaUrl = decoded.first['url']?.toString();
            }
          } catch (_) {}
        }

        row['reply_to_json'] = jsonEncode({
          'id': replyRow['id'],
          'text': replyRow['text'] ?? '',
          'senderId': replyRow['sender_id'],
          'isDeleted': replyRow['deleted'] == 1 || replyRow['deleted'] == true,
          'type': replyRow['type'],        // e.g. 'IMAGE', 'VIDEO', 'AUDIO'
          if (mediaUrl != null) 'mediaUrl': mediaUrl,
        });
      }
      hydrated.add(row);
    }
    return hydrated;
  }

  Future<void> syncHistoryFromServer({bool forceRefresh = false}) async {
    if (chatId == null || !mounted) return;

    // The server has no afterSeq/sinceSeq filter — the messages endpoint only
    // supports cursor/page/limit/query.  Strategy:
    //   1. Fetch page 1 (newest 50 messages) from the server.
    //   2. Persist with insertOrUpdate — duplicates are silently ignored.
    //   3. Compare the highest server seq against local to detect a gap.
    //   4. If there is still a gap, fall back to a full paginated fetch.
    final localLatestSeq = await _messageDao.getLastSeq(chatId!);

    // Fresh install / no local data → full paginated fetch
    if (localLatestSeq == 0) {
      await fetchMessagesFromServer();
      return;
    }

    try {
      // Single request: fetch the newest 50 messages (covers typical gaps after
      // a brief background/reconnect without an extra round-trip).
      final response = await _chatRepository.getRecentMessages(chatId!, limit: 50);
      if (!mounted) return;

      final success = response['success'] == true;
      final List<dynamic>? data = success ? response['data'] as List<dynamic>? : null;

      if (data != null && data.isNotEmpty) {
        // Determine the server's latest seq from the first element (newest-first).
        final serverLatestSeq = (data.first['seq'] as num?)?.toInt() ?? 0;

        if (serverLatestSeq == localLatestSeq && !forceRefresh) {
          Logger.log('Chat is up to date, seq: $localLatestSeq');
          return;
        }

        final sqliteRows = await Isolate.run(() {
          return data.map((item) {
            final dto = MessageDto.fromJson(item as Map<String, dynamic>);
            return dto.toSqliteMap();
          }).toList();
        });
        if (!mounted) return;

        final hydratedRows = await _hydrateReplyReferences(sqliteRows);
        final mergedRows = <Map<String, dynamic>>[];
        for (final incomingRow in hydratedRows) {
          mergedRows.add(await _mergeIncomingRow(incomingRow));
        }
        await _messageDao.insertOrUpdateMessages(mergedRows);
        if (!mounted) return;

        Logger.log('Synced ${mergedRows.length} recent messages '
            '(local seq: $localLatestSeq → server seq: $serverLatestSeq)');

        // If the gap is larger than what 50 messages covered, do a full fetch.
        final newLocalSeq = await _messageDao.getLastSeq(chatId!);
        if (serverLatestSeq > newLocalSeq) {
          Logger.log('Gap still exists after partial sync — falling back to full fetch');
          await fetchMessagesFromServer();
          return;
        }

        await loadFromDb(limitOverride: max(60, state.page * 60));
      }
    } catch (e) {
      Logger.log('Failed to sync recent messages, falling back to full fetch: $e');
      if (mounted) await fetchMessagesFromServer();
    }
  }

  Future<void> fetchMessagesFromServer({int page = 1}) async {
    if (chatId == null || !mounted) return;

    try {
      final response = await _chatRepository.getMessages(chatId!, page: page, limit: 30);
      if (!mounted) return;
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> data = response['data'];
        final pagination = response['pagination'] as Map<String, dynamic>?;
        final bool hasNext = pagination?['hasNext'] ?? false;

        final outboxItems = await _outboxDao.getPendingMessages(chatId!);
        if (!mounted) return;

        // Heavy JSON DTO mapping offloaded to background Isolate
        final List<Map<String, dynamic>> sqliteRows = await Isolate.run(() {
          return data.map((item) {
            final dto = MessageDto.fromJson(item as Map<String, dynamic>);
            return dto.toSqliteMap();
          }).toList();
        });
        if (!mounted) return;

        final hydratedRows = await _hydrateReplyReferences(sqliteRows);
        final mergedRows = <Map<String, dynamic>>[];
        for (final incomingRow in hydratedRows) {
          mergedRows.add(await _mergeIncomingRow(incomingRow));
        }

        if (outboxItems.isNotEmpty) {
          final outboxTexts = outboxItems.map((e) {
            final payload = jsonDecode(e['payload_json']);
            return MapEntry(e['client_msg_id'] as String, payload['text']);
          }).toList();

          for (var row in mergedRows) {
            if (row['sender_id'] == currentUserId) {
              for (var entry in outboxTexts) {
                if (entry.value == row['text']) {
                  await _outboxDao.deleteOutboxItem(entry.key);
                  if (!mounted) return;
                  break;
                }
              }
            }
          }
        }

        if (mergedRows.isNotEmpty) {
          await _messageDao.insertOrUpdateMessages(mergedRows);
          if (!mounted) return;

          state = state.copyWith(page: page, hasMore: hasNext);
          await loadFromDb(limitOverride: max(60, page * 60));
        } else {
          state = state.copyWith(page: page, hasMore: hasNext);
        }
      }
    } catch (e) {
      Logger.log('Failed to fetch messages: $e');
    }
  }

  Future<void> loadMore() async {
    if (!mounted || state.isLoadingMore || !state.hasMore) return;
    
    state = state.copyWith(isLoadingMore: true);
    
    final nextPage = state.page + 1;
    final previousCount = state.messageIds.length;
    
    // First try to load the next page from local SQLite database
    state = state.copyWith(page: nextPage);
    await loadFromDb(limitOverride: max(60, nextPage * 60));
    
    if (!mounted) return;
    
    // If the local database didn't have enough messages for the next page, fetch from server
    if (state.messageIds.length < nextPage * 30 && state.messageIds.length == previousCount) {
      await fetchMessagesFromServer(page: nextPage);
    }
    
    if (!mounted) return;
    state = state.copyWith(isLoadingMore: false);
  }

  void emitTyping() {
    if (chatId == null) return;

    final conversationPayload = {
      'conversationId': chatId,
    };
    // Leading-edge debounce:
    // প্রথম keystroke-এ তাৎক্ষণিক emit, তারপর 3 সেকেন্ড block
    // ফলে server-এ অতিরিক্ত hit হবে না
    if (!_isTypingEmitted) {
      _isTypingEmitted = true;
      try {
        _socketService.emit('message:typing', conversationPayload);
        Logger.log('⌨️ TYPING EMITTED (message:typing)');
      } catch (e) {
        Logger.log('Failed to emit typing: $e', type: "info");
      }
    }

    // 3 সেকেন্ড pause হলে ফ্লাগ reset হবে — পরেরবার type শুরু হলে আবার emit হবে
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 3), () {
      _isTypingEmitted = false;
      Logger.log('⌨️ TYPING debounce reset — next keystroke will emit again');
    });
  }

  Future<void> _replaceTempMessageWithServerData(String clientMsgId, Map<String, dynamic> serverData) async {
    final tempId = 'temp_$clientMsgId';
    final existing = state.messagesById[tempId];
    final msgId = serverData['id']?.toString();
    if (msgId == null || msgId.isEmpty) return;

    await _ensureCurrentUserId();
    await _resolveOtherUserId();

    final normalizedData = Map<String, dynamic>.from(serverData);
    normalizedData['conversationId'] ??= chatId;
    normalizedData['clientMsgId'] ??= clientMsgId;
    normalizedData['id'] ??= msgId;
    normalizedData['text'] ??= existing?.text;
    normalizedData['type'] ??= existing?.type.name.toUpperCase();
    normalizedData['senderId'] ??= (existing?.senderId != null && existing!.senderId!.isNotEmpty)
        ? existing.senderId
        : (_currentUserId.isNotEmpty ? _currentUserId : null);

    if (normalizedData['senderId'] == null || normalizedData['senderId'] == '') {
      normalizedData['senderId'] = _currentUserId;
    }

    final dto = MessageDto.fromJson(normalizedData);
    final sqliteMap = await _mergeIncomingRow(dto.toSqliteMap());
    await _messageDao.insertOrUpdateMessages([sqliteMap]);
    await _messageDao.deleteMessage(tempId);

    final newMsg = (existing != null)
        ? existing.copyWith(
            id: msgId,
            text: (normalizedData['text'] as String?) ?? existing.text,
            seq: dto.seq,
            status: MessageStatus.sent,
            senderId: normalizedData['senderId']?.toString() ?? existing.senderId,
            isMe: true,
            time: DateFormat('hh:mm a').format(DateTime.now().toLocal()),
            timestamp: DateTime.parse(dto.createdAt).toLocal(), // ← fix
          )
        : sqliteMap.toMessageModel(currentUserId, _otherUserId);

    final newById = Map<String, MessageModel>.from(state.messagesById);
    newById.remove(tempId);
    newById[newMsg.id] = newMsg;
    final newIds = state.messageIds.map((e) => e == tempId ? newMsg.id : e).toList();
    state = state.copyWith(messageIds: newIds, messagesById: newById);
  }

  Future<void> sendMessage(String text, {String? replyToId}) async {
    if (chatId == null || text.trim().isEmpty) return;

    await _ensureCurrentUserId();
    Logger.log('🚀 [SEND MESSAGE] text: "$text"');
    final clientMsgId = const Uuid().v4();
    final now = DateTime.now();

    final Map<String, Object?> payloadJson = {
      'conversationId': chatId,
      'clientMsgId': clientMsgId,
      'text': text,
      'type': 'TEXT',
      'attachments': [],
      if (replyToId != null) 'replyToId': replyToId,
    };

    final tempMsg = MessageModel(
      id: 'temp_$clientMsgId',
      text: text,
      time: 'Sending...',
      timestamp: now,
      isMe: true,
      senderId: currentUserId,
      status: MessageStatus.queued,
      replyToMessageId: replyToId,
    );

    final outboxRow = {
      'client_msg_id': clientMsgId,
      'conversation_id': chatId!,
      'action': 'SEND_MESSAGE',
      'payload_json': jsonEncode(payloadJson),
      'created_at': now.toIso8601String(),
    };
    final pendingRow = MessageDto(
      id: tempMsg.id,
      clientMsgId: clientMsgId,
      conversationId: chatId!,
      senderId: currentUserId,
      type: 'TEXT',
      text: text,
      status: 'queued',
      createdAt: now.toIso8601String(),
      replyToId: replyToId,
    ).toSqliteMap();

    // The local DB and outbox are committed atomically before the UI changes.
    await _messageDao.insertPendingMessageAndOutbox(pendingRow, outboxRow);
    if (!mounted) return;
    await loadFromDb(limitOverride: max(60, state.page * 60));
    unawaited(_ref.read(chatProvider.notifier).updateLastMessage(
      chatId!,
      text,
      DateFormatter.formatConversationTime(now),
    ));

    bool fallbackToRest = !_socketService.isConnected;

    try {
      if (_socketService.isConnected) {
        await _messageDao.updateMessageStatusByClientId(clientMsgId, 'sending');
        if (mounted && state.messagesById.containsKey(tempMsg.id)) {
          final updated = Map<String, MessageModel>.from(state.messagesById);
          updated[tempMsg.id] = updated[tempMsg.id]!.copyWith(
            status: MessageStatus.sending,
          );
          state = state.copyWith(messagesById: updated);
        }
        final socketPayload = Map<String, dynamic>.from(payloadJson)..remove('clientMsgId');
        final response = await _socketService.emitWithAck('message:send', socketPayload);
        if (response['ok'] == true) {
          await _outboxDao.deleteOutboxItem(clientMsgId);
          final serverData = response['data'];
          if (serverData != null) {
            await _replaceTempMessageWithServerData(clientMsgId, Map<String, dynamic>.from(serverData));
          }
          return;
        }

        final errCode = (response['error'] as Map?)?['code'];
        fallbackToRest = errCode == 'NOT_CONNECTED' ||
            errCode == 'EMIT_ERROR' ||
            errCode == 'ACK_TIMEOUT' ||
            errCode == 'VALIDATION_ERROR';
        Logger.log('Socket send not accepted: ${response['error']}');
      }

      if (fallbackToRest) {
        Logger.log('Falling back to REST send for chat $chatId');
        final restResponse = await _chatRepository.sendMessage(chatId!, payloadJson, clientMsgId);
        if (!mounted) return;
        final serverData = restResponse['data'];
        if (serverData is Map<String, dynamic>) {
          await _outboxDao.deleteOutboxItem(clientMsgId);
          await _replaceTempMessageWithServerData(clientMsgId, serverData);
          return;
        }
      }
    } catch (e) {
      Logger.log('Failed to send message via socket/REST: $e');
      try {
        final restResponse = await _chatRepository.sendMessage(chatId!, payloadJson, clientMsgId);
        if (!mounted) return;
        final serverData = restResponse['data'];
        if (serverData is Map<String, dynamic>) {
          await _outboxDao.deleteOutboxItem(clientMsgId);
          await _replaceTempMessageWithServerData(clientMsgId, serverData);
        }
      } catch (restError) {
        Logger.log('REST fallback failed: $restError');
        await _messageDao.updateMessageStatusByClientId(clientMsgId, 'queued');
        if (mounted && state.messagesById.containsKey(tempMsg.id)) {
          final updated = Map<String, MessageModel>.from(state.messagesById);
          updated[tempMsg.id] = updated[tempMsg.id]!.copyWith(
            status: MessageStatus.queued,
          );
          state = state.copyWith(messagesById: updated);
        }
      }
    }
  }

  Future<void> deleteMessage(String messageId) async {
    if (chatId == null) return;
    try {
      final response = await _socketService.emitWithAck('message:delete', {
        'conversationId': chatId,
        'messageId': messageId,
      });
      if (response['ok'] != true) {
        Logger.log('Server rejected delete message: ${response['error']}');
        return;
      }
      await _messageDao.markMessageDeleted(messageId);
      if (!mounted) return;
      final existing = state.messagesById[messageId];
      if (existing != null) {
        final updatedMsg = existing.copyWith(isDeleted: true);
        final newById = Map<String, MessageModel>.from(state.messagesById);
        newById[messageId] = updatedMsg;
        state = state.copyWith(messagesById: newById);
      }
    } catch (e) {
      Logger.log('Failed to delete message: $e');
    }
  }

  Future<void> editMessage(String messageId, String newText) async {
    if (chatId == null) return;
    
    // Optimistic Update
    final msg = state.messagesById[messageId];
    if (msg != null) {
      await _messageDao.updateMessageText(
        messageId,
        newText,
        editedAt: DateTime.now().toIso8601String(),
      );
      if (!mounted) return;
      final updatedMsg = msg.copyWith(text: newText, isEdited: true);
      final newById = Map<String, MessageModel>.from(state.messagesById);
      newById[messageId] = updatedMsg;
      state = state.copyWith(messagesById: newById);
    }

    try {
      final response = await _socketService.emitWithAck('message:edit', {
        'conversationId': chatId,
        'messageId': messageId,
        'text': newText,
      });

      if (response['ok'] == true) {
         Logger.log('Message edited successfully');
      } else {
         Logger.log('Server rejected edit message: ${response['error']}');
         // Revert on error
         if (msg != null) {
           await _messageDao.updateMessageText(messageId, msg.text);
           final newById = Map<String, MessageModel>.from(state.messagesById);
           newById[messageId] = msg;
           state = state.copyWith(messagesById: newById);
         }
      }
    } catch (e) {
      Logger.log('Failed to edit message: $e');
      if (msg != null) {
        await _messageDao.updateMessageText(messageId, msg.text);
        final newById = Map<String, MessageModel>.from(state.messagesById);
        newById[messageId] = msg;
        state = state.copyWith(messagesById: newById);
      }
    }
  }

  Future<void> pinMessage(String messageId, bool isPinned) async {
    if (chatId == null) return;
    
    // 1. Optimistic Update
    final msg = state.messagesById[messageId];
    if (msg != null) {
      await _messageDao.updateMessagePinned(
        messageId,
        isPinned,
        pinnedAt: isPinned ? DateTime.now().toIso8601String() : null,
      );
      if (!mounted) return;
      final updatedMsg = msg.copyWith(isPinned: isPinned);
      final newById = Map<String, MessageModel>.from(state.messagesById);
      newById[messageId] = updatedMsg;
      state = state.copyWith(messagesById: newById);
    }

    try {
      final response = await _socketService.emitWithAck('message:pin', {
        'conversationId': chatId,
        'messageId': messageId,
        'isPinned': isPinned,
      });

      if (response['ok'] == true) {
         Logger.log('Message pinned successfully');
      } else {
         Logger.log('Server rejected pin message: ${response['error']}');
         // Revert on error
         if (msg != null) {
           await _messageDao.updateMessagePinned(messageId, msg.isPinned ?? false);
           final newById = Map<String, MessageModel>.from(state.messagesById);
           newById[messageId] = msg;
           state = state.copyWith(messagesById: newById);
         }
      }
    } catch (e) {
      Logger.log('Failed to pin message: $e');
      if (msg != null) {
        await _messageDao.updateMessagePinned(messageId, msg.isPinned ?? false);
        final newById = Map<String, MessageModel>.from(state.messagesById);
        newById[messageId] = msg;
        state = state.copyWith(messagesById: newById);
      }
    }
  }

  Future<void> sendImageAttachment(String filePath, {String? caption, String? replyToId}) async {
    if (chatId == null) return;
    String? pendingClientMsgId;
    try {
      await _ensureCurrentUserId();
      final clientMsgId = const Uuid().v4();
      pendingClientMsgId = clientMsgId;
      final tempId = 'temp_$clientMsgId';
      final now = DateTime.now();
      final formattedTime = DateFormat('hh:mm a').format(now);

      await _messageDao.insertOrUpdateMessage(MessageDto(
        id: tempId,
        clientMsgId: clientMsgId,
        conversationId: chatId!,
        senderId: currentUserId,
        type: 'IMAGE',
        text: caption ?? '',
        status: 'sending',
        createdAt: now.toIso8601String(),
        replyToId: replyToId,
        mediaUrl: filePath,
      ).toSqliteMap());
      if (!mounted) return;
      await loadFromDb(limitOverride: max(60, state.page * 60));

      // Update chat list immediately
      _ref.read(chatProvider.notifier).updateLastMessage(chatId!, '📷 Photo', formattedTime);

      // 2. Upload file via presigned S3 URL
      final uploadResult = await _uploadService.uploadMediaFile(
        filePath: filePath,
        purpose: 'message',
      );

      final String objectKey = uploadResult['key'] ?? '';
      final String publicUrl = uploadResult['publicUrl'] ?? objectKey;
      final String contentType = uploadResult['contentType'] ?? 'image/jpeg';
      final String fileName = uploadResult['fileName'] ?? 'image.jpg';

      final String attachmentUrl = objectKey.isNotEmpty ? objectKey : publicUrl;
      if (attachmentUrl.isEmpty) {
        Logger.log('Attachment URL missing from upload result, aborting send', type: "error");
        await _messageDao.updateMessageStatusByClientId(clientMsgId, 'failed');
        if (mounted) await loadFromDb(limitOverride: max(60, state.page * 60));
        return;
      }

      // 3. Construct attachment payload (without clientMsgId to pass server validation)
      final Map<String, dynamic> attachmentObj = {
        'type': 'IMAGE',
        'url': attachmentUrl,
        'mimeType': contentType,
        'fileName': fileName,
      };

      final payload = {
        'conversationId': chatId,
        'clientMsgId': clientMsgId,
        'type': 'IMAGE',
        'text': caption ?? '',
        'attachments': [attachmentObj],
        if (replyToId != null) 'replyToId': replyToId,
      };

      // Save to outbox
      await _outboxDao.insertOutboxItem({
        'client_msg_id': clientMsgId,
        'conversation_id': chatId!,
        'action': 'SEND_MESSAGE',
        'payload_json': jsonEncode(payload),
        'created_at': DateTime.now().toIso8601String(),
      });

      final socketPayload = Map<String, dynamic>.from(payload)..remove('clientMsgId');
      final response = await _socketService.emitWithAck('message:send', socketPayload);
      if (response['ok'] == true) {
        await _outboxDao.deleteOutboxItem(clientMsgId);
        if (!mounted) return;
        final serverData = response['data'];
        if (serverData is Map) {
          await _replaceTempMessageWithServerData(
            clientMsgId,
            Map<String, dynamic>.from(serverData),
          );
        } else {
          await _messageDao.updateMessageStatusByClientId(clientMsgId, 'sent');
          if (mounted) await loadFromDb(limitOverride: max(60, state.page * 60));
        }
      } else {
        Logger.log('Server rejected image message: ${response['error']}');
        await _messageDao.updateMessageStatusByClientId(clientMsgId, 'queued');
        if (mounted) await loadFromDb(limitOverride: max(60, state.page * 60));
      }
      Logger.log('Image attachment message sent successfully with key $publicUrl');
    } catch (e) {
      Logger.log('Failed to upload and send image attachment: $e');
      if (pendingClientMsgId != null) {
        await _messageDao.updateMessageStatusByClientId(pendingClientMsgId, 'failed');
        if (mounted) await loadFromDb(limitOverride: max(60, state.page * 60));
      }
    }
  }

  Future<void> sendFileAttachment(String filePath, {String? caption, String? replyToId}) async {
    if (chatId == null) return;
    String? pendingClientMsgId;
    try {
      await _ensureCurrentUserId();
      final clientMsgId = const Uuid().v4();
      pendingClientMsgId = clientMsgId;
      final tempId = 'temp_$clientMsgId';
      final now = DateTime.now();
      final formattedTime = DateFormat('hh:mm a').format(now);

      await _messageDao.insertOrUpdateMessage(MessageDto(
        id: tempId,
        clientMsgId: clientMsgId,
        conversationId: chatId!,
        senderId: currentUserId,
        type: 'FILE',
        text: caption ?? '',
        status: 'sending',
        createdAt: now.toIso8601String(),
        replyToId: replyToId,
        mediaUrl: filePath,
      ).toSqliteMap());
      if (!mounted) return;
      await loadFromDb(limitOverride: max(60, state.page * 60));

      // Update chat list immediately
      _ref.read(chatProvider.notifier).updateLastMessage(chatId!, '📁 Attachment', formattedTime);

      // 2. Upload file via presigned S3 URL
      final uploadResult = await _uploadService.uploadMediaFile(
        filePath: filePath,
        purpose: 'message',
      );

      final String objectKey = uploadResult['key'] ?? '';
      final String publicUrl = uploadResult['publicUrl'] ?? objectKey;
      final String contentType = uploadResult['contentType'] ?? 'application/octet-stream';
      final String fileName = uploadResult['fileName'] ?? filePath.split('/').last.split('\\').last;

      final String attachmentUrl = objectKey.isNotEmpty ? objectKey : publicUrl;
      if (attachmentUrl.isEmpty) {
        Logger.log('Attachment URL missing from upload result, aborting send', type: "error");
        await _messageDao.updateMessageStatusByClientId(clientMsgId, 'failed');
        if (mounted) await loadFromDb(limitOverride: max(60, state.page * 60));
        return;
      }

      // 3. Construct attachment payload
      final Map<String, dynamic> attachmentObj = {
        'type': 'FILE',
        'url': attachmentUrl,
        'mimeType': contentType,
        'fileName': fileName,
      };

      final payload = {
        'conversationId': chatId,
        'clientMsgId': clientMsgId,
        'type': 'FILE',
        'text': caption ?? '',
        'attachments': [attachmentObj],
        if (replyToId != null) 'replyToId': replyToId,
      };

      // Save to outbox
      await _outboxDao.insertOutboxItem({
        'client_msg_id': clientMsgId,
        'conversation_id': chatId!,
        'action': 'SEND_MESSAGE',
        'payload_json': jsonEncode(payload),
        'created_at': DateTime.now().toIso8601String(),
      });

      final socketPayload = Map<String, dynamic>.from(payload)..remove('clientMsgId');
      final response = await _socketService.emitWithAck('message:send', socketPayload);
      if (response['ok'] == true) {
        await _outboxDao.deleteOutboxItem(clientMsgId);
        if (!mounted) return;
        final serverData = response['data'];
        if (serverData is Map) {
          await _replaceTempMessageWithServerData(
            clientMsgId,
            Map<String, dynamic>.from(serverData),
          );
        } else {
          await _messageDao.updateMessageStatusByClientId(clientMsgId, 'sent');
          if (mounted) await loadFromDb(limitOverride: max(60, state.page * 60));
        }
      } else {
        Logger.log('Server rejected file message: ${response['error']}');
        await _messageDao.updateMessageStatusByClientId(clientMsgId, 'queued');
        if (mounted) await loadFromDb(limitOverride: max(60, state.page * 60));
      }
      Logger.log('File attachment message sent successfully with key $publicUrl');
    } catch (e) {
      Logger.log('Failed to upload and send file attachment: $e');
      if (pendingClientMsgId != null) {
        await _messageDao.updateMessageStatusByClientId(pendingClientMsgId, 'failed');
        if (mounted) await loadFromDb(limitOverride: max(60, state.page * 60));
      }
    }
  }

  Future<void> reactToMessage(String messageId, String emoji, [bool? isAddedParam]) async {
    if (chatId == null) return;
    
    // 1. Optimistic Update in Memory
    final msg = state.messagesById[messageId];
    if (msg != null) {
      final currentReactions = msg.reactions != null ? List<Map<String, dynamic>>.from(msg.reactions!) : <Map<String, dynamic>>[];
      
      // Determine if adding or removing (toggle logic)
      final hasReacted = currentReactions.any((r) => r['emoji'] == emoji && r['userId'] == currentUserId);
      final isAdded = isAddedParam ?? !hasReacted;

      if (isAdded) {
        // Add the reaction optimistically
        if (!hasReacted) {
          currentReactions.add({
            'emoji': emoji,
            'userId': currentUserId, 
            'messageId': messageId,
          });
        }
      } else {
        // Remove the reaction optimistically
        final index = currentReactions.indexWhere((r) => r['emoji'] == emoji && r['userId'] == currentUserId);
        if (index != -1) {
          currentReactions.removeAt(index);
        }
      }
      
      await _messageDao.updateMessageReactions(messageId, jsonEncode(currentReactions));
      if (!mounted) return;
      final updatedMsg = msg.copyWith(reactions: currentReactions);
      final newById = Map<String, MessageModel>.from(state.messagesById);
      newById[messageId] = updatedMsg;
      state = ChatState(messageIds: state.messageIds, messagesById: newById);
      
      // 2. Emit to Socket
      try {
        final response = await _socketService.emitWithAck('message:react', {
          'conversationId': chatId,
          'messageId': messageId,
          'emoji': emoji,
          'isAdded': isAdded,
        });
        if (response['ok'] != true) {
          await _messageDao.updateMessageReactions(
            messageId,
            jsonEncode(msg.reactions ?? const []),
          );
          if (!mounted) return;
          final reverted = Map<String, MessageModel>.from(state.messagesById);
          reverted[messageId] = msg;
          state = state.copyWith(messagesById: reverted);
        }
      } catch (e) {
        Logger.log('Failed to react to message: $e');
        await _messageDao.updateMessageReactions(
          messageId,
          jsonEncode(msg.reactions ?? const []),
        );
        if (mounted) {
          final reverted = Map<String, MessageModel>.from(state.messagesById);
          reverted[messageId] = msg;
          state = state.copyWith(messagesById: reverted);
        }
      }
    }
  }
}
