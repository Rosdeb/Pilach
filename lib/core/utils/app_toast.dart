import 'dart:async';
import 'package:flutter/material.dart';

/// A lightweight iOS-style top toast that floats over the UI without
/// displacing content, auto-dismisses, and never stacks scaffold layers.
///
/// Usage:
///   AppToast.show(context, 'Profile saved');
///   AppToast.show(context, 'Upload failed', type: ToastType.error);
///   AppToast.show(context, 'Password changed', type: ToastType.success);

enum ToastType { info, success, error, warning }

class AppToast {
  AppToast._();

  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Dismiss any toast already on screen
    _dismiss();

    final overlay = Overlay.of(context);

    _current = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        type: type,
        onDismiss: _dismiss,
      ),
    );

    overlay.insert(_current!);

    _timer = Timer(duration, _dismiss);
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _bgColor {
    switch (widget.type) {
      case ToastType.success:
        return const Color(0xFF1A8A4A);
      case ToastType.error:
        return const Color(0xFFCC3333);
      case ToastType.warning:
        return const Color(0xFFCC7700);
      case ToastType.info:
        return const Color(0xFF2A2A2A);
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle_outline_rounded;
      case ToastType.error:
        return Icons.error_outline_rounded;
      case ToastType.warning:
        return Icons.warning_amber_rounded;
      case ToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(_icon, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: widget.onDismiss,
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
