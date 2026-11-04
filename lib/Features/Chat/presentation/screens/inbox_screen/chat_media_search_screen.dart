import 'dart:async';

import 'package:app/core/constants/api_constants.dart';
import 'package:app/core/network/chat_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/image_preview_viewer.dart';

class ChatMediaSearchScreen extends ConsumerStatefulWidget {
  const ChatMediaSearchScreen({
    super.key,
    required this.chatId,
    required this.chatTitle,
    this.initialKind = 'media',
  });

  final String chatId;
  final String chatTitle;
  final String initialKind;

  @override
  ConsumerState<ChatMediaSearchScreen> createState() =>
      _ChatMediaSearchScreenState();
}

class _ChatMediaSearchScreenState extends ConsumerState<ChatMediaSearchScreen> {
  static const _kinds = ['media', 'files', 'links', 'audio'];
  static const _pageSize = 30;

  late String _kind;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMediaItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _kind = _kinds.contains(widget.initialKind) ? widget.initialKind : 'media';
    _scrollController.addListener(_onScroll);
    scheduleMicrotask(_refresh);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 400) {
      _loadMore();
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _page = 1;
      _hasMore = true;
      _error = null;
      _isLoading = true;
    });
    await _loadPage(1, replace: true);
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    await _loadPage(_page + 1, replace: false);
  }

  Future<void> _loadPage(int page, {required bool replace}) async {
    try {
      final response = await ref
          .read(chatRepositoryProvider)
          .getChatMedia(
            widget.chatId,
            kind: _kind,
            page: page,
            limit: _pageSize,
          );
      final rawItems = _extractList(response);
      final parsed = rawItems
          .whereType<Map>()
          .expand(
            (raw) => _ChatMediaItem.fromApi(
              Map<String, dynamic>.from(raw),
              fallbackKind: _kind,
            ),
          )
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        if (replace) _items.clear();
        final knownKeys = _items.map((item) => item.key).toSet();
        _items.addAll(parsed.where((item) => knownKeys.add(item.key)));
        _page = page;
        _hasMore = _responseHasMore(response, rawItems.length, page);
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Could not load ${_tabLabel(_kind).toLowerCase()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  List<dynamic> _extractList(Map<String, dynamic> response) {
    dynamic value = response['data'];
    if (value is List) return value;
    if (value is Map) {
      for (final key in ['items', 'messages', 'results', 'data']) {
        if (value[key] is List) return value[key] as List;
      }
    }
    for (final key in ['items', 'messages', 'results']) {
      if (response[key] is List) return response[key] as List;
    }
    return const [];
  }

  bool _responseHasMore(
    Map<String, dynamic> response,
    int received,
    int currentPage,
  ) {
    final data = response['data'];
    final pagination = response['pagination'] is Map
        ? response['pagination'] as Map
        : data is Map && data['pagination'] is Map
        ? data['pagination'] as Map
        : response['meta'] is Map
        ? response['meta'] as Map
        : null;
    if (pagination != null) {
      final hasNext = pagination['hasNext'] ?? pagination['hasMore'];
      if (hasNext is bool) return hasNext;
      final totalPages = int.tryParse('${pagination['totalPages'] ?? ''}');
      if (totalPages != null) return currentPage < totalPages;
      if (pagination['nextPage'] != null || pagination['nextCursor'] != null) {
        return true;
      }
    }
    return received >= _pageSize;
  }

  void _changeKind(String kind) {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      _items.clear();
      _searchController.clear();
    });
    _refresh();
  }

  List<_ChatMediaItem> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _items;
    return _items.where((item) => item.searchText.contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20,color: Colors.black,),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Shared content', style: TextStyle(fontSize: 16,color: Colors.black,fontWeight: FontWeight.w500),),
            Text(
              widget.chatTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 1.0),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildTabs(theme),
          _buildSearchField(theme),
          Expanded(child: _buildContent(theme)),
        ],
      ),
    );
  }

  Widget _buildTabs(ThemeData theme) {
    return SizedBox(
      height: 47,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: _kinds.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final kind = _kinds[index];
          final selected = kind == _kind;
          return ChoiceChip(
            label: Text(_tabLabel(kind)),
            selected: selected,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            side: BorderSide(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: .3),
            ),
            labelStyle: TextStyle(
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            selectedColor: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surface,
            onSelected: (_) => _changeKind(kind),
          );
        },
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 16, 12),
      child: CupertinoSearchTextField(
        controller: _searchController,
        placeholder: 'Search ${_tabLabel(_kind).toLowerCase()}',
        onChanged: (_) => setState(() {}),
        onSuffixTap: () {
          _searchController.clear();
          setState(() {});
        },
        backgroundColor: theme.colorScheme.onSurface.withValues(alpha: .07),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CupertinoActivityIndicator(radius: 13));
    }
    if (_error != null && _items.isEmpty) {
      return _StatusView(
        icon: CupertinoIcons.exclamationmark_circle,
        title: _error!,
        actionLabel: 'Try again',
        onAction: _refresh,
      );
    }

    final items = _filteredItems;
    if (items.isEmpty) {
      final searching = _searchController.text.trim().isNotEmpty;
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * .22),
            _StatusView(
              icon: searching ? CupertinoIcons.search : _emptyIcon(_kind),
              title: searching
                  ? 'No matching ${_tabLabel(_kind).toLowerCase()}'
                  : 'No ${_tabLabel(_kind).toLowerCase()} shared yet',
              subtitle: searching ? 'Try a different search term' : null,
            ),
          ],
        ),
      );
    }

    if (_kind == 'media') return _buildMediaGrid(items, theme);
    return _buildList(items, theme);
  }

  Widget _buildMediaGrid(List<_ChatMediaItem> items, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(3, 0, 3, 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
        ),
        itemCount: items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return const Center(child: CupertinoActivityIndicator());
          }
          final item = items[index];
          return InkWell(
            onTap: () => _openItem(item),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.isImage)
                  CachedNetworkImage(
                    imageUrl: item.resolvedUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      color: theme.colorScheme.onSurface.withValues(alpha: .06),
                    ),
                    errorWidget: (_, _, _) => _mediaPlaceholder(theme, item),
                  )
                else
                  _mediaPlaceholder(theme, item),
                if (item.isVideo)
                  const Center(
                    child: Icon(
                      CupertinoIcons.play_circle_fill,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _mediaPlaceholder(ThemeData theme, _ChatMediaItem item) {
    return ColoredBox(
      color: theme.colorScheme.onSurface.withValues(alpha: .08),
      child: Icon(
        item.isVideo ? CupertinoIcons.videocam_fill : CupertinoIcons.photo,
        color: theme.colorScheme.onSurface.withValues(alpha: .4),
        size: 34,
      ),
    );
  }

  Widget _buildList(List<_ChatMediaItem> items, ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: items.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => Divider(
          height: 1,
          indent: 76,
          color: theme.dividerColor.withValues(alpha: .12),
        ),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CupertinoActivityIndicator()),
            );
          }
          final item = items[index];
          return ListTile(
            onTap: () => _openItem(item),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _itemIcon(item),
                color: theme.colorScheme.primary,
                size: 23,
              ),
            ),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              [
                if (item.sender.isNotEmpty) item.sender,
                if (item.formattedSize.isNotEmpty) item.formattedSize,
                if (item.formattedDate.isNotEmpty) item.formattedDate,
              ].join(' • '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: .55),
              ),
            ),
            trailing: Icon(
              CupertinoIcons.arrow_up_right,
              size: 17,
              color: theme.colorScheme.onSurface.withValues(alpha: .35),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openItem(_ChatMediaItem item) async {
    if (item.isImage) {
      FullScreenImageViewer.open(
        context,
        imagePathOrUrl: item.resolvedUrl,
        title: item.title,
      );
      return;
    }
    final uri = Uri.tryParse(item.resolvedUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this item')),
        );
      }
    }
  }

  static String _tabLabel(String kind) => switch (kind) {
    'files' => 'Files',
    'links' => 'Links',
    'audio' => 'Audio',
    _ => 'Media',
  };

  static IconData _emptyIcon(String kind) => switch (kind) {
    'files' => CupertinoIcons.doc,
    'links' => CupertinoIcons.link,
    'audio' => CupertinoIcons.waveform,
    _ => CupertinoIcons.photo_on_rectangle,
  };

  static IconData _itemIcon(_ChatMediaItem item) {
    if (item.kind == 'links') return CupertinoIcons.link;
    if (item.kind == 'audio') return CupertinoIcons.waveform;
    return CupertinoIcons.doc_fill;
  }
}

