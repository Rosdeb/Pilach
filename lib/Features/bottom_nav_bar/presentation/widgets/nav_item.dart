import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/components/AppText/appText.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

import '../providers/bottom_nav_provider.dart';


class NavItem extends ConsumerWidget {
  final IconData icon;
  final String label;
  final int index;
  final bool isSelected;

  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.index,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.onSurface;
    final unselectedColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return ZoomTapAnimation(
      onTap: () {
        ref.read(bottomNavProvider.notifier).changeIndex(index);
      },
      child: Container(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 7,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: 25,
            ),
            AppText(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}