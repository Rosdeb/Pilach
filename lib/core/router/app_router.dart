import 'package:flutter/animation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:messageapp/Features/Me/presentation/screens/block_userlist/block_userlist_screen.dart';
import 'package:messageapp/Features/Me/presentation/screens/edit_profile/edit_profile_screen.dart';
import 'package:messageapp/Features/Me/presentation/screens/email_setting/email_setting_screen.dart';
import 'package:messageapp/Features/Me/presentation/screens/security_privacy/security_privacy_screen.dart';
import 'package:messageapp/features/auth/presentation/screens/splash_screen.dart';

import '../../Features/bottom_nav_bar/presentation/screens/bottom_manu_wrappers.dart';
import '../constants/app_constants.dart';


CustomTransitionPage<dynamic> buildSlideTransitionPage({
  required LocalKey key,
  required Widget child,
  Offset begin = const Offset(1.0, 0.0),
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (
        context,
        animation,
        secondaryAnimation,
        child,
        ) {
      final tween = Tween<Offset>(
        begin: begin,
        end: Offset.zero,
      ).chain(
        CurveTween(curve: Curves.easeInOut),
      );

      return SlideTransition(
        position: animation.drive(tween),
        child: child,
      );
    },
  );
}


final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppPaths.splash,
    routes: [

      GoRoute(
        path: AppPaths.splash,
        name: AppRoutes.splash,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),

      GoRoute(
        path: AppPaths.bottom_manu,
        name: AppRoutes.bottom_manu,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: BottomMenuWrapper(),
        ),
      ),

      GoRoute(
        path: AppPaths.block_userlist,
        name: AppRoutes.block_userlist,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: const BlockedUsersScreen(),
        ),
      ),

      GoRoute(
        path: AppPaths.email_setting,
        name: AppRoutes.email_setting,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: EmailSettingsScreen(),
        ),
      ),

      GoRoute(
        path: AppPaths.security_privacy,
        name: AppRoutes.security_privacy,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: SecurityPrivacyScreen(),
        ),
      ),

      GoRoute(
        path: AppPaths.edit_profile,
        name: AppRoutes.edit_profile,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: EditProfileScreen(),
        ),
      ),


      // GoRoute(
      //   path: '/communities',
      //   builder: (context, state) => const CommunityListScreen(),
      // ),
      // GoRoute(
      //   path: '/chat/:chatId',
      //   builder: (context, state) {
      //     final chatId = state.pathParameters['chatId']!;
      //     return ChatRoomScreen(chatId: chatId);
      //   },
      // ),
      // GoRoute(
      //   path: '/profile',
      //   builder: (context, state) => const ProfileScreen(),
      // ),

    ],
  );
});