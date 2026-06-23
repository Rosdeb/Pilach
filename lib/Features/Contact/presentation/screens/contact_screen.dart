import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/AppText/appText.dart';
import '../providers/contact_providers.dart';
import '../widgets/create_contact_sheet.dart';
import '../widgets/create_group_sheet.dart';
import '../widgets/slidable_bar.dart';
class ContactScreen extends ConsumerWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedContacts = ref.watch(groupedContactsProvider);
    final searchController = TextEditingController(text: ref.read(contactSearchProvider));
    final theme = Theme.of(context);

    // Full A-Z asset list matching the screen's right sidebar layout gutter track
    final alphabetList = "#ABCDEFGHIJKLMNOPQRSTUVWXYZ".split('');

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
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
                expandedHeight: 65.0, // Gives room for the large iOS title layout
                toolbarHeight: 65.0,
                backgroundColor: theme.scaffoldBackgroundColor, // Semi-transparent base
                surfaceTintColor:  theme.scaffoldBackgroundColor,
                centerTitle: false,
                // This is where the magic glass blur effect happens
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                    child: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(left: 24.0, bottom: 16.0),
                      centerTitle: false,
                      title: AppText(
                        'Contacts',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 28,
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
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.search, color: theme.colorScheme.onSurface.withOpacity(0.6), size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: searchController,
                                onChanged: (val) => ref.read(contactSearchProvider.notifier).state = val,
                                style: TextStyle(color: theme.colorScheme.onSurface),
                                decoration: InputDecoration(
                                  hintText: 'Search',
                                  hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 16),
                                  border: InputBorder.none,
                                  isDense: true,
                                  fillColor: theme.colorScheme.surface,
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
                                child: Icon(CupertinoIcons.clear_fill, color: theme.colorScheme.onSurface.withOpacity(0.6), size: 16),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // --- TOP ACTION CARD ITEMS ---
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildTopActionRow(context, icon: Icons.group_add_outlined, title: 'New Group',onTap: (){
                              _showCreateGroupBottomSheet(context);
                            }),
                            Padding(
                              padding: const EdgeInsets.only(left: 56.0),
                              child: Divider(height: 1, thickness: 0.5, color: theme.dividerColor.withOpacity(0.12)),
                            ),
                            _buildTopActionRow(context, icon: Icons.person_add_alt, title: 'New Contact',onTap: (){
                              _showCreateBottomSheet(context);
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // --- DYNAMIC ALPHABETICAL CONTACT BLOCKS ---
                      if (groupedContacts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40.0),
                          child: Center(
                            child: Text('No Contacts Found', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
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
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                // Round Background Block Container Box for targeted letter cluster list
                                Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: currentLetterContacts.length,
                                    separatorBuilder: (context, index) => Padding(
                                      padding: const EdgeInsets.only(left: 68.0),
                                      child: Divider(height: 1, thickness: 0.5, color: theme.dividerColor.withOpacity(0.12)),
                                    ),
                                    itemBuilder: (context, itemIdx) {
                                      final contact = currentLetterContacts[itemIdx];
                                      return _buildContactTile(context, contact);
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
  Widget _buildTopActionRow(BuildContext context, {required IconData icon, required String title,required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(icon, color: theme.colorScheme.onSurface, size: 22),
      title: Text(
        title,
        style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500, fontSize: 16),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.3)),
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
  Widget _buildContactTile(BuildContext context, ContactItem contact) {
    final theme = Theme.of(context);
    // Generate fallback initials label placeholder if explicit image URL string avatar property data isn't initialized
    final String initials = contact.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: contact.avatarUrl == null
            ? (theme.brightness == Brightness.dark ? const Color(0xFF1A3E40) : const Color(0xFFB8D8DA))
            : Colors.transparent,
        backgroundImage: contact.avatarUrl != null ? NetworkImage(contact.avatarUrl!) : null,
        child: contact.avatarUrl == null
            ? Text(
          initials,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold),
        )
            : null,
      ),
      title: Text(
        contact.name,
        style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2.0),
        child: Text(
          contact.status,
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      onTap: () {},
    );
  }

}