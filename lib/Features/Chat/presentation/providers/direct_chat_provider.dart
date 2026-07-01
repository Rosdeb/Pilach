import 'dart:async';
import 'package:app/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
  StreamSubscription? _userActionSubscription;
  Timer? _typingResetTimer;
  DateTime? _lastTypingEmit;

  DirectChatNotifier(this.chatId, this._ref, this._chatRepository, this._socketService, this.currentUserId) : super(ChatState.initial()) {
    if (chatId != null) {
      _init();
    }
  }

  Future<void> _init() async {
    _messageSubscription = _socketService.onNewMessage.listen((data) async {
      if (data['conversationId'] == chatId || data['chatId'] == chatId) {
        if (data['clientMsgId'] != null) {
           await _outboxDao.deleteOutboxItem(data['clientMsgId']);
        } else if (data['senderId'] == currentUserId) {
           // Fallback: match by text if backend strips clientMsgId
           final outboxItems = await _outboxDao.getPendingMessages(chatId!);
           for (var item in outboxItems) {
              final payload = jsonDecode(item['payload_json']);
              if (payload['text'] == data['text']) {
                  await _outboxDao.deleteOutboxItem(item['client_msg_id']);
                  break;
              }
           }
        }
        // Save incoming/confirmed message to DB
        final dto = MessageDto.fromJson(data);
        await _messageDao.insertOrUpdateMessages([dto.toSqliteMap()]);
        
        // Reload UI
        await loadFromDb();
      }
    });

    _messageEditedSubscription = _socketService.onMessageEdited.listen((data) async {
      if (data['conversationId'] == chatId) {
        final dto = MessageDto.fromJson(data);
        await _messageDao.insertOrUpdateMessages([dto.toSqliteMap()]);
        await loadFromDb();
      }
    });

    _userActionSubscription = _socketService.onUserAction.listen((data) {
      if (data['action'] == 'typing') {
        _ref.read(typingStatusProvider(chatId!).notifier).state = true;
        
        _typingResetTimer?.cancel();
        _typingResetTimer = Timer(const Duration(seconds: 3), () {
           if (mounted) _ref.read(typingStatusProvider(chatId!).notifier).state = false;
        });
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
    _userActionSubscription?.cancel();
    _typingResetTimer?.cancel();
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
    
    // Sort by timestamp
    models.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
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
    // Throttle emits to once every 2 seconds to save bandwidth and prevent jank
    final now = DateTime.now();
    if (_lastTypingEmit != null && now.difference(_lastTypingEmit!).inSeconds < 2) {
      return;
    }
    _lastTypingEmit = now;

    try {
      _socketService.emit('message:typing', {
        'conversationId': chatId,
      });
    } catch (e) {
      Logger.log('Failed to emit typing: $e',type:"info");
    }
  }

  Future<void> sendMessage(String text) async {
    if (chatId == null || text.trim().isEmpty) return;

    final clientMsgId = const Uuid().v4();
    final now = DateTime.now();
    
    final payloadJson = {
      'conversationId': chatId,
      'text': text,
      'type': 'TEXT',
      'attachments': [],
      // 'clientMsgId': clientMsgId, // Removed because backend API spec doesn't allow it, might cause Unauthorized/Validation errors
    };
    
    // 1. Optimistic Update (UI)
    final tempMsg = MessageModel(
      id: 'temp_$clientMsgId',
      text: text,
      time: 'Sending...',
      timestamp: now,
      isMe: true,
      status: MessageStatus.sending,
    );
    
    final newIds = [...state.messageIds, tempMsg.id!];
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
      _socketService.emit('message:send', payloadJson);
      // Because socket.io `emit` is fire-and-forget, the real status update
      // happens when we receive `message:new` back from the socket.
      // SocketService should listen for `message:new`, save to DB, and remove from outbox.
    } catch (e) {
      print('Failed to emit message: $e');
    }
    
    // Reload from DB to reflect UI
    await loadFromDb();
  }
}