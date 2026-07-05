import 'package:app/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../../core/network/chat_repository.dart';
import '../../../../core/providers/api_provider.dart';
import '../../data/models/chat_model.dart';
import '../../../../core/database/daos/chat_dao.dart';
import '../../../../core/models/chat_dto.dart';
import '../../../../core/services/socket_service.dart';
import 'dart:async';
import 'dart:isolate';

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatModel>>((ref) {
  final chatRepo = ref.watch(chatRepositoryProvider);
  final socketService = ref.watch(socketServiceProvider);
  return ChatNotifier(chatRepo, socketService);
});

class ChatNotifier extends StateNotifier<List<ChatModel>> {
  final ChatDao _chatDao = ChatDao();
  final ChatRepository _chatRepository;
  final SocketService _socketService;
  StreamSubscription? _onlineSub;
  StreamSubscription? _offlineSub;

  ChatNotifier(this._chatRepository, this._socketService) : super([]) {
    _init();
    _listenToPresence();
  }

  void _listenToPresence() {
    _onlineSub = _socketService.onPresenceOnline.listen((data) {
      final userId = data['userId'] as String?;
      Logger.log('PRESENCE ONLINE received: userId=$userId');
      if (userId != null) _updatePresence(userId, true);
    });
    
    _offlineSub = _socketService.onPresenceOffline.listen((data) {
      final userId = data['userId'] as String?;
      Logger.log('PRESENCE OFFLINE received: userId=$userId');
      if (userId != null) _updatePresence(userId, false);
    });
  }

  void _updatePresence(String userId, bool isOnline) {
    if (!mounted) return;
    bool matched = false;
    state = state.map((chat) {
      if (chat.userId == userId) {
        matched = true;
        return chat.copyWith(isOnline: isOnline);
      }
      return chat;
    }).toList();
    Logger.log(' PRESENCE UPDATE: userId=$userId, isOnline=$isOnline, matched=$matched');
  }

  @override
  void dispose() {
    _onlineSub?.cancel();
    _offlineSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    // 1. Instantly load from local SQLite (Offline-first)
    await loadFromDb();

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
  }

  Future<void> fetchFromServer({bool isManualRefresh = false}) async {
    try {
      if (isManualRefresh) {
        await DefaultCacheManager().emptyCache();
      }

      final responseData = await _chatRepository.getConversations();
      Logger.log('API RESPONSE (/api/v1/conversations): $responseData');

      if (responseData['success'] == true && responseData['data'] != null) {
        final List<dynamic> data = responseData['data'];
        Logger.log('Total conversations from API: ${data.length}');

        final List<Map<String, dynamic>> sqliteRows = await Isolate.run(() {
          final rows = <Map<String, dynamic>>[];
          for (final item in data) {
            try {
              final dto = ChatDto.fromJson(item as Map<String, dynamic>);
              rows.add(dto.toSqliteMap());
            } catch (e) {
              // Ignore unparseable item
            }
          }
          return rows;
        });

        await _chatDao.insertOrUpdateChats(sqliteRows);
        Logger.log('Saved ${sqliteRows.length} chats to SQLite');

        await loadFromDb();
        Logger.log('Loaded ${state.length} chats from DB → UI');
      } else {
        Logger.log('API response not success or data is null');
      }
    } catch (e, st) {
      Logger.log('Failed to fetch chats from server: $e\n$st');
    }
  }

  Future<void> deleteChat(String id) async {
    ChatModel? targetChat;
    for (final c in state) {
      if (c.id == id) {
        targetChat = c;
        break;
      }
    }

    // Optimistically update UI state
    state = state.where((chat) => chat.id != id).toList();

    // Delete locally from SQLite
    await _chatDao.deleteChat(id);

    // Call server endpoint if target chat member/userId is available
    if (targetChat?.userId != null) {
      try {
        await _chatRepository.removeMember(id, targetChat!.userId!);
        Logger.log('Successfully removed member ${targetChat.userId} from chat $id on server');
      } catch (e) {
        Logger.log('Failed to remove member on server: $e');
      }
    }
  }

  void toggleUnreadChat(String id) {
    state = state.map((c) => c.id == id
        ? c.copyWith(unreadCount: c.unreadCount > 0 ? 0 : 1)
        : c,
    ).toList();
  }

  void toggleMuteChat(String id) {
    state = state.map((chat) {
      if (chat.id == id) {
        return chat.copyWith(isMuted: !chat.isMuted);
      }
      return chat;
    }).toList();
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