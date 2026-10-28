import 'package:app/core/utils/app_logger.dart';
import 'package:app/core/utils/date_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:app/core/models/message_dto.dart';
import 'package:app/core/network/chat_repository.dart';
import 'package:app/core/providers/api_provider.dart';
import 'package:app/Features/Chat/data/models/chat_model.dart';
import 'package:app/core/database/daos/chat_dao.dart';
import 'package:app/core/database/daos/message_dao.dart';
import 'package:app/core/models/chat_dto.dart';
import 'package:app/core/services/socket_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:app/core/database/daos/outbox_dao.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/Features/Chat/presentation/providers/direct_chat_provider.dart';
import 'package:app/Features/auth/presentation/providers/auth_provider.dart';

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatModel>>((
  ref,
) {
  final chatRepo = ref.watch(chatRepositoryProvider);
  final socketService = ref.watch(socketServiceProvider);
  return ChatNotifier(ref, chatRepo, socketService);
});

class ChatNotifier extends StateNotifier<List<ChatModel>> {
  final Ref _ref;
  final ChatDao _chatDao = ChatDao();
  final MessageDao _messageDao = MessageDao();
  final ChatRepository _chatRepository;
  final SocketService _socketService;
  StreamSubscription? _onlineSub;
  StreamSubscription? _offlineSub;
  StreamSubscription? _newMessageSub;
  StreamSubscription<void>? _reconnectSub;
  StreamSubscription? _reactionSub;
  StreamSubscription? _typingSub;
  final Map<String, Timer> _typingTimers = {};
  final List<StreamSubscription<Map<String, dynamic>>> _metadataSubscriptions =
      [];
  Timer? _metadataRefreshDebounce;
  String _currentUserId = '';

  ChatNotifier(this._ref, this._chatRepository, this._socketService)
    : super([]) {
    _init();
    _listenToPresence();
    _listenToNewMessages();
    _listenToChatChanges();
    _listenToReactions();
    _listenToTyping();
    _reconnectSub = _socketService.onReconnected.listen((_) {
      unawaited(_syncAfterReconnect());
    });
  }

