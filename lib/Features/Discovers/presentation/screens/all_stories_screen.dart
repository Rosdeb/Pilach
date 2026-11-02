import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:app/components/AppText/appText.dart';

import '../../../../core/constants/app_paths.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../models/story_model.dart';
import '../providers/story_provider.dart';

class AllStoriesScreen extends ConsumerWidget {
  const AllStoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final myStoriesState = ref.watch(myStoriesProvider);
    final myStories = myStoriesState.value ?? [];
    final feedState = ref.watch(storyFeedProvider);
    final allGroups = feedState.value ?? [];

    // Filter out our own stories from the feed groups to avoid duplicating them
    final currentUserId = authState.id;
    final otherGroups = allGroups.where((g) {
      if (currentUserId == null || currentUserId.isEmpty) return true;
      return g.userId != currentUserId;
    }).toList();

    final totalCount = 2 + otherGroups.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: theme.colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: AppText(
          "All Stories",
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              CupertinoIcons.plus_circle_fill,
              color: Color(0xFF0EB587),
              size: 26,
            ),
            tooltip: 'Create Story',
            onPressed: () => context.push(AppPaths.create_story),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0EB587),
        onRefresh: () async {
          await Future.wait([
            ref.read(storyFeedProvider.notifier).fetchStoriesFeed(),
            ref.read(myStoriesProvider.notifier).fetchMyStories(),
          ]);
        },
        child: (feedState.isLoading &&
                allGroups.isEmpty &&
                myStories.isEmpty &&
                myStoriesState.isLoading)
            ? const Center(child: CupertinoActivityIndicator())
            : GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 12.0,
                  mainAxisSpacing: 12.0,
                ),
                itemCount: totalCount,
                itemBuilder: (context, index) {
                  // 1. Facebook-style "Create Story" Card
                  if (index == 0) {
                    return FacebookCreateStoryCard(
                      profileImage: authState.profileImage,
                      userName: authState.name,
                      onTap: () => context.push(AppPaths.create_story),
                    );
                  }

                  // 2. Default "My Story" Card (Active stories or default empty state)
                  if (index == 1) {
                    return MyStoryCard(
                      myStories: myStories,
                      profileImage: authState.profileImage,
                      userName: authState.name,
                      onTap: () {
                        if (myStories.isNotEmpty) {
                          context.push(AppPaths.story_details, extra: myStories);
                        } else {
                          context.push(AppPaths.create_story);
                        }
                      },
                      onAddTap: () => context.push(AppPaths.create_story),
                    );
                  }

                  // 3. User Stories from Feed
                  final group = otherGroups[index - 2];
                  return StoryCard(userGroup: group);
                },
              ),
      ),
    );
  }
}

/// Facebook-style Create Story Card with user's photo and overlapping circular + button
class FacebookCreateStoryCard extends StatelessWidget {
  final String? profileImage;
  final String? userName;
  final VoidCallback onTap;

