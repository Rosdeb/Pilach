import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Direction the tile is currently open toward.
enum SlideDirection { none, left, right }

/// Drives the swipe-to-reveal animation for a [ChatTile].
///
/// All state lives here. No [setState] is ever needed in the widget tree —
/// the widget tree listens to [animation] directly via [AnimatedBuilder] or
/// [SlideTransition], so only the GPU composite layer repaints during a swipe.
///
/// Usage:
///   1. Create in [State.initState], dispose in [State.dispose].
///   2. Pass [vsync] from the [TickerProviderStateMixin].
///   3. Call [onDragUpdate] / [onDragEnd] from gesture callbacks.
///   4. Read [animation] in SlideTransition.
///   5. Read [direction] (a [ValueListenable]) to show/hide action panels.
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

  static const double actionWidth = 82.0;
  static const double maxDrag = actionWidth * 2;

  void onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta! * 0.82;
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
    final velocity = details.primaryVelocity ?? 0;
    final isLeft = direction.value == SlideDirection.left;

    if (velocity.abs() > 400) {
      // Fast fling
      final openFling = (isLeft && velocity > 0) || (!isLeft && velocity < 0);
      if (openFling) {
        _snapOpen();
      } else {
        close();
      }
      return;
    }

    // Slow drag — threshold at 60 % of action width
    if (_dragExtent.abs() > actionWidth * 0.6) {
      _snapOpen();
    } else {
      close();
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _snapOpen() {
    _dragExtent = direction.value == SlideDirection.left ? maxDrag : -maxDrag;
    _controller.forward();
  }

  /// Animate back to closed and reset direction.
  void close() {
    _controller.animateBack(0, duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOutCubic,
    ).whenComplete(() => direction.value = SlideDirection.none);
    _dragExtent = 0.0;
  }

  void dispose() {
    _curved.dispose();
    _controller.dispose();
    direction.dispose();
  }
}