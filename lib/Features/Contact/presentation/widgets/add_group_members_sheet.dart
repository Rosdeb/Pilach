import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/app_toast.dart';
import 'package:app/Features/Chat/presentation/providers/chat_provider.dart';

import '../providers/contact_providers.dart';
import '../providers/create_group_providers.dart';

class AddGroupMembersBottomSheet extends ConsumerStatefulWidget {
  final String conversationId;
  final String groupTitle;

  const AddGroupMembersBottomSheet({
    super.key,
    required this.conversationId,
    required this.groupTitle,
  });

  @override
  ConsumerState<AddGroupMembersBottomSheet> createState() =>
      _AddGroupMembersBottomSheetState();
}

class _AddGroupMembersBottomSheetState
    extends ConsumerState<AddGroupMembersBottomSheet> {
  final _searchController = TextEditingController();
  bool _isAdding = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addMembers(Set<String> selectedMembers) async {
    if (_isAdding) return;

    if (selectedMembers.isEmpty) {
      AppToast.show(
        context,
        'Please select at least one member',
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _isAdding = true);
    try {
      final success = await ref
          .read(chatProvider.notifier)
          .addMembersToConversation(
            widget.conversationId,
            selectedMembers.toList(growable: false),
          );

      if (!mounted) return;

      if (success) {
        ref.read(selectedMembersProvider.notifier).clear();
        AppToast.show(
          context,
          'Added ${selectedMembers.length} member(s) to ${widget.groupTitle}',
          type: ToastType.success,
        );
        Navigator.of(context).pop();
      } else {
        throw Exception('Server failed to add members');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      AppToast.show(
        context,
        message.isEmpty ? 'Failed to add members' : message,
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMembers = ref.watch(selectedMembersProvider);
    final allContacts = ref.watch(masterContactsProvider);
    final theme = Theme.of(context);

    // Filter contacts based on search query
    final filteredContacts = allContacts.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) ||
          c.id.toLowerCase().contains(q) ||
          c.status.toLowerCase().contains(q) ||
          (c.lastMessage?.toLowerCase().contains(q) ?? false);
    }).toList();

    final isManualIdEligible = _searchQuery.trim().isNotEmpty &&
        !allContacts.any(
          (c) => c.id.toLowerCase() == _searchQuery.trim().toLowerCase(),
        ) &&
        !selectedMembers.contains(_searchQuery.trim());

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- STICKY TOP NAVIGATION BAR ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      ref.read(selectedMembersProvider.notifier).clear();
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFFFF3B30), fontSize: 16),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        'Add Members',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        selectedMembers.isEmpty
                            ? widget.groupTitle
                            : '${selectedMembers.length} Selected',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: selectedMembers.isEmpty || _isAdding
                        ? null
                        : () => _addMembers(selectedMembers),
                    child: _isAdding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CupertinoActivityIndicator(),
                          )
                        : Text(
                            'Add',
                            style: TextStyle(
                              color: selectedMembers.isNotEmpty && !_isAdding
                                  ? const Color(0xFF34C759)
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.3,
                                    ),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
                ),
                children: [
                  // --- SELECTED MEMBERS CHIPS ---
                  if (selectedMembers.isNotEmpty) ...[
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: selectedMembers.map((memberId) {
                          final match = allContacts
                              .where((c) => c.id == memberId)
                              .firstOrNull;
                          final displayName = match?.name ??
                              (memberId.length > 10
                                  ? '${memberId.substring(0, 8)}…'
                                  : memberId);

                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    ref
                                        .read(selectedMembersProvider.notifier)
                                        .toggleMember(memberId);
                                  },
                                  child: Icon(
                                    CupertinoIcons.clear_circled_solid,
                                    size: 16,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                  ],

                  // --- SEARCH & FILTER BAR ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.search,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() => _searchQuery = val.trim());
                            },
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search conversations...',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.45,
                                ),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(
                              CupertinoIcons.clear_circled_solid,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.45,
                              ),
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // --- ADD MANUAL USER ID BUTTON ---
                  if (isManualIdEligible) ...[
                    const SizedBox(height: 8.0),
                    Material(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          ref
                              .read(selectedMembersProvider.notifier)
                              .toggleMember(_searchQuery.trim());
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(
                                  0xFF34C759,
                                ).withValues(alpha: 0.15),
                                child: const Icon(
                                  Icons.person_add_rounded,
                                  color: Color(0xFF34C759),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Add "${_searchQuery.trim()}"',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF34C759),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16.0),

                  // --- SECTION HEADER ---
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'YOUR CONVERSATIONS',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (allContacts.isNotEmpty)
                          Text(
                            '${allContacts.length} available',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.45,
                              ),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // --- CONVERSATION CONTACTS LIST ---
                  if (filteredContacts.isEmpty && !isManualIdEligible)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 24,
                      ),
                      child: Center(
                        child: Text(
                          allContacts.isEmpty
                              ? 'No conversations found.'
                              : 'No matching conversations found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                  if (filteredContacts.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < filteredContacts.length; i++) ...[
                            _buildContactRow(
                              contact: filteredContacts[i],
                              isChecked: selectedMembers.contains(
                                filteredContacts[i].id,
                              ),
                              theme: theme,
                              onTap: () {
                                ref
                                    .read(selectedMembersProvider.notifier)
                                    .toggleMember(filteredContacts[i].id);
                              },
                            ),
                            if (i < filteredContacts.length - 1)
                              Divider(
                                height: 1,
                                thickness: 0.5,
                                indent: 64,
                                endIndent: 16,
                                color: theme.dividerColor.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow({
    required ContactItem contact,
    required bool isChecked,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    const successColor = Color(0xFF34C759);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.brightness == Brightness.dark
                      ? const Color(0xFF1A3E40)
                      : const Color(0xFFB8D8DA),
                  backgroundImage:
                      contact.avatarUrl != null &&
                              contact.avatarUrl!.startsWith('http')
                          ? NetworkImage(contact.avatarUrl!)
                          : null,
                  child:
                      (contact.avatarUrl == null ||
                              !contact.avatarUrl!.startsWith('http'))
                          ? Text(
                              contact.name.isEmpty
                                  ? '?'
                                  : contact.name[0].toUpperCase(),
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                ),
                if (contact.isOnline)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: successColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isChecked ? successColor : Colors.transparent,
                border: Border.all(
                  color: isChecked
                      ? successColor
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
