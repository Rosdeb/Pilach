import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'create_group_sheet.dart';
import 'find_chat_bottom_sheet.dart';
import 'new_contact_sheet.dart';
// Import your NewContactBottomSheet location if triggering from here

class CreateBottomSheet extends ConsumerWidget {
  const CreateBottomSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.only(bottom: 34.0), // Adds standard iOS safe area padding
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
          // --- TOP DISMISS/DRAG PILL INDICATOR ---
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // --- HEADER TITLE ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Create New',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // --- SELECTION ITEMS CONTAINER GROUP ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildCreateRow(
                    context: context,
                    icon: CupertinoIcons.chat_bubble_2,
                    title: 'New Chat',
                    subtitle: 'Start a direct private message thread',
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate or trigger actions

                      showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent, // Ensures our custom rounded corners aren't clipped
                      builder: (context) => const FindChatBottomSheet(),
                      );
                    },
                  ),
                  _buildDivider(theme),
                  _buildCreateRow(
                    context: context,
                    icon: CupertinoIcons.group,
                    title: 'New Group',
                    subtitle: 'Chat together with up to 250 members',
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate or trigger actions

                      // Instantly chain slide open your New Contact Modal Sheet
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent, // Ensures our custom rounded corners aren't clipped
                        builder: (context) => const CreateGroupBottomSheet(),
                      );

                    },
                  ),
                  _buildDivider(theme),
                  _buildCreateRow(
                    context: context,
                    icon: CupertinoIcons.person_crop_circle_badge_plus,
                    title: 'Add Contact',
                    subtitle: 'Save a user using their app ID or QR code',
                    isLast: true,
                    onTap: () {
                      // Dismiss selection sheet first
                      Navigator.pop(context);

                      // Instantly chain slide open your New Contact Modal Sheet
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const NewContactBottomSheet(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    final theme = Theme.of(context);
    final successColor = theme.brightness == Brightness.dark ? const Color(0xFF34C759) : const Color(0xFF34C759);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: successColor.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: successColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2.0),
        child: Text(
          subtitle,
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: theme.colorScheme.onSurface.withOpacity(0.3),
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 60.0),
      child: Divider(height: 1, thickness: 0.5, color: theme.dividerColor.withOpacity(0.12)),
    );
  }
}