import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app/core/services/native_notifier.dart';

class InAppNotificationBanner extends StatefulWidget {
  final String title;
  final String message;
  final String? timeLabel;
  final String? avatarUrl;
  final VoidCallback? onTap;
  final Duration duration;
  final VoidCallback? onDismissRequested;

  const InAppNotificationBanner({
    super.key,
    required this.title,
    required this.message,
    this.timeLabel,
    this.avatarUrl,
    this.onTap,
    this.duration = const Duration(seconds: 4),
    this.onDismissRequested,
  });

  static OverlayEntry? _currentEntry;

  static void _dismissCurrent() {
    if (_currentEntry != null) {
      try {
        _currentEntry!.remove();
      } catch (_) {}
      _currentEntry = null;
    }
  }

  static Future<void> show({
    required OverlayState overlayState,
    required String title,
    required String message,
    String? timeLabel,
    String? avatarUrl,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
    bool forceNative = false,
  }) async {
    if (forceNative) {
      await NativeNotifier.show(
        title: title,
        body: message,
        avatarUrl: avatarUrl,
      );
      return;
    }

    _dismissCurrent();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => InAppNotificationBanner(
        title: title,
        message: message,
        timeLabel: timeLabel,
        avatarUrl: avatarUrl,
        onTap: onTap,
        duration: duration,
        onDismissRequested: () {
          try {
            entry.remove();
          } catch (_) {
            // Already removed
          } finally {
            if (identical(_currentEntry, entry)) {
              _currentEntry = null;
            }
          }
        },
      ),
    );
    _currentEntry = entry;
    overlayState.insert(entry);
  }

  @override
  State<InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    _timer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (!mounted || _isDismissing) return;
    _isDismissing = true;
    _controller.reverse().then((_) {
      widget.onDismissRequested?.call();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 8,
      right: 8,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! < -10) {
            _dismiss();
          }
        },
        onTap: () {
          _dismiss();
          widget.onTap?.call();
        },
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF202124)
                      : const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.28)
                          : Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        _buildAvatar(),
                        const SizedBox(width: 10),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (widget.timeLabel != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.timeLabel!,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black45,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.message,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : Colors.black54,
                                  fontSize: 13,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty) {
      if (widget.avatarUrl!.startsWith('http')) {
        return CircleAvatar(
          radius: 17,
          backgroundImage: NetworkImage(widget.avatarUrl!),
        );
      }
    }

    // Gradient Fallback Avatar
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3F3D56)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.notifications_active_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}
