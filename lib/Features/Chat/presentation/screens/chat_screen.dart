import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:app/core/constants/app_constants.dart';

import '../../../Contact/presentation/widgets/create_contact_sheet.dart';
import '../../data/models/chat_model.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_tile.dart';
import '../widgets/custom_fad.dart';
import '../widgets/search_bar_widget.dart';
import '../../../../core/providers/api_provider.dart';
import '../../../../core/services/socket_service.dart';

final _chatCountProvider = Provider<int>((ref) => ref.watch(chatProvider).length);

final _chatAtIndexProvider = Provider.family<ChatModel, int>((ref, index) => ref.watch(chatProvider)[index],);

// ─────────────────────────────────────────────────────────────────────────────
// Connection banner provider & notifier
// Checks actual network connectivity before displaying any offline status.
// Uses a 2.5s debounce on startup/reconnect to prevent flickering banners.
// ─────────────────────────────────────────────────────────────────────────────

enum ConnectionBannerStatus {
  hidden,
  offline,
  connecting,
  reconnecting,
}

final connectionBannerProvider = StateNotifierProvider.autoDispose<
    ConnectionBannerNotifier, ConnectionBannerStatus>((ref) {
  final socketService = ref.watch(socketServiceProvider);
  return ConnectionBannerNotifier(socketService);
});

class ConnectionBannerNotifier extends StateNotifier<ConnectionBannerStatus> {
  final SocketService _socketService;
  Timer? _debounceTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<SocketConnectionState>? _socketSub;
  bool _isNetworkOnline = true;
  SocketConnectionState _currentSocketState = SocketConnectionState.disconnected;

  ConnectionBannerNotifier(this._socketService)
      : super(ConnectionBannerStatus.hidden) {
    _init();
  }

  Future<void> _init() async {
    // 1. Initial check of network connectivity
    try {
      final results = await Connectivity().checkConnectivity();
      _isNetworkOnline = !results.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      _isNetworkOnline = true;
    }

    _currentSocketState = _socketService.connectionState;

    // Evaluate initial state without flashing banner if network is online
    _evaluate(isInitial: true);

    // 2. Listen to connectivity changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final online = !results.every((r) => r == ConnectivityResult.none);
      if (_isNetworkOnline != online) {
        _isNetworkOnline = online;
        _evaluate();
      }
    });

    // 3. Listen to socket state changes
    _socketSub = _socketService.connectionStates.listen((socketState) {
      if (_currentSocketState != socketState) {
        _currentSocketState = socketState;
        _evaluate();
      }
    });
  }

  void _evaluate({bool isInitial = false}) {
    if (!mounted) return;

    // If genuine network loss, show offline immediately
    if (!_isNetworkOnline) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      state = ConnectionBannerStatus.offline;
      return;
    }

    // Network is online
    if (_currentSocketState == SocketConnectionState.connected) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      state = ConnectionBannerStatus.hidden;
      return;
    }

    // Network is online, but socket is connecting / reconnecting / disconnected.
    // Debounce to give the socket 2.5s to establish connection without flashing banners.
    if (isInitial || state == ConnectionBannerStatus.hidden) {
      _debounceTimer ??= Timer(const Duration(milliseconds: 2500), () {
        _debounceTimer = null;
        if (!mounted) return;
        if (!_isNetworkOnline) {
          state = ConnectionBannerStatus.offline;
        } else if (_currentSocketState == SocketConnectionState.connecting ||
            _currentSocketState == SocketConnectionState.disconnected) {
          state = ConnectionBannerStatus.connecting;
        } else if (_currentSocketState == SocketConnectionState.reconnecting) {
          state = ConnectionBannerStatus.reconnecting;
        } else {
          state = ConnectionBannerStatus.hidden;
        }
      });
    } else {
      // Banner is already showing; update label according to socket state
      if (_currentSocketState == SocketConnectionState.reconnecting) {
        state = ConnectionBannerStatus.reconnecting;
      } else {
        state = ConnectionBannerStatus.connecting;
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _connectivitySub?.cancel();
    _socketSub?.cancel();
    super.dispose();
  }
}

class ChatScreen extends ConsumerWidget {
  ChatScreen({super.key});

  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(_chatCountProvider);
    final theme = Theme.of(context);
    final isEmpty = count == 0;
    final bannerStatus = ref.watch(connectionBannerProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await ref.read(chatProvider.notifier).fetchFromServer(isManualRefresh: true);
            },
            color: theme.colorScheme.primary,
            backgroundColor: theme.cardColor,
            strokeWidth: 3.0,
            displacement: 80.0,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()
              ),
              slivers: [
                const _ChatSliverAppBar(),

                if (bannerStatus != ConnectionBannerStatus.hidden)
                  SliverToBoxAdapter(
                    child: _ConnectionStatusBanner(status: bannerStatus),
                  ),

                // ── Search bar ────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
                    child: IOSSearchBar(
                      controller: _searchController,
                      readOnly: true,
                      onTap: () => context.push(AppPaths.chat_search),
                    ),
                  ),
                ),

                // ── Chat list ─────────────────────────────────────────────────
                if (isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No conversations yet',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  )
                else
                   SliverList(
                    
                      delegate: SliverChildBuilderDelegate((context, index) => _ChatTileRow(
                          key: ValueKey(ref.read(chatProvider)[index].id),
                          index: index,
                          isLast: index == count - 1,
                        ),
                        childCount: count,
                        addAutomaticKeepAlives: false,
                      ),
                    ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),

          Positioned(
            bottom: 130,
            right: 25,
            child: GlassFab(
              onPressed: () => _showActionMenu(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateBottomSheet(),
    );
  }
}

class _ConnectionStatusBanner extends StatelessWidget {
  const _ConnectionStatusBanner({required this.status});

  final ConnectionBannerStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == ConnectionBannerStatus.hidden) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final (label, textColor) = switch (status) {
      ConnectionBannerStatus.offline => (
        'No internet connection',
        theme.colorScheme.onSurface.withValues(alpha: 0.5),
      ),
      ConnectionBannerStatus.connecting => (
        'Connecting…',
        const Color(0xFFD97706),
      ),
      ConnectionBannerStatus.reconnecting => (
        'Reconnecting…',
        const Color(0xFFD97706),
      ),
      ConnectionBannerStatus.hidden => (
        '',
        Colors.transparent,
      ),
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 6),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App bar — const, never rebuilds
// ─────────────────────────────────────────────────────────────────────────────

class _ChatSliverAppBar extends StatelessWidget {
  const _ChatSliverAppBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverAppBar(
      pinned: true,
      expandedHeight: 60,
      toolbarHeight: 60,
      backgroundColor: theme.scaffoldBackgroundColor,
      surfaceTintColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFF34C759).withValues(alpha: 0.86),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () {},
          child: Icon(
            Icons.add,
            color: theme.colorScheme.onSurface,
            size: 24,
          ),
        ),
        const SizedBox(width: 18),
      ],
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          // BackdropFilter is expensive — wrapping in RepaintBoundary gives
          // it its own layer so it doesn't invalidate the list below.
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 20, bottom: 12),
            centerTitle: false,
            title: Text(
              'Chats',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatTileRow extends ConsumerWidget {
  const _ChatTileRow({
    super.key,
    required this.index,
    required this.isLast,
  });

  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(_chatAtIndexProvider(index));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChatTile(chat: chat),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 68),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: Theme.of(context).dividerColor,
            ),
          ),
      ],
    );
  }
}