class _ChatMediaItem {
  const _ChatMediaItem({
    required this.id,
    required this.kind,
    required this.url,
    required this.fileName,
    required this.mimeType,
    required this.messageText,
    required this.sender,
    required this.createdAt,
    required this.size,
  });

  final String id;
  final String kind;
  final String url;
  final String fileName;
  final String mimeType;
  final String messageText;
  final String sender;
  final DateTime? createdAt;
  final int? size;

  String get key => '$id|$url|$fileName';
  bool get isImage =>
      mimeType.startsWith('image/') ||
      ['IMAGE', 'GIF'].contains(mimeType.toUpperCase());
  bool get isVideo => mimeType.startsWith('video/') || mimeType == 'VIDEO';
  String get resolvedUrl {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final path = url.startsWith('/') ? url.substring(1) : url;
    return '${ApiConstants.baseUrl}/$path';
  }

  String get title {
    if (fileName.isNotEmpty) return fileName;
    if (kind == 'links') return url;
    if (messageText.isNotEmpty) return messageText;
    return kind == 'audio' ? 'Audio message' : 'Shared file';
  }

  String get searchText =>
      '$fileName $messageText $sender $url $mimeType'.toLowerCase();

  String get formattedDate => createdAt == null
      ? ''
      : DateFormat('MMM d, yyyy').format(createdAt!.toLocal());

