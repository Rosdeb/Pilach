import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app/core/constants/app_constants.dart';
import 'package:app/components/AppText/appText.dart';

class AllStoriesScreen extends ConsumerWidget {
  const AllStoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.colorScheme.onSurface, size: 20),
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
      ),
      body: GridView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75, // Adjust for portrait story aspect ratio
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
        ),
        itemCount: 12, // Mock count
        itemBuilder: (context, index) {
          return StoryCard(index: index);
        },
      ),
    );
  }
}

class StoryCard extends StatelessWidget {
  final int index;
  
  const StoryCard({Key? key, required this.index}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () {
        context.push(AppPaths.story_details, extra: index);
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background mock
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: index % 2 == 0 
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : CupertinoColors.systemOrange.withOpacity(0.1),
                child: Center(
                  child: Icon(
                    CupertinoIcons.photo, 
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    size: 32,
                  ),
                ),
              ),
            ),
            
            // Gradient overlay for text readability
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            
            // User Info at bottom
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [CupertinoColors.activeOrange, CupertinoColors.systemPink],
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(1.5),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: theme.colorScheme.onSurface.withOpacity(0.05),
                        child: Icon(CupertinoIcons.person_fill, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'User $index',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
