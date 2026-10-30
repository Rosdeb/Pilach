import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:app/core/constants/app_constants.dart' show AppRoutes;
import 'package:app/core/constants/app_paths.dart';
import 'package:app/core/database/daos/message_dao.dart';
import 'package:app/core/models/message_dto.dart';
import 'package:app/core/network/chat_repository.dart';
import 'package:app/core/utils/app_colour.dart';
import 'package:app/core/utils/date_formatter.dart';
import '../providers/chat_provider.dart';
import '../providers/direct_chat_provider.dart';
import '../../data/models/chat_model.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/chat_tile.dart';
import '../widgets/search_bar_widget.dart';

class ChatSearchScreen extends ConsumerStatefulWidget {
  final String? chatId;
  final String? chatTitle;

  const ChatSearchScreen({
    super.key,
    this.chatId,
    this.chatTitle,
  });

  @override
  ConsumerState<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends ConsumerState<ChatSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isLoading = false;
  String _currentQuery = '';
  List<Map<String, dynamic>> _messageResults = [];

  bool get _isInChatSearch => widget.chatId != null && widget.chatId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _currentQuery) return;
    _currentQuery = query;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    if (!mounted) return;
    if (query.length < 2) {
      setState(() {
        _messageResults = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      Map<String, dynamic> response;

      if (_isInChatSearch) {
        response = await chatRepo.searchMessagesInChat(
          widget.chatId!,
          query: query,
        );
      } else {
        response = await chatRepo.searchMessagesGlobal(
          query: query,
        );
      }

      List<dynamic> rawList = const [];
      if (response['data'] is List) {
        rawList = response['data'] as List;
      } else if (response is List) {
        rawList = response as List;
      }

      if (mounted) {
        setState(() {
          _messageResults = rawList
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messageResults = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allChats = ref.watch(chatProvider);

    final filteredChats = !_isInChatSearch && _currentQuery.length >= 2
        ? allChats.where((chat) {
            return chat.name.toLowerCase().contains(_currentQuery.toLowerCase());
          }).toList()
        : <ChatModel>[];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leadingWidth: 40,
        leading: IconButton(
          padding: const EdgeInsets.only(left: 14),
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: IOSSearchBar(
          controller: _searchController,
          autofocus: true,
          hintText: _isInChatSearch
              ? "Search in ${widget.chatTitle ?? 'chat'}..."
              : "Search chats and messages...",
          margin: const EdgeInsets.only(right: 16.0, top: 10, bottom: 10, left: 8.0),
        ),
      ),
      body: _buildBody(theme, allChats, filteredChats),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    List<ChatModel> allChats,
    List<ChatModel> filteredChats,
  ) {
    if (_currentQuery.trim().length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.search,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              ),
              const SizedBox(height: 12),
              Text(
                _isInChatSearch
                    ? "Type at least 2 characters to search messages in this chat"
                    : "Type at least 2 characters to search chats and messages",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 12),
      );
    }

    final hasNoResults =
        filteredChats.isEmpty && _messageResults.isEmpty;

    if (hasNoResults) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.doc_text_search,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              "No messages found for \"$_currentQuery\"",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        // --- CHATS SECTION (for Global Search) ---
        if (!_isInChatSearch && filteredChats.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              "CHATS (${filteredChats.length})",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ...filteredChats.map((chat) => ChatTile(
                key: ValueKey('chat_${chat.id}'),
                chat: chat,
              )),
          const SizedBox(height: 12),
        ],

        // --- MESSAGES SECTION ---
        if (_messageResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              _isInChatSearch
                  ? "MESSAGES FOUND (${_messageResults.length})"
                  : "MESSAGES (${_messageResults.length})",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ..._messageResults.map((item) {
            final message = item['message'] is Map
                ? Map<String, dynamic>.from(item['message'] as Map)
                : <String, dynamic>{};
            final itemChatId = ((widget.chatId != null &&
                        widget.chatId!.isNotEmpty)
                    ? widget.chatId!
                    : (item['chatId'] ??
                        message['chatId'] ??
                        message['conversationId']))
                ?.toString() ??
                '';
            final snippet =
                (item['snippet'] ?? message['text'] ?? '').toString();
            final msgType =
                (message['type'] ?? 'TEXT').toString().toUpperCase();
            final createdAt = message['createdAt'];

            ChatModel? targetChat;
            if (allChats.isNotEmpty) {
              targetChat = allChats.firstWhere(
                (c) => c.id == itemChatId,
                orElse: () => ChatModel(
                  id: itemChatId,
                  name: widget.chatTitle ?? 'Conversation',
                  message: snippet,
                  image: '',
                  time: '',
                  unreadCount: 0,
                  isOnline: false,
                ),
              );
            }

            return _buildMessageResultTile(
              theme: theme,
              chat: targetChat,
              snippet: snippet,
              type: msgType,
              createdAt: createdAt,
              onTap: () async {
                final messageId = (message['id'] ?? item['id'])?.toString();
                if (itemChatId.isNotEmpty) {
                  // Ensure message payload is in local SQLite database
                  if (message.isNotEmpty &&
                      messageId != null &&
                      messageId.isNotEmpty) {
                    try {
                      final dto = MessageDto.fromJson(message);
                      await MessageDao().insertOrUpdateMessage(
                        dto.toSqliteMap(),
                      );
                    } catch (_) {}
                  }

                  await ref
                      .read(chatProvider.notifier)
                      .ensureConversationLoaded(itemChatId);
                  ref.read(chatProvider.notifier).clearUnreadCount(itemChatId);
                  ref.read(currentChatIdProvider.notifier).state = itemChatId;
                  if (messageId != null && messageId.isNotEmpty) {
                    ref.read(targetScrollMessageIdProvider.notifier).state =
                        messageId;
                    ref.read(highlightedMessageIdProvider.notifier).state =
                        messageId;
                  }

                  if (_isInChatSearch) {
                    Navigator.of(context).pop();
                  } else {
                    context.push(AppPaths.chat);
                  }
                }
              },
            );
          }),
        ],
      ],
    );
  }

  Widget _buildMessageResultTile({
    required ThemeData theme,
    ChatModel? chat,
    required String snippet,
    required String type,
    dynamic createdAt,
    required VoidCallback onTap,
  }) {
    IconData typeIcon = CupertinoIcons.chat_bubble_text;
    if (type == 'IMAGE') typeIcon = CupertinoIcons.photo;
    if (type == 'VIDEO') typeIcon = CupertinoIcons.videocam;
    if (type == 'AUDIO' || type == 'VOICE') typeIcon = CupertinoIcons.mic;
    if (type == 'FILE') typeIcon = CupertinoIcons.doc;

    final formattedTime = createdAt != null
        ? DateFormatter.formatConversationTimeString(createdAt)
        : '';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (chat != null && !_isInChatSearch) ...[
              ChatAvatar(
                radius: 20,
                imageUrl: chat.image,
                memberAvatars: chat.memberAvatars,
                isGroup: chat.isGroup,
                isOnline: false,
                onlineColor: AppColors.successGreen,
                borderColor: theme.scaffoldBackgroundColor,
              ),
              const SizedBox(width: 12),
            ] else ...[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  typeIcon,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chat?.name ?? widget.chatTitle ?? 'Message',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (formattedTime.isNotEmpty)
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _buildHighlightedText(
                    text: snippet.isNotEmpty ? snippet : '[$type Message]',
                    query: _currentQuery,
                    theme: theme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText({
    required String text,
    required String query,
    required ThemeData theme,
  }) {
    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      );
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;

    while (start < text.length) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        ),
      ));
      start = index + query.length;
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        children: spans,
      ),
    );
  }
}
