import 'dart:ui';
import 'package:app/core/theme/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:app/core/constants/app_constants.dart' hide AppPaths;
import 'package:app/core/constants/app_paths.dart';
import '../../../../components/AppText/appText.dart';
import '../../models/QuickActionItem.dart';
import '../providers/discover_providers.dart';
import '../providers/story_provider.dart';
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
        child: RefreshIndicator(
          backgroundColor: AppColors.primary,
          color: Colors.white,
          onRefresh: () {
            return ref.read(myStoriesProvider.notifier).fetchMyStories();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                      _buildStoriesTray(context, ref),

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

  Widget _buildStoriesTray(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myStoriesState = ref.watch(myStoriesProvider);
    
    final myStories = myStoriesState.value ?? [];
    
    if (myStoriesState.isLoading && myStories.isEmpty) {
      return SizedBox(
        height: 115,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(left: index == 0 ? 16 : 0, right: 16.0),
              child: CustomShimmer(
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 50,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    // PRELOAD SYSTEM: Pre-cache all story images to disk immediately when the list loads!
    for (var story in myStories) {
      if (story.mediaUrl != null) {
        precacheImage(CachedNetworkImageProvider(story.mediaUrl!), context);
      }
    }

    final hasMyStories = myStories.isNotEmpty;
    
    // Total items: 1 (Add Story CTA) + (1 if user has stories) + 5 (mock other users)
    final itemCount = 1 + (hasMyStories ? 1 : 0) + 5;

    return SizedBox(
      height: 115,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            // First item is the "Publish Story" CTA slot
            return Padding(
              padding: const EdgeInsets.only(left: 3, right: 16.0),
              child: GestureDetector(
                onTap: () {
                  context.push(AppPaths.create_story);
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

          if (hasMyStories && index == 1) {
            // Display the user's own fetched story
            final latestStory = myStories.first;
            return Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: () {
                  // Navigate to view the story. You could pass the story ID or index.
                  context.push(AppPaths.story_details, extra: myStories);
                },
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [CupertinoColors.activeBlue, CupertinoColors.activeGreen],
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
                          backgroundImage: latestStory.thumbnailUrl != null 
                              ? CachedNetworkImageProvider(latestStory.thumbnailUrl!) 
                              : null,
                          child: latestStory.thumbnailUrl == null 
                              ? Icon(CupertinoIcons.person_fill, color: theme.colorScheme.onSurface.withOpacity(0.4))
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'My Story',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
            );
          }

          // Sample Other User Stories
          final mockIndex = hasMyStories ? index - 1 : index;
          return StoryAvatar(index: mockIndex);
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

// --- CUSTOM SHIMMER EFFECT ---

class CustomShimmer extends StatefulWidget {
  final Widget child;
  const CustomShimmer({super.key, required this.child});

  @override
  State<CustomShimmer> createState() => _CustomShimmerState();
}

class _CustomShimmerState extends State<CustomShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
              ],
              stops: const [0.1, 0.5, 0.9],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent * 2 - 1), 0.0, 0.0);
  }
}