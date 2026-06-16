import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_advanced_switch/flutter_advanced_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

// Replace these imports with your actual path utilities
import '../../../../../components/AppText/appText.dart';
import '../../../../../core/utils/app_colour.dart';

// MOCK PROVIDERS: Replace with your actual application state providers
final themeProvider = StateProvider<bool>(
  (ref) => false,
); // false = Light, true = Dark
final saveToPhotosProvider = StateProvider<bool>((ref) => true);
final enterIsSendProvider = StateProvider<bool>((ref) => false);

class ChatsSettingsScreen extends ConsumerWidget {
  const ChatsSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch current state values from Riverpod
    final isDarkMode = ref.watch(themeProvider);
    final isSaveToPhotosEnabled = ref.watch(saveToPhotosProvider);
    final isEnterIsSendEnabled = ref.watch(enterIsSendProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- APP BAR ---
          SliverAppBar(
            pinned: true,
            expandedHeight: 60.0,
            toolbarHeight: 60.0,
            backgroundColor: AppColors.background,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.back_icon,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const AppText(
              "Chats",
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // --- BODY CONTENT ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8.0),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    // Keeps text from touching edges
                    decoration: BoxDecoration(
                      color: AppColors.white_bg,
                      borderRadius: BorderRadius.circular(
                        12,
                      ), // Makes it a perfect pill shape
                    ),
                    child: Column(
                      children: [
                        chat_theme("Default caht theme", () {}),
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: AppColors.background,
                        ),

                        chat_theme("Export chat", () {}),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24.0),
                  // --- SECTION 1: DISPLAY & THEME ---
                  _buildSectionHeader('DISPLAY'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.textWhite,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSwitchRow(
                          icon: CupertinoIcons.brightness,
                          iconColor: Colors.purple,
                          title: 'Dark Mode',
                          value: isDarkMode,
                          onChanged: (val) =>
                              ref.read(themeProvider.notifier).state = val,
                        ),
                        _buildDivider(),
                        _buildActionRow(
                          icon: CupertinoIcons.photo_on_rectangle,
                          iconColor: Colors.teal,
                          title: 'Chat Wallpaper',
                          onTap: () {
                            // Navigate to Wallpaper Customizer
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // --- SECTION 2: CHAT PREFERENCES ---
                  _buildSectionHeader('CHAT SETTINGS'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.textWhite,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildSwitchRow(
                          icon: CupertinoIcons.return_icon,
                          iconColor: Colors.blue,
                          title: 'Enter is Send',
                          value: isEnterIsSendEnabled,
                          onChanged: (val) =>
                              ref.read(enterIsSendProvider.notifier).state =
                                  val,
                        ),
                        _buildDivider(),
                        _buildSwitchRow(
                          icon: CupertinoIcons.square_arrow_down,
                          iconColor: AppColors.successGreen,
                          title: 'Save to Photos',
                          value: isSaveToPhotosEnabled,
                          onChanged: (val) =>
                              ref.read(saveToPhotosProvider.notifier).state =
                                  val,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // --- SECTION 3: MAINTENANCE & ARCHIVE ---
                  _buildSectionHeader('BACKUP & HISTORY'),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.textWhite,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildActionRow(
                          icon: CupertinoIcons.cloud_upload,
                          iconColor: Colors.blueAccent,
                          title: 'Chat Backup',
                          trailingText: 'Auto: Weekly',
                          onTap: () {
                            // Navigate to Backup management view
                          },
                        ),
                        _buildDivider(),
                        _buildActionRow(
                          icon: CupertinoIcons.archivebox,
                          iconColor: Colors.orange,
                          title: 'Archive All Chats',
                          showArrow: false,
                          onTap: () {
                            // Trigger Batch Archive Action
                          },
                        ),
                        _buildDivider(),
                        _buildActionRow(
                          icon: CupertinoIcons.trash,
                          iconColor: Colors.red,
                          title: 'Clear All Chats',
                          textColor: Colors.red,
                          showArrow: false,
                          onTap: () {
                            // Trigger Clear Data confirmation dialog
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  GestureDetector chat_theme(String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.white_bg,
          borderRadius: BorderRadius.circular(
            12,
          ), // Makes it a perfect pill shape
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          // Distributes text and trail items perfectly
          crossAxisAlignment: CrossAxisAlignment.center,
          // Perfectly centers elements vertically
          children:  [
            AppText(
              title,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textDark,
                fontWeight: FontWeight.w400,
              ),
            ),
            // Optional trailing indicator to match the iOS vibe:
            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textDark),
          ],
        ),
      ),
    );
  }

  // Helper Section Header Layout
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textLight,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Inline List Item Divider Blueprint
  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 56.0),
      child: Divider(height: 1, thickness: 0.5, color: AppColors.background),
    );
  }

  // Navigation Row Component
  Widget _buildActionRow({
    required IconData icon,
    Color iconColor = AppColors.primary,
    required String title,
    Color textColor = AppColors.textDark,
    String? trailingText,
    bool showArrow = true,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w400,
          fontSize: 16,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText,
              style: const TextStyle(color: AppColors.textLight, fontSize: 14),
            ),
          if (trailingText != null && showArrow) const SizedBox(width: 6),
          if (showArrow)
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.border,
            ),
        ],
      ),
    );
  }

  // Interactive Switch Row Component
  Widget _buildSwitchRow({
    required IconData icon,
    Color iconColor = AppColors.successGreen,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final switchController = ValueNotifier<bool>(value);

    switchController.addListener(() {
      onChanged(switchController.value);
    });

    return ListTile(
      dense: true,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w400,
          fontSize: 16,
        ),
      ),
      trailing: Transform.scale(
        scaleX: 0.75,
        scaleY: 0.80,
        child: AdvancedSwitch(
          controller: switchController,
          width: 45,
          height: 24,
          activeColor: const Color(0xFF34C759),
          inactiveColor: Colors.grey.shade400,
        ),
      ),
    );
  }
}