  void _listenToNewMessages() {
    _newMessageSub = _socketService.onNewMessage.listen((data) async {
      try {
        final rawMessageData = data['message'] ?? data;
        if (rawMessageData is! Map) return;
        final messageData = Map<String, dynamic>.from(rawMessageData);
        final conversationId =
            (data['conversationId'] ??
                    data['chatId'] ??
                    messageData['conversationId'] ??
                    messageData['chatId'])
                ?.toString();
        if (conversationId == null || conversationId.isEmpty) return;

        // Reset typing indicator when a new message arrives from that chat
        _typingTimers[conversationId]?.cancel();
        _ref.read(typingStatusProvider(conversationId).notifier).state = false;
        _ref.read(typingUserNameProvider(conversationId).notifier).state = null;

        // If the broadcast is minimal, try to fill it from SQLite or Outbox
        final String? msgId = (messageData['id'] ?? messageData['messageId'])
            ?.toString();
        if (msgId != null &&
            (messageData['senderId'] == null || messageData['text'] == null)) {
          final localMsg = await _messageDao.getMessageById(msgId);
          if (localMsg != null) {
            messageData['senderId'] ??= localMsg['sender_id'];
            messageData['text'] ??= localMsg['text'];
            messageData['type'] ??= localMsg['type'];
            messageData['createdAt'] ??= localMsg['created_at'];
          }
        }
        final clientMsgId = messageData['clientMsgId']?.toString();
        if (messageData['text'] == null &&
            (clientMsgId != null ||
                messageData['senderId'] == null ||
                messageData['senderId'] == _currentUserId)) {
          final outboxDao = OutboxDao();
          final pending = await outboxDao.getPendingMessages(conversationId);
          if (pending.isNotEmpty) {
            for (var item in pending) {
              if (clientMsgId != null && item['client_msg_id'] == clientMsgId) {
                final payload = jsonDecode(item['payload_json']);
                messageData['text'] ??= payload['text'];
                messageData['type'] ??= payload['type'];
                break;
              } else if (clientMsgId == null) {
                final payload = jsonDecode(item['payload_json']);
                messageData['text'] ??= payload['text'];
                messageData['type'] ??= payload['type'];
                break;
              }
            }
          }
        }

        final existingMessage = msgId == null
            ? null
            : await _messageDao.getMessageById(msgId);

        // Persist before changing Riverpod/UI state.
        try {
          if (messageData['text'] != null) {
            final dto = MessageDto.fromJson(messageData);
            await _messageDao.insertOrUpdateMessages([dto.toSqliteMap()]);
          }
        } catch (e) {
          Logger.log('Failed to save background message to DB: $e');
        }

        final senderId = messageData['senderId']?.toString();
        String? rawText = messageData['text']?.toString();
        final type = messageData['type']?.toString() ?? 'TEXT';
        final createdAtStr =
            messageData['createdAt']?.toString() ??
            DateTime.now().toIso8601String();
        final rawAttachments = messageData['attachments'];
        final attachments = rawAttachments is List ? rawAttachments : null;

        String? attachmentType;
        if (attachments != null && attachments.isNotEmpty) {
          final first = attachments.first;
          if (first is Map) attachmentType = first['type']?.toString();
        }

        final actualType = attachmentType ?? type;

        String? previewText;
        if (rawText != null && rawText.isNotEmpty) {
          previewText = rawText;
          if (actualType == 'IMAGE')
            previewText = '📷 $rawText';
          else if (actualType == 'VIDEO')
            previewText = '🎥 $rawText';
          else if (actualType == 'AUDIO')
            previewText = '🎵 $rawText';
          else if (actualType == 'FILE')
            previewText = '📁 $rawText';
        } else {
          if (actualType == 'IMAGE')
            previewText = '📷 Photo';
          else if (actualType == 'VIDEO')
            previewText = '🎥 Video';
          else if (actualType == 'AUDIO')
            previewText = '🎵 Audio';
          else if (actualType == 'FILE')
            previewText = '📁 File';
        }

        final currentChatId = _ref.read(currentChatIdProvider);
        final isCurrentlyOpen = currentChatId == conversationId;

        final dt = DateTime.tryParse(createdAtStr)?.toLocal() ?? DateTime.now();
        final formattedTime = DateFormatter.formatConversationTime(dt);

        bool chatFound = false;
        final isIncoming =
            senderId != null &&
            senderId.isNotEmpty &&
            senderId != _currentUserId;

        if (previewText == null && isIncoming) {
          // If we couldn't resolve text for an incoming message, force fetch from server to get accurate preview
          await fetchFromServer();
          return;
        }

        final updatedList = state.map((chat) {
          if (chat.id == conversationId) {
            chatFound = true;
            final newUnreadCount =
                (isIncoming && !isCurrentlyOpen && existingMessage == null)
                ? chat.unreadCount + 1
                : (isCurrentlyOpen ? 0 : chat.unreadCount);

            return chat.copyWith(
              message: previewText ?? chat.message,
              time: formattedTime,
              unreadCount: newUnreadCount,
              isRead: newUnreadCount == 0,
            );
          }
          return chat;
        }).toList();

        if (chatFound) {
          final target = updatedList.firstWhere((c) => c.id == conversationId);
          final rest = updatedList
              .where((c) => c.id != conversationId)
              .toList();

          final pinned = [target, ...rest].where((c) => c.isPinned).toList();
          final unpinned = [target, ...rest].where((c) => !c.isPinned).toList();
          state = [...pinned, ...unpinned];

          await _chatDao.updateChatLastMessage(
            conversationId,
            previewText ?? target.message,
            createdAtStr,
            target.unreadCount,
          );
        } else {
          // Chat not found in current state - update SQLite and insert to state
          Logger.log(
            'New message received for unlisted chat $conversationId - inserting to DB & state',
          );
          await _chatDao.updateChatLastMessage(
            conversationId,
            previewText ?? 'Message',
            createdAtStr,
            isIncoming ? 1 : 0,
          );
          final localRow = await _chatDao.getChatById(conversationId);
          if (localRow != null) {
            final model = localRow.toChatModel().copyWith(
              message: previewText,
              time: formattedTime,
              unreadCount: isIncoming ? 1 : 0,
            );
            final rest = state.where((c) => c.id != conversationId).toList();
            state = [model, ...rest];
          }
          await fetchFromServer(forceUpdate: true);
        }
      } catch (e, st) {
        Logger.log(
          'Error updating chat list on new message: $e\n$st',
          type: "error",
        );
      }
    });
  }

