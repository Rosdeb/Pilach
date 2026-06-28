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

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Exposes only the chat count — so the SliverList itemCount doesn't force
/// a full list rebuild when only one item's fields change.
final _chatCountProvider = Provider<int>((ref) => ref.watch(chatProvider).length);

/// Exposes a single chat by index — ChatTile watches this instead of the
/// full list, so only the tile whose data changed gets rebuilt.
final _chatAtIndexProvider = Provider.family<ChatModel, int>((ref, index) => ref.watch(chatProvider)[index],);

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ChatScreen extends ConsumerWidget {
  ChatScreen({super.key});

  // TextEditingController is fine as a field on ConsumerWidget —
  // ConsumerWidget rebuilds don't recreate fields; only StatefulWidget.state does.
  // But to be safe and avoid potential leaks, keep it here since this widget
  // lives as long as the bottom nav tab is alive.
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch only the count — not the full list.
    // Pin/mute/delete changes will update individual tiles via _chatAtIndexProvider,
    // not this widget.
    final count = ref.watch(_chatCountProvider);
    final theme = Theme.of(context);
    final isEmpty = count == 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            // ClampingScrollPhysics on Android avoids the overscroll glow
            // repaint that BouncingScrollPhysics triggers. Use a platform check
            // so iOS keeps its native bounce feel.
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // ── Glass app bar ─────────────────────────────────────────────
              // Extracted to a const-constructable widget so it never rebuilds
              // when the chat list changes.
              const _ChatSliverAppBar(),

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
                    delegate: SliverChildBuilderDelegate(
                          (context, index) => _ChatTileRow(
                        // Stable key on chat ID so Flutter reuses element
                        // when list reorders (pin moves item to top).
                        // Without this, Flutter recreates the tile on every
                        // pin/unpin, throwing away animation state.
                        key: ValueKey(ref.read(chatProvider)[index].id),
                        index: index,
                        isLast: index == count - 1,
                      ),
                      childCount: count,
                      // addAutomaticKeepAlives: false means Flutter can
                      // discard off-screen tiles from memory freely.
                      addAutomaticKeepAlives: false,
                      // addRepaintBoundaries: true is the default — each
                      // SliverList item gets its own layer automatically.
                    ),
                  ),
                ),

              // Bottom padding so last tile clears the FAB.
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // ── FAB ───────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// Per-row widget — watches only its own chat via family provider
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps [ChatTile] + divider. Watches a single chat by index via
/// [_chatAtIndexProvider] so only this row rebuilds when its data changes.
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