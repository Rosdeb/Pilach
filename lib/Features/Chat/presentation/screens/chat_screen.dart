import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app/core/constants/app_constants.dart';

import '../../../Contact/presentation/widgets/create_contact_sheet.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_tile.dart';
import '../widgets/custom_fad.dart';
import '../widgets/search_bar_widget.dart';

class ChatScreen extends ConsumerWidget {
  ChatScreen({super.key});

  final TextEditingController searchController = TextEditingController();


  void _showActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatProvider);
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // --- SLIVER VIEW PORT ---
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // --- GLASS EFFECT LARGE TITLE APP BAR ---
              SliverAppBar(
                pinned: true,
                expandedHeight: 60.0,
                toolbarHeight: 60.0,
                backgroundColor: theme.scaffoldBackgroundColor,
                surfaceTintColor:  theme.scaffoldBackgroundColor,
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
                    onPressed: () {
                      // Your action here
                    },
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
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(left: 20.0, bottom: 12.0),
                      centerTitle: false,
                      title: Text(
                        'Chats', // Change this dynamically if needed
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),


              // --- FLOATING/STICKY SEARCH BAR ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 2.0),
                  child: IOSSearchBar(
                    controller: searchController,
                    readOnly: true,
                    onTap: () {
                      context.push(AppPaths.chat_search);
                    },
                  ),
                ),
              ),

              // --- SCROLLABLE CHAT LIST CONTAINER ---
              if (chats.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No conversations yet',
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final chat = chats[index];
                      final isLast = index == chats.length - 1;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ChatTile(chat: chat),
                          if (!isLast)
                            Padding(
                              padding: const EdgeInsets.only(left: 68.0),
                              // Aligns clean with avatar edge
                              child: Divider(
                                height: 1,
                                thickness: 0.5,
                                color: theme.dividerColor,
                              ),
                            ),
                        ],
                      );
                    }, childCount: chats.length),
                  ),
                ),

              // Safe bottom spacing margin inside slivers so items don't get stuck behind your FAB
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // --- FIXED FLOATING GLASS FAB ---
          Positioned(
            bottom: 130,
            right: 16,
            child: GlassFab(
              onPressed: (){
                _showActionMenu(context);
              }, // FIXED: Both buttons now open the identical UI trigger matrix!
            ),
          ),

        ],
      ),
    );
  }
}