  void _listenToTyping() {
    _typingSub = _socketService.onUserTyping.listen((data) {
      final eventChatId =
          (data['conversationId'] ?? data['chatId'])?.toString();
      final senderId = (data['userId'] ??
              data['senderId'] ??
              (data['user'] is Map ? data['user']['id'] : null))
          ?.toString();

      if (_currentUserId.isEmpty) {
        final authId = _ref.read(authProvider).id;
        if (authId != null && authId.isNotEmpty && authId != '***') {
          _currentUserId = authId;
        }
      }

      // Ignore typing indicators emitted by the current user
      if (senderId != null &&
          _currentUserId.isNotEmpty &&
          senderId == _currentUserId) {
        return;
      }

      String? targetChatId = eventChatId;
      if (targetChatId == null || targetChatId.isEmpty) {
        if (senderId != null) {
          final matched = state.cast<ChatModel?>().firstWhere(
                (c) => c != null && c.userId == senderId,
                orElse: () => null,
              );
          if (matched != null) {
            targetChatId = matched.id;
          }
        }
      }

      if (targetChatId != null && targetChatId.isNotEmpty) {
        final userName = (data['userName'] ??
                data['name'] ??
                data['username'] ??
                (data['user'] is Map
                    ? (data['user']['name'] ?? data['user']['username'])
                    : null))
            ?.toString();

        final chatId = targetChatId;
        _ref.read(typingStatusProvider(chatId).notifier).state = true;
        _ref.read(typingUserNameProvider(chatId).notifier).state = userName;

        _typingTimers[chatId]?.cancel();
        _typingTimers[chatId] = Timer(const Duration(seconds: 4), () {
          _ref.read(typingStatusProvider(chatId).notifier).state = false;
          _ref.read(typingUserNameProvider(chatId).notifier).state = null;
        });
      }
    });
  }

  void _listenToChatChanges() {
    void refresh(Map<String, dynamic> data) {
      _metadataRefreshDebounce?.cancel();
      _metadataRefreshDebounce = Timer(const Duration(milliseconds: 250), () {
        unawaited(fetchFromServer(forceUpdate: true));
        final convId = (data['conversationId'] ?? data['chatId'] ?? data['id'])
            ?.toString();
        if (convId != null && convId.isNotEmpty) {
          _socketService.joinConversation(convId);
        }
        _socketService.forceReconnect();
      });
    }

    _metadataSubscriptions.addAll([
      _socketService.onChatUpdated.listen(refresh),
      _socketService.onChatAdded.listen(refresh),
      _socketService.onMemberUpdated.listen(refresh),
      _socketService.onMemberRemoved.listen(refresh),
    ]);
  }

  void _listenToReactions() {
    _reactionSub = _socketService.onMessageReactionUpdated.listen((data) async {
      try {
        final msgId = (data['messageId'] ?? data['id'])?.toString();
        if (msgId == null || msgId.isEmpty) return;

        List<Map<String, dynamic>> parsed;
        final reactions = data['reactions'];
        if (reactions is List) {
          parsed = reactions
              .map<Map<String, dynamic>?>((item) {
                if (item is Map) {
                  final map = Map<String, dynamic>.from(item);
                  if (map['emoji'] == null) {
                    map['emoji'] = map['reaction'] ?? map['code'];
                  }
                  return map;
                } else if (item is String && item.isNotEmpty) {
                  return {'emoji': item};
                }
                return null;
              })
              .whereType<Map<String, dynamic>>()
              .toList();
        } else {
          final localRow = await _messageDao.getMessageById(msgId);
          final existingJson = localRow?['reactions_json']?.toString();
          List<Map<String, dynamic>> existingReactions = [];
          if (existingJson != null && existingJson.isNotEmpty) {
            try {
              final decoded = jsonDecode(existingJson);
              if (decoded is List) {
                existingReactions = decoded
                    .map<Map<String, dynamic>?>((item) {
                      if (item is Map) {
                        final map = Map<String, dynamic>.from(item);
                        if (map['emoji'] == null) {
                          map['emoji'] = map['reaction'] ?? map['code'];
                        }
                        return map;
                      } else if (item is String && item.isNotEmpty) {
                        return {'emoji': item};
                      }
                      return null;
                    })
                    .whereType<Map<String, dynamic>>()
                    .toList();
              }
            } catch (_) {}
          }
          parsed = existingReactions;
          final emoji = (data['emoji'] ?? data['reaction'] ?? data['code'])
              ?.toString();
          final userId = data['userId']?.toString();
          if (emoji != null &&
              emoji.isNotEmpty &&
              userId != null &&
              userId.isNotEmpty) {
            parsed.removeWhere(
              (item) =>
                  item['emoji']?.toString() == emoji &&
                  item['userId']?.toString() == userId,
            );
            if (data['isAdded'] != false) {
              parsed.add({
                'emoji': emoji,
                'userId': userId,
                'messageId': msgId,
              });
            }
          }
        }
        await _messageDao.updateMessageReactions(msgId, jsonEncode(parsed));
      } catch (e, st) {
        Logger.log(
          'Error updating reaction in ChatNotifier: $e\n$st',
          type: "error",
        );
      }
    });
  }

