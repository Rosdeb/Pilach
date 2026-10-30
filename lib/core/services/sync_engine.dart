import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/daos/chat_dao.dart';
import '../database/daos/message_dao.dart';
import '../database/daos/sync_state_dao.dart';
import '../models/chat_dto.dart';
import '../models/message_dto.dart';
import '../network/chat_repository.dart';
import '../utils/app_logger.dart';
import '../utils/message_merge_utils.dart';
import '../theme/theme_provider.dart';
import 'outbox_processor.dart';

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final chatDao = ChatDao();
  final messageDao = MessageDao();
  final syncStateDao = SyncStateDao();
  final chatRepo = ref.watch(chatRepositoryProvider);
  final outboxProcessor = ref.watch(outboxProcessorProvider);
  final preferences = ref.watch(sharedPreferencesProvider);
  final engine = SyncEngine(
    chatDao,
    messageDao,
    syncStateDao,
    chatRepo,
    outboxProcessor,
    preferences,
  );
  ref.onDispose(engine.dispose);
  return engine;
});

class SyncEngine with WidgetsBindingObserver {
  final ChatDao _chatDao;
  final MessageDao _messageDao;
  final SyncStateDao _syncStateDao;
  final ChatRepository _chatRepository;
  final OutboxProcessor _outboxProcessor;
  final SharedPreferences _preferences;

  bool _isSyncing = false;
  bool _disposed = false;

  SyncEngine(
    this._chatDao,
    this._messageDao,
    this._syncStateDao,
    this._chatRepository,
    this._outboxProcessor,
    this._preferences,
  ) {
    WidgetsBinding.instance.addObserver(this);
    unawaited(onAppResume());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // Flush outgoing messages queued while user was interacting
      unawaited(_outboxProcessor.processOutbox());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(onAppResume());
      unawaited(_outboxProcessor.processOutbox());
    }
  }

  Future<void> onAppResume() async {
    if (_disposed || _isSyncing) return;
    // The provider exists at app startup, including while logged out. Never
    // start authenticated sync requests until a session has been established.
    if (_preferences.getString('auth_token') == null) return;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.every((r) => r == ConnectivityResult.none)) return;
    } catch (_) {
      return;
    }

    _isSyncing = true;
    try {
      // 1. Synchronize remote conversation list and metadata
      await syncConversations();

      // 2. Synchronize message gaps for active conversations
      await syncGapsForAllChats();
    } catch (e) {
      Logger.log('Background sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> syncConversations() async {
    try {
      final response = await _chatRepository.getConversations();
      final data = response['data'];
      if (data is List) {
        final List<Map<String, dynamic>> sqliteChats = [];
        for (final item in data) {
          if (item is Map) {
            final dto = ChatDto.fromJson(Map<String, dynamic>.from(item));
            sqliteChats.add(dto.toSqliteMap(_preferences.getString('user_id')));
          }
        }
        if (sqliteChats.isNotEmpty) {
          await _chatDao.insertOrUpdateChats(sqliteChats);
        }
      }
    } catch (e) {
      Logger.log('SyncEngine failed to sync conversations: $e');
    }
  }

  Future<void> syncGapsForAllChats() async {
    try {
      final chats = await _chatDao.getAllChats();
      final gaps = <({String chatId, int remoteSeq})>[];
      for (final chat in chats) {
        if (_disposed) break;
        final chatId = chat['id']?.toString();
        final remoteSeq = (chat['last_message_seq'] as num?)?.toInt() ?? 0;
        if (chatId != null && chatId.isNotEmpty && remoteSeq > 0) {
          final localSeq = await _messageDao.getLastSeq(chatId);
          if (remoteSeq > localSeq) {
            gaps.add((chatId: chatId, remoteSeq: remoteSeq));
          }
        }
      }

      // Bound network concurrency so a large inbox cannot create a request
      // storm or compete with animation/frame work on resume.
      const batchSize = 3;
      for (var offset = 0; offset < gaps.length; offset += batchSize) {
        if (_disposed) break;
        final end = min(offset + batchSize, gaps.length);
        await Future.wait(
          gaps
              .sublist(offset, end)
              .map(
                (gap) =>
                    syncMessagesForChat(gap.chatId, chatLastSeq: gap.remoteSeq),
              ),
        );
      }
    } catch (e) {
      Logger.log('SyncEngine failed to sync gaps: $e');
    }
  }

  Future<void> syncMessagesForChat(String chatId, {int? chatLastSeq}) async {
    try {
      final localLastSeq = await _messageDao.getLastSeq(chatId);
      final remoteLastSeq = chatLastSeq ?? localLastSeq;
      if (remoteLastSeq <= localLastSeq) {
        return;
      }

      final syncState = await _syncStateDao.getSyncState(chatId);
      const pageSize = 150;
      const maxPagesPerResume = 5;

      for (var page = 1; page <= maxPagesPerResume; page++) {
        if (_disposed) break;
        final response = await _chatRepository.getMessages(
          chatId,
          page: page,
          limit: pageSize,
        );
        final rawList = response['data'];
        if (rawList is! List || rawList.isEmpty) break;

        final incomingRows = <Map<String, dynamic>>[];
        var reachedLocalBoundary = false;
        for (final item in rawList) {
          if (item is! Map) continue;
          final dto = MessageDto.fromJson(Map<String, dynamic>.from(item));
          if (dto.seq != null && dto.seq! <= localLastSeq) {
            reachedLocalBoundary = true;
          }
          incomingRows.add(dto.toSqliteMap());
        }

        final mergedRows = <Map<String, dynamic>>[];
        for (final incomingRow in incomingRows) {
          final id = incomingRow['id']?.toString();
          final existing = id == null
              ? null
              : await _messageDao.getMessageById(id);
          mergedRows.add(
            existing == null
                ? incomingRow
                : mergeMessageRows(incomingRow, existing),
          );
        }
        if (mergedRows.isNotEmpty) {
          await _messageDao.insertOrUpdateMessages(mergedRows);
        }

        if (reachedLocalBoundary || rawList.length < pageSize) break;
      }

      final updatedLastSeq = await _messageDao.getLastSeq(chatId);
      await _syncStateDao.updateSyncState({
        'conversation_id': chatId,
        'newest_synced_seq': updatedLastSeq,
        'oldest_synced_seq': syncState?['oldest_synced_seq'],
        'last_synced_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      Logger.log('SyncEngine failed to sync messages for $chatId: $e');
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
  }
}
