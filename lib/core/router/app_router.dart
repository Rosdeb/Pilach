import 'package:app/Features/Events/presentation/screens/event_screen.dart';
import 'package:app/Features/Market/presentation/screens/market_screen.dart';
import 'package:app/Features/News/presentation/screens/news_screen.dart';
import 'package:app/Features/Donate/presentation/screens/donate_screen.dart';
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
import '../../Features/Chat/data/models/chat_model.dart';
import '../../Features/bottom_nav_bar/presentation/screens/bottom_manu_wrappers.dart';
import '../constants/app_constants.dart' hide AppPaths;
import '../constants/app_paths.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Auth refresh listenable
// ─────────────────────────────────────────────────────────────────────────────

class RiverpodRouterRefreshListenable extends ChangeNotifier {
  RiverpodRouterRefreshListenable(Ref ref) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transition builders
// ─────────────────────────────────────────────────────────────────────────────

/// iOS-style slide: new page comes in from right, old page slides left (parallax).
/// Runs entirely as GPU layer transforms — zero Dart rebuilds during animation.
CustomTransitionPage<T> _slidePage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    maintainState: true,
    // 260 ms feels native on both 60 Hz and 120 Hz devices.
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Incoming page slides in from the right.
      final slideIn = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,      // fast start → smooth land
        reverseCurve: Curves.easeInCubic,
      ));

      // Outgoing page slides slightly left (iOS depth / parallax cue).
      // secondaryAnimation runs 0→1 as the new page pushes over this one.
      final slideOut = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.25, 0.0),
      ).animate(CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ));

      return SlideTransition(
        position: slideOut,   // previous page drifts left
        child: SlideTransition(
          position: slideIn,  // new page arrives from right
          child: child,
        ),
      );
    },
  );
}

