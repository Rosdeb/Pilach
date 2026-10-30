import 'dart:io';
import 'dart:ui';

import 'package:cupertino_native/components/tab_bar.dart';
import 'package:cupertino_native/style/sf_symbol.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/Features/Chat/presentation/screens/chat_screen.dart';
import 'package:app/Features/Chat/presentation/providers/chat_provider.dart';
import 'package:app/Features/Contact/presentation/screens/contact_screen.dart';
import 'package:app/Features/Discovers/presentation/screens/discover_screen.dart';
import 'package:app/Features/Me/presentation/screens/me_screen.dart';
import 'package:app/Features/Me/presentation/providers/setting_providers.dart';

import '../providers/bottom_nav_provider.dart';
import '../widgets/custom_bottom_nav.dart';

class BottomMenuWrapper extends ConsumerStatefulWidget {
  const BottomMenuWrapper({super.key});

  @override
  ConsumerState<BottomMenuWrapper> createState() => _BottomMenuWrapperState();
}

class _BottomMenuWrapperState extends ConsumerState<BottomMenuWrapper> {
  final List<Widget> pages = [
     ChatScreen(),
     ContactScreen(),
     DiscoverScreen(),
     MeScreen(),
  ];

  void _handleTabChange(int index) {
    ref.read(bottomNavProvider.notifier).changeIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(darkModeProvider);
    final currentIndex = ref.watch(bottomNavProvider);

    if (Platform.isIOS) {
      return _buildIOSLayout(currentIndex);
    }
    return _buildAndroidLayout(currentIndex);
  }

  // ── iOS: CNTabBar (true SF Symbols + native frosted glass) ───────────────
  Widget _buildIOSLayout(int currentIndex) {
    final totalUnread = ref.watch(totalUnreadCountProvider);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth / 4;

    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false, // CNTabBar manages home-indicator space itself
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [

              // Content behind the tab bar
              Positioned.fill(
                child: IndexedStack(
                  index: currentIndex,
                  children: pages,
                ),
              ),

              // Native iOS tab bar — SF Symbols, frosted glass, home indicator
              Align(
                alignment: Alignment.bottomCenter,
                child: CNTabBar(
                  items: const [
                    CNTabBarItem(
                      label: 'Chat',
                      icon: CNSymbol('bubble.left.and.bubble.right.fill'),
                    ),
                    CNTabBarItem(
                      label: 'Contact',
                      icon: CNSymbol('person.2.fill'),
                    ),
                    CNTabBarItem(
                      label: 'Discover',
                      icon: CNSymbol('safari.fill'),
                    ),
                    CNTabBarItem(
                      label: 'Setting',
                      icon: CNSymbol('gearshape.fill'),
                    ),
                  ],
                  currentIndex: currentIndex,
                  tint: const Color(0xFF0EB587),
                  backgroundColor: Colors.transparent,
                  height: 85,
                  onTap: _handleTabChange,
                ),
              ),

              // iOS Unread Count Badge with Red Number Text
              if (totalUnread > 0)
                Positioned(
                  bottom: 52,
                  left: (itemWidth / 2) + 6,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFE53935),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          totalUnread > 99 ? '99+' : totalUnread.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE53935), // Red number text
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

            ],
          ),
        ),
      ),
    );
  }

  // ── Android: existing CustomBottomNav unchanged ───────────────────────────
  Widget _buildAndroidLayout(int currentIndex) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          pages[currentIndex],
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomBottomNav(),
          ),
        ],
      ),
    );
  }
}