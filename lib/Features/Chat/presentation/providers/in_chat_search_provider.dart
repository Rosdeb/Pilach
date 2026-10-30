import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:app/core/database/daos/message_dao.dart';
import 'package:app/core/models/message_dto.dart';
import 'package:app/core/network/chat_repository.dart';
import 'direct_chat_provider.dart';

class InChatSearchState {
  final bool isActive;
  final String query;
  final List<String> matchingMessageIds;
  final int currentIndex;
  final bool isLoading;

  const InChatSearchState({
    this.isActive = false,
    this.query = '',
    this.matchingMessageIds = const [],
    this.currentIndex = 0,
    this.isLoading = false,
  });

  InChatSearchState copyWith({
    bool? isActive,
    String? query,
    List<String>? matchingMessageIds,
    int? currentIndex,
    bool? isLoading,
  }) {
    return InChatSearchState(
      isActive: isActive ?? this.isActive,
      query: query ?? this.query,
      matchingMessageIds: matchingMessageIds ?? this.matchingMessageIds,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class InChatSearchNotifier extends StateNotifier<InChatSearchState> {
  InChatSearchNotifier(this._ref) : super(const InChatSearchState());

  final Ref _ref;
  Timer? _debounceTimer;

  void activate() {
    state = const InChatSearchState(isActive: true);
  }

  void deactivate() {
    _debounceTimer?.cancel();
    state = const InChatSearchState(isActive: false);
    _ref.read(highlightedMessageIdProvider.notifier).state = null;
    _ref.read(targetScrollMessageIdProvider.notifier).state = null;
  }

  void onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      state = state.copyWith(
        query: '',
        matchingMessageIds: [],
        currentIndex: 0,
        isLoading: false,
      );
      _ref.read(highlightedMessageIdProvider.notifier).state = null;
      return;
    }

    state = state.copyWith(query: cleanQuery, isLoading: true);
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(cleanQuery);
    });
  }

  Future<void> _executeSearch(String query) async {
    final chatId = _ref.read(currentChatIdProvider);
    if (chatId == null || !state.isActive) return;

    try {
      final ids = <String>[];

      // 1. Search local SQLite for instant results
      final localRows = await MessageDao().searchMessagesInChat(chatId, query);
      for (final row in localRows) {
        final id = row['id']?.toString();
        if (id != null && id.isNotEmpty && !ids.contains(id)) {
          ids.add(id);
        }
      }

      // If we found local matches, update state right away for 0-latency feel
      if (ids.isNotEmpty && mounted && state.isActive) {
        state = state.copyWith(
          matchingMessageIds: List.from(ids),
          currentIndex: 0,
          isLoading: false,
        );
        _ref.read(targetScrollMessageIdProvider.notifier).state = ids[0];
        _ref.read(highlightedMessageIdProvider.notifier).state = ids[0];
      }

      // 2. Query authoritative server endpoint
      final repo = _ref.read(chatRepositoryProvider);
      final response = await repo.searchMessagesInChat(chatId, query: query);
      List<dynamic> rawList = const [];
      if (response['data'] is List) {
        rawList = response['data'] as List;
      } else if (response['items'] is List) {
        rawList = response['items'] as List;
      } else if (response['messages'] is List) {
        rawList = response['messages'] as List;
      }

      for (final item in rawList) {
        if (item is! Map) continue;
        final msg = item['message'] is Map
            ? Map<String, dynamic>.from(item['message'] as Map)
            : null;
        final id = (msg?['id'] ?? item['id'])?.toString();
        if (id != null && id.isNotEmpty) {
          if (msg != null) {
            try {
              final dto = MessageDto.fromJson(msg);
              await MessageDao().insertOrUpdateMessage(dto.toSqliteMap());
            } catch (_) {}
          }
          if (!ids.contains(id)) {
            ids.add(id);
          }
        }
      }

      if (!mounted || !state.isActive) return;

      state = state.copyWith(
        matchingMessageIds: ids,
        currentIndex: ids.isNotEmpty ? 0 : 0,
        isLoading: false,
      );

      if (ids.isNotEmpty) {
        _ref.read(targetScrollMessageIdProvider.notifier).state = ids[0];
        _ref.read(highlightedMessageIdProvider.notifier).state = ids[0];
      } else {
        _ref.read(highlightedMessageIdProvider.notifier).state = null;
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  void nextMatch() {
    if (state.matchingMessageIds.isEmpty) return;
    final nextIndex = (state.currentIndex + 1) % state.matchingMessageIds.length;
    state = state.copyWith(currentIndex: nextIndex);
    final targetId = state.matchingMessageIds[nextIndex];
    _ref.read(targetScrollMessageIdProvider.notifier).state = targetId;
    _ref.read(highlightedMessageIdProvider.notifier).state = targetId;
  }

  void previousMatch() {
    if (state.matchingMessageIds.isEmpty) return;
    final prevIndex =
        (state.currentIndex - 1 + state.matchingMessageIds.length) %
        state.matchingMessageIds.length;
    state = state.copyWith(currentIndex: prevIndex);
    final targetId = state.matchingMessageIds[prevIndex];
    _ref.read(targetScrollMessageIdProvider.notifier).state = targetId;
    _ref.read(highlightedMessageIdProvider.notifier).state = targetId;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final inChatSearchProvider =
    StateNotifierProvider.autoDispose<InChatSearchNotifier, InChatSearchState>((ref) {
  return InChatSearchNotifier(ref);
});
