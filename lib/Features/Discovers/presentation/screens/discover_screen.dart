import 'dart:ui';
import 'package:app/core/theme/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app/core/constants/app_constants.dart' hide AppPaths;
import 'package:app/core/constants/app_paths.dart';
import '../../../../components/AppText/appText.dart';
import '../../models/QuickActionItem.dart';
import '../providers/discover_providers.dart';
import '../widgets/action_quick_card.dart';
import '../widgets/radar_animations.dart';

class DiscoverScreen extends ConsumerWidget {
   DiscoverScreen({super.key});

  final  actions = [

    QuickActionItem(
      title: "Groups",
      icon: CupertinoIcons.person_3_fill,
      route: 'AppPaths.groups',
    ),

    QuickActionItem(
      title: "Events",
      icon: CupertinoIcons.calendar,
      route: AppPaths.event_screen,
    ),

    QuickActionItem(
      title: "Market",
      icon: CupertinoIcons.shopping_cart,
      route: AppPaths.market_screen,
    ),

    QuickActionItem(
      title: "Jobs",
      icon: CupertinoIcons.briefcase_fill,
      route: 'AppPaths.jobs',
    ),

    QuickActionItem(
      title: "News",
      icon: CupertinoIcons.news,
      route: AppPaths.news_screen,
    ),

    QuickActionItem(
      title: "Donate",
      icon: CupertinoIcons.heart_fill,
      route: AppPaths.donate_screen,
    ),

    QuickActionItem(
      title: "Language",
      icon: CupertinoIcons.globe,
      route: 'AppPaths.language',
    ),

    QuickActionItem(
      title: "Theme",
      icon: CupertinoIcons.paintbrush_fill,
      route: 'AppPaths.theme',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoverProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // iOS Large Title Navigation Bar
            SliverAppBar(
              pinned: true,
              floating: false,
              snap: false,
              automaticallyImplyLeading: false,
              expandedHeight: 65.0,
              toolbarHeight: 65.0,
              backgroundColor: theme.scaffoldBackgroundColor,
              surfaceTintColor: theme.scaffoldBackgroundColor,
              centerTitle: true,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                  child: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 20.0, bottom: 16.0),
                    centerTitle: false,
                    title: AppText(
                      'Discover',
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

            // Main Content Body
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // --- STORIES SECTION ---
                    _buildSectionHeader(context, 'Stories', 'See All', onActionTap: () {
                      context.push(AppPaths.all_stories);
                    }),
                    const SizedBox(height: 12),
                    _buildStoriesTray(context),

                    const SizedBox(height: 35),

                    // --- NEARBY SCAN SECTION ---
                    _buildSectionHeader(context, 'Nearby People', state.isScanning ? 'Scanning...' : 'Paused'),

                    const SizedBox(height: 20),
                    RadarScanner(
                      isScanning: state.isScanning,
                      onTap: () {
                        ref.read(discoverProvider.notifier).toggleScan();
                      },
                    ),

                    const SizedBox(height: 40),

                    _buildSectionHeader(
                      context,
                      "Quick Actions",
                      "",
                    ),

                    const SizedBox(height:16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal:16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.95,
                        ),
                        itemCount: actions.length,
                        itemBuilder: (context, index) {
                          return QuickActionCard(
                            icon: actions[index].icon,
                            title: actions[index].title,
                            onTap: () {
                              context.push(actions[index].route);
                            },
                          );

                        },

                      )
                    ),
                    const SizedBox(height:50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI Helper Components ---

  Widget _buildSectionHeader(BuildContext context, String title, String actionText, {VoidCallback? onActionTap}) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: onActionTap ?? () {},
            child: Text(
              actionText,
              style: const TextStyle(
                color: CupertinoColors.activeBlue,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoriesTray(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 115,
      child: ListView.builder(

        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: 6,
        itemBuilder: (context, index) {
          if (index == 0) {
            // First item is the "Publish Story" CTA slot
            return Padding(
              padding: const EdgeInsets.only(left:3,right: 16.0),
              child: GestureDetector(
                onTap: () {
                  // TODO: Publish story logic
                },
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            CupertinoIcons.plus,
                            size: 26,
                            color: CupertinoColors.activeBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Story',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
            );
          }

          // Sample User Stories
          return StoryAvatar(index: index);
        },
      ),
    );
  }

}

class StoryAvatar extends StatelessWidget {
  final int index;

  const StoryAvatar({Key? key, required this.index}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [CupertinoColors.activeOrange, CupertinoColors.systemPink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.onSurface.withOpacity(0.05),
                child: Icon(CupertinoIcons.person_fill, color: theme.colorScheme.onSurface.withOpacity(0.4)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'User $index',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}