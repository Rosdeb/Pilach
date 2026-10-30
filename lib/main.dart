import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/app/app_initializer.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart';
import 'package:app/core/utils/app_colour.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app/core/providers/api_provider.dart';
import 'package:app/core/services/notification_service.dart';
import 'package:app/core/services/outbox_processor.dart';
import 'package:app/core/services/sync_engine.dart';
import 'package:app/Features/Chat/presentation/providers/direct_chat_provider.dart';
import 'package:app/core/constants/app_paths.dart';
import 'package:app/core/widgets/global_keyboard_dismiss.dart';
import 'package:app/Features/bottom_nav_bar/presentation/providers/bottom_nav_provider.dart';
import 'package:app/Features/Me/presentation/providers/setting_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInitializer.init();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeState = ref.watch(themeProvider);
    final socketService = ref.watch(socketServiceProvider);
    final showActiveStatus = ref.watch(showActiveStatusProvider);
    socketService.setPresenceVisibility(showActiveStatus);
    ref.watch(outboxProcessorProvider);
    ref.watch(syncEngineProvider);
    final notificationService = ref.watch(notificationServiceProvider);
    notificationService.configureNavigation(
      activeChatId: () {
        final currentPath = router.routerDelegate.currentConfiguration.uri.path;
        return currentPath == AppPaths.chat
            ? ref.read(currentChatIdProvider)
            : null;
      },
      isMessageSurfaceVisible: () {
        final currentPath = router.routerDelegate.currentConfiguration.uri.path;
        if (currentPath == AppPaths.chat ||
            currentPath == AppPaths.chat_search ||
            currentPath == AppPaths.chat_profile) {
          return true;
        }
        return currentPath == AppPaths.bottom_manu &&
            ref.read(bottomNavProvider) == 0;
      },
      openChat: (chatId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(currentChatIdProvider.notifier).state = chatId;
          router.push(AppPaths.chat);
        });
      },
    );

    // Resolve dark mode status based on the selected ThemeMode and system platform brightness
    final systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = themeState.themeMode == ThemeMode.system
        ? systemBrightness == Brightness.dark
        : themeState.themeMode == ThemeMode.dark;

    // Sync the dark mode state to the AppColors utility
    AppColors.isDarkMode = isDarkMode;

    // Synchronize the resolved brightness status back to the theme provider state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.context.mounted) {
        ref.read(themeProvider.notifier).updateResolvedDarkMode(isDarkMode);
      }
    });

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Community Message App',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeState.themeMode,
      routerConfig: router,
      builder: (context, child) =>
          GlobalKeyboardDismiss(child: child ?? const SizedBox.shrink()),
    );
  }
}