  Future<void> _syncAfterReconnect() async {
    await fetchFromServer();
    for (final chat in List<ChatModel>.from(state)) {
      try {
        // The server has no afterSeq filter — fetch newest 50 messages and
        // let insertOrUpdate deduplicate against what is already in local DB.
        final response = await _chatRepository.getRecentMessages(
          chat.id,
          limit: 50,
        );
        final rawMessages = response['data'];
        if (rawMessages is! List || rawMessages.isEmpty) continue;
        final rows = <Map<String, dynamic>>[];
        for (final raw in rawMessages) {
          if (raw is! Map) continue;
          final dto = MessageDto.fromJson(Map<String, dynamic>.from(raw));
          if (dto.id.isNotEmpty && dto.conversationId.isNotEmpty) {
            rows.add(dto.toSqliteMap());
          }
        }
        if (rows.isNotEmpty) await _messageDao.insertOrUpdateMessages(rows);
      } catch (error) {
        Logger.log('Reconnect sync failed for ${chat.id}: $error');
      }
    }
  }

  void _listenToPresence() {
    _onlineSub = _socketService.onPresenceOnline.listen((data) async {
      final userId = _presenceUserId(data);
      Logger.log('PRESENCE ONLINE received: userId=$userId');
      if (userId != null) await _updatePresence(userId, true);
    });

    _offlineSub = _socketService.onPresenceOffline.listen((data) async {
      final userId = _presenceUserId(data);
      final payload = data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : data;
      final nestedUser = payload['user'] is Map
          ? Map<String, dynamic>.from(payload['user'] as Map)
          : const <String, dynamic>{};
      final lastSeen =
          payload['lastSeen'] ??
          payload['lastActive'] ??
          nestedUser['lastSeen'] ??
          nestedUser['lastActive'];
      String? lastActiveIso;

      if (lastSeen != null) {
        if (lastSeen is int) {
          lastActiveIso = DateTime.fromMillisecondsSinceEpoch(
            lastSeen,
          ).toIso8601String();
        } else if (lastSeen is String) {
          final parsed = int.tryParse(lastSeen);
          if (parsed != null) {
            lastActiveIso = DateTime.fromMillisecondsSinceEpoch(
              parsed,
            ).toIso8601String();
          } else {
            lastActiveIso =
                lastSeen; // Fallback in case backend sends iso string
          }
        }
      }

      Logger.log(
        'PRESENCE OFFLINE received: userId=$userId, lastActive=$lastActiveIso',
      );
      if (userId != null) {
        await _updatePresence(userId, false, lastActive: lastActiveIso);
      }
    });
  }

