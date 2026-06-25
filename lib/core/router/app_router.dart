import 'package:flutter/animation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app/Features/Chat/presentation/screens/inbox_screen/direct_chat_screen.dart';
import 'package:app/Features/Chat/presentation/screens/inbox_screen/chat_profile_screen.dart';
import 'package:app/Features/Chat/presentation/screens/chat_search_screen.dart';
import 'package:app/Features/Discovers/presentation/screens/all_stories_screen.dart';
import 'package:app/Features/Discovers/presentation/screens/story_details_screen.dart';
import 'package:app/Features/Me/presentation/screens/block_userlist/block_userlist_screen.dart';
import 'package:app/Features/Me/presentation/screens/chats_setting/chat_theme_selection_screen.dart';
import 'package:app/Features/Me/presentation/screens/chats_setting/chats_settings_screen.dart';
import 'package:app/Features/Me/presentation/screens/chats_setting/chat_wallpaper_screen.dart';
import 'package:app/Features/Me/presentation/screens/edit_profile/edit_profile_screen.dart';
import 'package:app/Features/Me/presentation/screens/email_setting/email_setting_screen.dart';
import 'package:app/Features/Me/presentation/screens/qr_scan/ar_scan_screen.dart';
import 'package:app/Features/Me/presentation/screens/security_privacy/security_privacy_screen.dart';
import 'package:app/Features/Me/presentation/screens/security_privacy/change_password_screen.dart';
import 'package:app/Features/auth/presentation/screens/splash_screen.dart';
import 'package:app/Features/auth/presentation/screens/login_screen.dart';
import 'package:app/Features/auth/presentation/screens/register_screen.dart';
import 'package:app/Features/auth/presentation/screens/verify_email_screen.dart';
import 'package:app/Features/auth/presentation/screens/two_factor_verify_screen.dart';
import 'package:app/Features/auth/presentation/screens/two_factor_email_verify_screen.dart';
import 'package:app/Features/auth/presentation/screens/two_factor_sms_verify_screen.dart';
import 'package:app/Features/Me/presentation/screens/security_privacy/two_factor_settings_screen.dart';
import 'package:app/Features/auth/presentation/providers/auth_provider.dart';

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
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Navigation Error')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Routing Error:\n\n${state.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.go(AppPaths.splash),
                    child: const Text('Return Home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final status = authState.status;

      final isSplashing = state.uri.path == AppPaths.splash;
      final isLoggingIn = state.uri.path == AppPaths.login ||
          state.uri.path == AppPaths.register ||
          state.uri.path == AppPaths.verify_email ||
          state.uri.path == AppPaths.two_factor_verify ||
          state.uri.path == AppPaths.two_factor_email_verify ||
          state.uri.path == AppPaths.two_factor_sms_verify;

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
        path: AppPaths.verify_email,
        name: AppRoutes.verify_email,
        pageBuilder: (context, state) {
          final email = state.extra as String? ?? '';
          return buildSlideTransitionPage(
            key: state.pageKey,
            child: VerifyEmailScreen(email: email),
          );
        },
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
        path: AppPaths.two_factor_settings,
        name: AppRoutes.two_factor_settings,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: const TwoFactorSettingsScreen(),
        ),
      ),

      GoRoute(
        path: AppPaths.two_factor_verify,
        name: AppRoutes.two_factor_verify,
        pageBuilder: (context, state) {
          final args = state.extra as TwoFactorVerifyArgs;
          return buildSlideTransitionPage(
            key: state.pageKey,
            child: TwoFactorVerifyScreen(args: args),
          );
        },
      ),

      GoRoute(
        path: AppPaths.two_factor_email_verify,
        name: AppRoutes.two_factor_email_verify,
        pageBuilder: (context, state) {
          final args = state.extra as TwoFactorEmailVerifyArgs;
          return buildSlideTransitionPage(
            key: state.pageKey,
            child: TwoFactorEmailVerifyScreen(args: args),
          );
        },
      ),

      GoRoute(
        path: AppPaths.two_factor_sms_verify,
        name: AppRoutes.two_factor_sms_verify,
        pageBuilder: (context, state) {
          final args = state.extra as TwoFactorSmsVerifyArgs;
          return buildSlideTransitionPage(
            key: state.pageKey,
            child: TwoFactorSmsVerifyScreen(args: args),
          );
        },
      ),

      GoRoute(
        path: AppPaths.change_password,
        name: AppRoutes.change_password,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: const ChangePasswordScreen(),
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
        path: AppPaths.chat_profile,
        name: AppRoutes.chat_profile,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: const ChatProfileScreen(),
        ),
      ),

      GoRoute(
        path: AppPaths.chat_search,
        name: AppRoutes.chat_search,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: const ChatSearchScreen(),
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

      GoRoute(
        path: AppPaths.all_stories,
        name: AppRoutes.all_stories,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: const AllStoriesScreen(),
        ),
      ),

      GoRoute(
        path: AppPaths.chat_theme_selection,
        name: AppRoutes.chat_theme_selection,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: const ChatThemeSelectionScreen(),
        ),
      ),

      GoRoute(
        path: AppPaths.chat_wallpaper,
        name: AppRoutes.chat_wallpaper,
        pageBuilder: (context, state) => buildSlideTransitionPage(
          key: state.pageKey,
          child: const ChatWallpaperScreen(),
        ),
      ),

      GoRoute(
        path: AppPaths.story_details,
        name: AppRoutes.story_details,
        pageBuilder: (context, state) {
          final index = state.extra as int? ?? 0;
          return buildSlideTransitionPage(
            key: state.pageKey,
            child: StoryDetailsScreen(storyIndex: index),
          );
        },
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