import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messageapp/components/AppText/appText.dart';
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
              color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFF757575),
              size: isSelected ? 25 : 25,),

            AppText(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF000000)
                    : const Color(0xFF757575),
              ),
            ),
          ],
        ),
      ),
    );
  }
}