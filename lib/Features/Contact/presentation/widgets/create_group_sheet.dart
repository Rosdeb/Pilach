import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_colour.dart';
import '../providers/contact_providers.dart';
import '../providers/create_group_providers.dart';

class CreateGroupBottomSheet extends ConsumerStatefulWidget {
  const CreateGroupBottomSheet({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateGroupBottomSheet> createState() => _CreateGroupBottomSheetState();
}

class _CreateGroupBottomSheetState extends ConsumerState<CreateGroupBottomSheet> {
  final _groupNameController = TextEditingController();

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch selected members set and master contact list records
    final selectedMembers = ref.watch(selectedMembersProvider);

    // Fallback static list lookup matching your Contacts Screen provider structure
    final contacts = ref.watch(masterContactsProvider);

    return ConstrainedBox(
      // FIXED: Swapped out hardcoded container height for a flexible max constraint boundary.
      // Gives the sheet space to shift up seamlessly without generating bottom rendering overflows.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // FIXED: Shrinks container down dynamically around elements
          children: [
            // --- STICKY iOS TOP NAVIGATION BAR ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: AppColors.background, width: 1)),
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
                      style: TextStyle(color: AppColors.destructiveRed, fontSize: 16),
                    ),
                  ),
                  Column(
                    children: [
                      const Text(
                        'New Group',
                        style: TextStyle(color: AppColors.textDark, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      if (selectedMembers.isNotEmpty)
                        Text(
                          '${selectedMembers.length} Selected',
                          style: const TextStyle(color: AppColors.textLight, fontSize: 11),
                        ),
                    ],
                  ),
                  GestureDetector(
                    onTap: selectedMembers.isEmpty || _groupNameController.text.trim().isEmpty
                        ? null
                        : () {
                      // Finalize group creation logic here
                      ref.read(selectedMembersProvider.notifier).clear();
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Create',
                      style: TextStyle(
                        color: selectedMembers.isEmpty || _groupNameController.text.trim().isEmpty
                            ? AppColors.textLight.withOpacity(0.5)
                            : AppColors.successGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- BODY SECTION CONTENT ---
            Flexible( // FIXED: Swapped Expanded for Flexible to allow elastic shrinking on viewport height adjustments
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24.0, // Dynamic Keyboard layout resizing
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SECTION: GROUP DETAILS CARD ---
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.textWhite,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // Dynamic Group Avatar Picker Node Placeholder
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.background_s1,
                            child: const Icon(CupertinoIcons.camera_fill, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _groupNameController,
                              onChanged: (value) => setState(() {}), // Force rebuild to refresh "Create" button validation state
                              style: const TextStyle(color: AppColors.textDark, fontSize: 16),
                              decoration: const InputDecoration(
                                hintText: 'Enter Group Name',
                                hintStyle: TextStyle(color: AppColors.textLight, fontSize: 16),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // --- SECTION LABEL: ADD MEMBERS ---
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                      child: Text(
                        'ADD MEMBERS',
                        style: TextStyle(color: AppColors.textLight, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),

                    // --- MEMBERS CHECKLIST CONTAINER BLOCK ---
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.textWhite,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: contacts.length,
                        separatorBuilder: (context, index) => const Padding(
                          padding: EdgeInsets.only(left: 68.0),
                          child: Divider(height: 1, thickness: 0.5, color: AppColors.background),
                        ),
                        itemBuilder: (context, index) {
                          final member = contacts[index];
                          final isChecked = selectedMembers.contains(member.id);

                          return ListTile(
                            onTap: () => ref.read(selectedMembersProvider.notifier).toggleMember(member.id),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.background_s2,
                              backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
                              child: member.avatarUrl == null
                                  ? Text(member.name[0], style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            title: Text(
                              member.name,
                              style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            subtitle: Text(
                              member.status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                            ),
                            // Custom iOS Checkmark circle indicator matching successGreen design highlight
                            trailing: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isChecked ? AppColors.successGreen : Colors.transparent,
                                border: Border.all(
                                  color: isChecked ? AppColors.successGreen : AppColors.border.withOpacity(0.6),
                                  width: 1.5,
                                ),
                              ),
                              child: isChecked
                                  ? const Icon(Icons.check, size: 16, color: AppColors.textWhite)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}