  String get formattedSize {
    final bytes = size;
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Iterable<_ChatMediaItem> fromApi(
    Map<String, dynamic> raw, {
    required String fallbackKind,
  }) sync* {
    final message = raw['message'] is Map
        ? Map<String, dynamic>.from(raw['message'] as Map)
        : raw;
    final attachments = message['attachments'] is List
        ? message['attachments'] as List
        : raw['attachments'] is List
        ? raw['attachments'] as List
        : const [];
    final text = '${message['text'] ?? raw['text'] ?? raw['snippet'] ?? ''}';
    final urls = fallbackKind == 'links'
        ? _extractUrls(text)
        : const <String>[];

    if (attachments.isNotEmpty) {
      for (var index = 0; index < attachments.length; index++) {
        final value = attachments[index];
        if (value is! Map) continue;
        final attachment = Map<String, dynamic>.from(value);
        final url = '${attachment['url'] ?? attachment['publicUrl'] ?? ''}';
        if (url.isEmpty) continue;
        yield _fromParts(
          raw: raw,
          message: message,
          attachment: attachment,
          url: url,
          text: text,
          fallbackKind: fallbackKind,
          suffix: '$index',
        );
      }
      return;
    }

    if (urls.isNotEmpty) {
      for (var index = 0; index < urls.length; index++) {
        yield _fromParts(
          raw: raw,
          message: message,
          attachment: const {},
          url: urls[index],
          text: text,
          fallbackKind: fallbackKind,
          suffix: '$index',
        );
      }
      return;
    }

    final url = '${raw['url'] ?? message['mediaUrl'] ?? raw['mediaUrl'] ?? ''}';
    if (url.isNotEmpty) {
      yield _fromParts(
        raw: raw,
        message: message,
        attachment: raw,
        url: url,
        text: text,
        fallbackKind: fallbackKind,
        suffix: '0',
      );
    }
  }

  static _ChatMediaItem _fromParts({
    required Map<String, dynamic> raw,
    required Map<String, dynamic> message,
    required Map<String, dynamic> attachment,
    required String url,
    required String text,
    required String fallbackKind,
    required String suffix,
  }) {
    final senderValue = message['sender'] ?? raw['sender'];
    final sender = senderValue is Map
        ? '${senderValue['name'] ?? senderValue['username'] ?? senderValue['profile']?['name'] ?? ''}'
        : '${message['senderName'] ?? raw['senderName'] ?? ''}';
    final dateValue = message['createdAt'] ?? raw['createdAt'];
    final sizeValue = attachment['size'] ?? raw['size'];
    return _ChatMediaItem(
      id: '${message['id'] ?? raw['id'] ?? 'item'}-$suffix',
      kind: fallbackKind,
      url: url,
      fileName:
          '${attachment['fileName'] ?? attachment['filename'] ?? raw['fileName'] ?? ''}',
      mimeType:
          '${attachment['mimeType'] ?? attachment['type'] ?? message['type'] ?? ''}',
      messageText: text,
      sender: sender,
      createdAt: dateValue == null ? null : DateTime.tryParse('$dateValue'),
      size: sizeValue is num ? sizeValue.toInt() : int.tryParse('$sizeValue'),
    );
  }

  static List<String> _extractUrls(String text) {
    return RegExp(r'https?://[^\s<>]+', caseSensitive: false)
        .allMatches(text)
        .map((match) => match.group(0)!.replaceFirst(RegExp(r'[),.!?]+$'), ''))
        .toList(growable: false);
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: .25),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 5),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: .5),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
