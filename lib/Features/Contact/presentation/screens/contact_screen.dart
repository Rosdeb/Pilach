import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/AppText/appText.dart';
import '../../../../core/utils/app_colour.dart';
import '../providers/contact_providers.dart';
import '../widgets/create_contact_sheet.dart';
import '../widgets/create_group_sheet.dart';
import '../widgets/new_contact_sheet.dart';
import '../widgets/slidable_bar.dart';
class ContactScreen extends ConsumerWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedContacts = ref.watch(groupedContactsProvider);
    final searchController = TextEditingController(text: ref.read(contactSearchProvider));

    // Full A-Z asset list matching the screen's right sidebar layout gutter track
    final alphabetList = "#ABCDEFGHIJKLMNOPQRSTUVWXYZ".split('');

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- GLASS EFFECT APP BAR ---
              SliverAppBar(
                pinned: true,
                floating: false,
                snap: false,
                automaticallyImplyLeading: false,
                expandedHeight: 80.0, // Gives room for the large iOS title layout
                toolbarHeight: 65.0,
                backgroundColor: AppColors.background, // Semi-transparent base
                centerTitle: false,
                // This is where the magic glass blur effect happens
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: const FlexibleSpaceBar(
                      titlePadding: EdgeInsets.only(left: 24.0, bottom: 16.0),
                      centerTitle: false,
                      title: AppText(
                        'Contacts',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // --- MAIN SCROLL LIST CONTENT ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0, right: 32.0, top: 12.0), // Padding adjusted for right side track
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- iOS STYLE SEARCH BAR ---
                      Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.textWhite,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.search, color: AppColors.textLight, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: searchController,
                                onChanged: (val) => ref.read(contactSearchProvider.notifier).state = val,
                                decoration: const InputDecoration(
                                  hintText: 'Search',
                                  hintStyle: TextStyle(color: AppColors.textLight, fontSize: 16),
                                  border: InputBorder.none,
                                  isDense: true,
                                  fillColor: AppColors.textWhite,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (searchController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  searchController.clear();
                                  ref.read(contactSearchProvider.notifier).state = '';
                                },
                                child: const Icon(CupertinoIcons.clear_fill, color: AppColors.textLight, size: 16),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // --- TOP ACTION CARD ITEMS ---
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.textWhite,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildTopActionRow(icon: Icons.group_add_outlined, title: 'New Group',onTap: (){
                              _showCreateGroupBottomSheet(context);
                            }),
                            const Padding(
                              padding: EdgeInsets.only(left: 56.0),
                              child: Divider(height: 1, thickness: 0.5, color: AppColors.background),
                            ),
                            _buildTopActionRow(icon: Icons.person_add_alt, title: 'New Contact',onTap: (){
                              _showCreateBottomSheet(context);
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // --- DYNAMIC ALPHABETICAL CONTACT BLOCKS ---
                      if (groupedContacts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40.0),
                          child: Center(
                            child: Text('No Contacts Found', style: TextStyle(color: AppColors.textLight)),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: groupedContacts.keys.length,
                          itemBuilder: (context, sectionIdx) {
                            final keyLetter = groupedContacts.keys.elementAt(sectionIdx);
                            final currentLetterContacts = groupedContacts[keyLetter]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Alphabet Section Header Label
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0, top: 8.0, bottom: 6.0),
                                  child: Text(
                                    keyLetter,
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                // Round Background Block Container Box for targeted letter cluster list
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.textWhite,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: currentLetterContacts.length,
                                    separatorBuilder: (context, index) => const Padding(
                                      padding: EdgeInsets.only(left: 68.0),
                                      child: Divider(height: 1, thickness: 0.5, color: AppColors.background),
                                    ),
                                    itemBuilder: (context, itemIdx) {
                                      final contact = currentLetterContacts[itemIdx];
                                      return _buildContactTile(contact);
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // --- FIXED RIGHT SIDE ALPHABET INDEX SCROLL BAR TRACK ---
          AlphabetSidebar(
            alphabetList: alphabetList,
            onLetterSelected: (letter) {
              print(letter);
              // scroll logic here
            },
          ),

        ],
      ),
    );
  }

  // Row helper for top components ("New Group", "New Contact")
  Widget _buildTopActionRow({required IconData icon, required String title,required VoidCallback onTap}) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: AppColors.textDark, size: 22),
      title: Text(
        title,
        style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w500, fontSize: 16),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.border),
      onTap: onTap,
    );
  }


  void _showCreateBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Ensures our custom rounded corners aren't clipped
      builder: (context) => const CreateBottomSheet(),
    );
  }


  void _showCreateGroupBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Ensures our custom rounded corners aren't clipped
      builder: (context) => const CreateGroupBottomSheet(),
    );
  }

  // Row builder for items inside contact lists
  Widget _buildContactTile(ContactItem contact) {
    // Generate fallback initials label placeholder if explicit image URL string avatar property data isn't initialized
    final String initials = contact.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: contact.avatarUrl == null ? AppColors.background_s2 : Colors.transparent,
        backgroundImage: contact.avatarUrl != null ? NetworkImage(contact.avatarUrl!) : null,
        child: contact.avatarUrl == null
            ? Text(
          initials,
          style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.bold),
        )
            : null,
      ),
      title: Text(
        contact.name,
        style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2.0),
        child: Text(
          contact.status,
          style: const TextStyle(color: AppColors.textLight, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      onTap: () {},
    );
  }

  void _showNewContactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Crucial to allow text field keyboard offsets
      backgroundColor: Colors.transparent, // Keeps our custom rounded top visible
      builder: (context) => const NewContactBottomSheet(),
    );
  }

}