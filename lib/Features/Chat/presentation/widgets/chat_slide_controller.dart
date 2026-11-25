import 'package:flutter/widgets.dart';

/// Direction the tile is currently open toward.
enum SlideDirection { none, left, right }

/// Global coordinator to ensure only one tile is open at a time,
/// and allows closing open tiles during vertical scrolls or pull-to-refresh.
class ChatSlideCoordinator {
  static ChatSlideController? _active;

  static void registerActive(ChatSlideController controller) {
    if (_active != null && _active != controller) {
      _active?.close();
    }
    _active = controller;
  }

  static void unregister(ChatSlideController controller) {
    if (_active == controller) {
      _active = null;
    }
  }

  static void closeAll() {
    _active?.close();
    _active = null;
  }
}

/// Drives the swipe-to-reveal animation for a [ChatTile].
class ChatSlideController {
  ChatSlideController({required TickerProvider vsync})
      : _controller = AnimationController(
    vsync: vsync,
    duration: const Duration(milliseconds: 220),
  ) {
    _curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    animation = _curved;
  }

  final AnimationController _controller;
  late final CurvedAnimation _curved;

  late final Animation<double> animation;
  final ValueNotifier<SlideDirection> direction =
      ValueNotifier(SlideDirection.none);

  double _dragExtent = 0.0;
  double _accumulatedDelta = 0.0;
  bool _dragStarted = false;

  static const double actionWidth = 82.0;
  static const double maxDrag = actionWidth * 2;
  // Minimum horizontal slop to filter out accidental drags during vertical scrolling / pull-to-refresh
  static const double slopThreshold = 14.0;

  void onDragStart(DragStartDetails details) {
    _accumulatedDelta = 0.0;
    _dragStarted = false;
  }

  void onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta! * 0.82;

    // Filter out minor diagonal jitter until deliberate horizontal movement is detected
    if (!_dragStarted) {
      _accumulatedDelta += delta;
      if (_accumulatedDelta.abs() < slopThreshold) {
        return;
      }
      _dragStarted = true;
      ChatSlideCoordinator.registerActive(this);
    }

    final next = (_dragExtent + delta).clamp(-maxDrag, maxDrag);
    if (next == _dragExtent) return;

    // Lock direction on first non-zero movement
    if (_dragExtent == 0.0 && next != 0.0) {
      direction.value = next > 0 ? SlideDirection.left : SlideDirection.right;
    }

    // Prevent crossing zero mid-swipe
    if (direction.value == SlideDirection.left && next < 0) return;
    if (direction.value == SlideDirection.right && next > 0) return;

    _dragExtent = next;
    // Drive controller directly — no setState, no build()
    _controller.value = _dragExtent.abs() / maxDrag;
  }

  void onDragEnd(DragEndDetails details) {
    if (!_dragStarted) {
      close();
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    final isLeft = direction.value == SlideDirection.left;

    // Fast fling threshold raised to 650 to prevent accidental flicks
    if (velocity.abs() > 650) {
      final openFling = (isLeft && velocity > 0) || (!isLeft && velocity < 0);
      if (openFling) {
        _snapOpen();
      } else {
        close();
      }
      return;
    }

    // Deliberate drag threshold (require at least 45% of full action reveal)
    if (_dragExtent.abs() > maxDrag * 0.45) {
      _snapOpen();
    } else {
      close();
    }
  }

  void onDragCancel() {
    close();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _snapOpen() {
    _dragExtent = direction.value == SlideDirection.left ? maxDrag : -maxDrag;
    ChatSlideCoordinator.registerActive(this);
    _controller.forward();
  }

  /// Animate back to closed and reset direction.
  void close({bool animate = true}) {
    ChatSlideCoordinator.unregister(this);
    _dragExtent = 0.0;
    _accumulatedDelta = 0.0;
    _dragStarted = false;

    if (!animate) {
      _controller.value = 0.0;
      direction.value = SlideDirection.none;
    } else {
      _controller
          .animateBack(
            0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOutCubic,
          )
          .whenComplete(() {
            direction.value = SlideDirection.none;
          });
    }
  }

  void dispose() {
    ChatSlideCoordinator.unregister(this);
    _curved.dispose();
    _controller.dispose();
    direction.dispose();
  }
}