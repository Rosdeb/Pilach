import 'package:flutter/material.dart';

/// Dismisses the visible software keyboard when an unhandled/empty area is
/// tapped. Interactive children such as text fields and buttons win the
/// gesture arena, so their normal tap behavior is preserved.
class GlobalKeyboardDismiss extends StatelessWidget {
  const GlobalKeyboardDismiss({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onTap: isKeyboardVisible
          ? () => FocusManager.instance.primaryFocus?.unfocus()
          : null,
      child: child,
    );
  }
}
