import 'dart:async';
import 'package:flutter/material.dart';

class FloatingSuccessBar extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback? onDismiss;

  const FloatingSuccessBar({
    super.key,
    required this.message,
    this.duration = const Duration(seconds: 4),
    this.onDismiss,
  });

  static OverlayEntry? _currentEntry;

  static void show(
      BuildContext context, {
        required String message,
        Duration duration = const Duration(seconds: 4),
        VoidCallback? onDismiss,
      }) {
    _currentEntry?.remove();
    _currentEntry = null;

    final entry = OverlayEntry(
      builder: (_) => FloatingSuccessBar(
        message: message,
        duration: duration,
        onDismiss: onDismiss,
      ),
    );

    _currentEntry = entry;
    Overlay.of(context).insert(entry);
  }

  @override
  State<FloatingSuccessBar> createState() => _FloatingErrorBarState();
}

class _FloatingErrorBarState extends State<FloatingSuccessBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timer;

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
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    _timer = Timer(widget.duration, _dismiss);
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      FloatingSuccessBar._currentEntry?.remove();
      FloatingSuccessBar._currentEntry = null;
      widget.onDismiss?.call();
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
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.green, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(Icons.close_rounded,
                        color: Colors.black, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}