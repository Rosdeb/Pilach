import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:messageapp/app/app_initializer.dart';
import 'package:messageapp/core/router/app_router.dart';
import 'package:messageapp/core/theme/app_theme.dart';
import 'package:messageapp/core/theme/theme_provider.dart';
import 'package:messageapp/core/utils/app_colour.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInitializer.init();
  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeState = ref.watch(themeProvider);

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
    );
  }
}
