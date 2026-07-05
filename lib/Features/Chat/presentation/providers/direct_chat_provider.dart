import 'dart:async';
import 'package:app/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import '../../data/models/message_model.dart';
import '../../../../core/database/daos/message_dao.dart';
import '../../../../core/database/daos/outbox_dao.dart';
import '../../../../core/models/message_dto.dart';
import '../../../../core/network/chat_repository.dart';
import '../../../../core/providers/api_provider.dart';
import '../../../../core/services/socket_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

class ChatState {
  final List<String> messageIds;
  final Map<String, MessageModel> messagesById;

  ChatState({
    required this.messageIds,
    required this.messagesById,
  });

  factory ChatState.initial() => ChatState(messageIds: [], messagesById: {});
}

final currentChatIdProvider = StateProvider<String?>((ref) => null);

final typingStatusProvider = StateProvider.family<bool, String>((ref, chatId) => false);

final directChatProvider = StateNotifierProvider<DirectChatNotifier, ChatState>((ref) {
  final chatId = ref.watch(currentChatIdProvider);
  final chatRepo = ref.watch(chatRepositoryProvider);
  final socketService = ref.watch(socketServiceProvider);
  final authState = ref.watch(authProvider);
  final currentUserId = authState.id ?? '17e2377c-2221-4c39-b9b0-9ad4dc770f48'; // fallback
  return DirectChatNotifier(chatId, ref, chatRepo, socketService, currentUserId);
});

class DirectChatNotifier extends StateNotifier<ChatState> {
  final String? chatId;
  final Ref _ref;
  final ChatRepository _chatRepository;
  final SocketService _socketService;
  final MessageDao _messageDao = MessageDao();
  final OutboxDao _outboxDao = OutboxDao();
  final String currentUserId;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _messageEditedSubscription;
  StreamSubscription? _messageDeletedSubscription;
  StreamSubscription? _messagePinnedSubscription;
  StreamSubscription? _messageUnpinnedSubscription;
  StreamSubscription? _messageReactionSubscription;
  StreamSubscription? _userActionSubscription;
  StreamSubscription? _reconnectSubscription;
  Timer? _typingResetTimer;   // receiver side: typing indicator hide timer
  Timer? _typingDebounce;     // sender side: debounce emit — max 1 emit per 3s
  bool _isTypingEmitted = false;

  DirectChatNotifier(this.chatId, this._ref, this._chatRepository, this._socketService, this.currentUserId) : super(ChatState.initial()) {
    if (chatId != null) {
      _init();
    }
  }

  Future<void> _init() async {
    _messageSubscription = _socketService.onNewMessage.listen((data) async {
      Logger.log('📨 NEW MESSAGE EVENT received — data: $data');
      Logger.log('📨 Checking chatId match: data.conversationId=${data['conversationId']}, data.chatId=${data['chatId']}, our chatId=$chatId');
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        Logger.log('✅ NEW MESSAGE matched our chat — processing...');
        final messageData = data['message'] ?? data;
        
        if (messageData['clientMsgId'] != null) {
           await _outboxDao.deleteOutboxItem(messageData['clientMsgId']);
        } else if (messageData['senderId'] == currentUserId) {
           // Fallback: match by text if backend strips clientMsgId
           final outboxItems = await _outboxDao.getPendingMessages(chatId!);
           for (var item in outboxItems) {
              final payload = jsonDecode(item['payload_json']);
              if (payload['text'] == messageData['text']) {
                  await _outboxDao.deleteOutboxItem(item['client_msg_id']);
                  break;
              }
           }
        }
        // Save incoming/confirmed message to DB
        final dto = MessageDto.fromJson(messageData);
        await _messageDao.insertOrUpdateMessages([dto.toSqliteMap()]);
        
        // Reload UI
        await loadFromDb();
      } else {
        Logger.log('❌ NEW MESSAGE chatId mismatch — ignored');
      }
    });

