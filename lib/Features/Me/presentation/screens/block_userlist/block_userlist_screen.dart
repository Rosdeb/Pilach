import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:app/components/AppText/appText.dart';
import 'package:app/core/utils/app_toast.dart';
import 'package:app/Features/Contact/presentation/providers/contact_providers.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../providers/block_userlist_providers.dart';
import '../../widgets/block_list.dart';
import '../../widgets/block_list_search.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({Key? key}) : super(key: key);

  void _showBlockContactPicker(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allContacts = ref.read(masterContactsProvider);
    final blockedState = ref.read(blockedUsersProvider);
    final blockedIds = (blockedState.value ?? []).map((u) => u.id).toSet();
    final eligibleContacts =
        allContacts.where((c) => !blockedIds.contains(c.id)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            String filter = '';
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (scrollCtx, scrollController) {
                final displayContacts = filter.trim().isEmpty
                    ? eligibleContacts
                    : eligibleContacts.where((c) =>
                        c.name.toLowerCase().contains(filter.trim().toLowerCase())).toList();

                return Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Block a Contact',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(bottomSheetCtx).pop(),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: CupertinoSearchTextField(
                        placeholder: 'Search contacts to block',
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        onChanged: (val) {
                          setModalState(() {
                            filter = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: displayContacts.isEmpty
                          ? Center(
                              child: Text(
                                eligibleContacts.isEmpty
                                    ? 'No eligible contacts found'
                                    : 'No matches found',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: displayContacts.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                thickness: 0.5,
                                indent: 68,
                                color: theme.dividerColor.withOpacity(0.15),
                              ),
                              itemBuilder: (itemCtx, idx) {
                                final contact = displayContacts[idx];
                                final hasAvatar = contact.avatarUrl != null &&
                                    contact.avatarUrl!.trim().isNotEmpty &&
                                    contact.avatarUrl!.startsWith('http');
                                final initials = contact.name.isNotEmpty
                                    ? contact.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                                    : '?';

                                return ListTile(
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: theme.brightness == Brightness.dark
                                        ? const Color(0xFF1A3E40)
                                        : const Color(0xFFB8D8DA),
                                    backgroundImage: hasAvatar
                                        ? CachedNetworkImageProvider(contact.avatarUrl!.trim())
                                        : null,
                                    child: !hasAvatar
                                        ? Text(
                                            initials,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    contact.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  subtitle: Text(
                                    contact.status,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                  trailing: const Icon(
                                    CupertinoIcons.slash_circle,
                                    color: CupertinoColors.destructiveRed,
                                    size: 22,
                                  ),
                                  onTap: () {
                                    Navigator.of(bottomSheetCtx).pop();
                                    _confirmBlockContact(context, ref, contact);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _confirmBlockContact(BuildContext context, WidgetRef ref, ContactItem contact) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('Block ${contact.name}?'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text('Blocked contacts will no longer be able to message or call you.'),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Block'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(blockedUsersProvider.notifier)
                  .blockUser(contact.id);
              if (context.mounted) {
                if (success) {
                  AppToast.show(context, 'Blocked ${contact.name}',
                      type: ToastType.success);
                } else {
                  AppToast.show(context, 'Failed to block ${contact.name}',
                      type: ToastType.error);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedState = ref.watch(blockedUsersProvider);
    final filteredUsers = ref.watch(filteredBlockedUsersProvider);
    final searchQuery = ref.watch(searchbarProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () => ref.read(blockedUsersProvider.notifier).fetchBlockedUsers(),
        color: theme.colorScheme.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // --- GLASS EFFECT APP BAR ---
            SliverAppBar(
              pinned: true,
              floating: false,
              snap: false,
              expandedHeight: 60,
              toolbarHeight: 60,
              automaticallyImplyLeading: false,
              backgroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: AppText(
                'Blocked Users',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    CupertinoIcons.person_badge_plus,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  tooltip: 'Block a contact',
                  onPressed: () => _showBlockContactPicker(context, ref),
                ),
              ],
            ),

            // --- MAIN CONTENT ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- iOS SEARCH BAR ---
                    IOSSearchBar(
                      hintText: "Search blocked contacts",
                      onChanged: (value) {},
                    ),
                    const SizedBox(height: 24.0),

                    // --- LIST HEADER DESCRIPTION ---
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                      child: Row(
                        children: [
                          AppText(
                            'BLOCKED CONTACTS',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          if (blockedState.value != null)
                            AppText(
                              '${blockedState.value!.length}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // --- BLOCKED LIST CONTAINER ---
                    if (blockedState.isLoading && blockedState.value == null)
                      Container(
                        height: 120,
                        alignment: Alignment.center,
                        child: const CupertinoActivityIndicator(),
                      )
                    else if (blockedState.hasError && (blockedState.value == null || blockedState.value!.isEmpty))
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              CupertinoIcons.exclamationmark_triangle,
                              size: 40,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Failed to load blocked users',
                              style: TextStyle(color: theme.colorScheme.onSurface),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => ref
                                  .read(blockedUsersProvider.notifier)
                                  .fetchBlockedUsers(),
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    else if (filteredUsers.isEmpty)
                      _buildEmptyState(context, isSearch: searchQuery.isNotEmpty)
                    else
                      BlockedUserList(blockedUsers: filteredUsers),

                    const SizedBox(height: 12),
                    // --- iOS FOOTER EXPLANATION ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: AppText(
                        'Blocked users will not be able to send you messages, view your profile updates, or initiate voice/video calls with you.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {bool isSearch = false}) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            isSearch ? CupertinoIcons.search : CupertinoIcons.checkmark_shield,
            size: 48,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(height: 12),
          AppText(
            isSearch ? 'No Results Found' : 'No Blocked Users',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          AppText(
            isSearch
                ? 'Check your search query or clear the filter.'
                : 'Contacts you block will appear here.',
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
