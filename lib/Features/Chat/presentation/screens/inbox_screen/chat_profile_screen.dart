import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:messageapp/core/utils/app_colour.dart';
import 'package:messageapp/components/AppText/appText.dart';
import 'package:messageapp/core/constants/app_constants.dart';

class ChatProfileScreen extends StatelessWidget {
  const ChatProfileScreen({Key? key}) : super(key: key);

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
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundImage: CachedNetworkImageProvider('https://cdn.motor1.com/images/mgl/bglVnv/239:0:1438:1080/best-new-cars-coming-out-in-2025.webp'),
                      ),
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34C759),
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.scaffoldBackgroundColor, width: 3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppText(
                  'Alexandra Sterling',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  'Active now',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),

                // --- Action Buttons ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(context, CupertinoIcons.phone_fill, 'Audio', () {}),
                    _buildActionButton(context, CupertinoIcons.video_camera_solid, 'Video', () {}),
                    _buildActionButton(context, CupertinoIcons.person_solid, 'Profile', () {}),
                    _buildActionButton(context, CupertinoIcons.bell_slash_fill, 'Mute', () {}),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
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
              color: theme.colorScheme.onSurface.withOpacity(0.06),
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

  Widget _buildSettingTile(BuildContext context, IconData icon, String title, Color iconColor, {String? trailing, bool isDestructive = false}) {
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
            AppText(trailing, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))),
          if (trailing != null) const SizedBox(width: 8),
          Icon(Icons.arrow_forward_ios, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.3)),
        ],
      ),
      onTap: () {},
    );
  }
}