  String? _presenceUserId(Map<String, dynamic> event) {
    final payload = event['data'] is Map
        ? Map<String, dynamic>.from(event['data'] as Map)
        : event;
    final user = payload['user'] is Map
        ? Map<String, dynamic>.from(payload['user'] as Map)
        : const <String, dynamic>{};
    final id =
        payload['userId'] ??
        payload['user_id'] ??
        payload['id'] ??
        user['id'] ??
        user['_id'];
    final value = id?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> _updatePresence(
    String userId,
    bool isOnline, {
    String? lastActive,
  }) async {
    if (!mounted) return;
    await _chatDao.updatePresenceByUserId(
      userId,
      isOnline: isOnline,
      lastActive: lastActive,
    );
    if (!mounted) return;
    bool matched = false;
    state = state.map((chat) {
      if (chat.userId == userId) {
        matched = true;
        return chat.copyWith(
          isOnline: isOnline,
          lastActive: lastActive ?? chat.lastActive,
        );
      }
      return chat;
    }).toList();
    Logger.log(
      ' PRESENCE UPDATE: userId=$userId, isOnline=$isOnline, matched=$matched',
    );
  }

  Future<void> clearUnreadCount(String id) async {
    state = state
        .map((c) => c.id == id ? c.copyWith(unreadCount: 0, isRead: true) : c)
        .toList();
    await _chatDao.clearUnreadCount(id);
  }

  Future<void> updateLastMessage(
    String chatId,
    String message,
    String time, {
    bool bumpToTop = true,
  }) async {
    if (!mounted) return;

    bool found = false;
    final updatedList = state.map((c) {
      if (c.id == chatId) {
        found = true;
        return c.copyWith(message: message, time: time);
      }
      return c;
    }).toList();

    if (found) {
      if (bumpToTop) {
        final target = updatedList.firstWhere((c) => c.id == chatId);
        final rest = updatedList.where((c) => c.id != chatId).toList();
        final pinned = [target, ...rest].where((c) => c.isPinned).toList();
        final unpinned = [target, ...rest].where((c) => !c.isPinned).toList();
        state = [...pinned, ...unpinned];
      } else {
        state = updatedList;
      }

      await _chatDao.updateChatLastMessage(
        chatId,
        message,
        DateTime.now().toIso8601String(),
        updatedList.firstWhere((c) => c.id == chatId).unreadCount,
      );
    } else {
      // Chat is not yet in state (e.g. newly created conversation, first message sent)
      Logger.log(
        'updateLastMessage: Chat $chatId not in state, updating DB and syncing',
      );
      await _chatDao.updateChatLastMessage(
        chatId,
        message,
        DateTime.now().toIso8601String(),
        0,
      );

      Map<String, dynamic>? localRow = await _chatDao.getChatById(chatId);
      if (localRow == null) {
        final nowStr = DateTime.now().toIso8601String();
        await _chatDao.insertOrUpdateChat({
          'id': chatId,
          'type': 'PRIVATE',
          'title': 'Chat',
          'avatar_url': null,
          'unread_count': 0,
          'last_message_preview': message,
          'last_message_at': nowStr,
          'created_at': nowStr,
          'updated_at': nowStr,
          'is_online': 0,
        });
        localRow = await _chatDao.getChatById(chatId);
      }

      if (localRow != null) {
        final newChat = localRow.toChatModel().copyWith(
          message: message,
          time: time,
        );
        final rest = state.where((c) => c.id != chatId).toList();
        final pinned = [newChat, ...rest].where((c) => c.isPinned).toList();
        final unpinned = [newChat, ...rest].where((c) => !c.isPinned).toList();
        state = [...pinned, ...unpinned];
      }
      unawaited(_fetchAndSaveConversationMetadata(chatId));
    }
  }

  Future<void> _fetchAndSaveConversationMetadata(String conversationId) async {
    try {
      final res = await _chatRepository.getConversation(conversationId);
      final data = res['data'] is Map
          ? res['data']
          : (res['id'] != null ? res : null);
      if (data != null && data is Map) {
        final dto = ChatDto.fromJson(Map<String, dynamic>.from(data));
        await _chatDao.insertOrUpdateChat(dto.toSqliteMap(_currentUserId));
        await loadFromDb();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _onlineSub?.cancel();
    _offlineSub?.cancel();
    _newMessageSub?.cancel();
    _reconnectSub?.cancel();
    _reactionSub?.cancel();
    _typingSub?.cancel();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    for (final subscription in _metadataSubscriptions) {
      subscription.cancel();
    }
    _metadataRefreshDebounce?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id') ?? '';

    // 1. Instantly load from local SQLite (Offline-first)
    await loadFromDb();

    for (final presence in _socketService.presenceSnapshot) {
      final userId = _presenceUserId(presence);
      if (userId != null) {
        await _updatePresence(
          userId,
          presence['isOnline'] == true,
          lastActive: presence['lastSeen']?.toString(),
        );
      }
    }

    // 2. Real API fetch from server
    await fetchFromServer();
  }

  Future<void> loadFromDb() async {
    final chatRows = await _chatDao.getAllChats();
    final models = await Isolate.run(() {
      final list = chatRows.map((row) => row.toChatModel()).toList();
      final pinned = list.where((chat) => chat.isPinned).toList();
      final unpinned = list.where((chat) => !chat.isPinned).toList();
      return [...pinned, ...unpinned];
    });

    state = models;
    _socketService.syncConversationSubscriptions(models.map((chat) => chat.id));
  }

  Future<void> fetchFromServer({
    bool isManualRefresh = false,
    bool forceUpdate = false,
  }) async {
    try {
      if (isManualRefresh) {
        await DefaultCacheManager().emptyCache();
      }

      final responseData = await _chatRepository.getConversations();
      Logger.log('API RESPONSE (/api/v1/conversations): $responseData');

      List<dynamic>? dataList;
      if (responseData['data'] is List) {
        dataList = responseData['data'] as List<dynamic>;
      } else if (responseData['conversations'] is List) {
        dataList = responseData['conversations'] as List<dynamic>;
      } else if (responseData is List) {
        dataList = responseData as List<dynamic>;
      }

      if (dataList != null) {
        final List<dynamic> data = dataList;
        Logger.log('Total conversations from API: ${data.length}');

        final currentUserId = _currentUserId;
        final List<Map<String, dynamic>> sqliteRows = await Isolate.run(() {
          final rows = <Map<String, dynamic>>[];
          for (final item in data) {
            try {
              if (item is Map) {
                final map = Map<String, dynamic>.from(item);
                final dto = ChatDto.fromJson(map);
                rows.add(dto.toSqliteMap(currentUserId));
              }
            } catch (e) {
              // Ignore unparseable item
            }
          }
          return rows;
        });

        final localRows = await _chatDao.getAllChats();
        bool hasChanges =
            forceUpdate ||
            sqliteRows.length != localRows.length ||
            sqliteRows.length != state.length;

        if (!hasChanges) {
          final localMap = {for (var row in localRows) row['id']: row};
          for (final serverRow in sqliteRows) {
            final localRow = localMap[serverRow['id']];
            if (localRow == null) {
              hasChanges = true;
              break;
            }
            if (serverRow['last_message_at']?.toString() !=
                    localRow['last_message_at']?.toString() ||
                serverRow['last_message_preview']?.toString() !=
                    localRow['last_message_preview']?.toString() ||
                serverRow['unread_count']?.toString() !=
                    localRow['unread_count']?.toString() ||
                serverRow['title']?.toString() !=
                    localRow['title']?.toString() ||
                serverRow['avatar_url']?.toString() !=
                    localRow['avatar_url']?.toString() ||
                (serverRow['is_online'] != null &&
                    serverRow['is_online']?.toString() !=
                        localRow['is_online']?.toString()) ||
                (serverRow['last_active_at'] != null &&
                    serverRow['last_active_at']?.toString() !=
                        localRow['last_active_at']?.toString())) {
              hasChanges = true;
              break;
            }
          }
        }

        if (hasChanges) {
          await _chatDao.insertOrUpdateChats(sqliteRows);
          Logger.log('Saved ${sqliteRows.length} chats to SQLite');

          await loadFromDb();
          Logger.log('Loaded ${state.length} chats from DB → UI');
        } else if (state.length != localRows.length) {
          await loadFromDb();
        } else {
          Logger.log('Local DB is up-to-date. Skipping UI update.');
        }
      } else {
        Logger.log('API response not success or data is null');
      }
    } catch (e, st) {
      Logger.log('Failed to fetch chats from server: $e\n$st');
    }
  }

  Future<String?> findOrCreatePrivateConversation(String otherUserId) async {
    final cleanUserId = otherUserId.trim();
    if (cleanUserId.isEmpty) return null;

    if (_currentUserId.isEmpty) {
      final authId = _ref.read(authProvider).id;
      if (authId != null && authId.isNotEmpty && authId != '***') {
        _currentUserId = authId;
      } else {
        final prefs = await SharedPreferences.getInstance();
        _currentUserId = prefs.getString('user_id') ?? '';
      }
    }

    if (_currentUserId.isNotEmpty && cleanUserId == _currentUserId) {
      Logger.log('Cannot create conversation with self');
      return null;
    }

    // 1. Check in-memory state
    final existingChat = state.cast<ChatModel?>().firstWhere(
      (c) => c != null && (c.userId == cleanUserId || c.id == cleanUserId),
      orElse: () => null,
    );
    if (existingChat != null) {
      Logger.log('Found existing in-memory conversation: ${existingChat.id}');
      return existingChat.id;
    }

    // 2. Check local database
    final localRow = await _chatDao.getChatByOtherUserId(cleanUserId);
    if (localRow != null && localRow['id'] != null) {
      final existingId = localRow['id'] as String;
      Logger.log('Found existing local DB conversation: $existingId');
      await loadFromDb();
      return existingId;
    }

    // 3. Create or fetch via API (POST /api/v1/conversations)
    String? conversationId;
    Map<String, dynamic>? conversationData;

    try {
      final res = await _chatRepository.createConversation(
        type: 'PRIVATE',
        userIds: [cleanUserId],
      );

      Logger.log('Create conversation API response: $res');

      if (res['data'] is Map) {
        conversationData = Map<String, dynamic>.from(res['data'] as Map);
      } else if (res['id'] != null || res['_id'] != null) {
        conversationData = Map<String, dynamic>.from(res);
      }

      conversationId =
          conversationData?['id']?.toString() ??
          conversationData?['_id']?.toString() ??
          res['id']?.toString() ??
          res['conversationId']?.toString();
    } catch (e, st) {
      Logger.log(
        'createConversation API call encountered: $e\n$st',
        type: 'error',
      );
    }

    // 4. If conversationId is still not found (or if backend had conflict/existing conversation):
    // Search the user's active conversations on the server for cleanUserId
    if (conversationId == null || conversationId.isEmpty) {
      try {
        Logger.log(
          'Searching existing conversations on server for $cleanUserId...',
        );
        final serverRes = await _chatRepository.getConversations();
        final rawData = serverRes['data'] is List
            ? serverRes['data']
            : (serverRes['conversations'] is List
                  ? serverRes['conversations']
                  : (serverRes is List ? serverRes : null));
        if (rawData is List) {
          for (final item in rawData) {
            if (item is Map) {
              final type = item['type']?.toString();
              if (type == 'PRIVATE') {
                bool isMatch = false;
                final members = item['members'];
                if (members is List) {
                  for (final m in members) {
                    if (m is Map) {
                      final uid =
                          m['userId']?.toString() ??
                          (m['user'] as Map?)?['id']?.toString();
                      if (uid != null && uid == cleanUserId) {
                        isMatch = true;
                        break;
                      }
                    }
                  }
                }
                final dmKey = item['dmKey']?.toString();
                if (dmKey != null && dmKey.contains(cleanUserId)) {
                  isMatch = true;
                }

                if (isMatch) {
                  conversationId =
                      item['id']?.toString() ?? item['_id']?.toString();
                  conversationData = Map<String, dynamic>.from(item);
                  Logger.log(
                    'Found matching conversation on server: $conversationId',
                  );
                  break;
                }
              }
            }
          }
        }
      } catch (e) {
        Logger.log('Error querying server conversations: $e', type: 'error');
      }
    }

    // 5. Persist the conversation if we have conversationId
    if (conversationId != null && conversationId.isNotEmpty) {
      if (conversationData == null || conversationData['members'] == null) {
        try {
          final detailRes = await _chatRepository.getConversation(
            conversationId,
          );
          if (detailRes['data'] is Map) {
            conversationData = Map<String, dynamic>.from(
              detailRes['data'] as Map,
            );
          } else if (detailRes['id'] != null || detailRes['_id'] != null) {
            conversationData = Map<String, dynamic>.from(detailRes);
          }
        } catch (_) {}
      }

      try {
        final Map<String, dynamic> sqliteMap;
        if (conversationData != null) {
          final dto = ChatDto.fromJson(conversationData);
          sqliteMap = dto.toSqliteMap(_currentUserId);
        } else {
          sqliteMap = {
            'id': conversationId,
            'other_user_id': cleanUserId,
            'type': 'PRIVATE',
            'title': 'Chat',
            'avatar_url': null,
            'unread_count': 0,
            'last_message_preview': 'New Chat',
            'last_message_at': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
            'is_online': 0,
            'last_active_at': null,
          };
        }
        sqliteMap['other_user_id'] ??= cleanUserId;
        await _chatDao.insertOrUpdateChat(sqliteMap);
        await loadFromDb();
      } catch (e) {
        Logger.log('Could not persist conversation dto: $e');
      }

      // 6. Refresh all conversations from server to sync UI state
      try {
        await fetchFromServer(forceUpdate: true);
      } catch (_) {}

      // Ensure newly created chat is in state immediately
      if (!state.any((c) => c.id == conversationId)) {
        final localRow = await _chatDao.getChatById(conversationId);
        if (localRow != null) {
          state = [localRow.toChatModel(), ...state];
        }
      }

      // Sync socket room for real-time events immediately
      _socketService.joinConversation(conversationId);
      _socketService.forceReconnect();

      return conversationId;
    }

    // Final fallback check in synced state
    final syncedChat = state.cast<ChatModel?>().firstWhere(
      (c) => c != null && (c.userId == cleanUserId || c.id == cleanUserId),
      orElse: () => null,
    );
    if (syncedChat != null) {
      return syncedChat.id;
    }

    return null;
  }

  Future<String?> createGroupConversation({
    required String title,
    required List<String> userIds,
  }) async {
    try {
      final res = await _chatRepository.createConversation(
        type: 'GROUP',
        title: title,
        userIds: userIds,
      );

      Logger.log('Create group API response: $res');

      String? conversationId;
      Map<String, dynamic>? conversationData;

      if (res['data'] is Map) {
        conversationData = Map<String, dynamic>.from(res['data'] as Map);
        conversationId =
            conversationData['id']?.toString() ??
            conversationData['_id']?.toString();
      } else if (res['id'] != null || res['_id'] != null) {
        conversationData = Map<String, dynamic>.from(res);
        conversationId = res['id']?.toString() ?? res['_id']?.toString();
      }

      if (conversationData != null && _currentUserId.isNotEmpty) {
        try {
          final dto = ChatDto.fromJson(conversationData);
          await _chatDao.insertOrUpdateChat(dto.toSqliteMap(_currentUserId));
          await loadFromDb();
        } catch (e) {
          Logger.log('Could not persist created group dto: $e');
        }
      }

      await fetchFromServer(forceUpdate: true);

      if (conversationId != null) {
        if (!state.any((c) => c.id == conversationId)) {
          final localRow = await _chatDao.getChatById(conversationId);
          if (localRow != null) {
            state = [localRow.toChatModel(), ...state];
          }
        }
        _socketService.joinConversation(conversationId);
        _socketService.forceReconnect();
      }

      return conversationId;
    } catch (e, st) {
      Logger.log('Failed to create group conversation: $e\n$st', type: 'error');
      rethrow;
    }
  }

  Future<bool> addMembersToConversation(
    String conversationId,
    List<String> userIds,
  ) async {
    try {
      final res = await _chatRepository.addMembers(conversationId, userIds);
      Logger.log('Add members API response: $res');
      await fetchFromServer();
      return true;
    } catch (e, st) {
      Logger.log('Failed to add members: $e\n$st', type: 'error');
      return false;
    }
  }

  Future<void> muteConversation(String conversationId, bool isMuted) async {
    // Optimistic UI update
    state = state.map((chat) {
      if (chat.id == conversationId) {
        return chat.copyWith(isMuted: isMuted);
      }
      return chat;
    }).toList();

    // Local DB persist
    try {
      await _chatDao.updateMuteStatus(conversationId, isMuted);
    } catch (e, st) {
      Logger.log('Failed to save mute status to DB: $e\n$st', type: "error");
    }

    // Server API call
    try {
      await _chatRepository.muteConversation(conversationId, isMuted);
    } catch (e, st) {
      Logger.log(
        'Failed to mute conversation on server: $e\n$st',
        type: "error",
      );
    }
  }

  Future<void> deleteChat(String id) async {
    // Optimistically update UI state
    state = state.where((chat) => chat.id != id).toList();

    // Delete locally from SQLite
    await _chatDao.deleteChat(id);
    await _messageDao.deleteMessagesByConversationId(id);

    // Call server endpoint if target chat member/userId is available
    if (_currentUserId.isNotEmpty) {
      try {
        await _chatRepository.removeMember(id, _currentUserId);
        Logger.log(
          'Successfully removed myself ($_currentUserId) from chat $id on server',
        );
      } catch (e) {
        Logger.log('Failed to remove member on server: $e');
      }
    }
  }

  void toggleUnreadChat(String id) {
    state = state
        .map(
          (c) => c.id == id
              ? c.copyWith(unreadCount: c.unreadCount > 0 ? 0 : 1)
              : c,
        )
        .toList();
  }

  void togglePinChat(String id) {
    state = state.map((chat) {
      if (chat.id == id) {
        return chat.copyWith(isPinned: !chat.isPinned);
      }
      return chat;
    }).toList();
    _sortChats();
  }

  void _sortChats() {
    final pinned = state.where((chat) => chat.isPinned).toList();
    final unpinned = state.where((chat) => !chat.isPinned).toList();
    state = [...pinned, ...unpinned];
  }
}

final chatSearchProviders = StateProvider<String>((ref) => '');
