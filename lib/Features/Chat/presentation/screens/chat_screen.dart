import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app/core/constants/app_constants.dart';

import '../../../Contact/presentation/widgets/create_contact_sheet.dart';
import '../../data/models/chat_model.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_tile.dart';
import '../widgets/custom_fad.dart';
import '../widgets/search_bar_widget.dart';

final _chatCountProvider = Provider<int>((ref) => ref.watch(chatProvider).length);

final _chatAtIndexProvider = Provider.family<ChatModel, int>((ref, index) => ref.watch(chatProvider)[index],);

class ChatScreen extends ConsumerWidget {
  ChatScreen({super.key});

  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(_chatCountProvider);
    final theme = Theme.of(context);
    final isEmpty = count == 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const _ChatSliverAppBar(),

              // ── Pull to Refresh ───────────────────────────────────────────
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  await ref.read(chatProvider.notifier).fetchFromServer(isManualRefresh: true);
                },
              ),

              // ── Search bar ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
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
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) => _ChatTileRow(
                        key: ValueKey(ref.read(chatProvider)[index].id),
                        index: index,
                        isLast: index == count - 1,
                      ),
                      childCount: count,
                      addAutomaticKeepAlives: false,

                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          Positioned(
            bottom: 130,
            right: 16,
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
            backgroundColor: const Color(0xFF34C759).withOpacity(0.86),
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