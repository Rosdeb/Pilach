import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/bottom_nav_provider.dart';
import 'nav_item.dart';

class CustomBottomNav extends ConsumerWidget {
  const CustomBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavProvider);

    return SizedBox(
      height: 70,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 3,
                  spreadRadius: 0,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              NavItem(
                icon: currentIndex == 0
                    ? CupertinoIcons.chat_bubble_2_fill
                    : CupertinoIcons.chat_bubble_2,
                label: 'Chat',
                index: 0,
                isSelected: currentIndex == 0,
              ),
              NavItem(
                icon: currentIndex == 1
                    ? CupertinoIcons.person_2_fill
                    : CupertinoIcons.person_2,
                label: 'Contact',
                index: 1,
                isSelected: currentIndex == 1,
              ),
              NavItem(
                icon: currentIndex == 2
                    ? CupertinoIcons.compass_fill
                    : CupertinoIcons.compass,
                label: 'Discover',
                index: 2,
                isSelected: currentIndex == 2,
              ),
              NavItem(
                icon: currentIndex == 3
                    ? CupertinoIcons.gear_alt_fill
                    : CupertinoIcons.gear_alt,
                label: 'Setting',
                index: 3,
                isSelected: currentIndex == 3,
              ),
            ],
          )
        ],
      ),
    );
  }
}
