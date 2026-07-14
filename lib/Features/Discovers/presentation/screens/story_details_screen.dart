import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:app/Features/Discovers/models/story_model.dart';
import 'package:app/core/providers/api_provider.dart';
import 'package:app/core/utils/app_logger.dart';
import 'package:app/Features/Me/presentation/providers/profile_provider.dart';
import 'package:app/Features/Discovers/presentation/providers/story_provider.dart';

class StoryDetailsScreen extends ConsumerStatefulWidget {
  final List<StoryModel> stories;
  final int initialIndex;

  const StoryDetailsScreen({super.key, required this.stories, this.initialIndex = 0});

  @override
  ConsumerState<StoryDetailsScreen> createState() => _StoryDetailsScreenState();
}

class _StoryDetailsScreenState extends ConsumerState<StoryDetailsScreen> with SingleTickerProviderStateMixin {
  late int currentIndex;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex < widget.stories.length ? widget.initialIndex : 0;
    
    // Simulate story duration (e.g., 5 seconds)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        setState(() {});
      })..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _nextStory();
        }
      });
    _progressController.forward();
    
    _recordAndFetchViews();
  }

  void _nextStory() {
    if (currentIndex < widget.stories.length - 1) {
      setState(() {
        currentIndex++;
      });
      _progressController.forward(from: 0.0);
      _recordAndFetchViews();
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _previousStory() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
      });
      _progressController.forward(from: 0.0);
      _recordAndFetchViews();
    } else {
      _progressController.forward(from: 0.0);
    }
  }

  Future<void> _recordAndFetchViews() async {
    if (widget.stories.isEmpty) return;
    final currentStory = widget.stories[currentIndex];
    final apiService = ref.read(apiServiceProvider);
    
    try {
      // 1. Record a view
      Logger.log('🚀 Recording view for story: ${currentStory.id}');
      final viewRes = await apiService.post('/api/v1/stories/${currentStory.id}/views', data: {});
      Logger.log('📥 View recorded response: ${viewRes.data}');
      
      // 2. Fetch view list
      Logger.log('🚀 Fetching views list for story: ${currentStory.id}');
      final listRes = await apiService.get('/api/v1/stories/${currentStory.id}/views');
      Logger.log('📥 Views list response: ${listRes.data}');
    } catch (e) {
      Logger.log('Error recording/fetching views: $e');
    }
  }

  Future<void> _deleteStory() async {
    if (widget.stories.isEmpty) return;
    final currentStory = widget.stories[currentIndex];
    final apiService = ref.read(apiServiceProvider);
    
    // Pause the progress controller while showing the dialog
    _progressController.stop();

    // Show confirmation dialog
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Story?'),
        content: const Text('Are you sure you want to delete this story?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm != true) {
      _progressController.forward();
      return;
    }

    try {
      Logger.log('🚀 Deleting story: ${currentStory.id}');
      final response = await apiService.delete('/api/v1/stories/${currentStory.id}');
      Logger.log('📥 Delete story response: ${response.data}');

      if (response.data['success'] == true) {
        // Refresh the stories list
        ref.read(myStoriesProvider.notifier).fetchMyStories();
        if (mounted) Navigator.of(context).pop();
      } else {
        _progressController.forward();
      }
    } catch (e) {
      Logger.log('Error deleting story: $e');
      _progressController.forward();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) return const Scaffold(backgroundColor: Colors.black);
    final currentStory = widget.stories[currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 3) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        onLongPress: () => _progressController.stop(),
        onLongPressUp: () => _progressController.forward(),
        child: SafeArea(
          child: Stack(
            children: [
              // STORY CONTENT (Simulated image/color)
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: currentStory.mediaUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: currentStory.mediaUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                            errorWidget: (context, url, error) => const Center(child: Icon(CupertinoIcons.photo, color: Colors.white54, size: 80)),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            CupertinoIcons.photo, 
                            color: Colors.white54,
                            size: 80,
                          ),
                        ),
                ),
              ),
              
              // CAPTION
              if (currentStory.caption != null && currentStory.caption!.isNotEmpty)
                Positioned(
                  bottom: 80,
                  left: 20,
                  right: 20,
                  child: Text(
                    currentStory.caption!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // TOP GRADIENT FOR TEXT VISIBILITY
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 100,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // PROGRESS BAR AND HEADER
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Column(
                  children: [
                    // Progress Bar
                    Row(
                      children: List.generate(widget.stories.length, (index) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: index == widget.stories.length - 1 ? 0 : 4.0),
                            child: LinearProgressIndicator(
                              value: index < currentIndex ? 1.0 : (index == currentIndex ? _progressController.value : 0.0),
                              backgroundColor: Colors.white.withValues(alpha: 0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 2.5,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    // Header (Avatar, Name, Time, Close)
                    Consumer(builder: (context, ref, child) {
                      final profileState = ref.watch(profileNotifierProvider);
                      final myProfile = profileState.value;
                      
                      // Check both userId and id because different backend endpoints might use either
                      final isMyStory = myProfile != null && 
                                        (currentStory.authorId == myProfile.userId || currentStory.authorId == myProfile.id);
                      
                      final displayName = isMyStory ? myProfile.name : "User";
                      final avatarUrl = isMyStory ? myProfile.avatarUrl : null;
                      
                      String timeAgo = "Just now";
                      if (currentStory.createdAt != null) {
                        final diff = DateTime.now().difference(currentStory.createdAt!);
                        if (diff.inDays > 0) {
                          timeAgo = "${diff.inDays}d ago";
                        } else if (diff.inHours > 0) {
                          timeAgo = "${diff.inHours}h ago";
                        } else if (diff.inMinutes > 0) {
                          timeAgo = "${diff.inMinutes}m ago";
                        }
                      }

                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.grey,
                            backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                            child: avatarUrl == null ? const Icon(CupertinoIcons.person_fill, color: Colors.white, size: 20) : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  timeAgo,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isMyStory)
                            Container(
                              height: 30,
                              width: 30,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 2,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: _deleteStory,
                                icon: Image.asset(
                                  "assets/icons/trash.png",
                                  height: 20,
                                  width: 20,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.more_horiz, color: Colors.white),
                              onPressed: () {},
                            ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              // BOTTOM REPLY BAR
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            "Send message",
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(CupertinoIcons.heart, color: Colors.white, size: 28),
                      const SizedBox(width: 16),
                      const Icon(CupertinoIcons.paperplane, color: Colors.white, size: 28),
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
}
