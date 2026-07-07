import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:app/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/upload_service.dart';
import 'package:app/Features/Chat/data/models/message_model.dart';
import '../../../../core/database/daos/message_dao.dart';
import '../../../../core/database/daos/outbox_dao.dart';
import '../../../../core/models/message_dto.dart';
import '../../../../core/network/chat_repository.dart';
import '../../../../core/providers/api_provider.dart';
import '../../../../core/services/socket_service.dart';
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
  final authState = ref.watch(authProvider);
  return DirectChatNotifier(chatId, ref, chatRepo, socketService, uploadService, authState.id);
});

class DirectChatNotifier extends StateNotifier<ChatState> {
  final String? chatId;
  final Ref _ref;
  final ChatRepository _chatRepository;
  final SocketService _socketService;
  final UploadService _uploadService;
  final MessageDao _messageDao = MessageDao();
  final OutboxDao _outboxDao = OutboxDao();
  String _currentUserId; // Made mutable

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
  Timer? _typingResetTimer;   
  Timer? _typingDebounce;     
  bool _isTypingEmitted = false;

  DirectChatNotifier(this.chatId, this._ref, this._chatRepository, this._socketService, this._uploadService, String? initialUserId) 
    : _currentUserId = initialUserId ?? '', 
      super(ChatState.initial()) {
    if (chatId != null) {
      _init();
    }
  }

  String get currentUserId => _currentUserId;

  Future<String> _ensureCurrentUserId() async {
    if (_currentUserId.isNotEmpty) return _currentUserId;

    final authId = _ref.read(authProvider).id;
    if (authId != null && authId.isNotEmpty) {
      _currentUserId = authId;
      return _currentUserId;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getString('user_id');
    if (savedUserId != null && savedUserId.isNotEmpty) {
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
        final rawId = payload['id'] ?? payload['_id'] ?? payload['userId'] ?? payload['sub'];
        if (rawId != null) {
          _currentUserId = rawId.toString();
          await prefs.setString('user_id', _currentUserId);
          return _currentUserId;
        }
      } catch (_) {}
    }

    return _currentUserId;
  }

  Future<void> _init() async {
    await _ensureCurrentUserId();

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
            Logger.log('Message $msgId already handled by ACK, skipping broadcast overwrite.');
            return;
          }
          
          // Secondary fallback: if still no senderId, it MUST be our own message that lacked a temp match
          if (messageData['senderId'] == null || messageData['senderId'] == '') {
            messageData['senderId'] = currentUserId;
          }

          Logger.log('Parsing message data...');
          final dto = MessageDto.fromJson(messageData);
          final sqliteMap = dto.toSqliteMap();
          Logger.log('Saving message to DB: id=${sqliteMap['id']}');
          
          await _messageDao.insertOrUpdateMessages([sqliteMap]);
          
          // Directly insert/update in state without rebuilding all message objects from DB
          final newMsg = sqliteMap.toMessageModel(currentUserId);
          final newById = Map<String, MessageModel>.from(state.messagesById);
          List<String> newIds;
          