    _messageEditedSubscription = _socketService.onMessageUpdated.listen((data) async {
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        final messageData = data['message'] ?? data;
        final dto = MessageDto.fromJson(messageData);
        await _messageDao.insertOrUpdateMessages([dto.toSqliteMap()]);
        await loadFromDb();
      }
    });

    _messageDeletedSubscription = _socketService.onMessageDeleted.listen((data) async {
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        final msgId = data['messageId'];
        if (msgId != null) {
          await _messageDao.deleteMessage(msgId);
          await loadFromDb();
        }
      }
    });

    _messagePinnedSubscription = _socketService.onMessagePinned.listen((data) async {
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        final messageData = data['message'] ?? data;
        final dto = MessageDto.fromJson(messageData);
        await _messageDao.insertOrUpdateMessages([dto.toSqliteMap()]);
        await loadFromDb();
      }
    });

    _messageUnpinnedSubscription = _socketService.onMessageUnpinned.listen((data) async {
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        final messageData = data['message'] ?? data;
        final dto = MessageDto.fromJson(messageData);
        await _messageDao.insertOrUpdateMessages([dto.toSqliteMap()]);
        await loadFromDb();
      }
    });

    _messageReactionSubscription = _socketService.onMessageReactionUpdated.listen((data) async {
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        final msgId = data['messageId'];
        final reactions = data['reactions'];
        if (msgId != null && reactions != null) {
          await _messageDao.updateMessageReactions(msgId, jsonEncode(reactions));
          await loadFromDb();
        }
      }
    });

    _userActionSubscription = _socketService.onUserTyping.listen((data) {
      Logger.log('⌨️ TYPING EVENT received — data: $data, our chatId: $chatId');
      if (data['chatId'] == chatId || data['conversationId'] == chatId) {
        Logger.log('✅ TYPING matched our chat — showing indicator');
        _ref.read(typingStatusProvider(chatId!).notifier).state = true;
        
        _typingResetTimer?.cancel();
        _typingResetTimer = Timer(const Duration(seconds: 3), () {
           if (mounted) _ref.read(typingStatusProvider(chatId!).notifier).state = false;
        });
      } else {
        Logger.log('❌ TYPING chatId mismatch — ignored');
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
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageEditedSubscription?.cancel();
    _messageDeletedSubscription?.cancel();
    _messagePinnedSubscription?.cancel();
    _messageUnpinnedSubscription?.cancel();
    _messageReactionSubscription?.cancel();
    _userActionSubscription?.cancel();
    _reconnectSubscription?.cancel();
    _typingResetTimer?.cancel();
    _typingDebounce?.cancel();
    super.dispose();
  }

  Future<void> loadFromDb() async {
    if (chatId == null) return;
    
    final msgRows = await _messageDao.getMessagesForChat(chatId!);
    final outboxRows = await _outboxDao.getPendingMessages(chatId!);
    
    
    // Convert DB rows to MessageModels
    final List<MessageModel> models = msgRows.map((row) => row.toMessageModel(currentUserId)).toList();
    
    // Also include pending outbox messages optimistically
    for (var outboxMsg in outboxRows) {
       final payload = jsonDecode(outboxMsg['payload_json']);
       models.add(MessageModel(
         id: 'temp_${outboxMsg['client_msg_id']}',
         text: payload['text'],
         time: 'Sending...',
         timestamp: DateTime.parse(outboxMsg['created_at']),
         isMe: true,
         status: MessageStatus.sending,
       ));
    }
    
    // Sort by timestamp descending (newest first)
    models.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    final List<String> ids = [];
    final Map<String, MessageModel> byId = {};
    for (var model in models) {
      if (model.id != null) {
        ids.add(model.id!);
        byId[model.id!] = model;
      }
    }
    
    state = ChatState(messageIds: ids, messagesById: byId);
  }

  Future<void> fetchMessagesFromServer() async {
    if (chatId == null) return;
    
    try {
      final response = await _chatRepository.getMessages(chatId!);
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> data = response['data'];
        
        final outboxItems = await _outboxDao.getPendingMessages(chatId!);

        final List<Map<String, dynamic>> sqliteRows = data.map((item) {
          if (item['senderId'] == currentUserId) {
            for (var outboxItem in outboxItems) {
               final payload = jsonDecode(outboxItem['payload_json']);
               if (payload['text'] == item['text']) {
                  _outboxDao.deleteOutboxItem(outboxItem['client_msg_id']);
                  break;
               }
            }
          }
          final dto = MessageDto.fromJson(item as Map<String, dynamic>);
          return dto.toSqliteMap();
        }).toList();

        await _messageDao.insertOrUpdateMessages(sqliteRows);
        await loadFromDb();
      }
    } catch (e) {
      print('Failed to fetch messages: $e');
    }
  }

  void emitTyping() {
    if (chatId == null) return;

    final payload = {
      'conversationId': chatId,
      'chatId': chatId,
    };

    // Leading-edge debounce:
    // প্রথম keystroke-এ তাৎক্ষণিক emit, তারপর 3 সেকেন্ড block
    // ফলে server-এ অতিরিক্ত hit হবে না
    if (!_isTypingEmitted) {
      _isTypingEmitted = true;
      try {
        _socketService.emit('message:typing', payload);
        Logger.log('⌨️ TYPING EMITTED (leading debounce)');
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

    final clientMsgId = const Uuid().v4();
    final now = DateTime.now();
    
    // Server 'replyToId' field accept করে না (VALIDATION_ERROR).
    // Reply শুধু local DB-তে save হবে এবং UI-তে দেখাবে।
    // Socket payload-এ replyToId পাঠানো হবে না।
    final payloadJson = {
      'conversationId': chatId,
      'text': text,
      'type': 'TEXT',
      'attachments': [],
      // replyToId intentionally removed — server does not support it yet
    };
    
    // 1. Optimistic Update (UI)
    final tempMsg = MessageModel(
      id: 'temp_$clientMsgId',
      text: text,
      time: 'Sending...',
      timestamp: now,
      isMe: true,
      status: MessageStatus.sending,
      replyToMessageId: replyToId, // শুধু locally রাখা হচ্ছে UI-এর জন্য
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
         // Message was sent successfully, we can remove it from outbox
         await _outboxDao.deleteOutboxItem(clientMsgId);
      } else {
         final errCode = (response['error'] as Map?)?['code'];
         Logger.log('Server rejected message: ${response['error']}');
         // VALIDATION_ERROR হলে outbox থেকে delete করো — retry করলে same error আসবে
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
      // Optimistic delete
      await _messageDao.deleteMessage(messageId);
      await loadFromDb();
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