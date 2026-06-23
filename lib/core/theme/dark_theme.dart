import 'package:flutter/material.dart';

final ColorScheme darkColorScheme = const ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF2563EB),
  onPrimary: Colors.white,
  secondary: Color(0xFF10B981),
  onSecondary: Colors.white,
  error: Colors.red,
  onError: Colors.white,
  background: Color(0xFF0F172A),
  onBackground: Color(0xFFF8FAFC),
  surface: Color(0xFF1E293B),
  onSurface: Color(0xFFF8FAFC),
);

final ThemeData darkThemeData = ThemeData(
  useMaterial3: true,
  colorScheme: darkColorScheme,
  scaffoldBackgroundColor: darkColorScheme.background,
  dividerColor: const Color(0xFF334155),
  dividerTheme: const DividerThemeData(
    color: Color(0xFF334155),
    thickness: 0.5,
  ),

  // Text
  textTheme: const TextTheme(
    headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC)),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFF8FAFC)),
    bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
  ),

  // AppBar
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    backgroundColor: Color(0xFF1E293B),
    foregroundColor: Color(0xFFF8FAFC),
  ),

  // Button
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),

  // Input
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF1E293B),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  ),
);