          if (matchedTempId != null) {
            newById.remove(matchedTempId);
            newById[newMsg.id!] = newMsg;
            newIds = state.messageIds.map((id) => id == matchedTempId ? newMsg.id! : id).toList();
          } else if (!state.messagesById.containsKey(newMsg.id)) {
            newById[newMsg.id!] = newMsg;
            newIds = [newMsg.id!, ...state.messageIds];
          } else {
            final existing = state.messagesById[newMsg.id!];
            if (existing != null) {
              newById[newMsg.id!] = existing.copyWith(
                seq: newMsg.seq ?? existing.seq,
                status: newMsg.status,
                text: (newMsg.text.isNotEmpty) ? newMsg.text : existing.text,
                mediaUrl: (newMsg.mediaUrl != null && newMsg.mediaUrl!.isNotEmpty) ? newMsg.mediaUrl : existing.mediaUrl,
              );
            } else {
              newById[newMsg.id!] = newMsg;
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
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        final messageData = data['message'] ?? data;
        final dto = MessageDto.fromJson(messageData);
        final sqliteMap = dto.toSqliteMap();
        await _messageDao.insertOrUpdateMessages([sqliteMap]);
        final updatedMsg = sqliteMap.toMessageModel(currentUserId);
        if (state.messagesById.containsKey(updatedMsg.id)) {
          final newById = Map<String, MessageModel>.from(state.messagesById);
          newById[updatedMsg.id!] = updatedMsg;
          state = state.copyWith(messagesById: newById);
        }
      }
    });

    _messageDeletedSubscription = _socketService.onMessageDeleted.listen((data) async {
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        final msgId = data['messageId'] as String?;
        if (msgId != null) {
          final existing = state.messagesById[msgId];
          if (existing != null) {
            final updatedMsg = existing.copyWith(isDeleted: true);
            final newById = Map<String, MessageModel>.from(state.messagesById);
            newById[msgId] = updatedMsg;
            state = state.copyWith(messagesById: newById);
          }
        }
      }
    });

    _messagePinnedSubscription = _socketService.onMessagePinned.listen((data) async {
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        final messageData = data['message'] ?? data;
        final dto = MessageDto.fromJson(messageData);
        final sqliteMap = dto.toSqliteMap();
        await _messageDao.insertOrUpdateMessages([sqliteMap]);
        final updatedMsg = sqliteMap.toMessageModel(currentUserId);
        if (state.messagesById.containsKey(updatedMsg.id)) {
          final newById = Map<String, MessageModel>.from(state.messagesById);
          newById[updatedMsg.id!] = updatedMsg;
          state = state.copyWith(messagesById: newById);
        }
      }
    });

    _messageUnpinnedSubscription = _socketService.onMessageUnpinned.listen((data) async {
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        final messageData = data['message'] ?? data;
        final dto = MessageDto.fromJson(messageData);
        final sqliteMap = dto.toSqliteMap();
        await _messageDao.insertOrUpdateMessages([sqliteMap]);
        final updatedMsg = sqliteMap.toMessageModel(currentUserId);
        if (state.messagesById.containsKey(updatedMsg.id)) {
          final newById = Map<String, MessageModel>.from(state.messagesById);
          newById[updatedMsg.id!] = updatedMsg;
          state = state.copyWith(messagesById: newById);
        }
      }
    });

    _messageReactionSubscription = _socketService.onMessageReactionUpdated.listen((data) async {
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        final msgId = data['messageId'] as String?;
        final reactions = data['reactions'];
        if (msgId != null && reactions != null) {
          await _messageDao.updateMessageReactions(msgId, jsonEncode(reactions));
          final existing = state.messagesById[msgId];
          if (existing != null) {
            final List<Map<String, dynamic>> parsed = List<Map<String, dynamic>>.from(reactions);
            final updatedMsg = existing.copyWith(reactions: parsed);
            final newById = Map<String, MessageModel>.from(state.messagesById);
            newById[msgId] = updatedMsg;
            state = state.copyWith(messagesById: newById);
          }
        }
      }
    });

    _messageReadReceiptSubscription = _socketService.onMessageReadReceipt.listen((data) async {
      Logger.log('👁️ READ RECEIPT received — data: $data');
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        final int? readSeq = (data['seq'] ?? data['lastReadSeq']) as int?;
        if (readSeq != null && mounted) {
          if (chatId != null) {
            await _messageDao.updateMessageStatusUpToSeq(chatId!, 'seen', readSeq);
          }
          final newById = Map<String, MessageModel>.from(state.messagesById);
          bool hasChanges = false;
          newById.forEach((id, msg) {
            if (msg.isMe && (msg.seq == null || msg.seq! <= readSeq) && msg.status != MessageStatus.seen) {
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
        final int? deliveredSeq = (data['seq'] ?? data['lastDeliveredSeq']) as int?;
        if (deliveredSeq != null && mounted) {
          if (chatId != null) {
            await _messageDao.updateMessageStatusUpToSeq(chatId!, 'delivered', deliveredSeq);
          }
          final newById = Map<String, MessageModel>.from(state.messagesById);
          bool hasChanges = false;
          newById.forEach((id, msg) {
            if (msg.isMe && (msg.seq == null || msg.seq! <= deliveredSeq) && (msg.status == MessageStatus.sent || msg.status == MessageStatus.sending)) {
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
       final pending = await _outboxDao.getPendingMessages(chatId!);
       if (pending.isEmpty) return;

       Logger.log('🚀 SOCKET: Reconnected! Flushing ${pending.length} outbox messages for chat $chatId');

       for (final item in pending) {
          try {
            final payload = jsonDecode(item['payload_json']);
            final cleanPayload = Map<String, dynamic>.from(payload)
              ..remove('replyToId');

            final response = await _socketService.emitWithAck('message:send', cleanPayload);

            if (response['ok'] == true) {
              // ✅ Outbox থেকে delete করো
              await _outboxDao.deleteOutboxItem(item['client_msg_id']);
              Logger.log('✅ Queued message sent: ${item['client_msg_id']}');

              // ✅ loadFromDb() না — state-এ directly temp message update করো
              // "Sending..." সরিয়ে actual time বসাও 
              // message:new আসলে real message দিয়ে replace হবে
              final tempId = 'temp_${item['client_msg_id']}';
              final tempMsg = state.messagesById[tempId];
              if (tempMsg != null && mounted) {
                final formattedTime = DateFormat('hh:mm a').format(DateTime.now().toLocal());
                final updatedMsg = tempMsg.copyWith(
                  time: formattedTime,
                  status: MessageStatus.sent,
                );
                final newById = Map<String, MessageModel>.from(state.messagesById);
                newById[tempId] = updatedMsg;
                state = ChatState(messageIds: state.messageIds, messagesById: newById);
              }
            } else {
              final errCode = (response['error'] as Map?)?['code'];
              Logger.log('❌ Server rejected queued message: ${response['error']}');
              // VALIDATION_ERROR → retry করলে same error, তাই delete
              if (errCode == 'VALIDATION_ERROR') {
                await _outboxDao.deleteOutboxItem(item['client_msg_id']);
                // সরাসরি state থেকেও বাদ দাও
                final tempId = 'temp_${item['client_msg_id']}';
                if (mounted && state.messagesById.containsKey(tempId)) {
                  final newIds = state.messageIds.where((id) => id != tempId).toList();
                  final newById = Map<String, MessageModel>.from(state.messagesById)
                    ..remove(tempId);
                  state = ChatState(messageIds: newIds, messagesById: newById);
                }
              }
            }
          } catch (e) {
            Logger.log('Failed to flush outbox item: $e');
          }
       }
    });

    // 1. Load instantly from local SQLite (Offline-first)
    await loadFromDb();
    
    // 2. Fetch latest from server
    await fetchMessagesFromServer();
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

  Future<void> loadFromDb() async {
    if (chatId == null) return;
    
    // Load local messages up to current loaded count (at least page * 30)
    final limit = (state.messageIds.length > state.page * 30)
        ? state.messageIds.length
        : state.page * 30;
    final msgRows = await _messageDao.getMessagesForChat(chatId!, limit: limit);
    if (!mounted) return;
    final outboxRows = await _outboxDao.getPendingMessages(chatId!);
    if (!mounted) return;
    final userId = currentUserId;

    // Heavy mapping and sorting offloaded to background Isolate
    final List<MessageModel> models = await Isolate.run(() {
      final List<MessageModel> list = msgRows.map((row) => row.toMessageModel(userId)).toList();
      
      for (var outboxMsg in outboxRows) {
        final payload = jsonDecode(outboxMsg['payload_json']);
        list.add(MessageModel(
          id: 'temp_${outboxMsg['client_msg_id']}',
          text: payload['text'] ?? '',
          time: 'Sending...',
          timestamp: DateTime.parse(outboxMsg['created_at']),
          isMe: true,
          status: MessageStatus.sending,
        ));
      }
      
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
    
    if (!mounted) return;
    
    final List<String> ids = [];
    final Map<String, MessageModel> byId = {};
    for (var model in models) {
      if (model.id != null) {
        ids.add(model.id!);
        byId[model.id!] = model;
      }
    }
    
    // Optimize: Only update Riverpod state if message IDs list or message contents have changed
    final bool changed = _hasStateChanged(state.messageIds, ids, state.messagesById, byId);
    if (changed) {
      state = state.copyWith(messageIds: ids, messagesById: byId);
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

        if (outboxItems.isNotEmpty) {
          final outboxTexts = outboxItems.map((e) {
            final payload = jsonDecode(e['payload_json']);
            return MapEntry(e['client_msg_id'] as String, payload['text']);
          }).toList();

          for (var row in sqliteRows) {
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

        await _messageDao.insertOrUpdateMessages(sqliteRows);
        if (!mounted) return;
        
        state = state.copyWith(page: page, hasMore: hasNext);
        await loadFromDb();
      }
    } catch (e) {
      print('Failed to fetch messages: $e');
    }
  }

  Future<void> loadMore() async {
    if (!mounted || state.isLoadingMore || !state.hasMore) return;
    
    state = state.copyWith(isLoadingMore: true);
    
    final nextPage = state.page + 1;
    await fetchMessagesFromServer(page: nextPage);
    
    if (!mounted) return;
    state = state.copyWith(isLoadingMore: false);
  }

  void emitTyping() {
    if (chatId == null) return;

    final conversationPayload = {
      'conversationId': chatId,
    };
    final chatPayload = {
      'chatId': chatId,
    };

    // Leading-edge debounce:
    // প্রথম keystroke-এ তাৎক্ষণিক emit, তারপর 3 সেকেন্ড block
    // ফলে server-এ অতিরিক্ত hit হবে না
    if (!_isTypingEmitted) {
      _isTypingEmitted = true;
      try {
        _socketService.emit('message:typing', conversationPayload);
        _socketService.emit('user:typing', chatPayload);
        Logger.log('⌨️ TYPING EMITTED (message:typing & user:typing)');
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

  Future<void> sendMessage(String text, {String? replyToId}) async {
    if (chatId == null || text.trim().isEmpty) return;

    await _ensureCurrentUserId();
    print('🚀 [SEND MESSAGE] text: "$text"');
    final clientMsgId = const Uuid().v4();
    final now = DateTime.now();
    
    final payloadJson = {
      'conversationId': chatId,
      'text': text,
      'type': 'TEXT',
      'attachments': [],
    };
    
    // 1. Optimistic Update (UI)
    final tempMsg = MessageModel(
      id: 'temp_$clientMsgId',
      text: text,
      time: 'Sending...',
      timestamp: now,
      isMe: true,
      senderId: currentUserId,
      status: MessageStatus.sending,
      replyToMessageId: replyToId,
    );
    
    final newIds = [tempMsg.id!, ...state.messageIds];
    final newById = Map<String, MessageModel>.from(state.messagesById);
    newById[tempMsg.id!] = tempMsg;
    state = ChatState(messageIds: newIds, messagesById: newById);

    // 2. Save to Outbox (Offline support)
    await _outboxDao.insertOutboxItem({
      'client_msg_id': clientMsgId,
      'conversation_id': chatId!,
      'action': 'SEND_MESSAGE',
      'payload_json': jsonEncode(payloadJson),
      'created_at': now.toIso8601String(),
    });

    // 3. Try to emit via socket
    try {
      final response = await _socketService.emitWithAck('message:send', payloadJson);
      
      if (response['ok'] == true) {
         await _outboxDao.deleteOutboxItem(clientMsgId);
         
         if (!mounted) return;
         final serverData = response['data'];
         if (serverData != null) {
            final tId = 'temp_$clientMsgId';
            final existing = state.messagesById[tId];
            if (existing != null) {
              final newMsg = existing.copyWith(
                id: serverData['id'],
                seq: serverData['seq'],
                status: MessageStatus.sent,
                time: DateFormat('hh:mm a').format(now),
              );
              final newById = Map<String, MessageModel>.from(state.messagesById);
              newById.remove(tId);
              newById[newMsg.id!] = newMsg;
              final newIds = state.messageIds.map((e) => e == tId ? newMsg.id! : e).toList();
              state = state.copyWith(messageIds: newIds, messagesById: newById);
              
              final sqliteMap = MessageDto(
                id: newMsg.id!,
                clientMsgId: clientMsgId,
                conversationId: chatId!,
                seq: newMsg.seq,
                senderId: currentUserId,
                type: 'TEXT',
                text: text,
                status: 'sent',
                createdAt: now.toIso8601String(),
              ).toSqliteMap();
              await _messageDao.insertOrUpdateMessages([sqliteMap]);
            }
         }
      } else {
         final errCode = (response['error'] as Map?)?['code'];
         Logger.log('Server rejected message: ${response['error']}');
         if (errCode == 'VALIDATION_ERROR') {
           await _outboxDao.deleteOutboxItem(clientMsgId);
         }
      }
    } catch (e) {
      Logger.log('Failed to emit message: $e');
    }

    // ✅ ok==true হলে loadFromDb() এখনই call করব না
    // কারণ DB তে এখনো real message নেই — message:new event আসলে সেটা handle করবে
    // temp message state-এ থাকবে যতক্ষণ না message:new আসে
    //
    // ❌ NOT_CONNECTED বা error হলে outbox-এ আছে — loadFromDb() call করো
    // যাতে "Sending..." দেখায় (outbox থেকে temp message আসবে)
  }

  Future<void> deleteMessage(String messageId) async {
    if (chatId == null) return;
    try {
      _socketService.emit('message:delete', {
        'conversationId': chatId,
        'messageId': messageId,
      });
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

  Future<void> pinMessage(String messageId, bool isPinned) async {
    if (chatId == null) return;
    try {
      _socketService.emit('message:pin', {
        'conversationId': chatId,
        'messageId': messageId,
        'isPinned': isPinned,
      });
    } catch (e) {
      Logger.log('Failed to pin message: $e');
    }
  }

  Future<void> sendImageAttachment(String filePath, {String? caption}) async {
    if (chatId == null) return;
    try {
      final clientMsgId = const Uuid().v4();
      final tempId = 'temp_$clientMsgId';
      final formattedTime = DateFormat('hh:mm a').format(DateTime.now());

      // 1. Optimistic insertion into UI
      final optimisticMsg = MessageModel(
        id: tempId,
        text: caption ?? '',
        time: formattedTime,
        timestamp: DateTime.now(),
        isMe: true,
        type: MessageType.image,
        mediaUrl: filePath,
        status: MessageStatus.sending,
      );

      final newById = Map<String, MessageModel>.from(state.messagesById);
      newById[tempId] = optimisticMsg;
      final newIds = [tempId, ...state.messageIds];
      state = state.copyWith(messageIds: newIds, messagesById: newById);

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
        'type': 'IMAGE',
        'text': caption ?? '',
        'attachments': [attachmentObj],
      };

      // Save to outbox
      await _outboxDao.insertOutboxItem({
        'client_msg_id': clientMsgId,
        'conversation_id': chatId!,
        'action': 'SEND_MESSAGE',
        'payload_json': jsonEncode(payload),
        'created_at': DateTime.now().toIso8601String(),
      });

      final response = await _socketService.emitWithAck('message:send', payload);
      if (response['ok'] == true) {
        await _outboxDao.deleteOutboxItem(clientMsgId);
        if (!mounted) return;
        final serverData = response['data'];
        if (serverData != null) {
          final tId = 'temp_$clientMsgId';
          final existing = state.messagesById[tId];
          if (existing != null) {
            final newMsg = existing.copyWith(
              id: serverData['id'],
              seq: serverData['seq'],
              status: MessageStatus.sent,
              time: DateFormat('hh:mm a').format(DateTime.now()),
            );
            final newById = Map<String, MessageModel>.from(state.messagesById);
            newById.remove(tId);
            newById[newMsg.id!] = newMsg;
            final newIds = state.messageIds.map((e) => e == tId ? newMsg.id! : e).toList();
            state = state.copyWith(messageIds: newIds, messagesById: newById);
            
            final sqliteMap = MessageDto(
              id: newMsg.id!,
              clientMsgId: clientMsgId,
              conversationId: chatId!,
              seq: newMsg.seq,
              senderId: currentUserId,
              type: 'IMAGE',
              text: caption ?? '',
              status: 'sent',
              createdAt: DateTime.now().toIso8601String(),
              mediaUrl: publicUrl,
            ).toSqliteMap();
            await _messageDao.insertOrUpdateMessages([sqliteMap]);
          }
        }
      } else {
        final errCode = (response['error'] as Map?)?['code'];
        Logger.log('Server rejected image message: ${response['error']}');
        if (errCode == 'VALIDATION_ERROR') {
          await _outboxDao.deleteOutboxItem(clientMsgId);
        }
      }
      Logger.log('Image attachment message sent successfully with key $publicUrl');
    } catch (e) {
      Logger.log('Failed to upload and send image attachment: $e');
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
      
      final updatedMsg = msg.copyWith(reactions: currentReactions);
      final newById = Map<String, MessageModel>.from(state.messagesById);
      newById[messageId] = updatedMsg;
      state = ChatState(messageIds: state.messageIds, messagesById: newById);
      
      // Also optionally save optimistically to DB so it persists until server responds
      _messageDao.updateMessageReactions(messageId, jsonEncode(currentReactions));

      // 2. Emit to Socket
      try {
        _socketService.emit('message:react', {
          'conversationId': chatId,
          'messageId': messageId,
          'emoji': emoji,
          'isAdded': isAdded,
        });
      } catch (e) {
        Logger.log('Failed to react to message: $e');
      }
    }
  }
}