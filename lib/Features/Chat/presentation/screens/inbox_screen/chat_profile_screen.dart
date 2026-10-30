import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/components/AppText/appText.dart';
import 'package:app/core/constants/app_paths.dart';
import '../../../data/models/chat_model.dart';
import '../../widgets/chat_avatar.dart';
import '../../../../Contact/presentation/widgets/add_group_members_sheet.dart';

class ChatProfileScreen extends StatelessWidget {
  final ChatModel chat;

  const ChatProfileScreen({super.key, required this.chat});

  void _showAddMemberSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddGroupMembersBottomSheet(
        conversationId: chat.id,
        groupTitle: chat.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 10),
                // --- Avatar & Identity ---
                Center(
                  child: ChatAvatar(
                    radius: 50,
                    imageUrl: chat.image,
                    memberAvatars: chat.memberAvatars,
                    isGroup: chat.isGroup,
                    isOnline: chat.isOnline && !chat.isGroup,
                    onlineColor: const Color(0xFF34C759),
                    borderColor: theme.scaffoldBackgroundColor,
                  ),
                ),
                const SizedBox(height: 16),
                AppText(
                  chat.name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  chat.isGroup ? 'Group Conversation' : 'Active now',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),

                // --- Action Buttons ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (chat.isGroup)
                      _buildActionButton(
                        context,
                        CupertinoIcons.person_badge_plus,
                        'Add Member',
                        () => _showAddMemberSheet(context),
                      )
                    else
                      _buildActionButton(
                        context,
                        CupertinoIcons.search,
                        'Search',
                        () => context.push(AppPaths.chat_search),
                      ),
                    _buildActionButton(
                      context,
                      CupertinoIcons.bell_slash_fill,
                      'Mute',
                      () {},
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // --- Group Management (If Group) ---
          if (chat.isGroup)
            SliverToBoxAdapter(
              child: _buildSectionGroup(context, [
                _buildSettingTile(
                  context,
                  CupertinoIcons.person_badge_plus,
                  'Add Members',
                  const Color(0xFF34C759),
                  onTap: () => _showAddMemberSheet(context),
                ),
              ]),
            ),

          // --- Customization Settings ---
          SliverToBoxAdapter(
            child: _buildSectionGroup(context, [
              _buildSettingTile(context, CupertinoIcons.paintbrush_fill, 'Theme', Colors.purple, trailing: 'Default'),
              _buildSettingTile(context, CupertinoIcons.smiley, 'Quick Emoji', Colors.orange, trailing: '👍'),
              _buildSettingTile(context, CupertinoIcons.t_bubble, 'Nicknames', Colors.blue),
              _buildSettingTile(context, CupertinoIcons.search, 'Search in Conversation', theme.colorScheme.onSurface),
            ]),
          ),

          // --- Media ---
          SliverToBoxAdapter(
            child: _buildSectionGroup(context, [
              _buildSettingTile(context, CupertinoIcons.photo_on_rectangle, 'View Photos & Videos', Colors.teal),
              _buildSettingTile(context, CupertinoIcons.folder_fill, 'Files & Links', Colors.indigo),
            ]),
          ),

          // --- Privacy ---
          SliverToBoxAdapter(
            child: _buildSectionGroup(context, [
              _buildSettingTile(context, CupertinoIcons.nosign, 'Block User', Colors.red, isDestructive: true),
              _buildSettingTile(context, CupertinoIcons.flag_fill, 'Report', Colors.red, isDestructive: true),
            ]),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          AppText(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionGroup(BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context,
    IconData icon,
    String title,
    Color iconColor, {
    String? trailing,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final textColor = isDestructive ? Colors.red : theme.colorScheme.onSurface;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: AppText(
        title,
        style: TextStyle(fontSize: 16, color: textColor, fontWeight: FontWeight.w400),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            AppText(trailing, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          if (trailing != null) const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
        ],
      ),
      onTap: onTap ?? () {},
    );
  }
}