/// Fade-only transition — best for overlay-style screens (search, modals).
CustomTransitionPage<T> _fadePage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    maintainState: true,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 140),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        ),
        child: child,
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Router
// ─────────────────────────────────────────────────────────────────────────────

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = RiverpodRouterRefreshListenable(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppPaths.splash,
    refreshListenable: refreshListenable,

    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Navigation Error')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
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

    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final status = authState.status;
      final path = state.uri.path;

      final isSplash = path == AppPaths.splash;
      final isAuth =
          path == AppPaths.login ||
              path == AppPaths.register ||
              path == AppPaths.verify_email ||
              path == AppPaths.two_factor_verify ||
              path == AppPaths.two_factor_email_verify ||
              path == AppPaths.two_factor_sms_verify;

      if (status == AuthStatus.initial) return null;

      if (status == AuthStatus.unauthenticated) {
        if (!isAuth && !isSplash) return AppPaths.login;
      }

      if (status == AuthStatus.authenticated) {
        // Only redirect login/register/verify_email to bottom menu.
        // We allow authenticated users to visit two_factor_*_verify screens for enrollment.
        final isStrictAuth = path == AppPaths.login ||
                             path == AppPaths.register ||
                             path == AppPaths.verify_email;
                             
        if (isStrictAuth || isSplash) return AppPaths.bottom_manu;
      }

      return null;
    },

    routes: [
      // ── Auth flow ──────────────────────────────────────────────────────────
      GoRoute(
        path: AppPaths.splash,
        name: AppRoutes.splash,
        pageBuilder: (c, s) => _fadePage(key: s.pageKey, child: const SplashScreen()),
      ),
      GoRoute(
        path: AppPaths.login,
        name: AppRoutes.login,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: const LoginScreen()),
      ),
      GoRoute(
        path: AppPaths.register,
        name: AppRoutes.register,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: const RegisterScreen()),
      ),
      GoRoute(
        path: AppPaths.verify_email,
        name: AppRoutes.verify_email,
        pageBuilder: (c, s) => _slidePage(
          key: s.pageKey,
          child: VerifyEmailScreen(email: s.extra as String? ?? ''),
        ),
      ),
      GoRoute(
        path: AppPaths.two_factor_verify,
        name: AppRoutes.two_factor_verify,
        pageBuilder: (c, s) => _slidePage(
          key: s.pageKey,
          child: TwoFactorVerifyScreen(args: s.extra as TwoFactorVerifyArgs),
        ),
      ),
      GoRoute(
        path: AppPaths.two_factor_email_verify,
        name: AppRoutes.two_factor_email_verify,
        pageBuilder: (c, s) => _slidePage(
          key: s.pageKey,
          child: TwoFactorEmailVerifyScreen(args: s.extra as TwoFactorEmailVerifyArgs),
        ),
      ),
      GoRoute(
        path: AppPaths.two_factor_sms_verify,
        name: AppRoutes.two_factor_sms_verify,
        pageBuilder: (c, s) => _slidePage(
          key: s.pageKey,
          child: TwoFactorSmsVerifyScreen(args: s.extra as TwoFactorSmsVerifyArgs),
        ),
      ),

      // ── Main shell ─────────────────────────────────────────────────────────
      GoRoute(
        path: AppPaths.bottom_manu,
        name: AppRoutes.bottom_manu,
        pageBuilder: (c, s) => _fadePage(key: s.pageKey, child: BottomMenuWrapper()),
      ),

      // ── Chat ───────────────────────────────────────────────────────────────
      GoRoute(
        path: AppPaths.chat,
        name: AppRoutes.chat,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: DirectChatScreen()),
      ),
      GoRoute(
        path: AppPaths.chat_profile,
        name: AppRoutes.chat_profile,
        pageBuilder: (c, s) {
          final chat = s.extra as ChatModel;
          return _slidePage(key: s.pageKey, child: ChatProfileScreen(chat: chat));
        },
      ),
      GoRoute(
        // Search feels more like an overlay → fade, not slide
        path: AppPaths.chat_search,
        name: AppRoutes.chat_search,
        pageBuilder: (c, s) => _fadePage(key: s.pageKey, child: const ChatSearchScreen()),
      ),

      // ── Me / Settings ──────────────────────────────────────────────────────
      GoRoute(
        path: AppPaths.edit_profile,
        name: AppRoutes.edit_profile,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: EditProfileScreen()),
      ),
      GoRoute(
        path: AppPaths.email_setting,
        name: AppRoutes.email_setting,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: EmailSettingsScreen()),
      ),
      GoRoute(
        path: AppPaths.security_privacy,
        name: AppRoutes.security_privacy,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: SecurityPrivacyScreen()),
      ),
      GoRoute(
        path: AppPaths.two_factor_settings,
        name: AppRoutes.two_factor_settings,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: const TwoFactorSettingsScreen()),
      ),
      GoRoute(
        path: AppPaths.change_password,
        name: AppRoutes.change_password,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: const ChangePasswordScreen()),
      ),
      GoRoute(
        path: AppPaths.block_userlist,
        name: AppRoutes.block_userlist,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: const BlockedUsersScreen()),
      ),
      GoRoute(
        path: AppPaths.chats_setting,
        name: AppRoutes.chats_setting,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: ChatsSettingsScreen()),
      ),
      GoRoute(
        path: AppPaths.chat_theme_selection,
        name: AppRoutes.chat_theme_selection,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: const ChatThemeSelectionScreen()),
      ),
      GoRoute(
        path: AppPaths.chat_wallpaper,
        name: AppRoutes.chat_wallpaper,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: const ChatWallpaperScreen()),
      ),
      GoRoute(
        path: AppPaths.qr_screen,
        name: AppRoutes.qr_screen,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: QrScanScreen()),
      ),

      // ── Discovers ──────────────────────────────────────────────────────────
      GoRoute(
        path: AppPaths.all_stories,
        name: AppRoutes.all_stories,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: const AllStoriesScreen()),
      ),
      GoRoute(
        path: AppPaths.story_details,
        name: AppRoutes.story_details,
        pageBuilder: (c, s) => _slidePage(
          key: s.pageKey,
          child: StoryDetailsScreen(storyIndex: s.extra as int? ?? 0),
        ),
      ),

      // ── Other screens ──────────────────────────────────────────────────────
      GoRoute(
        path: AppPaths.event_screen,
        name: AppRoutes.event_screen,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: const EventScreen()),
      ),
      GoRoute(
        path: AppPaths.market_screen,
        name: AppRoutes.market_screen,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: const MarketScreen()),
      ),
      GoRoute(
        path: AppPaths.news_screen,
        name: AppRoutes.news_screen,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: const NewsScreen()),
      ),
      GoRoute(
        path: AppPaths.donate_screen,
        name: AppRoutes.donate_screen,
        pageBuilder: (c, s) => _slidePage(key: s.pageKey, child: const DonateScreen()),
      ),
    ],
  );
});