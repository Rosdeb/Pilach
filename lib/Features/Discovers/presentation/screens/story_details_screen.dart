import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class StoryDetailsScreen extends StatefulWidget {
  final int storyIndex;

  const StoryDetailsScreen({super.key, this.storyIndex = 0});

  @override
  State<StoryDetailsScreen> createState() => _StoryDetailsScreenState();
}

class _StoryDetailsScreenState extends State<StoryDetailsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    // Simulate story duration (e.g., 5 seconds)
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        setState(() {});
      })..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) Navigator.of(context).pop();
        }
      });
    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) => _progressController.stop(),
        onTapUp: (_) => _progressController.forward(),
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
                    color: widget.storyIndex % 2 == 0 
                      ? Colors.blue.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.photo, 
                      color: Colors.white54,
                      size: 80,
                    ),
                  ),
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
                    LinearProgressIndicator(
                      value: _progressController.value,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 2.5,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    const SizedBox(height: 12),
                    // Header (Avatar, Name, Time, Close)
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey,
                          child: Icon(CupertinoIcons.person_fill, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "User ${widget.storyIndex}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "2h ago",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_horiz, color: Colors.white),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
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
