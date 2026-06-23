import 'package:flutter/animation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:messageapp/Features/Chat/presentation/screens/inbox_screen/direct_chat_screen.dart';
import 'package:messageapp/Features/Me/presentation/screens/block_userlist/block_userlist_screen.dart';
import 'package:messageapp/Features/Me/presentation/screens/chats_setting/chats_settings_screen.dart';
import 'package:messageapp/Features/Me/presentation/screens/edit_profile/edit_profile_screen.dart';
import 'package:messageapp/Features/Me/presentation/screens/email_setting/email_setting_screen.dart';
import 'package:messageapp/Features/Me/presentation/screens/qr_scan/ar_scan_screen.dart';
import 'package:messageapp/Features/Me/presentation/screens/security_privacy/security_privacy_screen.dart';
import 'package:messageapp/Features/auth/presentation/screens/splash_screen.dart';
import 'package:messageapp/Features/auth/presentation/screens/login_screen.dart';
import 'package:messageapp/Features/auth/presentation/screens/register_screen.dart';
import 'package:messageapp/Features/auth/presentation/providers/auth_provider.dart';

import '../../Features/bottom_nav_bar/presentation/screens/bottom_manu_wrappers.dart';
import '../constants/app_constants.dart';

class RiverpodRouterRefreshListenable extends ChangeNotifier {
  RiverpodRouterRefreshListenable(Ref ref) {
    ref.listen<AuthState>(
      authProvider,
      (previous, next) {
        if (previous?.status != next.status) {
          notifyListeners();
        }
      },
    );
  }
}

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
  final refreshListenable = RiverpodRouterRefreshListenable(ref);

  return GoRouter(
    initialLocation: AppPaths.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final status = authState.status;

      final isSplashing = state.matchedLocation == AppPaths.splash;
      final isLoggingIn = state.matchedLocation == AppPaths.login || state.matchedLocation == AppPaths.register;

      if (status == AuthStatus.initial) {
        return null; // Stay on splash while loading initial auth state
      }

      if (status == AuthStatus.unauthenticated) {
        if (!isLoggingIn && !isSplashing) {
          return AppPaths.login;
        }
      }

      if (status == AuthStatus.authenticated) {
        if (isLoggingIn || isSplashing) {
          return AppPaths.bottom_manu;
        }
      }

      return null;
    },
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
        path: AppPaths.login,
        name: AppRoutes.login,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),

      GoRoute(
        path: AppPaths.register,
        name: AppRoutes.register,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: const RegisterScreen(),
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

      GoRoute(
        path: AppPaths.chat,
        name: AppRoutes.chat,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: DirectChatScreen(),
        ),
      ),


      GoRoute(
        path: AppPaths.qr_screen,
        name: AppRoutes.qr_screen,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: QrScanScreen(),
        ),
      ),

      GoRoute(
        path: AppPaths.chats_setting,
        name: AppRoutes.chats_setting,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: ChatsSettingsScreen(),
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