  const FacebookCreateStoryCard({
    super.key,
    this.profileImage,
    this.userName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = profileImage != null &&
        profileImage!.trim().isNotEmpty &&
        profileImage!.startsWith('http');

    final initials = (userName != null && userName!.trim().isNotEmpty)
        ? userName!
            .trim()
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'U';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Top: User Profile Photo (68% height)
            Expanded(
              flex: 68,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage)
                    CachedNetworkImage(
                      imageUrl: profileImage!.trim(),
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                        child: const Center(child: CupertinoActivityIndicator()),
                      ),
                      errorWidget: (context, url, error) =>
                          _buildPlaceholder(theme, initials),
                    )
                  else
                    _buildPlaceholder(theme, initials),
                  // Subtle bottom gradient to blend smoothly into the seam
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom: Facebook-style container with overlapping + icon (32% height)
            Expanded(
              flex: 32,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // Card Bottom Bar
                  Container(
                    width: double.infinity,
                    color: theme.colorScheme.surface,
                    padding: const EdgeInsets.only(
                      top: 18,
                      bottom: 8,
                      left: 6,
                      right: 6,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Create story',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Facebook iconic circular plus button overlapping the seam
                  Positioned(
                    top: -18,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1877F2), // Facebook Blue
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1877F2).withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
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

  Widget _buildPlaceholder(ThemeData theme, String initials) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.15),
            theme.colorScheme.primary.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// "My Story" card shown by default — displays latest active story preview or elegant empty state
class MyStoryCard extends StatelessWidget {
  final List<StoryModel> myStories;
  final String? profileImage;
  final String? userName;
  final VoidCallback onTap;
  final VoidCallback onAddTap;

  const MyStoryCard({
    super.key,
    required this.myStories,
    this.profileImage,
    this.userName,
    required this.onTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasStories = myStories.isNotEmpty;
    final hasProfileImage = profileImage != null &&
        profileImage!.trim().isNotEmpty &&
        profileImage!.startsWith('http');

    final initials = (userName != null && userName!.trim().isNotEmpty)
        ? userName!
            .trim()
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'Me';

    if (hasStories) {
      // Pick the most recent story for preview
      final latestStory = myStories.reduce((a, b) {
        final aDate = a.createdAt;
        final bDate = b.createdAt;
        if (aDate == null) return b;
        if (bDate == null) return a;
        return aDate.isAfter(bDate) ? a : b;
      });

      final String? mediaUrl = (latestStory.thumbnailUrl != null &&
              latestStory.thumbnailUrl!.trim().isNotEmpty &&
              latestStory.thumbnailUrl!.startsWith('http'))
          ? latestStory.thumbnailUrl!.trim()
          : ((latestStory.mediaUrl != null &&
                  latestStory.mediaUrl!.trim().isNotEmpty &&
                  latestStory.mediaUrl!.startsWith('http'))
              ? latestStory.mediaUrl!.trim()
              : null);

      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF0EB587).withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Story Background image
              if (mediaUrl != null)
                CachedNetworkImage(
                  imageUrl: mediaUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    child: const Center(child: CupertinoActivityIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: theme.colorScheme.surface,
                    child: const Icon(CupertinoIcons.photo, size: 32),
                  ),
                )
              else
                Container(
                  color: theme.colorScheme.surface,
                  child: const Icon(CupertinoIcons.photo, size: 32),
                ),

              // Gradient Overlay (top for avatar, bottom for text)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),

              // Top row: Avatar with vibrant story ring & count badge
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Gradient ring around avatar
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF0EB587),
                            Color(0xFF00C6FF),
                          ],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: theme.scaffoldBackgroundColor,
                        backgroundImage: hasProfileImage
                            ? CachedNetworkImageProvider(profileImage!.trim())
                            : null,
                        child: !hasProfileImage
                            ? Text(
                                initials,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              )
                            : null,
                      ),
                    ),

                    // Story count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.layers_fill,
                            color: Colors.white,
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${myStories.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom info: "My Story" + count
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'My Story',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${myStories.length} active ${myStories.length == 1 ? 'story' : 'stories'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default My Story Card when user has NO stories yet
    return GestureDetector(
      onTap: onAddTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Soft gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.surface,
                    theme.colorScheme.primary.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),

            // Center content: Avatar with dashed/empty ring & add icon
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          backgroundImage: hasProfileImage
                              ? CachedNetworkImageProvider(profileImage!.trim())
                              : null,
                          child: !hasProfileImage
                              ? Text(
                                  initials,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0EB587),
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.plus,
                          color: Colors.white,
                          size: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'My Story',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No active story',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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
}

/// Standard Feed Story Card for other users
class StoryCard extends StatelessWidget {
  final UserStoryGroup userGroup;

  const StoryCard({super.key, required this.userGroup});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latestStory = userGroup.latestStory;
    final String? mediaUrl = (latestStory?.thumbnailUrl != null &&
            latestStory!.thumbnailUrl!.trim().isNotEmpty &&
            latestStory.thumbnailUrl!.startsWith('http'))
        ? latestStory.thumbnailUrl!.trim()
        : ((latestStory?.mediaUrl != null &&
                latestStory!.mediaUrl!.trim().isNotEmpty &&
                latestStory.mediaUrl!.startsWith('http'))
            ? latestStory.mediaUrl!.trim()
            : null);

    final String initials = userGroup.name.trim().isNotEmpty
        ? userGroup.name
            .trim()
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    return GestureDetector(
      onTap: () {
        context.push(AppPaths.story_details, extra: userGroup.stories);
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image or placeholder
            if (mediaUrl != null)
              CachedNetworkImage(
                imageUrl: mediaUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  child: const Center(child: CupertinoActivityIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.photo,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      size: 32,
                    ),
                  ),
                ),
              )
            else
              Container(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                child: Center(
                  child: Icon(
                    CupertinoIcons.photo,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    size: 32,
                  ),
                ),
              ),

            // Gradient overlay for text readability
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),

            // Top-right stories count badge if user has multiple stories
            if (userGroup.stories.length > 1)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '${userGroup.stories.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // User Info at bottom
            Positioned(
              bottom: 12,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          CupertinoColors.activeOrange,
                          CupertinoColors.systemPink,
                        ],
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(1.5),
                      child: CircleAvatar(
                        radius: 13,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.1),
                        backgroundImage: (userGroup.avatarUrl != null &&
                                userGroup.avatarUrl!.trim().isNotEmpty &&
                                userGroup.avatarUrl!.startsWith('http'))
                            ? CachedNetworkImageProvider(
                                userGroup.avatarUrl!.trim())
                            : null,
                        child: (userGroup.avatarUrl == null ||
                                userGroup.avatarUrl!.trim().isEmpty ||
                                !userGroup.avatarUrl!.startsWith('http'))
                            ? Text(
                                initials,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      userGroup.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(color: Colors.black45, blurRadius: 3),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
}
