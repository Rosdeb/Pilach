import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/message_model.dart';
import '../../../../core/database/daos/message_dao.dart';
import '../../../../core/database/daos/outbox_dao.dart';
import '../../../../core/models/message_dto.dart';
import '../../../../core/network/chat_repository.dart';
import '../../../../core/providers/api_provider.dart';
import '../../../../core/services/socket_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

final currentChatIdProvider = StateProvider<String?>((ref) => null);

final directChatProvider = StateNotifierProvider<DirectChatNotifier, List<MessageModel>>((ref) {
  final chatId = ref.watch(currentChatIdProvider);
  final chatRepo = ref.watch(chatRepositoryProvider);
  final socketService = ref.watch(socketServiceProvider);
  return DirectChatNotifier(chatId, chatRepo, socketService);
});

class DirectChatNotifier extends StateNotifier<List<MessageModel>> {
  final String? chatId;
  final ChatRepository _chatRepository;
  final SocketService _socketService;
  final MessageDao _messageDao = MessageDao();
  final OutboxDao _outboxDao = OutboxDao();
  final String currentUserId = '17e2377c-2221-4c39-b9b0-9ad4dc770f48'; // Ideally from auth

  StreamSubscription? _messageSubscription;
  StreamSubscription? _messageEditedSubscription;

  DirectChatNotifier(this.chatId, this._chatRepository, this._socketService) : super([]) {
    if (chatId != null) {
      _init();
    }
  }

  Future<void> _init() async {
    // Listen to socket events
    _messageSubscription = _socketService.onNewMessage.listen((data) async {
      // Check if it belongs to this chat
      if (data['conversationId'] == chatId) {
        // Remove from outbox if it was our message
        if (data['clientMsgId'] != null) {
           await _outboxDao.deleteOutboxItem(data['clientMsgId']);
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

    // 1. Load instantly from local SQLite (Offline-first)
    await loadFromDb();
    
    // 2. Fetch latest from server
    await fetchMessagesFromServer();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageEditedSubscription?.cancel();
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
    state = models;
  }

  Future<void> fetchMessagesFromServer() async {
    if (chatId == null) return;
    
    try {
      final response = await _chatRepository.getMessages(chatId!);
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> data = response['data'];
        
        final List<Map<String, dynamic>> sqliteRows = data.map((item) {
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
    state = [...state, tempMsg];

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
      _socketService.emit('send', payloadJson);
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